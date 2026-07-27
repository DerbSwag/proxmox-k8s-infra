# Proxmox K8s Infrastructure Lab — Architecture Guide

เอกสารอธิบายแต่ละ component ว่าคืออะไร ทำอะไร ทำงานยังไง

---

## 🖥️ Proxmox VE (Virtualization)

**คืออะไร:** แพลตฟอร์ม virtualization สำหรับสร้าง VM บน bare-metal server

**ทำอะไร:**
- รัน VM ทั้งหมดของ lab (k8s nodes + dns-server)
- Cluster 2 nodes (hypervisor-01 + hypervisor-02) ทำให้มี HA capability

**ทำงานยังไง:**
- hypervisor-01 (192.0.2.1) — host VM 103, 200, 201
- hypervisor-02 (192.0.2.2) — host VM 210
- ใช้ local-lvm (thin provisioning) เก็บ disk ของ VM
- Backup ทุกอาทิตย์ 02:00 ด้วย vzdump snapshot mode
- Firewall เปิด DROP policy อนุญาตเฉพาะ LAN

---

## ☸️ k3s (Kubernetes)

**คืออะไร:** Lightweight Kubernetes distribution สำหรับ edge/lab

**ทำอะไร:**
- รัน container workloads ทั้งหมด (monitoring, apps, DNS)
- จัดการ scheduling, networking, storage ให้ containers

**ทำงานยังไง:**
- 1 master (control plane) + 2 workers
- ใช้ flannel เป็น CNI (pod network <POD_CIDR>)
- ใช้ local-path-provisioner สำหรับ persistent storage
- kubectl ใช้ได้เฉพาะบน k8s-master

**ติดตั้งยังไง:**
```bash
cd ansible/
ansible-playbook playbook-k3s.yaml
```

---

## 📊 Prometheus + Grafana + Alertmanager (Monitoring Stack)

**คืออะไร:**
- **Prometheus** — เก็บ metrics (CPU, RAM, disk, network) จากทุก node/pod
- **Grafana** — แสดง dashboard สวย ๆ จาก metrics
- **Alertmanager** — จัดการ alert rules แล้วส่งไป Lark

**ทำอะไร:**
- Monitor ทุก k8s node + pod แบบ real-time
- Alert เมื่อ resource ผิดปกติ (disk full, pod crash, node down)
- แสดง Cluster Overview dashboard

**ทำงานยังไง:**
```
Node/Pod → Prometheus scrape metrics ทุก 30s
         → ตรวจ alert rules
         → ถ้า trigger → ส่งไป Alertmanager
         → Alertmanager route ไป Lark Alert Adapter
         → ส่ง webhook ไป Lark group
```

**Access:**
- Grafana: http://192.0.2.10:31000 (admin/<see-secret>)
- Prometheus: http://192.0.2.10:31090
- Alertmanager: http://192.0.2.10:31093

---

## 🔔 Lark Alert Adapter

**คืออะไร:** Python app ที่แปลง Alertmanager webhook เป็น Lark message format

**ทำอะไร:** รับ alert จาก Alertmanager → format ข้อความ → ส่งไป Lark group

**ทำงานยังไง:**
- รันเป็น pod ใน namespace monitoring
- ClusterIP service port 5001
- ArgoCD auto-sync จาก `k8s/monitoring/lark-alert-adapter/`

---

## 📡 Zabbix v7.0 (Infrastructure Monitoring)

**คืออะไร:** Enterprise monitoring platform สำหรับ monitor ทุกอย่าง (servers, network, camera)

**ทำอะไร:**
- Monitor 14 hosts: k8s nodes, Proxmox, Windows servers, camera (SNMP)
- ส่ง alert ไป Lark เมื่อมีปัญหา (3 media types: Linux/Windows/camera)

