# Disaster Recovery Runbook

## Overview

| Scenario | RTO Target | RPO | Method |
|----------|-----------|-----|--------|
| Single worker node failure | 5 min | 0 (stateless) | K3s auto-reschedule |
| Master node failure | 30 min | Last backup | Restore VM + rejoin |
| Full cluster loss | 60 min | Last backup | Terraform + Ansible rebuild |
| Proxmox host failure | 15 min | Last backup | HA failover / restore VM |

---

## Scenario 1: Worker Node Down

**Detection:** Alert `KubeNodeNotReady` (auto)

**Recovery:**
```bash
# 1. Check if VM is running on Proxmox
ssh root@10.0.1.1 "qm status 101"  # worker-01
ssh root@10.0.1.1 "qm status 102"  # worker-02

# 2. Start VM if stopped
ssh root@10.0.1.1 "qm start 101"

# 3. If VM corrupted — restore from backup
ssh root@10.0.1.1 "qmrestore /var/lib/vz/dump/vzdump-qemu-101-*.vma.zst 101 --force"

# 4. Rejoin cluster (if k3s agent broken)
ssh devops@10.0.1.11 "sudo systemctl restart k3s-agent"
```

---

## Scenario 2: Master Node Down

**Detection:** kubectl unreachable, all alerts stop

**Recovery:**
```bash
# 1. Try restart VM
ssh root@10.0.1.1 "qm start 100"

# 2. If VM corrupted — restore from backup
ssh root@10.0.1.1 "qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 100 --force"

# 3. Verify k3s master
ssh devops@10.0.1.10 "sudo systemctl status k3s && kubectl get nodes"

# 4. If full rebuild needed
cd terraform/ && terraform apply -auto-approve -target=proxmox_vm_qemu.k8s_master
cd ../ansible/ && ansible-playbook playbook-k3s.yaml --limit k8s-master
```

---

## Scenario 3: Full Cluster Rebuild

**When:** Both Proxmox hosts alive but all K8s VMs lost

```bash
# 1. Provision VMs (5 min)
cd terraform/
terraform apply -auto-approve

# 2. Install K3s cluster (10 min)
cd ../ansible/
ansible-playbook playbook-k3s.yaml

# 3. Install Zabbix agent (2 min)
ansible-playbook playbook-zabbix-agent.yaml

# 4. Deploy stack via Helm (15 min)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Namespaces
kubectl apply -f k8s/namespaces/namespaces.yaml

# Sealed Secrets controller
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f helm/kube-prometheus-stack/values.yaml -n monitoring --create-namespace

# Loki
helm upgrade --install loki-stack grafana/loki-stack \
  -f helm/loki-stack/values.yaml -n monitoring

# Zabbix
helm upgrade --install zabbix zabbix-community/zabbix \
  -f helm/zabbix/values.yaml -n zabbix --create-namespace

# Traefik
helm upgrade --install traefik traefik/traefik \
  -f helm/traefik/values.yaml -n traefik --create-namespace

# ArgoCD
helm install argocd argo/argo-cd -n argocd --create-namespace

# 5. Apply configs
kubectl apply -f k8s/network-policies/
kubectl apply -f k8s/network-policies/egress-policies.yaml
kubectl apply -f k8s/monitoring/custom-alerts.yaml
kubectl apply -f k8s/dns/bind9/
kubectl apply -f k8s/monitoring/lark-alert-adapter/
kubectl apply -f argocd/apps/applications.yaml

# 6. Apply hardening
bash scripts/apply-k3s-hardening.sh

# 7. Verify
bash scripts/morning-check.sh
bash scripts/test-netpol.sh
```

---

## Scenario 4: Proxmox Host Failure

**If pve01 (primary) down:**
- VMs on pve01: k8s-master (100), k8s-worker-01 (101)
- VMs on pve02: k8s-worker-02 (102)

```bash
# Check if Corosync sees the other node
ssh root@10.0.1.2 "pvecm status"

# Restore VMs from backup on pve02 (if has enough resources)
ssh root@10.0.1.2 "qmrestore /path/to/backup/vzdump-qemu-100-*.vma.zst 100"
ssh root@10.0.1.2 "qmrestore /path/to/backup/vzdump-qemu-101-*.vma.zst 101"
ssh root@10.0.1.2 "qm start 100 && qm start 101"
```

---

## Backup Schedule

| What | When | Retention | Location |
|------|------|-----------|----------|
| All VMs (snapshot) | Sunday 02:00 | keep-last=2, keep-weekly=4 | local (/var/lib/vz) |
| etcd (k3s auto) | Every hour | 5 snapshots | /var/lib/rancher/k3s/server/db/snapshots |
| Git repo | Every push | Unlimited | GitHub |

> ⚠️ **CORRECTION (2026-06-16):** k3s here uses **SQLite (kine)**, NOT etcd — the
> `db/snapshots` path above never existed. A real datastore backup is now in place:
> `scripts/k3s-backup.sh` (cron 03:00 on master, as `devops`) does a consistent
> `sqlite3 .backup` of `state.db` + tars the local-path PV data from the workers and
> ships everything to **pve01:/var/lib/vz/k3s-backups** (a separate disk), 7-day
> retention. This closes the gap that caused total data loss on 2026-06-16
> (local-path PVs are wiped by `k3s-uninstall.sh` and were not backed up anywhere).

---

## Post-Recovery Checklist

- [ ] All 3 nodes Ready
- [ ] All pods Running (no CrashLoop)
- [ ] ArgoCD apps Synced + Healthy
- [ ] DNS resolution works (`bash scripts/test-netpol.sh`)
- [ ] Prometheus scraping all targets
- [ ] Alerts reaching Lark
- [ ] Zabbix monitoring all 14 hosts
- [ ] Disk usage < 75%
