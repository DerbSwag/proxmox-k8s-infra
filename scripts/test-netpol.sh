#!/bin/bash
# NetworkPolicy Connectivity Test
# Run BEFORE and AFTER applying NetworkPolicy changes
# Usage: ssh labuser@192.0.2.10 'bash -s' < scripts/test-netpol.sh

set -e

POD_NAME="netpol-test-$$"
PASS=0
FAIL=0

echo "=========================================="
echo "  🔒 NetworkPolicy Test - $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="

# Test namespaces to verify DNS + service connectivity
TESTS=(
  "default|kubernetes.default.svc.cluster.local|DNS"
  "default|zabbix-postgresql.zabbix.svc.cluster.local|cross-ns DNS"
  "default|bind9.infra.svc.cluster.local|cross-ns DNS"
  "default|lark-alert-adapter.monitoring.svc.cluster.local|cross-ns DNS"
)

for test in "${TESTS[@]}"; do
  IFS='|' read -r ns target desc <<< "$test"

  kubectl delete pod -n "$ns" "$POD_NAME" --grace-period=0 --force >/dev/null 2>&1 || true
  kubectl run "$POD_NAME" -n "$ns" --restart=Never --image=busybox:1.36 \
    --command -- sh -c "nslookup $target >/dev/null 2>&1 && echo OK || echo FAIL" >/dev/null 2>&1

  # Wait for completion (max 30s)
  for i in $(seq 1 30); do
    STATUS=$(kubectl get pod -n "$ns" "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null)
    [ "$STATUS" = "Succeeded" ] || [ "$STATUS" = "Failed" ] && break
    sleep 1
  done

  RESULT=$(kubectl logs -n "$ns" "$POD_NAME" 2>/dev/null)
  kubectl delete pod -n "$ns" "$POD_NAME" --grace-period=0 --force >/dev/null 2>&1 || true

  if [ "$RESULT" = "OK" ]; then
    echo "  ✅ [$ns] $desc → $target"
    PASS=$((PASS + 1))
  else
    echo "  🔴 [$ns] $desc → $target (FAILED)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "  ⚠️  DO NOT merge NetworkPolicy changes until all tests pass"
  exit 1
else
  echo "  ✅ All connectivity tests passed"
fi
echo "=========================================="
