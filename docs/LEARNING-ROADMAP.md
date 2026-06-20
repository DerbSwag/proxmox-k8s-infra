# Learning Roadmap — เข้าใจ company-lab-infra ให้ลึก

แผนเรียนที่อิงจาก stack จริงของโปรเจกต์นี้ และ **map กับ incident จริง** ที่เคยเกิด
(ดู `INCIDENTS.md` / `docs/incidents/`). โปรเจกต์นี้คือ **DevOps / SRE / Infrastructure**
— ไม่ใช่ web development. เรียงจากฐานล่างขึ้นบน เรียนตามลำดับได้เลย.

> หมายเหตุ: คอร์ส "Full-stack Web Developer" ที่มีอยู่ ใช้ได้แค่ **Git/GitHub**, **DevOps**,
> และ **SQL** ส่วนที่เหลือ (HTML/CSS/Vue/React/Next.js...) เป็น frontend ไม่เกี่ยวโปรเจกต์นี้.

---

## ภาพรวม Stack ของโปรเจกต์
```
Proxmox VE (pve01/pve02)         ← virtualization (รัน VM ทั้งหมด)
  └─ VMs: k8s-master, worker-01, worker-02, dns, linux-lab
       └─ k3s (Kubernetes)       ← orchestration
            ├─ Helm + ArgoCD     ← deploy / GitOps
            ├─ Prometheus/Grafana/Alertmanager/Loki  ← monitoring
            ├─ Vault             ← secrets
            ├─ Zabbix            ← monitor Windows/CCTV/network
            └─ NetworkPolicy / Traefik / CoreDNS / bind9
Terraform + Ansible              ← provision + config (IaC)
Git/GitHub                       ← source of truth (กู้ระบบจากตรงนี้)
```

---

## STAGE 0 — Linux & Networking (ฐานทุกอย่าง) 🔴 สำคัญสุด
**ทำไม:** ทุกอย่างรันบน Ubuntu/Debian. ครึ่งหนึ่งของ incident เป็นปัญหา Linux/network ล้วน.

เรียน:
- CLI พื้นฐาน, ไฟล์/permission, `sudo`, package (apt)
- **systemd**: `systemctl`, `journalctl` (อ่าน log) — ใช้ debug ทุก incident
- **networking**: `ip addr`, netplan, default route, DNS, `/dev/tcp` test
- **firewall**: ufw, iptables (INPUT/FORWARD chain, NAT)
- SSH (key, jump host), `scp`

**Map กับ incident จริง:**
- `2026-06-03 VXLAN blocked by UFW` — ufw บล็อก UDP 8472 → ต้องเข้าใจ iptables
- `2026-06-16 worker duplicate IP` — netplan static+DHCP ซ้อน → asymmetric routing
- `2026-06-08 master OOM` — `free -h`, swap, memory pressure

