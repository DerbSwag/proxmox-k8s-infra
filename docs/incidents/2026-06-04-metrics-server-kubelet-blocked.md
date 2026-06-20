# Incident: metrics-server cannot scrape worker kubelets (10250)

**Date:** 2026-06-04
**Severity:** Low (cosmetic)
**Status:** OPEN — deferred to next maintenance window
**Impact:** `kubectl top nodes/pods` shows `<unknown>` for both workers. HPA would be affected. Actual workloads unaffected.

## Symptoms

- `kubectl top nodes` → workers report `<unknown>`
- metrics-server logs: `Failed to scrape node, timeout to access kubelet ... 10250 context deadline exceeded`
- master → worker:10250 times out; worker → master:10250 works fine

## Diagnosis (confirmed via tcpdump)

- master sends SYN to worker:10250 → no SYN-ACK returned (retransmits)
- iptables ACCEPT rule for 10250 matches (pkt counter increments) but kernel never replies
- Packet reaches NIC and passes filter, but is dropped before the socket by `KUBE-ROUTER-INPUT` chain (k3s built-in kube-router netpol controller)

## What did NOT fix it

- UFW allow 10250 (rule present, pkts>0, no effect)
- iptables -I INPUT ACCEPT 10250 at top (no effect)
- `systemctl restart k3s` on worker-02 (no effect)

These confirm the drop happens inside the kube-router netpol layer, not ufw/filter.

## Root Cause (probable)

Known k3s + kube-router interaction with host-destined traffic after node reboot. The KUBE-ROUTER-INPUT chain does not whitelist host port 10250 for cross-node source IPs, so kubelet API traffic from metrics-server pod (SNAT'd to node IP) is dropped.

## Planned Fix (maintenance window)

Restart the k3s control-plane / kube-router on master to rebuild the full netpol ruleset cleanly:

```bash
# On master, during maintenance window:
sudo systemctl restart k3s
# verify after:
kubectl top nodes
```

Higher risk (briefly disrupts API server) — do NOT run during business hours.

## Workaround / Current State

Skipped. Node metrics still available via Prometheus node-exporter (unaffected). Only kubectl top / HPA depend on metrics-server.

---

## UPDATE 2026-06-08 — escalation + new findings (worker-01 isolated)

Attempted to fix during business hours. This made things worse before stabilizing. Key learnings:

### Scope refined
- Issue is now **isolated to worker-01 only** (worker-02 recovered after its clean reboot on 06-03).
- Affects BOTH `kubelet:10250` AND `node-exporter:9100` on worker-01 — i.e. all host-destined ports from cross-node sources, not just kubelet.
- Confirmed even worker-01 → its OWN ens18 IP:9100 is dropped (only 127.0.0.1 works), so it is host-local netfilter, not purely cross-node.
- UFW had no rule for 9100 (only 10250/8472/6443 were added earlier). Added 9100 on all nodes — still did not fix worker-01 (rule present, traffic still dropped before socket).

### worker-01 has a corrupt systemd unit state
- worker-01 has BOTH `k3s.service` (unit file on disk, enabled) AND a leftover `k3s-agent.service` (runtime-only, unit file missing).
- `systemctl is-active k3s-agent` reports active while `systemctl is-enabled k3s-agent` reports not-found — inconsistent state.
- Restarting "k3s" vs "k3s-agent" hit different services on different attempts → kube-router rules never rebuilt cleanly. This is the likely reason worker-01 won't recover like worker-02 did.

### What did NOT fix worker-01 (this round)
- UFW allow 9100 + reload
- `iptables -F && -t nat -F && -t mangle -F` + restart k3s
- Two full VM reboots
- conntrack flush (note: `conntrack` CLI not installed on nodes — earlier "success" was a no-op)

### COLLATERAL DAMAGE (important)
Flushing iptables + restarting k3s on worker-01 while it was drained caused all pods to pile onto master + worker-02. **Master (4GB RAM) hit OOM** (free_mem dropped to ~140MB), sshd hung (banner-exchange refused), and the control-plane became unreachable. This triggered the alert burst: CoreDNS down, apiserver TargetDown 100%, etc.

Recovery steps:
1. `qm reboot 200` via Proxmox (SSH was unresponsive)
2. Master came back but OOM'd again immediately on k3s start (worker-01 still cordoned → workload concentrated)
3. **Increased master VM RAM 4GB → 6GB** via Proxmox (`qm set 200 --memory 6144`) — this resolved the OOM. This is the permanent fix for the long-standing master memory pressure noted on 06-03.
4. Uncordoned worker-01, restarted its k3s, cluster re-stabilized.
5. Unsealed Vault (sealed again due to worker-01 drain — standalone Vault does not auto-unseal).

### Revised Planned Fix (maintenance window)
worker-01 needs a **clean k3s agent reinstall**, not just a restart:
```bash
# On worker-01, during maintenance window:
sudo systemctl stop k3s k3s-agent 2>/dev/null
sudo /usr/local/bin/k3s-agent-uninstall.sh   # or k3s-uninstall.sh as appropriate
# remove leftover units, then reinstall agent joined to master
# verify: master -> worker-01:9100 and :10250 reachable; kubectl top nodes
```

### Hard lessons
- **Do NOT flush iptables / restart k3s on a drained node while master RAM is tight** — the reschedule storm OOMs the control-plane.
- Master needed 6GB minimum (now applied). Consider bumping workers too.
- Standalone Vault must be unsealed after every restart — automate (auto-unseal) or expect manual step.
- `conntrack` CLI is not installed on these nodes.
