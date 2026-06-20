# NetworkPolicy Review — 2026-05-11

## Summary

Reviewed NetworkPolicies in all namespaces after DNS incident (`2026-05-11-dns-blocked-by-networkpolicy.md`). ตรวจว่าไม่มี policy อื่นบล็อคทราฟฟิกสำคัญ

## Namespaces & Policies

| Namespace | Policies | Default Deny | Notes |
|-----------|----------|--------------|-------|
| argocd | 7 (per-component) | ❌ No | แต่ละ service มี allow-list ของ port ตัวเอง |
| default | 2 (deny + allow-fastapi:8000) | ✅ Yes | ✅ OK |
| infra | 2 (deny + allow-dns:53) | ✅ Yes | ✅ bind9 reachable |
| kube-system | 3 (deny + allow-internal + **allow-dns:53**) | ✅ Yes | ✅ Fixed 2026-05-11 |
| monitoring | 3 (deny + allow-internal + allow-nodeport) | ✅ Yes | ✅ Prometheus scrapes all targets |
| zabbix | 2 (deny + allow-zabbix:8080 + same-ns) | ✅ Yes | ✅ OK |
| kube-node-lease / kube-public | 0 | — | No workloads |

## Connectivity Verification

**Prometheus scrape targets (13 pools):** ทั้งหมด ✅ UP
- grafana, alertmanager (×2), apiserver, coredns, kubelet (×3 nodes), operator, prometheus (×2), kube-state-metrics, node-exporter (×3 nodes)

**Firing alerts:** มีแค่ `Watchdog` (heartbeat alert = ปกติ)

**DNS (via morning-check.sh):** ✅ จาก `default` ns สามารถ resolve ได้ทั้ง 3 services

## Findings

### ✅ ไม่มี policy ที่บล็อคของสำคัญ

หลังจาก apply `allow-dns` ใน kube-system:
- Pod ใน namespace ใดก็ตาม → query CoreDNS ได้
- Prometheus (จาก monitoring) → scrape ทุก target ได้
- ArgoCD (internal components) → คุยกันได้ผ่าน per-component policies
- Zabbix web → PostgreSQL (same ns, allow podSelector {})

### ⚠️ ข้อสังเกตที่ควรปรับปรุง (non-critical)

1. **`allow-kube-system-internal` ยังเปิดกว้างไป**
   ใช้ `podSelector: {}` = apply กับทุก pod ใน kube-system
   ควรจำกัดเฉพาะที่จำเป็น เช่น `metrics-server`, `local-path-provisioner`
   *Not blocking — แค่ best practice*

2. **`argocd` ไม่มี `default-deny-ingress`**
   อาศัย per-component policies เท่านั้น → ถ้ามี pod ใหม่ใน namespace นี้จะเปิดหมด
   *Acceptable เพราะ ArgoCD chart จัดการเอง*

3. **ไม่มี `Egress` rules ทั่วทั้ง cluster**
   ทุก policy มี `policyTypes: [Ingress]` อย่างเดียว
   *Acceptable สำหรับ homelab — egress lockdown ต้องใช้ร่วมกับ DNS egress allow*

4. **`monitoring/allow-internal`** ใช้ `podSelector: {}` ยอมให้ทุก pod ใน monitoring คุยกัน — OK

## Recommendations

- [x] Apply `allow-dns` (done)
- [ ] เพิ่ม runbook section: "ทุกครั้งที่เพิ่ม default-deny ต้องคิด DNS ด้วย"
- [ ] (future) ทำ policy test automation — สร้าง pod ใน default ns แล้วทดสอบว่า reach service ที่คาดหวังได้/ไม่ได้

## Conclusion

**✅ Cluster networking healthy.** DNS incident ถูกแก้ และไม่มี policy อื่นที่เสี่ยงทำให้เกิด outage คล้ายกัน
