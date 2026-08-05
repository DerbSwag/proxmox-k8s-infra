# Zabbix Configuration Notes

## Global Macros

| Macro | Value | Purpose |
|-------|-------|---------|
| `{$SERVICE.NAME.NOT_MATCHES}` | `^(GoogleUpdater.*\|AppXSvc\|Intel\(R\).*\|SQLAgent\$.*\|igccservice)$` | Suppress false-positive alerts for Windows services that are "automatic (trigger start)" but don't run continuously |

> ⚠️ **Template macro overrides the global macro.** The template **"Windows by Zabbix agent"** (hostid 10081) defines its own `{$SERVICE.NAME.NOT_MATCHES}` which takes precedence over the global one for every linked host. Editing only the global macro has NO effect on monitored Windows hosts. Always update the template-level macro.

### Template "Windows by Zabbix agent" — `{$SERVICE.NAME.NOT_MATCHES}`
Added `GoogleUpdater.*` at the front of the template regex on 2026-06-12, and `AppXSvc` on 2026-06-17 for the same trigger-start false-positive pattern. This stops hourly flapping alerts for `GoogleUpdaterService<ver>` / `GoogleUpdaterInternalService<ver>` services that stop themselves after startup. After editing, run:
```
kubectl exec -n zabbix deploy/zabbix-zabbix-server -- zabbix_server -R config_cache_reload
```

## Alert Routing (Lark) — separated by OS, 2026-06-16

Zabbix trigger actions route to per-OS Lark groups via separate webhook media types.

| Action (eventsource=0) | Condition (host group) | Media type | Status |
|------------------------|------------------------|------------|--------|
| Forward to Lark Windows (id 9) | Windows PCs (gid 22) | Lark_Windows (72) → dedicated Windows group | enabled |
| Forward to Lark camera (id 10)   | camera (gid 23)        | Lark_camera (71) | enabled |
| Alert to Lark (id 7) / Forward to Lark Linux (id 8) | Zabbix/Linux servers | Lark_Linux (70) | disabled |

**Key fix (2026-06-16):** Previously all three media types (70/71/72) pointed to the **same** Lark webhook, so Windows/camera/Linux alerts all landed in one group despite the separate actions. Pointed `Lark_Windows` (media type 72) to a **dedicated Windows Lark group webhook** so Windows-host alerts (GSTAR/APP-SERVER-03/HRMI/APP-SERVER-01/APS) no longer mix with k8s/Linux noise.

- Webhook URLs live only in the Zabbix DB (`media_type_param`, name=`URL`) — NOT committed to git (secret).
- To re-point a group: update `media_type_param.value` for the relevant mediatypeid (70=Linux, 71=camera, 72=Windows).
- ⚠️ `kubectl exec` into `zabbix-postgresql-0` currently fails (pod on worker-01, kubelet:10250 blocked — see incident 2026-06-04). Workaround: run a throwaway `postgres:16` pod pinned to master and connect to the `zabbix-postgresql` ClusterIP service instead of exec-ing the pod.

## Server Tuning

| Parameter | Value | Default | Reason |
|-----------|-------|---------|--------|
| `ValueCacheSize` | 64M | 8M | Prevent "value cache working in low-memory mode" with 14 hosts |
| `CacheSize` | 64M | 32M | Accommodate growing number of items |

## Agent Source Allowlist for k8s-hosted Zabbix

When Zabbix Server runs inside Kubernetes, passive agent checks may reach monitored hosts from different source addresses:

- the Zabbix server pod IP,
- the Kubernetes pod CIDR,
- or a node egress IP if traffic is SNATed by the CNI/node.

If `zabbix_get` returns `Connection reset by peer`, the agent is usually reachable on TCP/10050 but rejecting the source because its `Server=` allowlist is incomplete.

Public-safe example:

```ini
Server=<control-plane-ip>,<worker-node-ip-1>,<worker-node-ip-2>,<pod-cidr>
```

Validation pattern:

```bash
kubectl -n zabbix exec <zabbix-server-pod> -c zabbix-server -- \
  zabbix_get -s <agent-ip> -p 10050 -t 4 -k agent.ping
```

Expected result:

```text
1
```

Operational note: if the Zabbix server pod moves to another node, agent availability can turn red unless every possible node egress IP is included in `Server=`.

## Known Issues

- **APP-SERVER-04 (198.51.100.11)**: Agent `Server=` config needs `192.0.2.11` added (Zabbix server SNAT IP). Requires RDP access to fix.
- **APP-SERVER-02 (203.0.113.23)**: Windows Firewall blocks 192.0.2.x/24. Firewall rule added on 2026-05-15 but agent config also needs update.
- **Disk space alerts**: APP-SERVER-01 D: drive >90% — needs cleanup by server admin.
- **APP-SERVER-03 (198.51.100.9)** (checked 2026-06-08): host is UP (ping + SMB/445 OK) but Zabbix agent (10050) and RDP (3389) are CLOSED. Routing to the 100.x VLAN is fine (APP-SERVER-04 100.11:10050 reachable). Zabbix DB shows `available=2`, error "cannot establish TCP connection to 198.51.100.9:10050: timed out". Root cause is on the host: Zabbix Agent service stopped/crashed or Windows Firewall blocking 10050+3389. Needs console/physical access (RDP also down) — server admin to start "Zabbix Agent" service and allow inbound 10050.
