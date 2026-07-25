# Proxmox K8s Infrastructure Lab [![Validate](https://github.com/DerbSwag/proxmox-k8s-infra/actions/workflows/validate.yml/badge.svg)](https://github.com/DerbSwag/proxmox-k8s-infra/actions/workflows/validate.yml)

Sanitized GitOps portfolio repository for a Proxmox + k3s infrastructure lab.

---

## 📈 Key Results

| Metric | Value |
|--------|-------|
| Nodes | 3 (k3s v1.34.5 on Proxmox) |
| Hosts monitored (Zabbix) | 14 (Linux, Windows, CCTV, Proxmox) |
| ArgoCD apps (auto-sync) | 7 |
| Incidents documented | 10 |
| DR rebuild time | < 60 min (Terraform + Ansible) |
| Security scan (Kubescape) | MITRE 66% / NSA 65% |
| Alerting | Prometheus → Lark (real-time) |

## 🖥️ Cluster Info

| Node | IP | Role | Specs |
|------|----|------|-------|
| k8s-master | 10.0.1.10 | Control Plane | 2 vCPU / 4GB RAM / 50GB |
| k8s-worker-01 | 10.0.1.11 | Worker | 2 vCPU / 4GB RAM / 50GB |
| k8s-worker-02 | 10.0.1.12 | Worker | 2 vCPU / 4GB RAM / 50GB |
| linux-lab | 10.0.1.20 | Learning Lab | 2 vCPU / 2GB RAM / 32GB |

- **k3s version**: v1.34.5
- **OS**: Ubuntu 24.04.4 LTS
- **Proxmox VE**: 9.1.1 (Kernel 6.17.2-1-pve)
  - pve01 (10.0.1.1) — 16GB RAM, 4 cores
  - pve02 (10.0.1.2) — 8GB RAM, 4 cores
  - Template: VM 9000 (Ubuntu 24.04 + cloud-init)

---

## 📦 Stack

| Component | Namespace | Access | Notes |
|-----------|-----------|--------|-------|
| BIND9 DNS | infra | :30053 (UDP) / :30054 (TCP) | lab.local zone |
| Zabbix v7.0 | zabbix | :30080 | 14 hosts monitored |
| Prometheus | monitoring | :31090 | kube-prometheus-stack |
| Grafana | monitoring | :31000 | admin/<see-secret> |
| Alertmanager | monitoring | :31093 | Lark webhook ✅ |
| Loki + Promtail | monitoring | - | loki-stack v2.10.3 |
| Lark Alert Adapter | monitoring | ClusterIP :5001 | Prometheus → Lark |
| ArgoCD | argocd | port-forward 8888 | auto-sync + Image Updater |
| ArgoCD Image Updater | argocd | - | auto-deploy on new image |
| FastAPI | default | :30627 | demo app (Helm chart) |
| Traefik | traefik | - | ingress controller |
| Sealed Secrets | kube-system | - | encrypt secrets for Git |

---

## 🏗️ Repository Structure

    proxmox-k8s-infra/
    ├── terraform/
    │   ├── main.tf                  # Proxmox VM provisioning
    │   ├── variables.tf             # VM specs (CPU, RAM, disk, IP)
    │   └── terraform.tfvars.example
    ├── ansible/
    │   ├── inventory.ini            # Node inventory
    │   ├── ansible.cfg
    │   ├── playbook-k3s.yaml        # k3s cluster installation
    │   └── playbook-zabbix-agent.yaml # Zabbix agent auto-install
    ├── argocd/
    │   └── apps/applications.yaml   # ArgoCD apps (7 apps, auto-sync)
    ├── helm/
    │   ├── fastapi/                 # FastAPI Helm chart (Chart.yaml + templates)
    │   ├── kube-prometheus-stack/values.yaml
    │   ├── loki-stack/values.yaml
    │   ├── traefik/values.yaml
    │   └── zabbix/values.yaml
    ├── k8s/
    │   ├── dns/bind9/               # BIND9 DNS (configmap, deployment, service)
    │   ├── monitoring/              # Custom alerts, Lark adapter, DR test, Grafana dashboards
    │   ├── namespaces/namespaces.yaml
    │   ├── network-policies/        # Network isolation per namespace
    │   ├── security-hardening/      # Kubescape CronJob, audit policy
    │   ├── sealed-secrets/          # Sealed Secrets usage docs
    │   └── zabbix/
    ├── scripts/                         # morning-check, test-dr, verify-backups, etc.
    ├── docs/
    │   ├── incidents/               # 10 incident reports
    │   ├── runbook.md               # Troubleshooting guide
    │   ├── disaster-recovery.md     # DR plan (RTO 5-60 min)
    │   └── secret-rotation-plan.md
    └── README.md

