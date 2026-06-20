# Runbook — วิธีแก้ปัญหาที่พบบ่อย

## 🔴 Disk Full (k8s node)

**อาการ:** Alert "FS Space critically low" จาก Zabbix/Prometheus

**แก้ไข:**
```bash
# 1. เช็คว่าอะไรกิน disk
sudo du -sh /var/lib/* | sort -rh | head -10

# 2. ลบ unused container images
sudo crictl rmi --prune

# 3. ลบ old journal logs
sudo journalctl --vacuum-size=200M

# 4. ถ้ายังไม่พอ — extend LV (ถ้ามี VG free)
sudo vgs  # ดู VFree
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

---

## 🔴 Node NotReady

**อาการ:** `kubectl get nodes` แสดง NotReady

**แก้ไข:**
```bash
# 1. SSH เข้า node ที่มีปัญหา
ssh devops@<node-ip>

# 2. เช็ค kubelet
sudo systemctl status k3s-agent  # worker
sudo systemctl status k3s        # master

# 3. Restart k3s
sudo systemctl restart k3s-agent  # worker
sudo systemctl restart k3s        # master

# 4. ถ้ายังไม่ได้ — reboot
sudo reboot
```

---

## 🔴 Pod CrashLoopBackOff

**อาการ:** Pod restart ซ้ำ ๆ

**แก้ไข:**
```bash
# 1. ดู logs
kubectl logs <pod-name> -n <namespace> --previous

# 2. ดู events
kubectl describe pod <pod-name> -n <namespace>

# 3. สาเหตุที่พบบ่อย:
# - OOMKilled → เพิ่ม memory limit
# - Config error → แก้ ConfigMap/Secret
# - Image pull error → เช็ค image tag / registry access
```

---

## 🔴 ArgoCD OutOfSync

**อาการ:** App แสดง OutOfSync ใน ArgoCD

**แก้ไข:**
```bash
# 1. ดู error
kubectl get app <app-name> -n argocd -o jsonpath='{.status.conditions}'

# 2. ถ้า immutable field error → ลบ resource เดิมแล้วให้ ArgoCD สร้างใหม่
kubectl delete deploy <name> -n <namespace>

# 3. Force sync
kubectl annotate app <app-name> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

---

## 🔴 Proxmox apt update failed

**อาการ:** 401 Unauthorized จาก enterprise repo

**แก้ไข:**
```bash
# ปิด enterprise repos
mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled
mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# ตรวจสอบ no-subscription repo มีอยู่
cat /etc/apt/sources.list.d/pve-no-subscription.list
# ควรมี: deb http://download.proxmox.com/debian/pve trixie pve-no-subscription

apt-get update
```

---

## 🟡 Lark Alert ไม่ส่ง

**เช็ค:**
```bash
# 1. Pod ทำงานอยู่ไหม
kubectl get pods -n monitoring -l app=lark-alert-adapter

# 2. ดู logs
kubectl logs -n monitoring -l app=lark-alert-adapter --tail=20

# 3. Test ส่งตรง
echo '{"alerts":[{"status":"firing","labels":{"alertname":"Test"}}]}' | \
  curl -s -X POST http://10.42.0.32:5001 -H Content-Type:application/json -d @-
```

---

## 🟡 VM ไม่ start บน Proxmox

**แก้ไข:**
```bash
# 1. เช็ค status
qm status <vmid>

# 2. ดู log
journalctl -u pve-guests -f

# 3. ถ้า lock อยู่
qm unlock <vmid>
qm start <vmid>
```


---

## 🔴 DNS Resolution Failure (pod ใน namespace หนึ่ง resolve ชื่อ service ไม่ได้)

**อาการ:**
- `psql: could not translate host name "xxx" to address`
- `Temporary failure in name resolution`
- Pod ใหม่ CrashLoop แต่ pod เก่ายังรันปกติ
- Job/CronJob ข้าม namespace fail

**Quick test:**
```bash
# test DNS จาก pod ใน namespace ที่มีปัญหา
kubectl run -n <ns> dnstest --rm -it --image=busybox:1.36 -- nslookup kubernetes.default
```

**ถ้าเป็น "Connection refused" หรือ timeout:**
```bash
# 1. เช็ค NetworkPolicy ใน kube-system
kubectl get netpol -n kube-system

# 2. ถ้ามี default-deny-ingress ต้องมี allow-dns คู่กัน
kubectl apply -f k8s/network-policies/allow-dns.yaml
```

**ดู incident เต็ม:** `docs/incidents/2026-05-11-dns-blocked-by-networkpolicy.md`

---

## 🔴 Job/CronJob Failed (ข้าม namespace)

**อาการ:** Alert `KubeJobFailed` ซ้ำๆ

**แก้ไข:**
```bash
# 1. ดู job ล่าสุดที่ fail
kubectl get jobs -n <ns>

# 2. trigger manual run เพื่อดู error
kubectl create job -n <ns> test-run --from=cronjob/<cronjob-name>
sleep 10
kubectl logs -n <ns> -l job-name=test-run

# 3. ถ้าเจอ DNS error → ดูหัวข้อ DNS Resolution Failure ด้านบน

# 4. ถ้าเจอ PG connection error แต่ DNS OK → เช็ค credentials/secret
kubectl get secret -n <ns> <secret-name> -o yaml

# 5. เคลียร์ failed job
kubectl delete job -n <ns> <failed-job-name>
kubectl delete job -n <ns> test-run
```

---

## 🔴 NetworkPolicy blocks API server access (post-DNAT)

**อาการ:**
- Pods ใน namespace ที่มี deny-egress ไม่สามารถเข้า API server ได้
- connection refused ไป 10.43.0.1:443
- kube-state-metrics, Prometheus, Grafana sidecars CrashLoopBackOff
- Alert: TargetDown, PrometheusOperatorWatchErrors

**สาเหตุ:** kube-router ประเมิน NetworkPolicy **หลัง DNAT** — traffic ไป ClusterIP 10.43.0.1:443 จะถูกเห็นเป็น 10.0.1.10:6443 ดังนั้น egress rule ต้องอนุญาต node IP + port 6443 ด้วย

**แก้ไข:**
`ash
# 1. ยืนยันปัญหา
kubectl exec -n <ns> <pod> -- wget -qO- --no-check-certificate --timeout=3 https://10.43.0.1:443/version

# 2. เช็ค NetworkPolicy
kubectl get netpol -n <ns>
kubectl describe netpol allow-egress-<name> -n <ns>

# 3. เพิ่ม egress rule สำหรับ API server
# ใน egress rule ที่อนุญาต 10.0.1.x/24 ต้องมี port 6443
# แก้ที่ Git repo: k8s/network-policies/egress-policies.yaml
`

**ดู incident เต็ม:** docs/incidents/incident-2026-0515-netpol-blocks-apiserver.md

---

## 🔴 Prometheus No Active Targets

**อาการ:** Alert PrometheusNoActiveTargets หรือ targets page ว่างเปล่า

**แก้ไข:**
`ash
# 1. เช็คว่า Prometheus เข้า API server ได้ไหม
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- --no-check-certificate --timeout=3 https://10.43.0.1:443/version

# 2. ถ้า connection refused → ดูหัวข้อ NetworkPolicy blocks API server ด้านบน

# 3. ถ้าเข้าได้แต่ targets ยังว่าง → restart Prometheus Operator แล้ว restart Prometheus
kubectl delete pod -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-operator
kubectl delete pod -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0

# 4. รอ 60 วินาทีแล้วเช็ค
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | grep -c ' up'
`
