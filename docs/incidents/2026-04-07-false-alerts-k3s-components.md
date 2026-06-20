# Incident Report — False Positive Alerts (K3s Components)

- **Date detected:** 2026-04-07
- **Severity:** Low (noise only, no functional impact)
- **Status:** ✅ Resolved
- **Fix commit:** `59bb950`

---

## Summary

Prometheus/Alertmanager ส่ง alert ผิดๆ 3 ตัวตลอดเวลา:
- `KubeProxyDown`
- `KubeControllerManagerDown`
- `KubeSchedulerDown`

ทั้ง 3 service ไม่ได้ down จริง แต่เป็นเพราะ **K3s รวม component เหล่านี้เข้า binary เดียว** (kube-proxy, kube-scheduler, kube-controller-manager ไม่ได้ expose metrics แยก) ทำให้ Prometheus scrape endpoint แยกไม่ได้ → alert fire

## Root Cause

`kube-prometheus-stack` (chart ของ Helm) default สำหรับ vanilla Kubernetes ที่มี component แยกเป็น pod — ไม่ compatible กับ K3s architecture

## Fix Applied

แก้ `helm/kube-prometheus-stack/values.yaml`:

```yaml
defaultRules:
  rules:
    kubeControllerManager: false
    kubeProxy: false
    kubeSchedulerAlerting: false

kubeControllerManager:
  enabled: false
kubeProxy:
  enabled: false
kubeScheduler:
  enabled: false

# เพิ่ม Alertmanager route ส่ง alert เหล่านี้ไป null receiver
route:
  routes:
    - matchers: [alertname="KubeControllerManagerDown"]
      receiver: "null"
    - matchers: [alertname="KubeProxyDown"]
      receiver: "null"
    - matchers: [alertname="KubeSchedulerDown"]
      receiver: "null"
```

## Lessons Learned

- เวลา deploy Prometheus บน K3s (หรือ distro rewrite อื่นๆ เช่น RKE2, MicroK8s) ต้องปิด alert ของ component ที่ distro รวมเข้า binary
- ตรวจว่า alert ที่ firing ตรงกับ service ที่มีอยู่จริงก่อน panic
