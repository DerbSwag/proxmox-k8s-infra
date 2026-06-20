# RUNBOOK — Company Lab Infrastructure

> Proven procedures — วิธีแก้ปัญหาที่พบบ่อยในคลัสเตอร์
> Updated: 2026-06-15

## Quick Reference

| Item | Value |
|------|-------|
| Cluster | k3s (3 nodes: 1 master + 2 workers) |
| Hypervisor | Proxmox VE |
| Master IP | `10.0.1.10` |
| GitOps | ArgoCD (`argocd` namespace) |
| Monitoring | Prometheus + Grafana + Loki (`monitoring` ns) |
| Alert | Lark webhook → lark-alert-adapter pod |
| DNS | CoreDNS (k3s built-in) |
| Backup | Verify cron — `scripts/verify-backups.sh` |

---

## 🔴 Disk Full (k8s node)

**When:** Alert "FS Space critically low"

```bash
sudo du -sh /var/lib/* | sort -rh | head -10
sudo crictl rmi --prune
sudo journalctl --vacuum-size=200M
# ถ้ายังไม่พอ — extend LV
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

---

## 🔴 Node NotReady

**When:** `kubectl get nodes` shows NotReady

```bash
ssh devops@<node-ip>
sudo systemctl status k3s-agent   # worker
sudo systemctl restart k3s-agent
# ถ้ายังไม่ได้ → sudo reboot
```

---

## 🔴 Pod CrashLoopBackOff

```bash
kubectl logs <pod> -n <ns> --previous
kubectl describe pod <pod> -n <ns>
# Common: OOMKilled → เพิ่ม memory limit
#          Config error → แก้ ConfigMap/Secret
#          Image pull → เช็ค tag / registry
```

---

## 🔴 ArgoCD OutOfSync

```bash
# ดู error
kubectl get app <app> -n argocd -o jsonpath='{.status.conditions}'
# Immutable field → ลบ resource เดิม
kubectl delete deploy <name> -n <ns>
# Force sync
kubectl annotate app <app> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

---

## 🔴 DNS Resolution Failure

**When:** Pods resolve ไม่ได้, `nslookup kubernetes.default` fail

```bash
# Quick test
kubectl run -n <ns> dnstest --rm -it --image=busybox:1.36 -- nslookup kubernetes.default
# ถ้า refused → NetworkPolicy block DNS
kubectl get netpol -n kube-system
kubectl apply -f k8s/network-policies/allow-dns.yaml
```

**Ref:** `docs/incidents/2026-05-11-dns-blocked-by-networkpolicy.md`

---

## 🔴 NetworkPolicy blocks API server (post-DNAT)

**When:** Pods ใน ns ที่มี deny-egress เข้า API server ไม่ได้, kube-state-metrics CrashLoop

**Cause:** kube-router evaluates policy after DNAT — traffic ไป 10.43.0.1:443 เห็นเป็น 10.0.1.10:6443

```bash
# Verify
kubectl exec -n <ns> <pod> -- wget -qO- --no-check-certificate --timeout=3 https://10.43.0.1:443/version
# Fix: เพิ่ม egress rule อนุญาต 10.0.1.x/24 port 6443
# แก้ที่: k8s/network-policies/egress-policies.yaml
```

**Ref:** `docs/incidents/incident-2026-0515-netpol-blocks-apiserver.md`

---

## 🔴 Prometheus No Active Targets

```bash
# เช็ค API server access
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- --no-check-certificate --timeout=3 https://10.43.0.1:443/version
# ถ้า fail → ดู NetworkPolicy section ด้านบน
# ถ้า OK → restart operator + prometheus
kubectl delete pod -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-operator
kubectl delete pod -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0
```

---

## 🟡 Proxmox apt update failed (401)

```bash
mv /etc/apt/sources.list.d/ceph.sources{,.disabled}
mv /etc/apt/sources.list.d/pve-enterprise.sources{,.disabled}
apt-get update
```

---

## 🟡 Lark Alert ไม่ส่ง

```bash
kubectl get pods -n monitoring -l app=lark-alert-adapter
kubectl logs -n monitoring -l app=lark-alert-adapter --tail=20
# Test
echo '{"alerts":[{"status":"firing","labels":{"alertname":"Test"}}]}' | \
  curl -s -X POST http://10.42.0.32:5001 -H Content-Type:application/json -d @-
```

---

## 🟡 VM ไม่ start บน Proxmox

```bash
qm status <vmid>
qm unlock <vmid>
qm start <vmid>
```

---

## Health Check (Morning)

```bash
# ใช้ script สำเร็จรูป
bash scripts/morning-check.sh
# หรือ manual:
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed
kubectl get app -n argocd
```

---

## Secrets & Security

| Secret | Location | Rotate |
|--------|----------|--------|
| kubeconfig | `~/.kube/config` on master | k3s auto-manages |
| ArgoCD admin | `argocd-initial-admin-secret` | `argocd account update-password` |
| Sealed Secrets key | `sealed-secrets` ns | `kubeseal --re-encrypt` |
| Grafana admin | Helm values (sealed) | Update sealed secret |
| Lark webhook URL | ConfigMap in monitoring | Lark bot settings |

- ห้าม commit: `kubeconfig`, `.tfvars` with real values, sealed secret private key
- Secret rotation plan: `docs/secret-rotation-plan.md`

