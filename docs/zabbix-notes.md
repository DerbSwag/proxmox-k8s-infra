# Zabbix Configuration Notes

## Global Macros

| Macro | Value | Purpose |
|-------|-------|---------|
| `{$SERVICE.NAME.NOT_MATCHES}` | `^(GoogleUpdater.*\|AppXSvc\|Intel\(R\).*\|SQLAgent\$.*\|igccservice)$` | Suppress false-positive alerts for Windows services that are "automatic (trigger start)" but don't run continuously |

> ⚠️ **Template macro overrides the global macro.** The template **"Windows by Zabbix agent"** (hostid 10081) defines its own `{$SERVICE.NAME.NOT_MATCHES}` which takes precedence over the global one for every linked host. Editing only the global macro has NO effect on monitored Windows hosts. Always update the template-level macro.

### Template "Windows by Zabbix agent" — `{$SERVICE.NAME.NOT_MATCHES}`
Added `GoogleUpdater.*` at the front of the template regex on 2026-06-12 (and AppXSvc on 2026-06-17 � same trigger-start false-positive) to stop hourly flapping alerts for `GoogleUpdaterService<ver>` / `GoogleUpdaterInternalService<ver>` (trigger-start services that stop themselves; service name carries a Chrome version suffix that changes on every update). After editing, run:
```
kubectl exec -n zabbix deploy/zabbix-zabbix-server -- zabbix_server -R config_cache_reload
```

## Alert Routing (Lark) — separated by OS, 2026-06-16

Zabbix trigger actions route to per-OS Lark groups via separate webhook media types.

| Action (eventsource=0) | Condition (host group) | Media type | Status |
|------------------------|------------------------|------------|--------|
| Forward to Lark Windows (id 9) | Windows PCs (gid 22) | Lark_Windows (72) → dedicated Windows group | enabled |
| Forward to Lark CCTV (id 10)   | CCTV (gid 23)        | Lark_CCTV (71) | enabled |
| Alert to Lark (id 7) / Forward to Lark Linux (id 8) | Zabbix/Linux servers | Lark_Linux (70) | disabled |

**Key fix (2026-06-16):** Previously all three media types (70/71/72) pointed to the **same** Lark webhook, so Windows/CCTV/Linux alerts all landed in one group despite the separate actions. Pointed `Lark_Windows` (media type 72) to a **dedicated Windows Lark group webhook** so Windows-host alerts (GSTAR/M-SERVER/HRMI/FILE-SERVER/APS) no longer mix with k8s/Linux noise.

- Webhook URLs live only in the Zabbix DB (`media_type_param`, name=`URL`) — NOT committed to git (secret).
- To re-point a group: update `media_type_param.value` for the relevant mediatypeid (70=Linux, 71=CCTV, 72=Windows).
- ⚠️ `kubectl exec` into `zabbix-postgresql-0` currently fails (pod on worker-01, kubelet:10250 blocked — see incident 2026-06-04). Workaround: run a throwaway `postgres:16` pod pinned to master and connect to the `zabbix-postgresql` ClusterIP service instead of exec-ing the pod.

## Server Tuning

| Parameter | Value | Default | Reason |
|-----------|-------|---------|--------|
| `ValueCacheSize` | 64M | 8M | Prevent "value cache working in low-memory mode" with 14 hosts |
| `CacheSize` | 64M | 32M | Accommodate growing number of items |

## Known Issues

- **APS-SERVER (10.0.2.11)**: Agent `Server=` config needs `10.0.1.11` added (Zabbix server SNAT IP). Requires RDP access to fix.
- **GSTAR-SERVER (10.0.3.23)**: Windows Firewall blocks 10.0.1.x/24. Firewall rule added on 2026-05-15 but agent config also needs update.
- **Disk space alerts**: FILE-SERVER D: drive >90% — needs cleanup by server admin.
- **M-SERVER (10.0.2.9)** (checked 2026-06-08): host is UP (ping + SMB/445 OK) but Zabbix agent (10050) and RDP (3389) are CLOSED. Routing to the 100.x VLAN is fine (APS-SERVER 100.11:10050 reachable). Zabbix DB shows `available=2`, error "cannot establish TCP connection to 10.0.2.9:10050: timed out". Root cause is on the host: Zabbix Agent service stopped/crashed or Windows Firewall blocking 10050+3389. Needs console/physical access (RDP also down) — server admin to start "Zabbix Agent" service and allow inbound 10050.
