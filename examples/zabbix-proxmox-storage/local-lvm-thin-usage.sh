#!/usr/bin/env bash
# Usage: local-lvm-thin-usage.sh <volume-group> <thin-pool>
set -euo pipefail

vg="${1:?volume group is required}"
pool="${2:?thin pool is required}"
value="$(LC_ALL=C /sbin/lvs --noheadings --nosuffix -o data_percent "$vg/$pool" | tr -d '[:space:]')"

[[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 1
printf '%s\n' "$value"
