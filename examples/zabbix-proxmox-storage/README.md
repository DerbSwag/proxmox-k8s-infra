# Proxmox storage and backup monitoring example

This example separates three failure modes that ordinary filesystem monitoring can miss:

1. LVM thin-pool exhaustion.
2. A critical VM's latest backup job failing.
3. The newest successful backup archive exceeding its recovery-point objective.

The collector runs as root through cron and writes a numeric cache file. Zabbix Agent 2 reads only the cache file, so it does not need broad LVM privileges.

## Adapt safely

- Replace `<volume-group>`, `<thin-pool>`, `<backup-storage-path>`, and `<critical-vmid>`.
- Keep the backup path local to the Proxmox node that owns the storage.
- Start with warning at 85% and critical at 90% for a thin pool; tune to the restore capacity required by your environment.
- Create triggers for `pve.lvmthin.data_percent`, `pve.backup.critical_vm.status`, and `pve.backup.critical_vm.success_age`.
- Route the host group containing hypervisors to an on-call destination and test the complete notification path.

The backup collector returns `0` for success/running, `1` for a completed failed job, and `2` when no log exists. Alert when the result is non-zero or when archive age exceeds the chosen SLA.
