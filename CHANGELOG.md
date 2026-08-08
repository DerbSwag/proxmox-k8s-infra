# Changelog

All notable public-safe changes to this portfolio repository.

## [2026-08-08]

### Added

- Documented public-safe monitoring guardrails for Proxmox thin-pool capacity and scheduled VM backup health.
- Added the incident follow-up distinguishing a legacy storage failure from replacement-storage validation.
- Documented the need to route hypervisor alerts to an on-call destination, not only general Linux-host alerts.

## [2026-08-05]

### Added

- Added public-safe Zabbix Agent source allowlist note for Kubernetes-hosted Zabbix Server.
- Documented `Connection reset by peer` as an agent-side source rejection pattern, distinct from firewall timeout.
- Added validation pattern using `zabbix_get agent.ping` from the Zabbix Server pod.

## [2026-08-04]

### Added

- Added public-safe restore validation pattern for Proxmox backups using a temporary VMID and network isolation.
- Documented restore-test completion criteria and the difference between backup archive failure and target storage capacity constraints.
- Added public-safe thin-pool audit pattern for separating root filesystem cleanup from VM thin-pool cleanup.

## [2026-08-03]

### Added

- Added public-safe incident report for Proxmox HDD storage I/O errors during backup migration.
- Added Proxmox HDD storage runbook covering safe disk setup, backup migration, emergency disable, and hardware validation.

### Changed

- Updated incident and runbook summaries with storage safety and backup migration lessons.
- Added post-reboot read-only disk validation evidence showing the new HDD failed after 128 MiB with medium read errors.
- Added replacement completion evidence: replacement storage validated, backup dump copy verified, and original source retained as rollback.
- Documented backup schedule migration to replacement storage and a successful manual VM backup test.
- Added public-safe off-host backup copy pattern for VMs hosted on other Proxmox nodes.
- Documented node-specific backup schedules and off-host sync automation for local Proxmox directory storage.

## [2026-07-30]

### Added

- Added public-safe PostgreSQL backup restore drill summary.
- Documented restore validation pattern using a temporary database and idempotent cleanup.
- Added public-safe remote backup restore validation pattern.

### Changed

- Updated logrotate incident follow-up with sanitized shell PATH recovery notes.

## [2026-07-29]

### Added

- Added public-safe incident report for `logrotate.service` failure caused by duplicate rsyslog logrotate entries.
- Added public-safe Kubernetes operations lab documentation:
  - workload and storage,
  - PostgreSQL CronJob backup,
  - Prometheus alert rule,
  - Grafana namespace dashboard,
  - Loki log dashboard,
  - Grafana-managed log alert,
  - Argo CD repository authentication recovery,
  - GitOps self-heal and drift detection,
  - cleanup/runbook workflow,
  - remote backup checksum verification.
- Added Kubernetes lab cleanup runbook with safe deletion order and PVC preservation rules.
- Added lab documentation index under `docs/labs/`.

### Changed

- Added a `Validated Kubernetes Operations Labs` index to the root README.
- Replaced the repository tree with ASCII-safe formatting.

## [2026-07-27]

### Changed

- Reworked README into a portfolio-first structure.
- Removed detailed host inventory and direct access examples from top-level docs.
- Replaced environment-specific network values with sanitized descriptions and placeholders.
- Converted public-facing docs to clean UTF-8/ASCII-safe Markdown.
- Reframed runbook and incident documentation as public-safe operational summaries.

### Added

- Validated capabilities section covering:
  - GitOps deployment and self-heal,
  - Argo CD drift detection,
  - Grafana metrics dashboards,
  - Loki log dashboards,
  - Prometheus and Grafana alerting,
  - backup retention,
  - off-PVC export,
  - remote backup verification,
  - cleanup runbook behavior.

## [2026-06]

### Added

- Terraform and Ansible examples for Proxmox-based k3s infrastructure.
- Argo CD GitOps application examples.
- Helm values and Kubernetes manifests for platform services.
- Monitoring and alerting examples with Prometheus, Grafana, Loki, and Zabbix patterns.
- Security-hardening examples with NetworkPolicy, Sealed Secrets, and Kubescape remediation notes.
- Public-safe incident and runbook documentation.

### Fixed

- Documented common operational issues such as disk pressure, DNS policy blocks, alert routing failures, and GitOps drift.
- Captured disaster recovery and backup lessons in sanitized form.
