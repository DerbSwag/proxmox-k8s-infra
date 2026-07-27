#!/usr/bin/env bash
export PATH=/usr/local/bin:/usr/bin:/bin
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "=== DNS working? ==="
kubectl run dnst --image=busybox:1.36 --restart=Never -n default --command -- sh -c "nslookup google.com <KUBERNETES_SERVICE_IP>0" >/dev/null 2>&1 || true
sleep 6
kubectl logs dnst -n default 2>&1 | grep -iE "Address" | tail -2
kubectl delete pod dnst -n default --force >/dev/null 2>&1 || true
echo "=== prometheus coredns targets ==="
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -c prometheus -- wget -qO- "http://localhost:9090/api/v1/targets?state=active" 2>/dev/null > /tmp/t.json
python3 - <<'PY'
import json
d=json.load(open('/tmp/t.json'))
for t in d['data']['activeTargets']:
    if 'dns' in t['labels'].get('job','').lower() or 'coredns' in str(t['labels']).lower():
        print(t['health'], t['labels'].get('job'), t['labels'].get('instance'), t.get('lastError','')[:70])
PY
rm -f /tmp/t.json
