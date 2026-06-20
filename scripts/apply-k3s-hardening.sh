#!/bin/bash
# Apply K3s security hardening (audit logging + secrets encryption at rest)
# Usage: bash apply-hardening.sh
#
# Prerequisites:
# - Run ON k8s-master
# - audit-policy.yaml in ../k8s/security-hardening/
# - Config file ../k8s/k3s-config.yaml

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AUDIT_POLICY="$REPO_ROOT/k8s/security-hardening/audit-policy.yaml"
K3S_CONFIG="$REPO_ROOT/k8s/k3s-config.yaml"

if [ ! -f "$AUDIT_POLICY" ] || [ ! -f "$K3S_CONFIG" ]; then
  echo "Missing required files. Check paths."
  exit 1
fi

echo "=== [1/5] BACKUP ==="
BACKUP=/root/k3s-backup-$(date +%Y%m%d-%H%M%S)
sudo mkdir -p "$BACKUP"
sudo cp -a /etc/rancher/k3s/ "$BACKUP/rancher-config"
sudo cp -a /var/lib/rancher/k3s/server/db "$BACKUP/db"
sudo cp /var/lib/rancher/k3s/server/token "$BACKUP/token"
echo "Backup at $BACKUP"
sudo du -sh "$BACKUP"

echo ""
echo "=== [2/5] COPY AUDIT POLICY ==="
sudo cp "$AUDIT_POLICY" /var/lib/rancher/k3s/server/audit-policy.yaml
sudo chmod 644 /var/lib/rancher/k3s/server/audit-policy.yaml

echo ""
echo "=== [3/5] APPLY K3S CONFIG ==="
sudo cp "$K3S_CONFIG" /etc/rancher/k3s/config.yaml
sudo mkdir -p /var/lib/rancher/k3s/server/logs

echo ""
echo "=== [4/5] RESTART K3S ==="
sudo systemctl restart k3s
for i in $(seq 1 60); do
  if kubectl get --raw /readyz 2>/dev/null | grep -q ok; then
    echo "K3s ready after ${i}s"
    break
  fi
  sleep 1
done

echo ""
echo "=== [5/5] RE-ENCRYPT EXISTING SECRETS ==="
kubectl get secrets -A -o json | kubectl replace -f - > /dev/null
echo "All existing secrets re-encrypted"

echo ""
echo "=== DONE ==="
echo "Audit log: /var/lib/rancher/k3s/server/logs/audit.log"
echo "Encryption config: /var/lib/rancher/k3s/server/cred/encryption-config.json"
echo "Backup: $BACKUP"
