# Secret Rotation Plan

## Overview

| Secret | Location | Rotation Period | Method |
|--------|----------|-----------------|--------|
| Grafana admin password | Helm values | 90 days | Helm upgrade |
| ArgoCD admin password | argocd-initial-admin-secret | 90 days | argocd account update-password |
| Zabbix DB password | SealedSecret | 180 days | kubeseal re-encrypt |
| Lark webhook URL | ConfigMap | On compromise | Update adapter deployment |
| Sealed Secrets key | kube-system | 365 days | Auto-rotated by controller |
| k3s token | /var/lib/rancher/k3s/server/token | Never (cluster lifetime) | Cluster rebuild |
| SSH keys (devops user) | ~/.ssh/authorized_keys | 365 days | Ansible playbook |

---

## Rotation Procedures

### Grafana Admin Password
```bash
# Update values.yaml
sed -i 's/adminPassword: .*/adminPassword: NEW_PASSWORD/' helm/kube-prometheus-stack/values.yaml

# Apply
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -f helm/kube-prometheus-stack/values.yaml -n monitoring
```

### ArgoCD Admin Password
```bash
# On k8s-master
argocd login localhost:8888 --insecure
argocd account update-password
# Delete initial secret after first change
kubectl delete secret argocd-initial-admin-secret -n argocd
```

### Zabbix DB Password
```bash
# 1. Generate new sealed secret
echo -n 'NEW_PASSWORD' | kubectl create secret generic zabbix-db-creds \
  --from-file=password=/dev/stdin --dry-run=client -o yaml -n zabbix | \
  kubeseal --format yaml > k8s/sealed-secrets/zabbix-db-creds.yaml

# 2. Apply sealed secret
kubectl apply -f k8s/sealed-secrets/zabbix-db-creds.yaml

# 3. Update PostgreSQL password
kubectl exec -n zabbix zabbix-postgresql-0 -- \
  psql -U zabbix -c "ALTER USER zabbix PASSWORD 'NEW_PASSWORD';"

# 4. Restart zabbix pods
kubectl rollout restart deployment -n zabbix
```

### Sealed Secrets Controller Key
```bash
# Check current key age
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o jsonpath='{.items[0].metadata.creationTimestamp}'

# Controller auto-rotates keys every 30 days by default
# Old keys are kept for decryption, new secrets use new key
# Manual rotation: restart controller
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

---

## Schedule

| Month | Action |
|-------|--------|
| Every 1st | Kubescape scan (automated CronJob) |
| Every 3 months (Jan/Apr/Jul/Oct) | Rotate Grafana + ArgoCD passwords |
| Every 6 months (Jan/Jul) | Rotate Zabbix DB password |
| Every 12 months (Jan) | Rotate SSH keys via Ansible |

---

## Monitoring

- Alert `KubernetesSecretExpiry` — TODO: implement cert-manager or custom check
- Sealed Secrets controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets`
- Check for secrets older than 180 days:
  ```bash
  kubectl get secrets -A -o json | jq -r '.items[] | select(.metadata.creationTimestamp < (now - 15552000 | todate)) | "\(.metadata.namespace)/\(.metadata.name) created \(.metadata.creationTimestamp)"'
  ```
