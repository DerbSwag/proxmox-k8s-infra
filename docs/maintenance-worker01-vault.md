# Maintenance Window Runbook — worker-01 reinstall + Vault auto-unseal

> Prepared 2026-06-16. Two independent tasks. Do them in a low-traffic window.
> Master RAM is now 6GB; cluster tolerates worker-01 being out during the work.

---

## Pre-flight (both tasks)

```bash
ssh devops@10.0.1.10
export PATH=$PATH:/usr/local/bin
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes            # all Ready (worker-01 currently cordoned)
kubectl get pods -A | grep -v Running | grep -v Completed   # baseline
free -h | grep Mem           # confirm headroom before draining
```

---

## TASK 1 — worker-01 clean k3s agent reinstall

### Why
worker-01 has an orphaned `k3s.service` (active, no unit file) alongside the real
`k3s-agent.service` (enabled). This split state leaves kube-router/netfilter in a
broken state: host ports 9100 (node-exporter) and 10250 (kubelet) are dropped for
cross-node traffic. Symptoms: TargetDown for worker-01, `kubectl exec/logs` into
pods on worker-01 fail with 502, probe-driven restart loops for pods landing there.
Confirmed NOT fixed by: UFW rules, iptables flush, service restart, cold reboot.

### Facts gathered (2026-06-16)
- k3s version: `v1.34.5+k3s1`
- Uninstaller present: `/usr/local/bin/k3s-agent-uninstall.sh`
- Units: `k3s-agent.service` (enabled), stray `k3s.service` (active, no file)
- Node IP 10.0.1.11, joins master at `https://10.0.1.10:6443`

### Steps
```bash
# 1. Drain (already cordoned). Keep DaemonSets.
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data --force

# 2. On worker-01: capture join token from MASTER first
#    (run on master)
sudo cat /var/lib/rancher/k3s/server/node-token   # = $TOKEN

# 3. On worker-01: stop everything and uninstall the agent cleanly
ssh devops@10.0.1.11
sudo systemctl stop k3s k3s-agent 2>/dev/null
sudo /usr/local/bin/k3s-agent-uninstall.sh        # removes agent, CNI, iptables
#   verify nothing left:
ls /etc/systemd/system/ | grep k3s                # expect empty
ip link | grep -E 'cni0|flannel'                  # expect gone

# 4. Reinstall agent fresh, joined to master
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION=v1.34.5+k3s1 \
  K3S_URL=https://10.0.1.10:6443 \
  K3S_TOKEN=$TOKEN \
  sh -

# 5. Back on master: verify
kubectl get nodes                                  # worker-01 Ready
kubectl uncordon k8s-worker-01
# host-port check (the real test):
timeout 4 bash -c 'echo > /dev/tcp/10.0.1.11/9100'  && echo OK9100
timeout 4 bash -c 'echo > /dev/tcp/10.0.1.11/10250' && echo OK10250
kubectl exec -n kube-system <a-pod-on-worker01> -- echo ok   # should NOT 502
```

### Rollback
If reinstall fails to join: worker-01 stays drained/cordoned. Cluster keeps running
on master+worker-02 (current state). No workload impact beyond reduced capacity.

### Watch during the work
`watch -n5 'free -h | grep Mem'` on master — the 06-08 incident OOMed master when
pods piled up. With 6GB it should be fine, but abort/uncordon if free <300MB.

---

## TASK 2 — Vault auto-unseal ✅ DONE (2026-06-16)

### Why
Standalone Vault (file storage) starts **sealed** after every pod restart / power
event. Manually unsealed on 06-04, 06-08, 06-16 (x3). Auto-unseal removes this toil.

### Implemented: Option B (lab-appropriate)
A CronJob in the `vault` namespace runs every 2 minutes, reads the unseal key from a
k8s Secret, and unseals Vault if sealed (idempotent no-op when already unsealed).

- Manifest (in git): `k8s/vault/auto-unseal-cronjob.yaml` (ServiceAccount + CronJob)
- Secret `vault-unseal` is created **out-of-band, NOT in git**:
  ```bash
  UNSEAL=$(python3 -c "import json;print(json.load(open('/home/devops/vault-init-keys.json'))['unseal_keys_b64'][0])")
  kubectl create secret generic vault-unseal -n vault --from-literal=key="$UNSEAL"
  kubectl apply -f k8s/vault/auto-unseal-cronjob.yaml
  ```
- Schedule `*/2 * * * *`, `concurrencyPolicy: Forbid`, history limit 1.

### Verified
`kubectl delete pod vault-0 -n vault` → pod returned **1/1 Running** within ~2 min
(standalone Vault would otherwise stay 0/1 sealed). CronJob job completed and unsealed.

### Security note
The unseal key sits in a plain Secret in the `vault` namespace — anyone with read
access to that Secret can unseal Vault. Acceptable for this single-node LAB only.
Production must use KMS/transit auto-unseal instead. (sealed-secrets controller was
not present after the DR rebuild, so a plain Secret was used; revisit if sealed-secrets
is reinstalled.)

---

## Post-work
- `kubectl get nodes` all Ready and uncordoned
- Prometheus targets: worker-01 9100/10250 UP (TargetDown clears)
- `kubectl top nodes` shows worker-01 metrics (was `<unknown>`)
- Vault survives a pod delete without manual unseal — ✅ DONE
- Update incidents 2026-06-04 / 2026-06-08 status → RESOLVED
