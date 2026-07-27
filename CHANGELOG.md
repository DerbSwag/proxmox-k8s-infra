# Changelog

All notable public-safe changes to this portfolio repository.

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

