# Incident Report — Multiple CrashLoops (Misdiagnosed)

- **Date detected:** 2026-05-09
- **Severity:** High (production services down)
- **Status:** ✅ Resolved (root cause later traced to DNS issue)
- **Related:** [`2026-05-11-dns-blocked-by-networkpolicy.md`](./2026-05-11-dns-blocked-by-networkpolicy.md)

---

## Summary

มี pod crash พร้อมกัน 3 ตัว:
1. `zabbix-zabbix-web-5d476bbff-9jttv` — CrashLoop (restart 253 ครั้ง)
2. `argocd-repo-server-6fd5c47689-rttv9` — CrashLoop (restart 279 ครั้ง)
3. `zabbix-nodesclean` CronJob — Failed

ตอนแก้คิดว่าเป็น 3 ปัญหาแยก — แต่ **ทั้งหมดมาจาก DNS block เดียวกัน** (NetworkPolicy ที่ merge วันที่ 8 พ.ค.)

## Timeline

| เวลา | เหตุการณ์ |
|------|-----------|
| 2026-05-09 ~03:30 | Alert flood: zabbix-web CrashLoop + argocd-repo-server CrashLoop |
| 2026-05-09 ~10:30 | Investigation: `PostgreSQL not available` (zabbix-web), `context canceled` (argocd) |
| 2026-05-09 ~10:35 | **Fix #1:** `kubectl rollout undo` zabbix-web → pod เก่าที่มี cached DNS กลับมา |
| 2026-05-09 ~10:40 | **Fix #2:** restart argocd-repo-server → ได้ pod ใหม่ที่ซักพักก็ crash อีก |
| 2026-05-09 ~11:07 | argocd-repo-server crash อีกรอบ |
| 2026-05-09 ~11:10 | **Fix #3:** เพิ่ม liveness probe tolerance (timeoutSeconds 5→15, failureThreshold 3→5) → pod อยู่ได้ |
| 2026-05-11 ~08:00 | zabbix-nodesclean fail ซ้ำ → สืบต่อจนพบ root cause ที่แท้จริง |

## What We Thought vs What It Actually Was

| Symptom | Initial diagnosis | Actual root cause |
|---------|------------------|-------------------|
| zabbix-web: `PostgreSQL not available` | Deployment config ผิด → rollback | DNS resolve `zabbix-postgresql` ไม่ได้ |
| argocd-repo-server: health check timeout | Probe ตั้ง tight เกินไป | DNS lookup ภายใน service ช้า/fail |
| nodesclean Job failed | Transient error → delete job | DNS fail ทุกครั้งที่ pod เริ่ม |

## Fix Applied (ที่ถูกต้อง in hindsight)

Root cause fix: apply NetworkPolicy `allow-dns` — ดู [`2026-05-11-dns-blocked-by-networkpolicy.md`](./2026-05-11-dns-blocked-by-networkpolicy.md)

แต่ workarounds ที่ทำตอนนั้นก็มีประโยชน์:
- ✅ Probe tolerance ของ argocd-repo-server กว้างขึ้น — ดีสำหรับ stability ระยะยาว

## Lessons Learned

1. **Multiple simultaneous crashes = 1 shared dependency issue**
   ถ้า pod จากหลาย namespace crash พร้อมกัน ตรวจ common dependency ก่อน (DNS, network, storage) อย่ารีบแก้ทีละตัว
2. **Rollback แก้อาการปลายทางได้ ไม่ได้แก้ root cause**
   Pod เก่าทำงานได้เพราะ DNS cached ไม่ใช่เพราะ config ถูก
3. **อย่าตีความ error message ตามตัวอักษร**
   `PostgreSQL not available` ไม่ได้แปลว่า PG มีปัญหา — มันคือ client ไม่รู้จะไปหาที่ไหน
4. **Investigate ก่อน fix**
   ถ้าตอนวันที่ 9 พ.ค. ทำ `kubectl exec` แล้ว `nslookup zabbix-postgresql` จะเจอทันทีภายใน 30 วินาที — ประหยัดเวลา ~2 วัน
