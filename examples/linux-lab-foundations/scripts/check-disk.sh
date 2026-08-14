#!/usr/bin/env bash
set -euo pipefail

threshold="${1:-80}"
usage="$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')"

printf 'Root filesystem usage: %s%%\n' "$usage"
if (( usage >= threshold )); then
  printf 'WARNING: usage is at or above %s%%\n' "$threshold" >&2
  exit 1
fi

printf 'OK: usage is below %s%%\n' "$threshold"
