# Incident Report — ApplicationSet CRD Missing (ArgoCD v3.3.6)

- **Date detected:** 2026-04-07
- **Severity:** Medium (ArgoCD feature broken)
- **Status:** ✅ Resolved
- **Fix commit:** `4009ddd`

---

## Summary

หลัง upgrade/install ArgoCD v3.3.6 พบว่า **ApplicationSet controller ไม่ทำงาน** — สร้าง ApplicationSet ไม่ได้เพราะ CRD `applicationsets.argoproj.io` หาย

## Root Cause

ArgoCD v3.3.6 Helm chart ไม่ได้ bundled ApplicationSet CRD ให้ auto-install (หรือถูก override/ลบตอน deploy) ทำให้ controller start ได้แต่ serve API ไม่ได้

## Fix Applied

เพิ่ม CRD เต็ม (`applicationset-crd.yaml`, 23K lines) เข้า repo แล้ว apply ตรง:

```bash
kubectl apply -f argocd/crds/applicationset-crd.yaml
```

## Lessons Learned

- ArgoCD upgrade/reinstall ต้อง verify CRDs ครบทั้งหมด ไม่ใช่แค่ pod status
- เก็บ CRDs ไว้ใน Git เผื่อ chart/release ลบ CRD ตอน uninstall
- ตั้ง annotation `helm.sh/resource-policy: keep` บน CRDs ใน Helm chart
