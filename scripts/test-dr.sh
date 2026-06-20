#!/bin/bash
# Disaster Recovery Validation Test
# Tests that critical components can be verified after recovery
# Usage: ssh devops@10.0.1.10 'bash -s' < scripts/test-dr.sh

set -e

PASS=0
FAIL=0

check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✅ $desc"
    PASS=$((PASS + 1))
  else
    echo "  🔴 $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=========================================="
echo "  🔄 DR Validation Test - $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="

echo ""
echo "📌 [1/5] NODES"
check "k8s-master Ready" "kubectl get node k8s-master | grep -q ' Ready'"
check "k8s-worker-01 Ready" "kubectl get node k8s-worker-01 | grep -q ' Ready'"
check "k8s-worker-02 Ready" "kubectl get node k8s-worker-02 | grep -q ' Ready'"

echo ""
echo "📌 [2/5] CRITICAL SERVICES"
check "CoreDNS running" "kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers | grep -q ."
check "Prometheus running" "kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running --no-headers | grep -q ."
check "Grafana running" "kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --field-selector=status.phase=Running --no-headers | grep -q ."
check "ArgoCD server running" "kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running --no-headers | grep -q ."
check "Zabbix web running" "kubectl get pods -n zabbix -l app.kubernetes.io/component=web --field-selector=status.phase=Running --no-headers | grep -q ."
check "Lark adapter running" "kubectl get pods -n monitoring -l app=lark-alert-adapter --field-selector=status.phase=Running --no-headers | grep -q ."

echo ""
echo "📌 [3/5] DNS RESOLUTION"
DNS_RESULT=$(kubectl run dr-dns-test --rm -it --restart=Never --image=busybox:1.36 -n default -- nslookup kubernetes.default.svc.cluster.local 2>&1)
if echo "$DNS_RESULT" | grep -q "Address.*10\."; then
  echo "  ✅ DNS resolution from default ns"
  PASS=$((PASS + 1))
else
  echo "  🔴 DNS resolution from default ns"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "📌 [4/5] ARGOCD SYNC STATUS"
OUTOFSYNC=$(kubectl get apps -n argocd --no-headers 2>/dev/null | awk '$2!="Synced"' | wc -l)
if [ "$OUTOFSYNC" -eq 0 ]; then
  echo "  ✅ All ArgoCD apps synced"
  PASS=$((PASS + 1))
else
  echo "  ⚠️  $OUTOFSYNC app(s) out of sync"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "📌 [5/5] PROMETHEUS TARGETS"
TARGETS_DOWN=$(kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -- \
  wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | \
  python3 -c "import sys,json;d=json.load(sys.stdin);print(sum(1 for t in d['data']['activeTargets'] if t['health']!='up'))" 2>/dev/null || echo "unknown")
if [ "$TARGETS_DOWN" = "0" ]; then
  echo "  ✅ All Prometheus targets UP"
  PASS=$((PASS + 1))
elif [ "$TARGETS_DOWN" = "unknown" ]; then
  echo "  ⚠️  Could not check Prometheus targets"
  FAIL=$((FAIL + 1))
else
  echo "  🔴 $TARGETS_DOWN target(s) DOWN"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "  ⚠️  DR validation incomplete — review failed checks"
  exit 1
else
  echo "  ✅ All DR checks passed — cluster fully operational"
fi
echo "=========================================="
