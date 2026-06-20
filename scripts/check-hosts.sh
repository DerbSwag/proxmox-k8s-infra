#!/bin/bash
echo "--- SRV-APP01 (10.0.3.23) ---"
ping -c 2 -W 2 10.0.3.23 2>&1 | tail -3

echo "--- SRV-ERP (10.0.2.9) ---"
ping -c 2 -W 2 10.0.2.9 2>&1 | tail -3

echo "--- k8s-worker-01 disk ---"
kubectl get --raw '/api/v1/nodes/k8s-worker-01/proxy/stats/summary' | \
  python3 -c "
import sys,json
d=json.load(sys.stdin)
fs=d['node']['fs']
cap=fs['capacityBytes']
avail=fs['availableBytes']
used=(cap-avail)*100//cap
print(f'  Used: {used}% ({(cap-avail)//1024//1024//1024}G / {cap//1024//1024//1024}G)')
"
