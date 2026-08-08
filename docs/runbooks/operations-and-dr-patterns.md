# Operations and DR Patterns

## Daily health check

Review cluster readiness, backup age, backup destination capacity, active storage alerts, and the newest restore evidence. Treat a successful copy as incomplete until archive integrity or a restore test is recorded.

## Off-host Proxmox backup copy

For local directory storage, back up VMs on each node to local storage first, then copy the latest archive to a second failure domain. Verify SHA-256 checksums at both ends and retain the source until the destination is readable and a normal scheduled cycle has completed.

```bash
rsync -avh /var/lib/vz/dump/<backup-files> root@<destination-host>:/mnt/pve/<backup-storage>/dump/<offhost-folder>/
sha256sum /var/lib/vz/dump/<backup-files>
ssh root@<destination-host> 'sha256sum /mnt/pve/<backup-storage>/dump/<offhost-folder>/<backup-files>'
```

## Power recovery order

1. Confirm hypervisor storage and cluster/quorum state.
2. Start the control-plane VM before dependent workers.
3. Verify API, DNS, and node readiness before application recovery.
4. Check monitoring, backup jobs, and alert delivery after the platform stabilizes.

Use an explicit expected-vote procedure only with an approved quorum-loss runbook; revert it when the cluster is healthy.

## Backup retention

Keep local staging retention explicit and shorter than or equal to capacity allows. Before manual cleanup, validate the latest datastore/PV archives and their off-node copy. Never clean runtime directories as a substitute for managing backup staging.
