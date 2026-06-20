# Incident Report — False Positive Alerts (LarkAlertAdapterDown + InfoInhibitor)

- **Date detected:** 2026-05-14
- **Severity:** Medium (alert noise → team fatigue)
- **Status:** ✅ Resolved
- **Fix commit:** `8a2d36b`

---

## Summary

หลัง deploy custom alerts เมื่อ 12-13 พ.ค. มี alert fire ซ้ำๆ ส่งไป Lark โดยไม่มีปัญหาจริง:
1. **LarkAlertAdapterDown** — fire ซ้ำ 6+ ครั้ง ทั้งที่ pod running ปกติ
2. **InfoInhibitor** — ส่งไป Lark ทั้งที่เป็น meta-alert ควร route ไป null
3. **CoreDNSLowSuccessRate** — fire แล้ว resolve เอง (transient)

---

## Root Cause

### LarkAlertAdapterDown (False Positive)

**Expr เดิม:**
```yaml
absent(up{job="lark-alert-adapter"}) == 1
or
sum(kube_pod_status_ready{namespace="monitoring",pod=~"lark-alert-adapter.*"} == 0) > 0
```

**ปัญหา:** ไม่มี ServiceMonitor สำหรับ lark-alert-adapter → Prometheus ไม่มี metric `up{job="lark-alert-adapter"}` → `absent()` return 1 ตลอด → alert fire ตลอด

### InfoInhibitor

เป็น built-in alert ของ kube-prometheus-stack ที่ควร route ไป null receiver แต่ไม่ได้ตั้ง route → ส่งไป Lark

### CoreDNSLowSuccessRate

Transient spike ตอน apply egress NetworkPolicies เมื่อ 13 พ.ค. — DNS query แรกๆ หลัง policy change อาจ fail ชั่วคราว → resolve เองภายในไม่กี่นาที

---

## Fix Applied

### 1. แก้ LarkAlertAdapterDown expr
```yaml
# ก่อน (false positive)
absent(up{job="lark-alert-adapter"}) == 1
or
sum(kube_pod_status_ready{...} == 0) > 0

# หลัง (ถูกต้อง)
kube_pod_status_ready{namespace="monitoring",pod=~"lark-alert-adapter.*",condition="true"} == 0
```

### 2. เพิ่ม InfoInhibitor route ไป null
```yaml
routes:
  - matchers:
    - alertname="InfoInhibitor"
    receiver: "null"
```

### 3. CoreDNSLowSuccessRate
ไม่ต้องแก้ — alert ทำงานถูกต้อง (fire เมื่อ success < 95%, resolve เมื่อกลับปกติ)

---

## ผลลัพธ์

| Alert | ก่อน | หลัง |
|-------|------|------|
| LarkAlertAdapterDown | Fire ซ้ำทุก 4 ชม. (false positive) | ไม่ fire (pod ready = 1) |
| InfoInhibitor | ส่งไป Lark | Route ไป null — ไม่ส่ง |
| CoreDNSLowSuccessRate | Fire + Resolve (ถูกต้อง) | ไม่เปลี่ยน — ทำงานปกติ |

---

## Lessons Learned

1. **`absent()` ต้องมี metric อยู่จริง** — ถ้าไม่มี ServiceMonitor ห้ามใช้ `absent(up{job=...})` เพราะจะ fire ตลอด
2. **Test alert ก่อน deploy** — ควร query expr ใน Prometheus UI ก่อนว่า return ค่าถูกต้อง
3. **kube-prometheus-stack มี meta-alerts** (Watchdog, InfoInhibitor) ที่ต้อง route ไป null ทุกครั้ง
4. **Policy changes อาจทำให้ DNS spike ชั่วคราว** — CoreDNSLowSuccessRate alert ทำงานถูกต้อง เป็น expected behavior