**ทำงานยังไง:**
- Zabbix Server รันบน k8s (namespace: zabbix)
- Zabbix Agent ติดตั้งบนทุก node (port 10050)
- PostgreSQL เป็น database
- Alert → Lark webhook โดยตรง (ไม่ผ่าน Alertmanager)

**Access:** http://192.0.2.10:30080

---

## 🚀 ArgoCD (GitOps CD)

**คืออะไร:** GitOps continuous delivery tool — deploy apps จาก Git อัตโนมัติ

**ทำอะไร:**
- Watch Git repo → ถ้ามีการเปลี่ยนแปลง → sync ไป k8s cluster อัตโนมัติ
- Self-heal: ถ้าใครแก้ k8s ด้วยมือ ArgoCD จะ revert กลับตาม Git

**ทำงานยังไง:**
```
Push code/config ไป GitHub
    ↓
ArgoCD detect change (poll ทุก 3 นาที)
    ↓
Compare desired state (Git) vs actual state (cluster)
    ↓
ถ้าต่าง → auto-sync → apply changes
```

**Apps ที่ manage:**
- lark-alert-adapter (k8s manifests)
- fastapi (Helm chart)

**Access:** `kubectl port-forward svc/argocd-server -n argocd 8888:443 --address 0.0.0.0`

---

## 🔄 ArgoCD Image Updater

**คืออะไร:** Add-on ของ ArgoCD ที่ตรวจ container registry อัตโนมัติ

**ทำอะไร:** ถ้ามี image tag ใหม่บน GHCR → update deployment อัตโนมัติ

**ทำงานยังไง:**
```
Push image ใหม่ขึ้น ghcr.io/derbswag/devops-api
    ↓
Image Updater ตรวจเจอ (ทุก 2 นาที)
    ↓
Update image tag ใน ArgoCD app
    ↓
ArgoCD sync → deploy version ใหม่
```

ไม่ต้องมี CI workflow แก้ไฟล์ใน Git — Image Updater จัดการเอง

---

## 🌐 BIND9 DNS

**คืออะไร:** DNS server สำหรับ resolve ชื่อภายใน (lab.local)

**ทำอะไร:** แปลงชื่อ เช่น `k8s-master.lab.local` → `192.0.2.10`

**ทำงานยังไง:**
- รันเป็น pod ใน namespace infra
- Zone files อยู่ใน ConfigMap (`k8s/dns/bind9/configmap.yaml`)
- NodePort 30053 (UDP) / 30054 (TCP)

**ทดสอบ:**
```bash
nslookup k8s-master.lab.local 192.0.2.10 -port=30053
```

---

## 🏗️ Terraform (Infrastructure as Code)

**คืออะไร:** เครื่องมือสร้าง infrastructure จาก code

**ทำอะไร:** สร้าง VMs บน Proxmox อัตโนมัติ (clone จาก template 9000)

**ทำงานยังไง:**
```bash
cd terraform/
terraform init      # ดาวน์โหลด provider
terraform plan      # preview สิ่งที่จะสร้าง
terraform apply     # สร้าง VMs จริง
terraform destroy   # ลบทั้งหมด
```

**Config:**
- `main.tf` — resource definitions (VMs)
- `variables.tf` — specs ของแต่ละ VM (CPU, RAM, IP)
- `terraform.tfvars` — credentials (gitignored)

---

## 🔧 Ansible (Configuration Management)

**คืออะไร:** เครื่องมือ automate การติดตั้ง/ตั้งค่า server

**ทำอะไร:**
- `playbook-k3s.yaml` — ติดตั้ง k3s cluster ทั้งหมด
- `playbook-zabbix-agent.yaml` — ติดตั้ง Zabbix agent บนทุก node

**ทำงานยังไง:**
```bash
cd ansible/
ansible-playbook playbook-k3s.yaml           # สร้าง cluster
ansible-playbook playbook-zabbix-agent.yaml   # ติดตั้ง monitoring
```

