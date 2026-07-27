# Action Log — Zabbix Problems Cleanup (2026-05-13)

- **Date:** 2026-05-13
- **Performed by:** DevOps (AI-assisted)
- **Severity:** Mixed (Low–Medium)

---

## Actions Taken

### 1. ✅ Set SNMP Community Macro
- ตั้ง global macro `{$SNMP_COMMUNITY}` = `public`
- ผลลัพธ์: CAMERA-01/02/03 จะกลับมา poll SNMP ได้ภายใน 5 นาที

### 2. ✅ Suppressed 23 Noise Triggers
Disabled triggers สำหรับ services ที่ไม่สำคัญ:
- Google Updater Service (v148, v149)
- Google Updater Internal Service (v148, v149)
- AppXSvc (AppX Deployment Service)
- Intel(R) Graphics Command Center Service
- Intel(R) Platform License Manager Service
- webthreatdefusersvc (Web Threat Defense User Service)

### 3. ✅ Checked Unreachable Hosts

| Host | Result | Action Needed |
|------|--------|---------------|
| APP-SERVER-02 (203.0.113.23) | 100% packet loss | เครื่องปิด/network down — เช็คที่หน้างาน |
| APP-SERVER-03 (198.51.100.9) | Ping OK, agent down | RDP → restart Zabbix Agent service |

### 4. ✅ Checked k8s-worker-01 Disk
- Used: **38%** (17G / 47G) — ปกติ, Image GC ทำงานดี

---

## Remaining (ต้องทำ manual)

- [ ] APP-SERVER-02 — เช็คที่หน้างานว่าเครื่องเปิดอยู่ไหม
- [ ] APP-SERVER-03 — RDP เข้าไป restart Zabbix Agent
- [ ] APP-SERVER-01 — Cleanup disk D: (>90% of 1.8TB)
