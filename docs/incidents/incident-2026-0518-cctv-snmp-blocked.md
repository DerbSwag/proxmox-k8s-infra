# Incident: CCTV SNMP Monitoring Unavailable

## Date: 2026-05-18
## Severity: Low
## Duration: ~5 days (since NetworkPolicy deploy on May 13)
## Status: Resolved

---

## Summary

All 3 CCTV cameras (Hikvision) showed SNMP availability as unknown/grey in Zabbix. SNMP polling from Zabbix server pod was blocked by NetworkPolicy.

---

## Affected Hosts

| Host | IP | Interface |
|------|-----|-----------|
| CCTV-01 | 10.0.3.9 | SNMP :161 |
| CCTV-02 | 10.0.1.x | SNMP :161 |
| CCTV-03 | 10.0.2.139 | SNMP :161 |

---

## Root Cause

NetworkPolicy `allow-egress-zabbix` in the `zabbix` namespace only allowed TCP port 10050 (Zabbix agent) egress. SNMP uses **UDP port 161** which was not included in the policy.

The policy was deployed on 2026-05-13 via ArgoCD. Before that, there was no egress restriction and SNMP worked fine.

---

## Resolution

Added UDP port 161 to all egress rules in `allow-egress-zabbix` NetworkPolicy:

```yaml
ports:
  - port: 10050
  - port: 161
    protocol: UDP
```

Commit: `90f74c8` — `fix(netpol): add SNMP UDP 161 egress for Zabbix CCTV monitoring`

---

## Verification

```bash
# From Zabbix server pod:
fping 10.0.3.9 10.0.1.x 10.0.2.139  # all alive
# UDP 161 connectivity confirmed via /dev/udp test
```

---

## Additional Fix: SNMP Template

After fixing the NetworkPolicy, SNMP availability remained grey because CCTV hosts only had "ICMP Ping" template linked — no SNMP items existed to trigger SNMP polling.

**Fix:** Replaced "ICMP Ping" template with "Generic by SNMP" template (which includes ICMP + SNMP discovery + network interface monitoring).

```python
# Via Zabbix API
host.update(hostid=X, templates=[{"templateid": "10563"}])  # Generic by SNMP
```

Result: SNMP availability turned green, 12 items now being collected per CCTV (uptime, interfaces, ICMP).

---

## Lesson Learned

1. When creating egress NetworkPolicies for monitoring namespaces, remember to include all protocols used:
   - TCP 10050 — Zabbix agent
   - UDP 161 — SNMP
   - ICMP — ping checks

2. SNMP availability in Zabbix only turns green when there are actual SNMP items being polled — having an SNMP interface configured is not enough.
