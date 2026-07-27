# Root Cause + Fix: Worker host-port blocked (duplicate static IP)

**Date analysed:** 2026-06-16
**Status:** ✅ RESOLVED 2026-06-17 (fixed via SSH with auto-revert safety net; no console needed in the end)
**Explains:** the entire "worker-01 host-port 9100/10250 blocked" saga since 2026-06-04,
including why restarts/reinstalls/reboots never fixed it, and why it later affected
worker-02 too.

## The real root cause

All three node VMs were cloned from the same master template and **never had their
netplan IP corrected**. Every node has:

```
/etc/netplan/00-installer-config.yaml   -> static address 192.0.2.10/24  (MASTER's IP!)
/etc/netplan/50-cloud-init.yaml         -> dhcp4: true
```

So on EVERY node the interface ends up with:
- `192.0.2.10/24` (static — duplicated across all 3 nodes!)
- a rotating DHCP lease (.94 / .166 / .167 — changes over time)
- default route egressing via the DHCP src address

Meanwhile k3s registered the nodes with InternalIP .140/.141/.142 (correct), and the
LAN/ARP maps .141→worker1 MAC, .142→worker2 MAC (correct). The mismatch between the
interface's actual addresses (.140 + DHCP) and the IP the cluster/LAN expects (.141/.142)
causes **asymmetric routing**: a SYN arriving on .141 is answered from the wrong source
address (.140 or DHCP), so the reply is dropped / never associated with the connection.

### Why it presents as "host ports blocked"
- NodePort (e.g. Zabbix 30080) works because kube-proxy DNATs and the path differs.
- Pod-network traffic works (flannel VXLAN, separate addressing).
- But **direct host-port hits to 9100 (node-exporter) and 10250 (kubelet)** from another
  node land on the misconfigured host IP and get no valid reply → Prometheus TargetDown,
  `kubectl exec/logs` 502 for pods on that node.
- master can scrape itself (same-node, loopback-ish path) → master targets UP, workers DOWN.

### Why earlier "fixes" failed
UFW rules, iptables flushes, k3s restarts, cold reboots, even a full clean reinstall —
none touched netplan, so the duplicate-IP/asymmetric-routing condition persisted.

## Evidence
- `ip -4 addr show ens18` on each worker: shows `192.0.2.10/24` + a dynamic DHCP IP.
- netplan files identical on all 3 nodes (static .140 + dhcp4:true).
- k3s `INTERNAL-IP`: .140/.141/.142 (correct, from --node-ip / original lease).
- ARP on master: .141→worker1 MAC, .142→worker2 MAC.
- Prometheus `up`: only 192.0.2.10 targets =1; .141 and .142 node-exporter+kubelet =0.

## SAFE FIX (maintenance window, with Proxmox console open)

> ⚠️ Changing the IP can drop your SSH session. Always have the Proxmox **noVNC console**
> open for each VM before editing. Fix ONE node at a time. Do master LAST.

For each node, set a clean static netplan with the CORRECT unique IP and no DHCP:

```yaml
# /etc/netplan/00-installer-config.yaml   (worker-01 example: use .141; worker-02 .142; master .140)
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: false
      addresses:
        - 192.0.2.11/24      # <-- unique per node
      routes:
        - to: default
          via: 192.0.2.x
      nameservers:
        addresses: [192.0.2.x, 8.8.8.8]
```

Steps per node (via Proxmox console, NOT ssh, to survive IP change):
```bash
# 1. remove the cloud-init dhcp override so it won't re-add DHCP
sudo rm -f /etc/netplan/50-cloud-init.yaml
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
# 2. write the correct 00-installer-config.yaml (unique IP, dhcp4:false) as above
sudo chmod 600 /etc/netplan/*.yaml
# 3. apply with auto-rollback safety net
sudo netplan try        # press ENTER to keep if network still works; auto-reverts in 120s otherwise
# 4. verify single correct IP
ip -4 addr show ens18    # should show ONLY .141/.142/.140, no .94/.166/.167
```

Order: **worker-01 → worker-02 → master** (master last; if master SSH drops you still
have console). After each node: from master run
`timeout 4 bash -c 'echo > /dev/tcp/<nodeip>/9100'` → should be OPEN.

### Post-fix verification
```bash
kubectl get nodes -o wide          # InternalIP matches the single static IP
# Prometheus: node-exporter + kubelet targets all UP for all 3 nodes
# kubectl top nodes                # all nodes report (no <unknown>)
# kubectl exec into a pod on each node                # no 502
```

### Rollback
`netplan try` auto-reverts after 120s if you don't confirm. If a node becomes
unreachable and console is stuck, reset the VM via Proxmox; the old (broken but
working-for-k3s) config returns on boot only if you didn't delete 50-cloud-init —
so keep a copy: `sudo cp /etc/netplan/50-cloud-init.yaml /root/50-cloud-init.yaml.bak`.

## Long-term
- Fix the VM template so clones don't carry the master's static IP.
- Decide on static IPs vs DHCP reservations cluster-wide; don't mix both.

## RESOLUTION (2026-06-17)
Fixed **both workers** via SSH (no Proxmox console needed in the end) using an
auto-revert safety net (background job that restores config in 90s unless cancelled):

1. Removed `/etc/netplan/50-cloud-init.yaml` (the `dhcp4: true` override).
2. Disabled cloud-init networking: `echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`.
3. `netplan apply` → interface left with ONLY the correct static IP (.141 / .142).

**Second cause found during the fix:** after removing DHCP, host ports were STILL
blocked because the **UFW rules for 9100/10250 were missing** (they existed before the
2026-06-16 DR rebuild but were lost when the agent was reinstalled). Re-added:
```bash
ufw allow from 192.0.2.x/24 to any port 9100 proto tcp     # node-exporter
ufw allow from 192.0.2.x/24 to any port 10250 proto tcp    # kubelet
```
So the real root cause was **two things stacked**: dual-IP asymmetric routing **AND**
missing UFW host-port rules. Both had to be fixed.

### Gotchas during the fix
- The first attempt's safety-net **reverted the change** before we disarmed it (race) —
  the DHCP override came back. Re-ran and disarmed promptly.
- Scripts pushed from Windows carried **CRLF**; `netplan`/bash silently misbehaved until
  stripped with `tr -d '\r'` on the node/master.

### Verified after fix
- `ip -4 addr show ens18` → single static IP per node (no DHCP secondary).
- master → worker 9100 & 10250 = OPEN (both workers).
- Prometheus: all node-exporter + kubelet targets UP (3/3 nodes).
- `kubectl top nodes` → all nodes report (no `<unknown>`).
- `kubectl exec` into a pod on worker-01 → works (was 502).

Master (.140) was left untouched — it already had the correct static IP and its host
ports were never blocked (it could scrape itself). No master change required.
