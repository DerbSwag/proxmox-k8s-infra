# Proxmox HDD Storage Runbook

Public-safe runbook for adding, validating, disabling, and recovering a Proxmox directory-backed HDD storage target.

This runbook intentionally uses placeholders. Keep real disk serials, hostnames, IP addresses, and raw terminal logs in private evidence only.

---

## Goal

Use an additional HDD as Proxmox storage for:

- VM disks,
- ISO files,
- backup dumps,
- snippets or lab artifacts.

Recommended storage type for simple lab use:

```text
Directory storage on ext4
```

---

## Pre-Flight Checks

Before wiping or formatting any disk:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
pvesm status
df -h
```

Confirm:

- the target disk is the expected disk,
- the disk is not mounted,
- the disk does not contain data that must be preserved,
- the disk is not the Proxmox boot disk,
- the target storage name does not already exist.

Do not proceed unless the disk can be safely wiped.

---

## Create Directory Storage

Example placeholders:

```bash
DISK=/dev/<disk>
PART=/dev/<disk-partition>
STORAGE=<storage-name>
MOUNT=/mnt/pve/<storage-name>
```

Create filesystem and mount:

```bash
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:0 -t 1:8300 -c 1:"$STORAGE" "$DISK"
partprobe "$DISK" || blockdev --rereadpt "$DISK"
mkfs.ext4 -F -L "$STORAGE" "$PART"
mkdir -p "$MOUNT"
UUID=$(blkid -s UUID -o value "$PART")
echo "UUID=$UUID $MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
mount "$MOUNT"
```

Add Proxmox storage:

```bash
pvesm add dir "$STORAGE" \
  --path "$MOUNT" \
  --content images,iso,backup,snippets \
  --is_mountpoint 1
```

Validate:

```bash
pvesm status
df -h "$MOUNT"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$DISK"
```

---

## Backup Migration Pattern

Use copy-then-verify-delete. Do not move or delete source backups first.

```bash
rsync -a /var/lib/vz/dump/ /mnt/pve/<storage-name>/dump/
```

Validate at minimum:

```bash
du -sh /var/lib/vz/dump /mnt/pve/<storage-name>/dump
find /var/lib/vz/dump -type f | wc -l
find /mnt/pve/<storage-name>/dump -type f | wc -l
```

For stronger validation:

```bash
rsync -a --checksum --dry-run --itemize-changes \
  /var/lib/vz/dump/ \
  /mnt/pve/<storage-name>/dump/
```

Only delete source files after:

- copy completed,
- source and target counts match,
- checksum dry-run shows no differences,
- no new backup job is actively writing to the source directory,
- target disk has no kernel I/O errors.

---

## Warning Signs

Stop using the disk if any of these appear:

```text
emergency_ro
I/O error, dev <disk>
Sense Key : Hardware Error
Sense Key : Medium Error
Add. Sense: Internal target failure
Add. Sense: Unrecovered read error - auto reallocate failed
failed command: READ DMA
failed command: READ FPDMA QUEUED
Buffer I/O error
EXT4-fs error
```

Check:

```bash
grep <storage-name> /proc/mounts
journalctl -k -n 200 --no-pager
smartctl -a /dev/<disk>
```

Important: `SMART PASSED` does not mean the disk is safe if the kernel reports hardware I/O errors.

---

## Emergency Disable

If the disk becomes unstable, prevent Proxmox from using it:

```bash
pvesm set <storage-name> --disable 1
```

Disable auto-mount:

```bash
cp /etc/fstab /etc/fstab.bak-<date>
sed -i '/<storage-name>/s/^/# disabled due to disk hardware IO error: /' /etc/fstab
```

Do not delete the original backup source until the target storage is proven reliable.

---

## Hardware Recovery Checklist

1. Schedule downtime if the disk or cable must be touched.
2. Reseat SATA data and power cables.
3. Try a different SATA port.
4. Reboot the host to clear stale I/O state.
5. Run SMART:

```bash
smartctl -a /dev/<disk>
smartctl -t long /dev/<disk>
smartctl -l selftest /dev/<disk>
```

6. Run a controlled write/read test before re-enabling storage.
7. Replace the disk if kernel I/O errors return.

If the disk already has I/O errors, start with a read-only scan instead of a write test:

```bash
dd if=/dev/<disk> of=/dev/null bs=64M iflag=direct status=progress
journalctl -k -b --no-pager | grep -Ei '<disk>|I/O error|Medium Error|Hardware Error|READ DMA|READ FPDMA'
```

If the read-only scan fails with `Input/output error`, do not reformat, remount, or re-enable the disk for Proxmox storage. Treat the disk as failed or unsafe.

---

## Re-Enable Only After Validation

Only re-enable the storage if:

- no kernel I/O errors appear after reboot,
- SMART does not show concerning reallocated or pending sectors,
- a read-only scan and write/read test complete cleanly,
- backup copy verification completes cleanly.

Re-enable:

```bash
pvesm set <storage-name> --disable 0
```

---

## Replacement Completion Checklist

After replacing a failed disk, record completion only when all checks pass:

```text
SMART summary has no reallocated, pending, or uncorrectable sector warnings
read-only scan completes without Input/output error
filesystem is recreated cleanly
storage mount is active and writable
Proxmox storage status is active
write/read smoke test completes cleanly
backup dump copy completes
source and target file counts match
checksum dry-run reports no differences
backup schedule points to the replacement storage
manual backup test writes a new archive to the replacement storage
kernel log shows no new disk I/O errors after validation
source backups are kept temporarily as rollback copy
```

Do not delete the original backup source on the same day as replacement. Wait for at least one normal backup/reboot cycle before moving retention fully to the replacement storage.

---

## Off-Host Backup Copy Pattern

Directory storage backed by a local disk is not shared storage. Other Proxmox nodes may see the cluster-wide storage definition, but they cannot use the storage unless the same mount exists on that node.

Avoid cluster-wide `all` backup jobs when the selected storage is a local disk mounted on only one node. Split schedules by node or use true shared storage.

Example pattern:

```text
backup job A: VMs on storage-owning node -> replacement local storage
backup job B: VMs on another node -> that node's local storage
sync job C: copy latest backup from other node -> replacement local storage
```

For a VM hosted on another Proxmox node, create an explicit off-host backup copy:

```bash
rsync -avh --progress \
  /var/lib/vz/dump/<backup-files> \
  root@<storage-host>:/mnt/pve/<storage-name>/dump/<offhost-folder>/
```

Verify:

```bash
sha256sum /var/lib/vz/dump/<backup-files>
ssh root@<storage-host> 'sha256sum /mnt/pve/<storage-name>/dump/<offhost-folder>/<backup-files>'
ssh root@<storage-host> "journalctl -k -b --no-pager | grep -Ei '<disk>|I/O error|Medium Error|Hardware Error|READ DMA|READ FPDMA'"
```

Record completion only when:

```text
source and destination checksums match
destination backup files are present on the replacement storage
replacement storage has enough free space
kernel logs remain clean after the copy
```

For recurring protection, run the off-host sync after the scheduled backup window and log both checksum verification and replacement-storage disk health.
