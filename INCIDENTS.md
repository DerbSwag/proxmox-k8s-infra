# Incident Portfolio Summary

This file summarizes incident patterns from the lab in a public-safe format. It intentionally excludes real hostnames, internal IPs, webhook URLs, credentials, and step-by-step access commands.

## Why Incidents Are Included

The goal is to show operational maturity:

- detect failures,
- identify root cause,
- apply a fix,
- verify recovery,
- capture lessons learned,
- improve runbooks and automation.

## Incident Categories

| Category | What was learned |
| --- | --- |
| DNS blocked by NetworkPolicy | Default-deny policies need explicit DNS egress and should be tested from inside pods |
| API server blocked by NetworkPolicy | Network policy controllers may evaluate traffic after DNAT, so service IP assumptions can be wrong |
| Alert delivery blocked | Monitoring integrations need egress tests after policy changes |
| Disk pressure | Container images, logs, and backup retention need routine cleanup and capacity checks |
| GitOps drift | Live edits should be detected and reconciled back to Git state |
| Full cluster rebuild | Disaster recovery requires GitOps manifests, backups, and documented restore order |
| Vault restart/data loss | Development-mode storage is not acceptable for persistent secrets |
| Metrics gaps | Kubelet and node-exporter reachability must be checked separately from application availability |
| Proxmox host instability | Hardware and quorum issues need separate runbooks from Kubernetes incidents |
| Proxmox HDD storage I/O error | New storage disks must be burn-tested; never delete source backups until the target copy is verified |
| Proxmox SATA link instability | Kernel SATA resets can indicate a cable, connector, port, or drive-interface fault even when SMART media health passes |
| Windows Server VirtIO and Guest Agent setup | Windows needs a matching VirtIO storage driver; validate the dedicated `QEMU-GA` service after installation |
| Power outage recovery | VM autostart, dependency order, and control-plane recovery must be verified |
| Windows Server license expiry | Event 1074 can distinguish a planned license-enforcement shutdown from an unexpected restart; licensing and host-hardware investigations must remain separate |
| Logrotate duplicate entries | Distribution-managed log rotation should not be duplicated by custom rules |

## Representative Incident Template

```text
Problem:
  What failed and how users/operators noticed it.

Impact:
  What workload, service, alert, or recovery path was affected.

Root cause:
  The smallest confirmed cause, not the first guess.

Fix:
  The action that changed system state and resolved the incident.

Verification:
  The command, dashboard, alert state, or checksum that proved recovery.

Lessons learned:
  What changed in automation, monitoring, runbooks, or design.
```

## Portfolio Value

These incidents demonstrate:

- troubleshooting under uncertainty,
- network policy debugging,
- backup and disaster recovery thinking,
- observability pipeline validation,
- GitOps recovery and self-heal behavior,
- Proxmox storage safety and backup migration discipline,
- Linux service troubleshooting and log rotation hygiene,
- operational documentation discipline.

Detailed internal evidence is kept in the private source-of-truth repository.