**Flow:**
```
Ansible อ่าน inventory.ini (รายชื่อ nodes)
    ↓
SSH เข้าทุก node
    ↓
รัน tasks ตามลำดับ (install packages, configure, start services)
    ↓
เสร็จ — ทุก node พร้อมใช้งาน
```

---

## 🔒 Sealed Secrets

**คืออะไร:** เครื่องมือเข้ารหัส Kubernetes Secrets ให้เก็บใน Git ได้

**ทำอะไร:** encrypt secret → commit ขึ้น Git ได้ปลอดภัย → controller decrypt ใน cluster

**ทำงานยังไง:**
```bash
# สร้าง secret ปกติ (dry-run)
kubectl create secret generic my-secret --from-literal=password=xxx --dry-run=client -o yaml > secret.yaml

# Seal (encrypt)
kubeseal --kubeconfig /etc/rancher/k3s/k3s.yaml --format yaml < secret.yaml > sealed-secret.yaml

# Apply — controller จะ decrypt ให้
kubectl apply -f sealed-secret.yaml
```

---

## 🛡️ Network Policies

**คืออะไร:** Kubernetes firewall rules ระดับ pod/namespace

**ทำอะไร:** ป้องกันไม่ให้ pods ข้าม namespace คุยกันโดยไม่จำเป็น

**ทำงานยังไง:**
- Default deny ingress ทุก namespace (monitoring, zabbix, infra)
- Allow เฉพาะ traffic ภายใน namespace เดียวกัน
- Allow NodePort access จากภายนอก (เฉพาะ port ที่กำหนด)

---

## 🔥 Proxmox Firewall

**คืออะไร:** Host-level firewall บน Proxmox nodes

**ทำอะไร:** Block traffic จากภายนอก LAN, อนุญาตเฉพาะ port ที่จำเป็น

**Policy:** DROP (ปฏิเสธทุกอย่างที่ไม่ match rules)

**Allowed:**
| Port | Service | Source |
|------|---------|--------|
| 22 | SSH | LAN (4 subnets) |
| 8006 | Proxmox WebUI | LAN |
| 30000-32767 | k8s NodePort | LAN |
| 10050 | Zabbix Agent | 192.0.2.x/24, 203.0.113.x/24 |
| 5405-5412 | Corosync (cluster) | 192.0.2.x/24 |

---

## 📦 FastAPI (Demo App)

**คืออะไร:** Python web API framework — ใช้เป็น demo app สำหรับ CI/CD pipeline

**ทำอะไร:** แสดงว่า pipeline ทำงานได้ end-to-end (build → push → deploy)

**ทำงานยังไง:**
- Helm chart อยู่ที่ `helm/fastapi/`
- ArgoCD manage + Image Updater auto-deploy
- NodePort 30627

**Access:** http://192.0.2.10:30627

---

## 🔄 CI/CD Flow (ภาพรวม)

```
Developer push image ขึ้น GHCR
         │
         ▼
ArgoCD Image Updater ตรวจเจอ tag ใหม่ (ทุก 2 นาที)
         │
         ▼
ArgoCD sync Helm chart ด้วย tag ใหม่
         │
         ▼
k3s deploy pod ใหม่ (rolling update)
         │
         ▼
Prometheus monitor → ถ้ามีปัญหา → Alert ไป Lark
```

---

## 🏗️ IaC Flow (สร้าง cluster ใหม่ทั้งหมด)

```
terraform apply          → สร้าง VMs บน Proxmox (~5 นาที)
         │
         ▼
ansible-playbook k3s     → ติดตั้ง k3s cluster (~5 นาที)
         │
         ▼
ansible-playbook zabbix  → ติดตั้ง monitoring agent (~2 นาที)
         │
         ▼
helm install / ArgoCD    → deploy stack ทั้งหมด (~5 นาที)
         │
         ▼
Cluster พร้อมใช้งาน      → รวม ~15-20 นาที
```
