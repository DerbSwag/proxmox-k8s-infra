# Incident Report — Zabbix to Lark Alert ไม่ส่ง

- **Date detected:** ~2026-05-05
- **Severity:** Medium (monitoring blind spot — alerts not reaching team)
- **Status:** ✅ Resolved & Verified
- **Fix commit:** `ff96b4f`

---

## Summary

Zabbix ตรวจจับปัญหาได้ (triggers fire) แต่ **alert ไม่ถูกส่งไปยัง Lark** ทำให้ทีมไม่ได้รับ notification — เป็น monitoring blind spot ที่อาจทำให้ miss incident จริง

## Root Cause

Media types ใน Zabbix ไม่ได้ถูก configure ให้ส่งไปยัง Lark webhook อย่างถูกต้อง — ต้อง setup media types แยกสำหรับแต่ละ host group:
1. Linux servers
2. Windows servers
3. CCTV devices

## Fix Applied

Configure Zabbix media types ทั้ง 3 ให้ส่งผ่าน Lark Alert Adapter (`lark-alert-adapter` pod ใน monitoring namespace, ClusterIP :5001):
- สร้าง/แก้ media type ให้ชี้ไปที่ webhook URL ของ Lark
- Map user/group ให้ได้รับ alert ตาม severity

## Verification

ทดสอบส่ง alert จริงทั้ง 3 media types:
- ✅ Linux server alerts → Lark
- ✅ Windows server alerts → Lark
- ✅ CCTV alerts → Lark

## Lessons Learned

- Monitoring ที่ไม่ส่ง alert = ไม่มี monitoring — ต้อง verify end-to-end หลัง setup
- ควรมี "alert test" เป็นส่วนหนึ่งของ morning health check
- Lark Alert Adapter pod ต้อง running ตลอด — เพิ่ม alert สำหรับ pod down ของตัว adapter เอง
