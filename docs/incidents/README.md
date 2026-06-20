# Incident Reports

บันทึกเหตุการณ์ที่กระทบ production สำหรับการ learn และป้องกันซ้ำ

## Format

แต่ละไฟล์ชื่อ `YYYY-MM-DD-short-description.md` ต้องมี:

- Summary
- Timeline
- Root cause
- Fix applied
- Action items
- Lessons learned

## Index (เรียงจากใหม่ไปเก่า)

| Date | Severity | Title | Status |
|------|----------|-------|--------|
| 2026-05-11 | High | [DNS blocked by NetworkPolicy](./2026-05-11-dns-blocked-by-networkpolicy.md) | ✅ Resolved |
| 2026-05-09 | High | [Multiple CrashLoops Misdiagnosed](./2026-05-09-multiple-crashloops-misdiagnosed.md) | ✅ Resolved (root = DNS) |
| 2026-05-09 | Medium | [Worker Nodes Disk Near Full](./2026-05-09-worker-nodes-disk-full.md) | ✅ Resolved + Automated |
| 2026-05-08 | Medium | [Kubescape Security Gaps](./2026-05-08-kubescape-security-gaps.md) | ✅ Remediated |
| 2026-05-05 | Medium | [Zabbix to Lark Alert ไม่ส่ง](./2026-05-05-zabbix-lark-alert-not-sending.md) | ✅ Resolved & Verified |
| 2026-04-07 | Medium | [ArgoCD ApplicationSet CRD Missing](./2026-04-07-argocd-applicationset-crd-missing.md) | ✅ Resolved |
| 2026-04-07 | Low | [Proxmox apt update 401 Unauthorized](./2026-04-07-proxmox-apt-401-unauthorized.md) | ✅ Resolved |
| 2026-04-07 | Low | [False Positive Alerts (K3s)](./2026-04-07-false-alerts-k3s-components.md) | ✅ Resolved |

## Patterns Observed

จากทั้งหมด 8 incidents:

1. **Security/hardening changes มี blast radius ใหญ่** — NetworkPolicy, probe tuning ส่งผลข้าม namespace ได้
2. **K3s ≠ vanilla K8s** — default alerts/charts ต้อง tune ตาม distro
3. **Root cause ≠ symptom location** — CrashLoop ของ zabbix-web จริงๆ คือ DNS
4. **Disk sizing ควร uniform** — worker 24G vs master 48G = worker เต็มก่อน
5. **ไม่ผ่าน test ก่อน production** — NetworkPolicy, CRD ต้องมี automated verification
6. **Monitoring ต้อง verify end-to-end** — Zabbix detect ได้แต่ alert ไม่ส่ง = ไม่มี monitoring
7. **Fresh install ต้อง harden ทันที** — Proxmox enterprise repo, K8s security context ควรทำตั้งแต่ day 1
