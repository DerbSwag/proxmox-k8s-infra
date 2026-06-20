# Incident Report — Worker Nodes Disk Near Full

- **Date detected:** 2026-05-09
- **Severity:** Medium (approaching eviction threshold)
- **Status:** ✅ Resolved + Automated
- **Fix commit:** `dc5e462`

---

## Summary

Worker nodes ทั้ง 2 ตัวใกล้เต็ม:
- worker-01: **81%** (4.4G free) — เสี่ยง eviction threshold (~85%)
- worker-02: **75%** (5.6G free)

Master สบาย (31%) เพราะ disk ใหญ่กว่า (48G vs 24G)

## Timeline

| เวลา | เหตุการณ์ |
|------|-----------|
| 2026-05-09 ~13:00 | Alert disk usage approaching threshold |
| 2026-05-09 ~13:30 | Manual cleanup: `crictl rmi --prune` + `journalctl --vacuum-time=3d` |
| 2026-05-09 ~13:35 | Push config to automate going forward |

## Root Cause

1. **ไม่มี image garbage collection threshold ที่เหมาะสม**
   K3s default: start GC ที่ 85% → ช้าเกินไปสำหรับ disk 24G
2. **Journal logs ไม่ถูกตัด** — สะสม 200MB+
3. **Worker disk sizing เล็ก** (24G vs master 48G)

## Fix Applied

### 1. Image GC threshold (ทุก node)
`/etc/rancher/k3s/config.yaml`:
```yaml
kubelet-arg:
  - "image-gc-high-threshold=70"  # เริ่มลบที่ 70%
  - "image-gc-low-threshold=50"   # ลบจนเหลือ 50%
```

### 2. Journal cleanup cron (ทุก node)
`/etc/cron.d/clean-journal`:
```
0 3 * * 0 root journalctl --vacuum-time=3d
```

ไฟล์ใน repo:
- `k8s/k3s-config.yaml`
- `scripts/setup-disk-cleanup.sh`

## Result (หลัง cleanup + restart)

| Node | ก่อน | หลัง |
|------|------|------|
| worker-01 | 81% | 66% |
| worker-02 | 75% | 58% |

## TODO

- [x] ขยาย disk worker-01/02 → 48G (lvextend, VM disk 50G อยู่แล้ว) — Done 2026-05-11
- [x] Prometheus alert: disk > 75% warning, > 85% critical — Done 2026-05-11
- [x] PVE 95 storage cleanup: ลบ orphan vm-100, snapshot `list`, backup keep-last=1 — Done 2026-05-11

## Lessons Learned

- Default K3s image GC threshold (85%) ไม่เหมาะกับ disk เล็ก — ต้อง tune ตาม size
- Journal logs สะสมเร็วกว่าคิด ต้องตั้ง rotation
- Sizing VM ให้ match ตัวอื่นใน tier เดียวกัน (workers ควรเท่า master)
