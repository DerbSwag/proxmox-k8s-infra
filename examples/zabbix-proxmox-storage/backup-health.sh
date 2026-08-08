#!/usr/bin/env bash
# Usage: backup-health.sh <backup-dir> <vmid> <status|success_age>
set -euo pipefail

backup_dir="${1:?backup directory is required}"
vmid="${2:?VMID is required}"
metric="${3:?metric is required}"
latest_log="$(find "$backup_dir" -maxdepth 1 -type f -name "vzdump-qemu-${vmid}-*.log" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR == 1 { print $2 }')"

case "$metric" in
  status)
    [[ -n "$latest_log" ]] || { echo 2; exit; }
    grep -Fq "ERROR: Backup of VM ${vmid} failed" "$latest_log" && echo 1 || echo 0
    ;;
  success_age)
    archive_time="$(find "$backup_dir" -maxdepth 1 -type f -name "vzdump-qemu-${vmid}-*.vma.zst" -printf '%T@\n' 2>/dev/null | sort -nr | head -1)"
    [[ -n "$archive_time" ]] || { echo 2147483647; exit; }
    echo "$(( $(date +%s) - ${archive_time%.*} ))"
    ;;
  *) exit 2 ;;
esac
