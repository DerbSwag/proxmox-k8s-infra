#!/bin/bash
# Setup monthly backup verification cron on Proxmox host
# Usage: ssh root@10.0.1.1 'bash -s' < scripts/setup-backup-verify-cron.sh

SCRIPT_PATH="/usr/local/bin/verify-backups.sh"
CRON_ENTRY="0 4 1 * * /usr/local/bin/verify-backups.sh >> /var/log/backup-verify.log 2>&1"

# Install verify-backups.sh
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/lib/vz/dump"
MAX_AGE_DAYS=8
FAIL=0
VMS="100 101 102"

echo "=== Backup Verification $(date '+%Y-%m-%d %H:%M') ==="
for vmid in $VMS; do
  LATEST=$(ls -t ${BACKUP_DIR}/vzdump-qemu-${vmid}-*.vma.zst 2>/dev/null | head -1)
  if [ -z "$LATEST" ]; then
    echo "  FAIL VM $vmid: NO BACKUP"; FAIL=$((FAIL+1)); continue
  fi
  FILE_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 86400 ))
  FILE_SIZE=$(du -h "$LATEST" | cut -f1)
  if [ "$FILE_AGE" -gt "$MAX_AGE_DAYS" ]; then
    echo "  FAIL VM $vmid: ${FILE_AGE} days old"; FAIL=$((FAIL+1))
  else
    echo "  OK VM $vmid: ${FILE_SIZE}, ${FILE_AGE}d old"
  fi
done
echo "=== Done: $FAIL failures ==="
[ "$FAIL" -eq 0 ] || exit 1
EOF

chmod +x "$SCRIPT_PATH"

# Add cron if not exists
(crontab -l 2>/dev/null | grep -v verify-backups; echo "$CRON_ENTRY") | crontab -

echo "✅ Backup verification cron installed (1st of month, 04:00)"
echo "   Script: $SCRIPT_PATH"
echo "   Log: /var/log/backup-verify.log"
