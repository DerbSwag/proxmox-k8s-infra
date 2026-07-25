#!/bin/bash
# Morning Health Check - Proxmox K8s Lab
# Usage: ssh devops@10.0.1.10 'bash -s' < morning-check.sh

echo "=========================================="
echo "  🌅 Morning Health Check - $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="

echo ""
echo "📌 [1/6] NODES"
kubectl get nodes
echo ""

echo "📌 [2/6] PROBLEM PODS"
PROBLEMS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null)
if [ -z "$PROBLEMS" ]; then
  echo "✅ All pods healthy"
else
  echo "⚠️  Problem pods:"
  echo "$PROBLEMS"
fi
echo ""

echo "📌 [3/6] RESOURCE USAGE"
kubectl top nodes 2>/dev/null || echo "metrics-server not ready"
echo ""

echo "📌 [4/6] ARGOCD APPS (not Synced/Healthy only)"
kubectl get apps -n argocd 2>/dev/null | awk 'NR==1 || ($2!="Synced" || $3!="Healthy")'
echo ""

echo "📌 [5/6] DISK USAGE (master + workers, warn >75%, alert >85%)"
# local master disk
LOCAL=$(df -h / | awk 'NR==2')
LOCAL_USE=$(echo "$LOCAL" | awk '{gsub("%","",$5); print $5}')
if [ "$LOCAL_USE" -ge 85 ]; then
  echo "  master: 🔴 $LOCAL"
elif [ "$LOCAL_USE" -ge 75 ]; then
  echo "  master: ⚠️  $LOCAL"
else
  echo "  master: ✅ $LOCAL"
fi

# Workers via kubelet /stats/summary (through kubectl)
for node in k8s-worker-01 k8s-worker-02; do
  STATS=$(kubectl get --raw "/api/v1/nodes/${node}/proxy/stats/summary" 2>/dev/null)
  if [ -z "$STATS" ]; then
    echo "  $node: ❌ unreachable via kubelet"
    continue
  fi
  # Parse rootfs from fs section (bytes)
  CAPACITY=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['node']['fs']['capacityBytes'])" 2>/dev/null)
  AVAILABLE=$(echo "$STATS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['node']['fs']['availableBytes'])" 2>/dev/null)
  if [ -z "$CAPACITY" ] || [ -z "$AVAILABLE" ]; then
    echo "  $node: ⚠️  could not parse stats"
    continue
  fi
  USED=$((CAPACITY - AVAILABLE))
  USE=$((USED * 100 / CAPACITY))
  CAP_GB=$((CAPACITY / 1024 / 1024 / 1024))
  USED_GB=$((USED / 1024 / 1024 / 1024))
  AVAIL_GB=$((AVAILABLE / 1024 / 1024 / 1024))
  LINE="${CAP_GB}G ${USED_GB}G ${AVAIL_GB}G ${USE}%"
  if [ "$USE" -ge 85 ]; then
    echo "  $node: 🔴 $LINE"
  elif [ "$USE" -ge 75 ]; then
    echo "  $node: ⚠️  $LINE"
  else
    echo "  $node: ✅ $LINE"
  fi
done
echo ""

echo "📌 [6/6] DNS RESOLUTION (cross-namespace)"
# สร้าง test pod รอ completion แล้วเก็บ log
DNS_TEST_POD="dns-healthcheck-$$"
kubectl delete pod -n default "$DNS_TEST_POD" --grace-period=0 --force >/dev/null 2>&1
kubectl run "$DNS_TEST_POD" \
  --restart=Never \
  --image=busybox:1.36 \
  -n default \
  --command -- sh -c '
    for target in kubernetes.default.svc zabbix-postgresql.zabbix.svc bind9.infra.svc; do
      if nslookup "$target" 2>&1 | grep -q "Address.*10\."; then
        echo "OK $target"
      else
        echo "FAIL $target"
      fi
    done
  ' >/dev/null 2>&1

# wait for pod to complete (max 30s)
for i in $(seq 1 30); do
  STATUS=$(kubectl get pod -n default "$DNS_TEST_POD" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$STATUS" = "Succeeded" ] || [ "$STATUS" = "Failed" ]; then
    break
  fi
  sleep 1
done

LOGS=$(kubectl logs -n default "$DNS_TEST_POD" 2>/dev/null)
kubectl delete pod -n default "$DNS_TEST_POD" --grace-period=0 --force >/dev/null 2>&1

if [ -z "$LOGS" ]; then
  echo "  ⚠️  DNS test did not complete"
else
  echo "$LOGS" | while read line; do
    case "$line" in
      OK*) echo "  ✅ ${line#OK }" ;;
      FAIL*) echo "  🔴 ${line#FAIL } (FAILED)" ;;
    esac
  done
fi
echo ""

echo "=========================================="
echo "  🔗 Grafana:  http://10.0.1.10:31000/d/cluster-overview"
echo "  🔗 Zabbix:   http://10.0.1.10:30080"
echo "  🔗 Proxmox:  https://10.0.1.1:8006"
echo "=========================================="