แหล่งเรียน (ฟรี/ไทย): YouTube "Linux เบื้องต้น", Linux Journey, `man` pages,
คอร์ส **DevOps (#19)** ในลิสต์เริ่มที่ Linux

---

## STAGE 1 — Git & GitHub
**ทำไม:** ทั้งโปรเจกต์เป็น GitOps — config อยู่ใน git, กู้ระบบจาก git (DR rebuild ทำได้เพราะมีตรงนี้).

เรียน: clone/commit/push, branch, merge/rebase, conflict, `.gitignore`, **ไม่ commit secret**

**Map:** `2026-06-16 DR rebuild` — กู้ทั้ง cluster จาก repo ได้ใน ~1 ชม. เพราะ config อยู่ใน git
**คอร์สในลิสต์:** #3 Git/GitHub ✅ เรียนได้เลย

---

## STAGE 2 — Containers: Docker → Kubernetes → k3s 🔴 หัวใจ
**ทำไม:** workload ทั้งหมดเป็น container บน k3s.

เรียนตามลำดับ:
1. **Docker** — image, container, volume, network, Dockerfile, docker-compose
2. **Kubernetes** — pod, deployment, service (ClusterIP/NodePort), PV/PVC,
   ConfigMap/Secret, DaemonSet, StatefulSet, namespace, `kubectl`
3. **k3s** — lightweight k8s, agent/server, flannel CNI, local-path storage, kine(SQLite)
4. **NetworkPolicy** — ingress/egress, default-deny

**Map กับ incident จริง:**
- `2026-06-04 metrics-server / kube-router` — kubelet 10250, DaemonSet, host-port
- `network-policies` หลายไฟล์ — default-deny + allow rules
- `StatefulSet` (Vault/Zabbix postgres), `local-path PV` ที่หายตอน uninstall

แหล่งเรียน: "Kubernetes for Beginners" (KodeKloud/TechWorld with Nana — มี subtitle),
k3s docs, เล่นจริงบน lab ตัวเอง

---

## STAGE 3 — Helm & GitOps (ArgoCD)
**ทำไม:** ทุก stack deploy ด้วย Helm; ArgoCD sync จาก git.

เรียน:
- **Helm** — chart, values.yaml, `helm upgrade --install`, repo
- **ArgoCD** — Application CRD, auto-sync, self-heal

**Map:**
- `helm/kube-prometheus-stack/values.yaml`, `helm/vault/values.yaml` (ที่แก้ dev→standalone)
- `2026-06-16 DR` — `helm upgrade` redeploy ทุก stack + `argocd/apps/applications.yaml`
- `2026-06-16 zabbix values.yaml corrupt` — แก้ YAML ที่ Helm parse ไม่ได้

---

## STAGE 4 — Monitoring & Observability
**ทำไม:** ครึ่งหนึ่งของงานคือ "alert ดังแล้วทำไง".

เรียน:
- **Prometheus** — metrics, PromQL, scrape config, ServiceMonitor, **alert rules** (PrometheusRule)
- **Alertmanager** — routing, grouping, inhibit, repeat_interval, webhook
- **Grafana** — dashboard, datasource
- **Loki** — log aggregation
- **Zabbix** — agent/SNMP, template, trigger, macro, action/media (Lark webhook)

**Map กับ incident จริง:**
- `k8s/monitoring/custom-alerts.yaml` — เขียน alert rules เอง (CoreDNS, capacity, cluster-down)
- `2026-06-16 alert improvement` — inhibit/grouping ลด noise
- `Zabbix GoogleUpdater/AppXSvc suppress` — macro `{$SERVICE.NAME.NOT_MATCHES}`
- `Lark routing` — แยก Windows/CCTV group ด้วย media type

---

## STAGE 5 — Infrastructure as Code (Terraform + Ansible)
**ทำไม:** provision VM + config node แบบ reproducible.

เรียน:
- **Terraform** — provider, resource, state, plan/apply (provision Proxmox VM)
- **Ansible** — playbook, inventory, role, idempotency (ติดตั้ง k3s/zabbix-agent)

**Map:** `terraform/` (Proxmox VM), `ansible/playbook-k3s.yaml`, DR Scenario 3

---

## STAGE 6 — Virtualization (Proxmox VE)
**ทำไม:** ชั้นล่างสุด — VM ทั้งหมดรันที่นี่.

เรียน:
- VM/CT, storage (local/local-lvm), `qm` CLI, snapshot, **vzdump backup**
- **cluster + quorum** (corosync), HA, onboot/startup order
- network (bridge, VLAN)

**Map กับ incident จริง:**
- `2026-06-16 proxmox reboot no autostart` — onboot=1, startup order
- `2026-06-16 backup disk full` — vzdump, retention, prune
- `2026-06-17 pve02 hardware instability` — quorum, `pvecm expected 1`, hardware diag

---

## STAGE 7 — Secrets & Security (Vault)
เรียน:
- **Vault** — seal/unseal, KV engine, **Kubernetes auth**, policy, token
- sealed-secrets, secrets-at-rest

**Map:**
- `2026-06-04 vault dev-mode data loss` — inmem vs file storage
- `scripts/bootstrap-vault.sh`, `k8s/vault/auto-unseal-cronjob.yaml`

---

## ลำดับเรียนแนะนำ (ถ้าเวลาจำกัด)
```
1) Linux + networking         ← ขาดไม่ได้
2) Git/GitHub (#3)            ← เร็ว, ใช้ทุกวัน
3) Docker → Kubernetes/k3s    ← หัวใจ (ใช้เวลามากสุด)
4) DevOps course (#19)        ← ภาพรวมเครื่องมือ
5) Helm + ArgoCD
6) Prometheus + Grafana + Zabbix
7) Terraform + Ansible
8) Proxmox + Vault
```

## วิธีเรียนที่ได้ผลสุดสำหรับโปรเจกต์นี้
- **เรียนคู่กับ lab ตัวเอง** — อ่าน incident ที่เราแก้ไปแล้ว → ลองทำซ้ำใน lab → เข้าใจ "ทำไม"
- ทุกครั้งที่ alert ดัง = โอกาสเรียน 1 เรื่อง (debug จริง > ดูคลิป)
- ใช้ `RUNBOOK.md` + `docs/incidents/` เป็น "ข้อสอบ" — เปิดดูว่าแก้ยังไง แล้วลองอธิบายเอง

## Cert ที่เกี่ยวข้อง (ถ้าอยากมีเป้า)
- Linux: LFCS / RHCSA
- Kubernetes: **CKA** (Certified Kubernetes Administrator) ← ตรงโปรเจกต์สุด
- Terraform: HashiCorp Terraform Associate
- (Cloud: AWS/GCP — ถ้าจะขยายไป cloud)
