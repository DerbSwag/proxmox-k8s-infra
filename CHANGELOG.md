# Changelog

All notable changes to proxmox-k8s-infra. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [2026-06-17]
### Fixed
- **Worker host-port block RESOLVED** (open since 06-04): removed leftover DHCP
  override in netplan (dual-IP asymmetric routing) + re-added missing UFW rules for
  9100/10250 on both workers. All node-exporter/kubelet targets UP, `kubectl top` and
  `kubectl exec` to worker pods work again.
- Suppressed `AppXSvc` flapping (trigger-start service) on the Windows Zabbix template.
### Added
- RUNBOOK: "Worker host-port blocked" fix procedure (SSH-safe with auto-revert) +
  "Add a host to Zabbix" section.

## [2026-06-17 earlier]

## [2026-06-16] — Disaster Recovery day
### Added
- `scripts/k3s-backup.sh` — daily off-node backup of k3s SQLite datastore + local-path
  PVs to pve01 (separate disk), 7-day retention, cron 03:00. Closes the data-loss gap.
- `scripts/zabbix-readd-hosts.sh` — reprovision all monitored hosts via Zabbix API.
- `k8s/vault/auto-unseal-cronjob.yaml` — auto-unseal standalone Vault every 2 min
  (key in out-of-band Secret; verified by deleting vault-0).
- `k8s/monitoring/custom-alerts.yaml` — cluster-down summary alerts
  (ClusterControlPlaneDown / MultipleNodesDown / SingleNodeDown).
- Alertmanager inhibit rules + throttle so a full outage sends one clear signal,
  and the known worker-01 TargetDown repeats weekly instead of every 4h.
- Monitored hosts: CCTV-04 (10.0.1.x); pve01/pve02 on Zabbix Linux agent template.
- Proxmox VM autostart (`onboot=1` + startup order) on all cluster VMs.
### Changed
- Vault: dev-mode (inmem) → standalone file storage on PVC (`helm/vault/values.yaml`).
- Master VM RAM 4GB → 6GB (fix recurring OOM during reschedules).
- Proxmox backup retention `keep-last=1,keep-weekly=4` → `keep-last=1` (fit 65G disk).
- Windows Zabbix alerts routed to a dedicated Lark group (media type webhook).
### Fixed
- **Full cluster loss + rebuild** after worker-01 reinstall wiped master k3s state and
  local-path PVs. Rebuilt from GitOps; Zabbix/Vault config restored (history lost).
- Proxmox backups had been failing since ~05-24 (disk 100% full / "Broken pipe");
  pruned old dumps, verified fresh master+worker backups succeed.
- `helm/zabbix/values.yaml` corrupted (bad escapes/indentation) — repaired.
- Proxmox hosts rebooted (power event) with VMs not auto-starting → whole cluster down.
### Root cause (documented, fix pending)
- Worker host-port (9100/10250) blocked = duplicate static IP `10.0.1.10` in
  netplan on all nodes + DHCP override → asymmetric routing. Safe fix runbook prepared
  (needs Proxmox console). NOT a k3s/firewall issue.

## [2026-06-15]
### Added
- `RUNBOOK.md` — proven operational procedures (disk full, NotReady, CrashLoop,
  ArgoCD, DNS, NetworkPolicy, Lark, Proxmox).

## [2026-06-12]
### Fixed
- GoogleUpdater service alert flapping suppressed at the "Windows by Zabbix agent"
  template macro (`{$SERVICE.NAME.NOT_MATCHES}`); documented template-overrides-global gotcha.

## [2026-06-08]
### Changed
- Master VM RAM increased (OOM during worker-01 work); documented worker-01 k3s/k3s-agent
  systemd unit conflict.

## [2026-06-04]
### Changed
- Vault switched from dev-mode to standalone file storage + `scripts/bootstrap-vault.sh`.
### Docs
- Incident: metrics-server cannot scrape worker kubelets (deferred).

## [2026-06-03]
### Added
- linux-lab node-exporter scrape config in Prometheus.
### Fixed
- Zabbix web unreachable — VXLAN (UDP 8472) blocked by UFW; opened inter-node ports,
  persisted rules. Documented incident + probable trigger.
