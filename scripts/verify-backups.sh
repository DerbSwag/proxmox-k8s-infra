#!/bin/bash
# Backup Verification Script
# Verifies Proxmox VM backups exist and are recent
# Run monthly: ssh root@10.0.1.1 'bash -s' < scripts/verify-backups.sh

BACKUP_DIR="/var/lib/vz/dump"
MAX_AGE_DAYS=8  # Backups run weekly (Sunday), allow 8 days
FAIL=0

echo "=========================================="
echo "  💾 Backup Verification - $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="

# Expected VMs to have backups
VMS="100 101 102"

for vmid in $VMS; do
  LATEST=$(ls -t ${BACKUP_DIR}/vzdump-qemu-${vmid}-*.vma.zst 2>/dev/null | head -1)

  if [ -z "$LATEST" ]; then
    echo "  🔴 VM $vmid: NO BACKUP FOUND"
    FAIL=$((FAIL + 1))
    continue
  fi

  # Check age
  FILE_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 86400 ))
  FILE_SIZE=$(du -h "$LATEST" | cut -f1)

  if [ "$FILE_AGE" -gt "$MAX_AGE_DAYS" ]; then
    echo "  🔴 VM $vmid: backup too old (${FILE_AGE} days) — $LATEST"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ VM $vmid: ${FILE_SIZE}, ${FILE_AGE} days old — $(basename $LATEST)"
  fi
done

echo ""

# Check backup job schedule exists
if vzdump --help >/dev/null 2>&1; then
  JOBS=$(cat /etc/pve/jobs.cfg 2>/dev/null | grep -c "vzdump" || echo "0")
  if [ "$JOBS" -gt 0 ]; then
    echo "  ✅ Backup job configured ($JOBS job(s))"
  else
    echo "  ⚠️  No backup jobs in /etc/pve/jobs.cfg"
  fi
fi

echo ""
echo "=========================================="
if [ "$FAIL" -gt 0 ]; then
  echo "  ⚠️  $FAIL backup(s) missing or outdated"
  exit 1
else
  echo "  ✅ All backups verified"
fi
echo "=========================================="
