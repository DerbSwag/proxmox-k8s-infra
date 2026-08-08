# Incident Report - Proxmox HDD Storage I/O Error

- **Date detected:** 2026-08-03
- **Severity:** Medium
- **Status:** Resolved after disk replacement and storage validation
- **Area:** Proxmox storage, backup migration, physical disk reliability

---

## Summary

A new HDD was added to a Proxmox host as a directory-backed storage target for VM disks, ISO files, and backup dumps. During backup migration from the default Proxmox dump directory to the new storage, the disk began returning repeated read errors.

The kernel reported hardware-level I/O errors for the first replacement disk. The ext4 filesystem entered emergency read-only behavior, and the Proxmox storage was disabled to prevent further writes.

The failed disk was later replaced with another HDD. The new disk passed read-only screening, was formatted as ext4, mounted as the same Proxmox directory storage, and validated with backup copy verification.

This document is public-safe and intentionally excludes real hostnames, IP addresses, disk serials, and full terminal logs.

---

## Impact

- Backup migration to the first HDD could not be completed or trusted.
- The original backup source directory was preserved and not deleted.
- The unsafe Proxmox storage target was disabled until replacement.
- The host remained reachable by ping, SSH, and Proxmox web UI.
- Existing VMs on the original storage were not intentionally modified.
- After disk replacement, backup dumps were copied and verified on the new storage target.

---

## Symptoms

Observed patterns:

```text
rsync failed while copying backup archives
target filesystem entered emergency read-only mode
Proxmox storage showed as manually disabled after mitigation
kernel log showed repeated disk read errors
```

Representative kernel messages:

```text
Sense Key : Hardware Error
Add. Sense: Internal target failure
I/O error, dev <disk>, sector <sector>
failed command: READ DMA
```

The filesystem mount options included:

```text
emergency_ro
```

---

## Root Cause

The new HDD or its connection path was not reliable under sustained read/write activity.

Most likely causes:

- failing HDD media,
- unstable SATA data cable,
- unstable SATA power connection,
- bad SATA port,
- controller/device communication issue.

SMART overall health may still report `PASSED`, but that does not override repeated kernel-level I/O errors during real workload.

---

## Mitigation Applied

Stopped the migration workflow and avoided deleting the original backup source.

Disabled the new Proxmox storage:

```bash
pvesm set <storage-name> --disable 1
```

Disabled automatic mount for the problematic disk by commenting the related `/etc/fstab` entry:

```text
# disabled due to disk hardware IO error: UUID=<UUID> /mnt/pve/<storage-name> ext4 defaults,nofail 0 2
```

Created a backup copy of `/etc/fstab` before/after the storage disable change.

---

## Validation

Validated the host stayed reachable:

```text
ping OK
SSH port open
Proxmox web port open
simple SSH command OK
```

Validated storage protection:

```text
Proxmox storage: disabled
auto-mount entry: disabled/commented
original backup source: preserved
```

Validated disk issue:

```text
kernel logs still showed repeated read errors for the disk
filesystem mount showed emergency read-only behavior
SMART health check did not provide enough confidence to use the disk
```

Post-reboot read-only validation was also performed without mounting or re-enabling the storage. The disk failed during a controlled read-only scan:

```text
read-only dd test failed after 128 MiB
error reading /dev/<disk>: Input/output error
Sense Key : Medium Error
Add. Sense: Unrecovered read error - auto reallocate failed
I/O error, dev <disk>
```

This confirmed the issue was not only a filesystem state problem. The disk media or disk path was unable to complete basic reads after reboot.

---

## Replacement Validation

The failed HDD was replaced. The new disk was validated before being trusted for backup storage:

```text
SMART summary: passed with no reallocated, pending, or uncorrectable sectors
read-only scan: 10 GiB completed without disk I/O errors
filesystem: recreated as ext4
storage status: active
mountpoint: active and writable
write/read smoke test: 1 GiB completed successfully
backup copy: source and target file counts matched
checksum dry-run: no differences reported
kernel log after validation: no new disk I/O errors
```

The Proxmox backup schedule was updated to target the replacement storage. A manual backup test of a small VM completed successfully on the replacement storage:

```text
backup job target: replacement storage
test backup: completed successfully
test backup output: archive, log, and notes files present
replacement storage usage after test: approximately 11%
kernel log after test: no new disk I/O errors
```

