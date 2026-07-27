# Incident: Zabbix → Lark Webhook Failure

**Date:** 2026-05-13 → 2026-05-18 (5 days undetected)
**Severity:** Medium
**Impact:** All Zabbix alerts to Lark stopped working (Windows servers, camera, Linux hosts)
**Resolved:** 2026-05-18 17:39

## Timeline

| Time | Event |
|------|-------|
| 2026-05-06 | Last successful Lark alert (Google Updater service alerts) |
| 2026-05-13 | Added `default-deny-egress` NetworkPolicy to zabbix namespace |
| 2026-05-13 | **Lark webhook silently broke** — no alerts sent after this |
| 2026-05-18 17:25 | Discovered via Zabbix UI → Media type test → "Couldn't connect to server" |
| 2026-05-18 17:29 | Root cause identified: NetworkPolicy blocks port 443 egress |
| 2026-05-18 17:30 | Fix pushed (commit `0790247`) → ArgoCD synced → still failing |
| 2026-05-18 17:39 | Found protocol bug: port 443 was set to UDP instead of TCP |
| 2026-05-18 17:39 | Second fix pushed (commit `4b45187`) → removed stray `protocol: UDP` line |

## Root Cause

Added `default-deny-egress` to zabbix namespace but `allow-egress-zabbix` only permitted:
- Port 10050 (Zabbix agent) to internal subnets
- Port 161/UDP (SNMP) to internal subnets

**Missing:** Port 443 (HTTPS) to external IPs for Lark webhook (`open.larksuite.com`)

## Detection Method

Manual test in Zabbix UI → Administration → Media types → Test

## Fix

Added egress rule to `allow-egress-zabbix` NetworkPolicy:

```yaml
# Lark webhook (outbound HTTPS)
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - <PRIVATE_NETWORK_CIDR>
          - 172.16.0.0/12
          - 192.0.2.0/24
  ports:
    - port: 443
      protocol: TCP
```

Commit: `0790247` — auto-synced by ArgoCD

## Follow-up Fix: Protocol Bug

First fix still failed because the YAML had a stray `protocol: UDP` line below the `protocol: TCP` line. K8s applied the last value (UDP), making the rule 443/UDP instead of 443/TCP.

```yaml
# Bug (applied as UDP):
      ports:
        - port: 443
          protocol: TCP

          protocol: UDP   ← stray line, overrides TCP

# Fixed:
      ports:
        - port: 443
          protocol: TCP
```

Commit: `4b45187`

## Lessons Learned

1. **Always test webhook after NetworkPolicy changes** — deny-all egress breaks outbound integrations silently
2. **monitoring namespace had the rule, zabbix didn't** — copy the pattern when adding deny-all to new namespaces
3. **No alerting on "alert system failure"** — consider adding a heartbeat/dead-man-switch to detect when alerting itself is broken
4. **5 days undetected** — need periodic webhook health check (cron job that tests Lark connectivity)
5. **Verify YAML after automated edits** — stray lines from copy-paste can silently change protocol/values
6. **Always re-test after fix** — first fix looked correct but had a hidden bug

## Prevention

- [ ] Add webhook connectivity test to CI/validation
- [ ] Add dead-man-switch (periodic test alert to Lark)
- [ ] Checklist for NetworkPolicy changes: verify all integrations still work