---

## 🟢 Add a host to Zabbix (agent or SNMP camera)

**Web:** http://10.0.1.10:30080 (Admin / zabbix)

Fastest = API. From master (reaches the Zabbix web NodePort):

```bash
# Agent host (Linux=template 10001, Windows=10081); SNMP camera = Generic by SNMP (10563)
ZBX=http://localhost:30080/api_jsonrpc.php
TOKEN=$(curl -s -X POST $ZBX -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' \
  | sed -E 's/.*"result":"([^"]+)".*/\1/')

# --- SNMP camera example (Hikvision, v2c community 'public') ---
curl -s -X POST $ZBX -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"host.create","params":{
  "host":"CCTV-05",
  "interfaces":[{"type":2,"main":1,"useip":1,"ip":"10.0.1.x","dns":"","port":"161",
    "details":{"version":2,"community":"{$SNMP_COMMUNITY}"}}],
  "groups":[{"groupid":"23"}],
  "templates":[{"templateid":"10563"}],
  "macros":[{"macro":"{$SNMP_COMMUNITY}","value":"public"}]},"auth":"'$TOKEN'","id":2}'
```

Then reload config and verify:
```bash
kubectl exec -n zabbix deploy/zabbix-zabbix-server -- zabbix_server -R config_cache_reload
# verify SNMP first from master:  snmpget -v2c -c public <ip> 1.3.6.1.2.1.1.1.0
```

- Group IDs: Linux servers=2, Hypervisors=7, Windows PCs=22, CCTV=23
- Bulk re-add (DR): `scripts/zabbix-readd-hosts.sh` (keep host list in sync there + README)
- Cameras: verify v2c community = `public`, SNMP port 161 (Hikvision web → Network → Advanced → SNMP)

---

## 🟢 Worker host-port blocked (9100/10250 down, kubectl exec 502)

**Symptom:** Prometheus TargetDown for a worker's node-exporter/kubelet; `kubectl top`
shows `<unknown>`; `kubectl exec/logs` into pods on that worker returns 502. NodePort
services still work. Root cause is TWO things stacked (see incident 2026-06-16-worker-duplicate-ip):
1. dual IP on ens18 (static + leftover DHCP) → asymmetric routing
2. missing UFW rules for 9100/10250

**Fix (per worker; SSH-safe with auto-revert):**
```bash
# on the worker (via master jump), as root:
# 1) safety net: auto-restore in 90s unless we disarm
cp -f /etc/netplan/50-cloud-init.yaml /root/50-cloud-init.yaml.bak 2>/dev/null
touch /root/REVERT_ARMED
nohup bash -c 'sleep 90; [ -f /root/REVERT_ARMED ] && cp -f /root/50-cloud-init.yaml.bak /etc/netplan/50-cloud-init.yaml && netplan apply' &>/dev/null &
# 2) remove DHCP override + disable cloud-init net
rm -f /etc/netplan/50-cloud-init.yaml
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
# 3) add the missing host-port firewall rules
ufw allow from 10.0.1.x/24 to any port 9100 proto tcp
ufw allow from 10.0.1.x/24 to any port 10250 proto tcp
netplan apply
ip -4 addr show ens18 | grep inet          # expect ONLY the static IP
# 4) if SSH still works -> disarm:
rm -f /root/REVERT_ARMED
```
Verify from master: `timeout 4 bash -c 'echo >/dev/tcp/<worker-ip>/9100'` (OPEN),
`kubectl top nodes`, `kubectl exec` into a pod on that worker.

> ⚠️ Do master LAST and only with Proxmox console open (losing master SSH = cluster blind).
> Scripts pushed from Windows: strip CRLF with `tr -d '\r'` or netplan misbehaves silently.

---

## 🔴 Proxmox host down / cluster non-quorate (pve02 flapping)

**When:** a Proxmox node drops (ping/SSH/web dead); `pvecm status` shows `Quorate: No`,
Nodes 1/2; the k8s worker on that host goes NotReady. (See incident
2026-06-17-pve02-hardware-instability — recurring hardware flap.)

```bash
# from the surviving host (pve01):
pvecm status | grep -iE 'Nodes|Quorate'
ping -c2 10.0.1.2            # is the other host reachable at all?

# If the dead host will stay down a while, let the survivor manage VMs:
pvecm expected 1                   # pve01 becomes quorate alone (temporary)

# k8s side — stop new pods landing on the dead worker:
kubectl cordon k8s-worker-02       # uncordon when it returns
```

When the host comes back (uptime confirms a reboot), VMs auto-start (`onboot=1`),
worker rejoins, and quorum returns automatically — expect a short alert burst that
self-resolves. **Hardware fix must be done at the machine** (LEDs/BIOS/memtest/SMART);
ping-but-services-dead that recurs across power cycles = hardware, not software.

> ⚠️ Backups of a VM live on its host's local disk. If that disk is the suspect,
> copy the VM backup off the failing host first.

---

## Related Docs

- `docs/runbook.md` — detailed procedures (full version)
- `docs/architecture.md` — cluster architecture diagram
- `docs/disaster-recovery.md` — DR plan & test scripts
- `docs/network-policy-review-2026-05-11.md` — netpol analysis
- `INCIDENTS.md` — incident log
