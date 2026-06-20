#!/usr/bin/env bash
export PATH=/usr/local/bin:/usr/bin:/bin
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "=== nodes ==="
kubectl get nodes 2>&1
echo "=== coredns pods ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>&1
echo "=== coredns recent logs ==="
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=8 2>&1 | tail -10
echo "=== coredns describe (events) ==="
kubectl describe pods -n kube-system -l k8s-app=kube-dns 2>&1 | grep -A6 Events: | head -12
