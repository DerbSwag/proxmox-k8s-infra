# Incident: Zabbix Server Not Running

## Date: 2026-05-15
## Severity: Medium
## Duration: ~4 days (since pod restart on May 11)
## Status: Resolved

---

## Summary

Zabbix server process was running but unable to connect to PostgreSQL database, causing it to not listen on port 10051. Zabbix web UI showed "Zabbix server is not running".

---

## Root Cause

Pod securityContext set `runAsUser: 1000` (ubuntu) but the Zabbix container image owns `/etc/zabbix/` as user `zabbix` (uid 1997). The entrypoint script uses `sed` to update `zabbix_server.conf` with environment variables (DBHost, etc.) but failed with "Permission denied". As a result, `DBHost` remained as `localhost` instead of `zabbix-postgresql`, causing connection refused to PostgreSQL.

---

## Symptoms

- Zabbix web: "Zabbix server is not running; the information displayed may not be current"
- Server log: `connection to database 'zabbix' failed: connection to server at "localhost", port 5432 failed: Connection refused`
- Port 10051 not listening (no TCP sockets open)
- Startup logs: `sed: couldn't open temporary file /etc/zabbix/sedXXX: Permission denied`

---

## Resolution

Changed `runAsUser` from 1000 to 1997 (zabbix uid) and `fsGroup` to 1995 in the deployment securityContext.

```bash
kubectl patch deploy -n zabbix zabbix-zabbix-server --type=json \
  --patch '[{"op":"replace","path":"/spec/template/spec/securityContext/runAsUser","value":1997},
            {"op":"replace","path":"/spec/template/spec/securityContext/fsGroup","value":1995}]'
```

Permanent fix: updated `helm/zabbix/values.yaml` with correct `podSecurityContext`.

---

## Lesson Learned

When applying security hardening (runAsNonRoot), always verify the UID matches the application's expected user inside the container image. Check with:
```bash
kubectl exec <pod> -- grep <app-user> /etc/passwd
```