---

## 🚀 Quick Access

    # SSH
    ssh devops@10.0.1.10    # k8s-master
    ssh devops@10.0.1.11    # k8s-worker-01
    ssh devops@10.0.1.12    # k8s-worker-02

    # ArgoCD UI
    kubectl port-forward svc/argocd-server -n argocd 8888:443 --address 0.0.0.0
    # open https://10.0.1.10:8888

    # Web UIs
    # BIND9 DNS:    nslookup k8s-master.lab.local 10.0.1.10 -port=30053
    # Zabbix:       http://10.0.1.10:30080
    # Grafana:      http://10.0.1.10:31000
    # Dashboard:    http://10.0.1.10:31000/d/cluster-overview
    # Prometheus:   http://10.0.1.10:31090
    # Alertmanager: http://10.0.1.10:31093
    # FastAPI:      http://10.0.1.10:30627

---

## 🔄 CI/CD Pipeline

```
Push image to GHCR → ArgoCD Image Updater detects new tag (every 2min)
→ Auto-update → Deploy to k3s
```

ไม่ต้อง cross-repo workflow หรือ PAT — แค่ push image ใหม่ขึ้น `ghcr.io/derbswag/devops-api` ก็ deploy อัตโนมัติ

---

## 🏗️ Infrastructure as Code

**Rebuild entire cluster from scratch:**

    # 1. Provision VMs on Proxmox
    cd terraform/
    cp terraform.tfvars.example terraform.tfvars  # fill in password
    terraform init && terraform apply

    # 2. Install k3s cluster
    cd ../ansible/
    ansible-playbook playbook-k3s.yaml

    # 3. Install Zabbix agent on all nodes
    ansible-playbook playbook-zabbix-agent.yaml

    # 4. Deploy stack via ArgoCD + Helm (see Helm Deploy Reference below)

**Prerequisites:**
- Proxmox VM template (ID 9000) with Ubuntu 24.04 + cloud-init ✅
- SSH key configured in terraform.tfvars

---

## 🔧 Helm Deploy Reference

    # kube-prometheus-stack
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
      -f helm/kube-prometheus-stack/values.yaml -n monitoring --create-namespace

    # Loki stack
    helm upgrade --install loki-stack grafana/loki-stack \
      -f helm/loki-stack/values.yaml -n monitoring

    # Zabbix
    helm upgrade --install zabbix zabbix-community/zabbix \
      -f helm/zabbix/values.yaml -n zabbix --create-namespace

    # Traefik
    helm upgrade --install traefik traefik/traefik \
      -f helm/traefik/values.yaml -n traefik --create-namespace

---

## 📡 Monitored Hosts (Zabbix)

| Host | Type | IP |
|------|------|----|
| k8s-master | Linux Zabbix Agent | 10.0.1.10 |
| k8s-worker-01 | Linux Zabbix Agent | 10.0.1.11 |
| k8s-worker-02 | Linux Zabbix Agent | 10.0.1.12 |
| pve01 | Proxmox | 10.0.1.1 |
| pve02 | Proxmox | 10.0.1.2 |
| SRV-FILE | Windows | 10.0.3.10 |
| SRV-APP01 | Windows | 10.0.3.23 |
| SRV-ERP | Windows | 10.0.2.9 |
| SRV-PLAN | Windows | 10.0.2.11 |
| SRV-HR | Windows | 10.0.2.13 |
| CCTV-01 | Hikvision SNMP v2c | 10.0.3.9 |
| CCTV-02 | Hikvision SNMP v2c | 10.0.1.x |
| CCTV-03 | Hikvision SNMP v2c | 10.0.2.139 |
| CCTV-04 | Hikvision SNMP v2c | 10.0.1.x |
| Zabbix Server | Self | - |

