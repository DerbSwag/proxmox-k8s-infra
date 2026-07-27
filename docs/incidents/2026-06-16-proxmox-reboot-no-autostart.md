# Incident: Proxmox hosts rebooted, all VMs stayed down (no autostart)

**Date:** 2026-06-16 (hosts rebooted ~2026-06-15 05:40)
**Severity:** High
**Status:** RESOLVED
**Impact:** Entire k3s cluster down for ~28h. Continuous TargetDown alerts (kubelet/node-exporter), monitoring blind. Vault/workloads offline.

## Symptoms

- Sustained `TargetDown 33%` alerts firing repeatedly (actually the whole cluster, but Prometheus could only report partial before it too went down)
- master (192.0.2.10) unreachable: no ping, no SSH

## Root Cause

Both Proxmox hosts (hypervisor-01 + hypervisor-02) rebooted ~1d4h before detection (uptime confirmed both ~1 day 4h) — likely a power event affecting both. **None of the cluster VMs had `onboot` enabled**, so after the hosts came back, every VM stayed `stopped`:
- hypervisor-01: 200 k8s-master, 201 k8s-worker-01, 103 dns-server, 101 linux-lab — all stopped
- hypervisor-02: 210 k8s-worker-02 — stopped

## Resolution

1. Started VMs in order via Proxmox: master(200)+dns(103) → workers(201,210)+linux-lab(101)
2. Cluster came up: 3 nodes Ready
3. Unsealed Vault (standalone, does not auto-unseal)
4. **Enabled autostart on all VMs to prevent recurrence:**
   ```bash
   # hypervisor-01
   qm set 200 --onboot 1 --startup order=1   # master
   qm set 103 --onboot 1 --startup order=1   # dns
   qm set 201 --onboot 1 --startup order=2   # worker-01
   qm set 101 --onboot 1                     # linux-lab
   # hypervisor-02
   qm set 210 --onboot 1 --startup order=2   # worker-02
   ```

## Follow-ups

- **Vault auto-unseal** is now clearly needed — every power event requires manual unseal. Implement transit/KMS auto-unseal or store unseal key in sealed-secrets with an init job.
- Consider UPS / graceful shutdown hooks for the Proxmox hosts.
- worker-01 host-port (9100/10250) still blocked after cold boot — confirms it is the systemd k3s/k3s-agent unit conflict, not transient state. Still pending clean agent reinstall.

## Note on alert quality (per user feedback)

The alert stream was noisy/ineffective:
- Real outage (whole cluster down) was buried under repeated identical TargetDown messages with no "cluster down" summary.
- GoogleUpdater flapping (now suppressed) and Windows agent alerts (APP-SERVER-03, HRMI, APP-SERVER-01) mixed in.
- Recommend: add a high-level "cluster/control-plane down" alert, group/throttle repeats, and route Windows-host alerts separately from k8s alerts.
