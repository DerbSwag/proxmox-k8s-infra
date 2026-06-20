#!/bin/bash
# Apply security context to workloads missing runAsNonRoot
echo "=== Patching deployments to run as non-root ==="

NAMESPACES="default monitoring zabbix infra"

for NS in $NAMESPACES; do
  echo "--- Namespace: $NS ---"
  DEPLOYMENTS=$(kubectl get deploy -n $NS --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)
  for DEP in $DEPLOYMENTS; do
    echo "  Patching: $DEP"
    kubectl patch deployment $DEP -n $NS --type=merge -p '{
      "spec": {
        "template": {
          "spec": {
            "securityContext": {
              "runAsNonRoot": true,
              "runAsUser": 1000,
              "fsGroup": 1000
            }
          }
        }
      }
    }' 2>/dev/null || echo "  SKIP (may need root)"
  done
done

echo ""
echo "=== Done. Check pod status: kubectl get pods -A ==="
