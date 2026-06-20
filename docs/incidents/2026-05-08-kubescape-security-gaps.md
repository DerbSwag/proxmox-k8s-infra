# Incident Report — Kubescape Security Gaps

- **Date detected:** 2026-05-08
- **Severity:** Medium (security posture gaps, no active exploit)
- **Status:** ✅ Remediated
- **Fix commits:** `b3dafa7`, `863734e`

---

## Summary

Kubescape security scan (MITRE + NSA frameworks) พบ security gaps หลายจุด:
- **MITRE score: 66.29%** (target 80%+)
- **NSA score: 65.36%** (target 80%+)

ปัญหาหลัก:
1. 7 namespaces ไม่มี NetworkPolicy (ไม่มี network isolation)
2. 9 deployments รัน container เป็น root
3. ไม่มี audit logging
4. ไม่มี etcd encryption at rest

## Root Cause

Cluster ถูก setup เน้น functionality ก่อน security — ไม่ได้ทำ hardening ตั้งแต่แรก เป็นเรื่องปกติของ lab environment ที่ค่อยๆ mature

## Fix Applied

### 1. NetworkPolicy (commit `b3dafa7`)
```bash
kubectl apply -f k8s/security-hardening/network-policies.yaml
```
- เพิ่ม `default-deny-ingress` ใน default + kube-system
- ลด missing policies จาก 7 → 1 namespace

### 2. Non-root security context (commit `b3dafa7`)
```bash
bash k8s/security-hardening/apply-security-context.sh
```
- Patch 9 deployments ให้มี `runAsNonRoot: true`, `allowPrivilegeEscalation: false`
- ยกเว้น: Traefik, Promtail (ต้อง host network/root)

### 3. Audit logging (commit `38e0a47`, 2026-05-11)
- เพิ่ม audit-policy.yaml + enable ใน k3s config

### 4. Secrets encryption at rest (commit `38e0a47`, 2026-05-11)
- Enable encryption config ใน k3s

## Side Effects

⚠️ **NetworkPolicy ที่เพิ่มใน kube-system ทำให้เกิด DNS incident วันที่ 9-11 พ.ค.**
ดู: [`2026-05-11-dns-blocked-by-networkpolicy.md`](./2026-05-11-dns-blocked-by-networkpolicy.md)

## Accepted Risks

- Traefik/Promtail require host network + root (ingress + log collection)
- kube-node-lease / kube-public — no workloads, no policy needed

## Lessons Learned

- Security hardening ต้องทำ incremental + test ทุก step — อย่า apply ทีเดียวหลาย policy
- NetworkPolicy เป็น double-edged sword — ต้อง verify DNS/connectivity หลัง apply
- ควร scan security เป็น periodic (monthly) ไม่ใช่ one-time
- Lab environment ก็ควรมี baseline security ตั้งแต่ day 1
