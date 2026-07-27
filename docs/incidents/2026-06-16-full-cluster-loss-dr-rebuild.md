# Incident: Full cluster loss during worker-01 reinstall (DR rebuild)

**Date:** 2026-06-16
**Severity:** CRITICAL
**Status:** RECOVERED (with data loss — accepted)
**Impact:** Entire k3s cluster lost. Zabbix history/config and Vault data permanently lost. ~1h rebuild.

## What happened

While reinstalling worker-01's k3s agent (to fix the long-standing host-port issue,
incident 2026-06-04), the cleanup steps destroyed far more than intended:

1. Ran `k3s-killall.sh` then attempted `k3s-agent-uninstall.sh` on worker-01.
2. Discovered worker-01 actually had a **k3s SERVER install** (`k3s-uninstall.sh`
   present, not just agent) — confirming the earlier "two units" confusion: worker-01
   had been mis-joined as a server/agent hybrid.
3. After uninstall + reinstall attempts, **the MASTER also lost all k3s state**:
   `/usr/local/bin/k3s`, systemd units, `/var/lib/rancher/k3s` (incl. datastore and
   local-path PV storage) — all gone. Exact propagation path unconfirmed, but the
   master's k3s went inactive and its data dir was emptied during the worker-01 work.
4. `k3s-uninstall.sh` removed `/var/lib/rancher/k3s/storage` → **local-path PV data
   for Vault and Zabbix-postgres was deleted.**

## Recovery (Option B — accept data loss, rebuild from GitOps)

Followed `docs/disaster-recovery.md` Scenario 3:
1. Fresh `k3s server` install on master (v1.34.5+k3s1, `--disable traefik`).
2. Re-joined both workers with the new node-token (clean agent installs).
3. Redeployed stack via Helm: kube-prometheus-stack (82.15.1), Loki, Zabbix, Vault
   (standalone persistent), ArgoCD.
4. Applied manifests: lark-alert-adapter, custom-alerts, bind9, network-policies,
   ArgoCD applications.
5. Re-bootstrapped Vault (new init keys at `~/vault-init-keys.json`, k8s auth,
   fastapi role + `secret/fastapi/db`).
6. Zabbix came up fresh (web HTTP 200) — **hosts/history must be re-added manually.**

### Result
- 3 nodes Ready, all pods Running, DNS OK, Prometheus targets up (3 node-exporters),
  Grafana/Alertmanager/Loki up, Zabbix web 200, Vault 1/1 unsealed.

## Permanent data loss
- **Zabbix history/metrics** (graphs, trends prior to 2026-06-16) — GONE (DB + the
  24-May VM backup were both lost; the backup was deleted during the disk-full cleanup).
- **Zabbix config was fully REBUILT** (2026-06-16): all 14 hosts re-added via
  `scripts/zabbix-readd-hosts.sh` (Linux/Windows/Proxmox/camera), GoogleUpdater
  suppression macro re-applied, per-OS Lark routing recreated (media types 70/71/72 +
  3 actions, Windows -> dedicated group), hypervisor-01/hypervisor-02 linked to Linux template (194
  items each, available), CAMERA-01/02/03 linked to Generic-by-SNMP (community placeholder,
  verified). **All 14 hosts UP.**
- **Vault**: previous secrets re-created via bootstrap (fastapi/db placeholder pw).
- **Vault**: previous secrets — re-created via bootstrap (only fastapi/db, placeholder pw).

## CRITICAL secondary finding — backups were broken
- Proxmox VM backups for **200 (master)** and **201 (worker-01)** had been **failing
  since ~2026-05-24** with `vma_queue_write: write error - Broken pipe` (likely backup
  target disk full). Only the template (9000) and worker-02 (210) backups succeeded.
- Latest usable 200/201 backup: **2026-05-24** (3 weeks stale). We chose NOT to restore
  it (Option B) since monitoring data since then was gone regardless.
- **etcd/datastore auto-snapshots**: none found — k3s uses SQLite (kine) by default,
  not etcd, so the documented `/var/lib/rancher/k3s/server/db/snapshots` did not exist.

## Repo fixes made during DR
- `helm/zabbix/values.yaml` was **corrupt** (broken escape chars + bad indentation,
  lines 16-18) and could not be parsed by Helm. Repaired and committed (68e2658).
  This file had been broken in git for a while; Zabbix only survived because it was
  deployed before the corruption.

## Action items (do these SOON)
1. **Fix Proxmox backups** — ✅ DONE 2026-06-16. Root cause: backup retention
   `keep-last=1,keep-weekly=4` accumulated more backups (10-15GB each × 4 VMs) than
   the 65GB pve root disk could hold → disk hit 100% → silent "Broken pipe" failures
   since ~05-24. Fix: pruned old backups (hypervisor-01 100%→63%, hypervisor-02 90%→36%), changed
   retention to `keep-last=1` in `/etc/pve/jobs.cfg` (shared cluster config), and
   verified fresh backups of 200 + 201 now succeed. **Longer term: backups should go
   to external storage (NFS/PBS), not the small local pve disk.** Also add an alert
   when a vzdump job fails (mailnotification is set to `always` but no one watches it).
2. **Use a proper datastore backup for k3s** — enable etcd (`--cluster-init`) with
   scheduled snapshots to S3/NFS, OR back up the SQLite `state.db` regularly.
3. **Move stateful PVs off local-path** or back them up — local-path data is destroyed
   by `k3s-uninstall.sh`. Consider an external NFS/Longhorn StorageClass for Vault/Zabbix DB.
4. **Vault auto-unseal** — ✅ DONE 2026-06-16. CronJob `k8s/vault/auto-unseal-cronjob.yaml`
   unseals Vault every 2 min from a `vault-unseal` Secret (key not in git). Verified by
   deleting vault-0 → returned 1/1 Running automatically. See maintenance runbook Task 2.
5. **Document Zabbix host inventory in git** — ✅ DONE. `scripts/zabbix-readd-hosts.sh`
   reprovisions all 13 hosts via API; inventory also in README "Monitored Hosts".
6. **worker-01 root cause** — ✅ CONFIRMED 2026-06-16 (not k3s). Duplicate static IP
   192.0.2.10 in netplan on all nodes + DHCP override → asymmetric routing drops
   cross-node host-port traffic (9100/10250). Fix runbook:
   `docs/incidents/2026-06-16-worker-duplicate-ip-rootcause.md` (needs Proxmox console).

## Lessons learned
- **Never run uninstall/killall on a node without first confirming exactly which
  install type it is** and what shared state it touches.
- **Verify backups actually produce files** — a green-looking schedule with only
  `.log` files (no `.vma.zst`) is a silent failure.
- local-path PV data is NOT safe across k3s reinstalls. Treat it as ephemeral.
- GitOps saved us: the whole stack was rebuildable from the repo in ~1h. Keep more
  state (Zabbix host inventory, Vault policies) in git.
