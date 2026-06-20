# Incident Report — DNS Blocked by NetworkPolicy

- **Date detected:** 2026-05-09 ~ 2026-05-11
- **Severity:** High (cluster-wide DNS failure for non-kube-system pods)
- **Status:** ✅ Resolved
- **Root cause commit:** NetworkPolicy added 2026-05-08
- **Fix commit:** `c362f87` (2026-05-11)

---

## Summary

NetworkPolicy `allow-kube-system-internal` (ใช้คู่กับ `default-deny-ingress` ใน `kube-system`) อนุญาตให้แค่ pods จาก `kube-system` และ `monitoring` เข้าถึง CoreDNS ได้ ทำให้ pod ใหม่ใน namespace อื่น (zabbix, argocd, default, infra) **resolve DNS ไม่ได้ทั้งหมด**

ผลกระทบไม่เห็นทันทีเพราะ pod เก่ายัง cache DNS อยู่ — อาการเริ่มโผล่เมื่อ pod ถูก restart/recreate หลัง 8 พ.ค.

---

## Timeline

| เวลา | เหตุการณ์ |
|------|-----------|
| 2026-05-08 | เพิ่ม `default-deny-ingress` + `allow-kube-system-internal` ใน kube-system |
| 2026-05-09 ~03:32 | `zabbix-web` rollout ใหม่ → pod resolve `zabbix-postgresql` ไม่ได้ → CrashLoop 253 รอบ |
| 2026-05-09 ~04:00 | `argocd-repo-server` รีสตาร์ท → health check timeout (DNS fail) |
| 2026-05-09 ~10:30 | Alert firing, rollback zabbix-web + restart argocd-repo-server |
| 2026-05-09 ~11:00 | เพิ่ม liveness probe tolerance สำหรับ argocd-repo-server |
| 2026-05-11 01:00 | CronJob `zabbix-nodesclean` รันตามปกติ → DNS fail → Job Failed |
| 2026-05-11 ~09:30 | พบ root cause: NetworkPolicy บล็อค DNS |
| 2026-05-11 ~09:45 | Apply NetworkPolicy `allow-dns` → DNS ทำงาน, job `DELETE 1` สำเร็จ |

---

## Root Cause

```yaml
# allow-kube-system-internal (ก่อน fix)
spec:
  podSelector: {}        # applies to ALL pods in kube-system (รวม CoreDNS)
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
```

Policy นี้บอกว่า "อนุญาตเฉพาะ traffic จาก kube-system + monitoring" แต่ไม่ได้ยกเว้น port 53 ของ CoreDNS ทำให้ DNS request จาก namespace อื่นถูก **kube-router drop** ที่ chain `KUBE-ROUTER-FORWARD`

---

## Why Not Detected Earlier

1. Pod เก่า (pre-incident) ยังทำงานได้เพราะ connection cache
2. Test suite ไม่มี DNS resolution test
3. Alertmanager แสดงอาการปลายทาง (CrashLoop, JobFailed) ไม่ชี้ root cause
4. NetworkPolicy ไม่ auto-rollback → Terraform/ArgoCD ไม่เห็นปัญหา

---

## Fix Applied

เพิ่ม NetworkPolicy `allow-dns` ที่เปิด port 53 (TCP/UDP) ให้ทุก namespace query ได้:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      k8s-app: kube-dns
  policyTypes: [Ingress]
  ingress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

ไฟล์: `k8s/network-policies/allow-dns.yaml`

---

## Related Incidents (ย้อนดูเคสอื่นที่น่าจะเกี่ยวข้อง)

1. **zabbix-web CrashLoopBackOff (9 พ.ค. 2026)**
   อาการ: `PostgreSQL server is not available`
   ที่เข้าใจตอนนั้น: rollback deployment
   Root cause แท้จริง: DNS resolve `zabbix-postgresql` ไม่ได้

2. **argocd-repo-server CrashLoopBackOff (9 พ.ค. 2026)**
   อาการ: Liveness probe timeout
   ที่เข้าใจตอนนั้น: เพิ่ม probe tolerance
   Root cause แท้จริง: health check อาจมี DNS lookup ภายใน → timeout

3. **zabbix-nodesclean Job Failed (10-11 พ.ค. 2026)**
   อาการ: job fail ทุกวัน 01:00
   Root cause: DNS fail ตอน connect PG

---

## Action Items

- [x] Apply `allow-dns` NetworkPolicy — **DONE**
- [x] Commit + push to main — **DONE** (`c362f87`)
- [ ] Review all NetworkPolicies — หา policy อื่นที่อาจบล็อคอะไรสำคัญ
- [ ] เพิ่ม DNS resolution check ใน `scripts/morning-check.sh`
- [ ] เพิ่ม alert: CoreDNS query success rate < 95% → warning
- [ ] เขียน test: ทุก namespace ต้อง resolve `kubernetes.default.svc` ได้
- [ ] ย้อนดู zabbix-web new deployment (revision ที่ rollback) ว่ามี code change อื่นนอกจาก DNS issue ไหม — อาจต้อง re-apply ได้หลัง fix DNS
- [ ] Document policy: "NetworkPolicy changes require DNS test before merge"

---

## Lessons Learned

1. **default-deny + DNS allow เป็น pair**
   ทุกครั้งที่เพิ่ม `default-deny-ingress` ต้องเพิ่ม `allow-dns` ทันที
2. **อาการปลายทางหลอก**
   CrashLoop/Timeout/Job Failed ไม่ได้ชี้ root cause เสมอ — ต้องตรวจ DNS เป็นอันดับแรกเวลา pod ใหม่มีปัญหา
3. **Connection cache ปกปิดปัญหา**
   Pod เก่าที่ running อยู่ ≠ config ถูก
4. **เปลี่ยน policy แล้วต้อง rollout test**
   ถ้าเพิ่ม NetworkPolicy ใหม่ ให้ลอง restart pod ในหลายๆ namespace เพื่อ verify