---

## 🛡️ Security

### Proxmox Firewall
- **Policy**: DROP (deny all by default)
- **Allowed subnets**: 10.0.3.x/24, 10.0.0.0/16, 10.0.2.x/24, 10.0.1.x/24
- **Ports**: SSH (22), WebUI (8006), NodePort (30000-32767), Zabbix (10050), Corosync (5405-5412)

### Kubernetes Network Policies
- Default deny ingress on: monitoring, zabbix, infra namespaces
- Allow internal namespace traffic
- Allow specific ports for NodePort services

### Sealed Secrets
- Controller: bitnami/sealed-secrets v0.27.3
- CLI: `kubeseal` on k8s-master
- Usage: see `k8s/sealed-secrets/README.md`

---

## 🛡️ Backup & Maintenance

- **Proxmox Backup**: Weekly (Sunday 02:00), all VMs, snapshot mode, zstd compression
  - Retention: keep-last=2, keep-weekly=4
  - Storage: local (/var/lib/vz)
- **LVM Thin Pool**: autoextend threshold 80% (both nodes)
- **Proxmox Repos**: pve-no-subscription + debian trixie (enterprise repos disabled)

---


## 🛡️ Kubescape Security Scan (May 8, 2026)

| Framework | Score |
|-----------|-------|
| MITRE | 66.29% |
| NSA | 65.36% |

**Remediated:**
- ✅ NetworkPolicy applied to default + kube-system (7→1 missing)
- ✅ Non-root security context (9 deployments patched)
- ✅ No privileged containers
- ✅ No insecure API port
- ✅ No anonymous access

**Accepted risks:**
- Traefik/Promtail require host network/root (ingress + log collection)
- kube-node-lease/kube-public — no workload, no policy needed

**Completed:**
- [x] Enable audit logging — commit 38e0a47
- [x] Enable etcd encryption at rest — commit 38e0a47

See: `k8s/security-hardening/README.md`

---
## ⚠️ Known Issues / Pending

| Item | Status | Notes |
|------|--------|-------|
| Zabbix to Lark alert | ✅ Verified | 3 media types (Linux/Windows/CCTV), all sending successfully |
| False alert suppression | ✅ Verified | KubeProxyDown / KubeControllerManagerDown / KubeSchedulerDown — no longer firing |
| VPN tunnel to private network | ❌ Cancelled | Keep personal and work networks separated |

---

## 🌅 Morning Health Check

    ssh devops@10.0.1.10 'bash -s' < scripts/morning-check.sh

---

## 📋 Incident Reports

10 documented incidents with root cause analysis: [docs/incidents/](docs/incidents/)

Highlights:
- DNS blocked by NetworkPolicy (forgot allow-dns after default deny)
- False positive alerts (absent() without ServiceMonitor)
- Worker nodes disk full (container images + logs)
- Lark webhook blocked by egress policy

---

## 📖 Runbook

Troubleshooting guide อยู่ที่ [`docs/runbook.md`](docs/runbook.md) ครอบคลุม:
- Disk full, Node NotReady, Pod CrashLoopBackOff
- ArgoCD OutOfSync, Proxmox apt errors
- Lark alert issues, VM start failures

---

## 🔐 Key Config Notes

- Zabbix agent Server= must include both node IP and pod CIDR (10.0.1.10,10.42.0.0/16)
- ArgoCD port-forward requires --address 0.0.0.0 for remote access
- kubectl must be run from k8s-master only
- BIND9 DNS serves `lab.local` zone (forward + reverse)
- ArgoCD Image Updater watches `ghcr.io/derbswag/devops-api` for new tags
