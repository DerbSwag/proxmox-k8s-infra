# Proxmox SATA Link Instability Runbook

## Trigger

Use this runbook for repeated kernel messages such as `ATA bus error`, `READ/WRITE FPDMA QUEUED`, `hard resetting link`, or negotiated SATA speed downgrade.

## Diagnose Before Changing Hardware

```bash
journalctl -k -b -1 --no-pager | grep -Ei 'ATA|FPDMA|resetting link|limiting.*speed'
lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN
readlink -f /sys/class/block/<system-disk>/device
smartctl -x /dev/<system-disk>
```

Separate media-health indicators from link-path indicators. A disk can report healthy sectors while its cable, connector, port, or interface loses link under I/O.

## Safe Maintenance Sequence

1. Confirm an off-host archive exists, is readable, and document its age.
2. Confirm the remaining Proxmox cluster members still have quorum.
3. Shut down the affected node cleanly in a maintenance window.
4. Reseat the SSD, data cable, and power connector.
5. Replace the SATA data cable and use another motherboard port if available.
6. Boot the host and confirm stable storage/network/cluster membership.

## Validation

```bash
smartctl -H /dev/<system-disk>
smartctl -t short /dev/<system-disk>
# wait for the device-specific short-test time
smartctl -l selftest /dev/<system-disk>

smartctl -t long /dev/<system-disk>
# wait for the device-specific extended-test time
smartctl -l selftest /dev/<system-disk>

journalctl -k -b --no-pager | grep -Ei 'ATA|FPDMA|resetting link|limiting.*speed'
```

Then create a new backup, copy it outside the host, compare checksums, and test archive readability. Continue kernel-log observation for at least seven days.

## Do Not Do

- Do not wipe, reformat, or run filesystem repair just because SMART says `PASSED`.
- Do not put new critical workloads on the node until validation completes.
- Do not claim HA protection for local storage merely because cluster quorum is healthy.
