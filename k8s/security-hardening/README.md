# Security Hardening

Based on Kubescape scan (May 8, 2026):
- MITRE: 66.29% → target 80%+
- NSA: 64.83% → target 80%+

## Apply Steps

### 1. Network Policies
```bash
kubectl apply -f k8s/security-hardening/network-policies.yaml
```

### 2. Audit Logging
```bash
sudo cp k8s/security-hardening/audit-policy.yaml /etc/rancher/k3s/audit-policy.yaml

# Add to /etc/rancher/k3s/config.yaml:
# kube-apiserver-arg:
#   - "audit-policy-file=/etc/rancher/k3s/audit-policy.yaml"
#   - "audit-log-path=/var/log/k3s-audit.log"
#   - "audit-log-maxage=30"
#   - "audit-log-maxsize=100"

sudo systemctl restart k3s
```

### 3. Non-root containers
```bash
bash k8s/security-hardening/apply-security-context.sh
```
⚠️ Some pods may fail if they require root. Check with `kubectl get pods -A`

### 4. Re-scan
```bash
~/.kubescape/bin/kubescape scan
```
