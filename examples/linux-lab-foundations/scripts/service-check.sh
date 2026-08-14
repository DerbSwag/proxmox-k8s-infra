#!/usr/bin/env bash
set -euo pipefail

services=("$@")
if (( ${#services[@]} == 0 )); then
  services=(ssh docker)
fi

failed=0
for service in "${services[@]}"; do
  if systemctl is-active --quiet "$service"; then
    printf '[OK] %s is running\n' "$service"
  else
    printf '[FAIL] %s is not running\n' "$service" >&2
    failed=1
  fi
done

exit "$failed"
