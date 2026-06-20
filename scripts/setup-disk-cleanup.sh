#!/bin/bash
# Setup disk cleanup automation on K3s nodes
# - Image GC: starts at 70%, cleans to 50%
# - Journal: keeps only 3 days, runs weekly

set -e

echo "=== Setting up K3s image GC ==="
sudo mkdir -p /etc/rancher/k3s
sudo cp "$(dirname "$0")/../k8s/k3s-config.yaml" /etc/rancher/k3s/config.yaml

echo "=== Setting up journal cleanup cron ==="
echo "0 3 * * 0 root journalctl --vacuum-time=3d" | sudo tee /etc/cron.d/clean-journal

echo "=== Restarting K3s ==="
if systemctl is-active --quiet k3s; then
  sudo systemctl restart k3s
elif systemctl is-active --quiet k3s-agent; then
  sudo systemctl restart k3s-agent
fi

echo "Done!"
