#!/usr/bin/env bash
# k3s datastore (SQLite) + local-path PV backup to a SEPARATE host (pve01).
# Run as the 'devops' user (NOT via sudo) so SSH keys resolve correctly.
# Local root-only reads use `sudo -n` (master has NOPASSWD; workers have a scoped rule).
#
# Lesson from 2026-06-16: local-path PV + k3s db were destroyed by k3s-uninstall.sh
# with no off-node backup. This closes that gap.
#
# Install on master (as devops):
#   cp scripts/k3s-backup.sh /usr/local/bin/k3s-backup.sh && chmod +x /usr/local/bin/k3s-backup.sh
#   crontab -e   ->   0 3 * * *  /usr/local/bin/k3s-backup.sh >> /home/devops/k3s-backup.log 2>&1
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
DBSRC=/var/lib/rancher/k3s/server/db/state.db
STAGE=/home/devops/k3s-backups
DEST_HOST=root@10.0.1.1          # pve01 (separate disk from the k8s VMs)
DEST_DIR=/var/lib/vz/k3s-backups
WORKERS="10.0.1.11 10.0.1.12"
RETENTION_DAYS=7
SSHKEY=/home/devops/.ssh/id_ed25519    # devops key (has access to pve01 + workers)
SSH="ssh -i $SSHKEY -o ConnectTimeout=8 -o StrictHostKeyChecking=no"
SCP="scp -i $SSHKEY -o ConnectTimeout=8 -o StrictHostKeyChecking=no"

mkdir -p "$STAGE"

# 1. Consistent SQLite backup of the k3s datastore (safe while running)
sudo -n sqlite3 "$DBSRC" ".backup '/tmp/state-$TS.db'"
sudo -n chown devops:devops "/tmp/state-$TS.db"
gzip -f "/tmp/state-$TS.db"
mv "/tmp/state-$TS.db.gz" "$STAGE/"

# 2. TAR local-path PV data from each worker (scoped NOPASSWD sudo for tar)
# tar may exit non-zero on harmless "file changed as we read it"; don't abort.
for node in $WORKERS; do
  $SSH devops@"$node" "sudo -n tar czf - -C /var/lib/rancher/k3s/storage ." \
    > "$STAGE/pv-$node-$TS.tar.gz" 2>/dev/null || true
  # drop empty/failed archives (node with no PVCs)
  [ -s "$STAGE/pv-$node-$TS.tar.gz" ] || rm -f "$STAGE/pv-$node-$TS.tar.gz"
done

# 3. Ship to the separate host
$SSH "$DEST_HOST" "mkdir -p $DEST_DIR"
$SCP "$STAGE"/*-"$TS".* "$DEST_HOST:$DEST_DIR/" >/dev/null

# 4. Prune local + remote older than retention
find "$STAGE" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
$SSH "$DEST_HOST" "find $DEST_DIR -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true"

echo "$(date) k3s-backup OK: state-$TS.db.gz + PV tars -> $DEST_HOST:$DEST_DIR"