An off-host backup copy was also created for a VM hosted on another Proxmox node. The source and destination checksums matched, and kernel logs on the replacement storage host remained clean after the copy.

Follow-up review identified that a cluster-wide backup job should not use `all` when the selected target is a local disk mounted on only one Proxmox node. The backup jobs were split so VMs on the storage-owning node use the replacement storage, while VMs on the other node use local backup first and then an off-host sync workflow.

The original backup source directory was intentionally kept after migration as a rollback copy until the new storage completes at least one normal backup/reboot cycle.

---

## Follow-Up Actions

Completed actions:

1. Disabled the unsafe storage target.
2. Disabled auto-mount for the unsafe disk.
3. Rebooted the host and confirmed the failed disk still produced read errors.
4. Replaced the disk.
5. Validated the replacement disk with read-only and write/read checks.
6. Recreated the directory-backed Proxmox storage.
7. Copied and verified backup dumps without deleting the original source.
8. Updated the Proxmox backup job target to the replacement storage.
9. Ran a manual VM backup test to the replacement storage.
10. Copied a backup from another Proxmox node to the replacement storage as an off-host backup and verified checksums.
11. Split backup schedules by node to avoid sending backups to inactive local storage mounts.
12. Added off-host backup sync automation after the weekly backup window.

Future preventive actions:

1. Keep source backups until the replacement storage passes at least one normal backup/reboot cycle.
2. Use SMART health and extended diagnostics for any reused disk:

```bash
smartctl -a /dev/<disk>
smartctl -t long /dev/<disk>
smartctl -l selftest /dev/<disk>
```

3. Only re-enable Proxmox storage after clean read-only testing, write/read testing, and backup copy verification.

---

## Lessons Learned

- Do not delete source backups until target storage is fully copied and verified.
- New or repurposed disks must be burn-tested before being trusted for VM disks or backup retention.
- `SMART PASSED` is not sufficient if kernel logs show `Hardware Error` or `I/O error`.
- A read-only scan can confirm whether a disk is unsafe without writing new data to it.
- Proxmox storage can be disabled quickly with `pvesm set <storage> --disable 1` to avoid accidental use.
- `/etc/fstab` auto-mount entries should be disabled when a disk is known unstable, even if `nofail` is present.
- Large backup migrations should be done with a verification plan and a rollback path.
- Replacement is not complete until storage is mounted, active in Proxmox, writable, backup copies match, checksum verification is clean, and kernel logs remain clean.
- Cluster-visible directory storage backed by a local disk is not shared storage. Backups for VMs on other nodes need shared storage or an explicit off-host copy.
- Avoid `all` backup jobs when the selected storage is only available on one Proxmox node.

---

## Safe Status At End

```text
Original backup source: kept
Failed HDD storage: disabled and replaced
Replacement HDD storage: active
Backup dump copy: verified
Backup schedule target: replacement storage
Manual VM backup test: passed
Off-host backup copy: verified
Backup schedules: split by node
Off-host sync automation: added
Original backup source: kept as rollback copy
VM creation on replacement HDD: allowed for lab use after validation
```

---

## Monitoring Follow-Up

A review of the earlier failed weekly backup confirmed that the failure occurred before the replacement-storage migration. The legacy job wrote to the host-local backup target while that host experienced both disk I/O errors and root-filesystem exhaustion. The resulting backup-process `Broken pipe` error was therefore a downstream symptom, not evidence against the replacement disk.

This distinction matters operationally: a successful small manual backup and restore test validates the replacement path, but the next scheduled backup remains the final proof for every protected VM.

The following public-safe monitoring controls were added:

| Risk | Monitoring control |
| --- | --- |
| Thin-pool exhaustion | Export the LVM thin-pool data percentage to monitoring; warn above 85% and treat 90% as critical. |
| Backup job failure | Track the result of the latest backup job for critical VMs. |
| Stale recovery point | Track the age of the newest successful backup archive; alert when it exceeds the backup SLA. |
| Missing notification route | Ensure hypervisor events are routed to an on-call destination, rather than relying only on a generic Linux-host rule. |

These alerts must remain actionable: do not suppress a backup-failure or stale-backup alert merely because its root cause is known. Resolve it only after a new scheduled backup produces a successful archive and the monitoring value recovers.
