# Proxmox host outage: SATA link instability pattern

## Summary

A Proxmox node and its local worker VM became unreachable together. Cluster quorum survived because the remaining two nodes stayed online.

## Confirmed Root Cause

Kernel logs showed repeated SATA bus errors and link resets during reads and writes on the host's system SSD. The kernel repeatedly reduced negotiated link speed after failures. SMART media-health values remained normal, while SATA Phy counters showed extensive link-loss transitions.

This identifies a storage-path fault rather than an agent, VM firewall, cluster quorum, or application-networking failure.

## Likely Fault Domain

The exact component requires physical remediation to isolate. Candidates are:

- SATA data cable
- SATA power connector
- motherboard SATA port
- SSD interface or drive electronics

SMART `PASSED` is not enough to clear a host when kernel logs show link resets under I/O.

## Immediate Response

1. Preserve and verify an off-host VM backup before maintenance.
2. Keep the node out of critical-workload placement.
3. Confirm the remaining cluster members have quorum.
4. In a maintenance window, replace/reseat the cable and connectors and try a different SATA port.
5. Run SMART short and extended tests after repair.
6. Create a fresh backup, copy it outside the node, verify checksum and archive readability, and observe logs for a week.

## Lessons

- A failed hypervisor storage path can present first as a network or monitoring outage because its hosted VMs disappear with it.
- Cluster quorum protects configuration consistency, not the availability of a node's local VM disks.
- Backup integrity and backup freshness are distinct: an older readable archive can be useful for maintenance but does not meet a current recovery-point objective.
