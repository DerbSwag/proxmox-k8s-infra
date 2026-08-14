# Proxmox K8s Infrastructure Lab

[![Validate](https://github.com/DerbSwag/proxmox-k8s-infra/actions/workflows/validate.yml/badge.svg)](https://github.com/DerbSwag/proxmox-k8s-infra/actions/workflows/validate.yml)

Public-safe portfolio repository for a Proxmox-based Kubernetes infrastructure lab.

This repo demonstrates how I design, deploy, operate, observe, secure, and recover a small realistic hands-on Kubernetes platform. It is intentionally sanitized: real hostnames, internal IPs, credentials, webhook URLs, and organization-specific inventory are excluded or replaced with placeholders.

---

## Overview

The lab is built to show practical DevOps/SRE capability beyond basic Kubernetes manifests. It covers the full lifecycle:

- Provision infrastructure.
- Bootstrap Kubernetes.
- Deploy applications with GitOps.
- Monitor metrics and logs.
- Route alerts.
- Apply security controls.
- Back up and recover stateful workloads.
- Document incidents and runbooks.

Key outcomes:

| Area | Result |
| --- | --- |
| Platform | 3-node k3s cluster on Proxmox |
| IaC | Terraform + Ansible |
| GitOps | Argo CD-managed applications |
| Observability | Prometheus, Grafana, Loki, Zabbix |
| Alerting | Prometheus/Alertmanager and Grafana alerting patterns |
| Security | NetworkPolicy, Sealed Secrets, Kubescape remediation |
| Backup | VM, datastore, PVC, PostgreSQL dump, and remote-copy workflows |
| Operations | Incident notes, runbooks, and recovery procedures |

---

## Architecture

```text
Proxmox
  -> Terraform-managed VMs
    -> Ansible-installed k3s cluster
      -> Argo CD GitOps apps
      -> Helm platform services
      -> Kubernetes manifests for networking, monitoring, and security
```

Node layout:

| Role | Count | Purpose |
| --- | ---: | --- |
| Control plane | 1 | Kubernetes API and control-plane services |
| Worker | 2 | Application and platform workloads |
| Utility host | 1 | External checks, learning tasks, and remote backup target |

Network values in this public repo use documentation ranges or placeholders. The private source-of-truth repository contains the real environment inventory.

---

## Validated Capabilities

| Capability | Evidence |
| --- | --- |
| GitOps deployment | Argo CD sync and health states verified |
| GitOps self-heal | Manual resource drift corrected back to Git state |
| Drift detection | Application events captured `Synced -> OutOfSync -> Synced` behavior |
| Metrics dashboards | Kubernetes CPU, memory, backup, and CronJob panels built in Grafana |
| Log dashboards | Loki dashboards built for namespace and app log review |
| Metrics alerts | PrometheusRule alert created and verified through Alertmanager |
| Log alerts | Grafana-managed Loki alert fired from a known log pattern |
| Backup retention | PostgreSQL backup retention tested and documented |
| Off-PVC export | SQL dump copied from PVC to node filesystem |
| Remote backup | SQL dump copied to a remote host and verified with SHA-256 |
| Cleanup runbook | Temporary lab resources removed safely while preserving stateful data |

---

## Validated Kubernetes Operations Labs

Detailed public-safe summary: [docs/labs/kubernetes-operations-lab.md](docs/labs/kubernetes-operations-lab.md)

Restore evidence: [PostgreSQL Backup Restore Drill](docs/labs/kubernetes-operations-lab.md#postgresql-backup-restore-drill)

- Kubernetes workload and storage
- PostgreSQL CronJob backup
- Prometheus alert rule
- Grafana namespace dashboard
- Loki log dashboard
- Grafana-managed log alert
- Argo CD repo auth recovery
- GitOps self-heal and drift detection
- Cleanup/runbook
- Remote backup checksum verification

The lab also documents the complete restore path: backup PVC -> off-cluster copy -> checksum -> temporary database restore -> query validation -> idempotent cleanup.

Related runbook: [docs/runbooks/kubernetes-lab-cleanup-runbook.md](docs/runbooks/kubernetes-lab-cleanup-runbook.md)

---

## Stack

| Layer | Tools |
| --- | --- |
| Virtualization | Proxmox VE |
| Infrastructure as Code | Terraform |
| Configuration management | Ansible |
| Kubernetes | k3s |
| GitOps | Argo CD, Argo CD Image Updater |
| Packaging | Helm |
| Monitoring | Prometheus, Grafana, kube-prometheus-stack |
| Logging | Loki, Promtail |
| External monitoring | Zabbix |
| Alerting | Alertmanager, Grafana-managed alerting, webhook adapter pattern |
| Security | NetworkPolicy, Sealed Secrets, Kubescape, audit logging, encryption at rest |
| Backup | Proxmox backup, k3s datastore backup, PostgreSQL dump, PVC export, remote copy |

---

## GitOps Workflow

```text
Container image or manifest change
  -> Git update
  -> Argo CD detects desired-state change
  -> Cluster reconciles to Git
  -> Health and sync status are verified
```

Tested behavior:

- Automated sync.
- Hard refresh after repository authentication recovery.
- Self-heal after live resource drift.
- Rollout verification after image update.

---

## Backup & Recovery

Backup patterns tested:

| Scope | Pattern |
| --- | --- |
| VM | Hypervisor-level backup |
| k3s state | Datastore backup script |
| Persistent volumes | Local-path PV backup and export workflow |
| PostgreSQL | Scheduled `pg_dump` to PVC |
| Off-cluster copy | `kubectl cp` export and remote `scp` copy |
| Verification | SHA-256 checksum comparison |

Lessons:

- A PVC is not a remote backup by itself.
- Backup success requires restore or integrity verification evidence.
- Cleanup procedures must preserve stateful resources unless backup and restore are validated.

Curated public-safe resources:

- [Linux lab foundations](examples/linux-lab-foundations/) — Docker, PostgreSQL health dependency, and host-check examples.
- [90-day flagship project plan](docs/plans/90-day-flagship-project-plan.md)
- [90-day execution calendar](docs/plans/90-day-execution-calendar.md)
- [Kubernetes operations lab source templates](k8s/labs/kubernetes-operations/)
- [Proxmox storage-monitoring examples](examples/zabbix-proxmox-storage/)
- [Operations and DR patterns](docs/runbooks/operations-and-dr-patterns.md)
- [Operational reliability case studies](docs/case-studies/operational-reliability-patterns.md)
- [Portable observability dashboard patterns](docs/labs/observability-dashboard-patterns.md)

---

## Observability & Alerting

The lab validates both metrics and logs:

- Prometheus scrape target checks.
- Grafana dashboards for Kubernetes workloads.
- Loki dashboards for namespace and app logs.
- PrometheusRule alerting through Alertmanager.
- Grafana-managed Loki alerting from LogQL.
- External monitoring pattern with Zabbix.

Alerting lessons:

- Alert queries need labels that route cleanly.
- Log alerts require converting logs to numeric series, for example with `count_over_time`.
- Alert pipelines should be tested with known synthetic failures before relying on them.

---

## Security Controls

Security controls demonstrated:

- Namespace-level NetworkPolicy.
- Default-deny patterns with explicit allow rules.
- Sealed Secrets workflow for encrypted Kubernetes secrets.
- Kubescape scan and remediation tracking.
- Kubernetes audit logging.
- Encryption-at-rest configuration.
- Secret rotation documentation.

Public-safety controls for this repo:

- No real credentials.
- No real webhook URLs.
- No private kubeconfig.
- No real Terraform variable files.
- No real organization inventory.
- Sanitized network and host examples.

---

## Repository Structure

```text
proxmox-k8s-infra/
|-- ansible/          # k3s and host automation examples
|-- argocd/           # GitOps application examples
|-- docs/             # sanitized architecture, labs, incidents, DR, and notes
|-- helm/             # Helm chart and platform values examples
|-- k8s/              # Kubernetes manifests
|-- scripts/          # operational helper scripts
|-- terraform/        # Proxmox VM provisioning examples
|-- CHANGELOG.md
|-- INCIDENTS.md
|-- RUNBOOK.md
`-- README.md
```

---

## What I Learned

- GitOps is only useful when the repo is a reliable source of truth.
- NetworkPolicy failures often look like application failures until tested from inside the pod.
- Observability needs both metrics and logs; one alone leaves blind spots.
- Backup claims are weak without checksum or restore evidence.
- Runbooks should separate safe repeatable cleanup from destructive commands.
- Public portfolio repos must tell the engineering story without exposing internal topology.

---

## Safety Notice

This is a learning and portfolio repo. Values are intentionally sanitized. Do not copy the examples directly into production without reviewing network ranges, secrets, access control, backup retention, and compliance requirements.
