# Incident Log: Cluster-wide Service Disruption

## Incident ID: INC-2026-0515
## Date: 2026-05-15
## Severity: High
## Duration: ~6 hours (approx 08:45 - 14:35 UTC+7)
## Status: Resolved

---

## Summary

Multiple monitoring and cluster services experienced CrashLoopBackOff and target-down alerts due to a combination of a failed VM reboot and a misconfigured NetworkPolicy blocking egress traffic to the Kubernetes API server.

---

## Timeline (UTC+7)

| Time | Event |
|------|-------|
| 08:45 | VM 200 (k8s-master) reboot failed with "VM quit/powerdown failed" error in Proxmox |
| 08:47 | VM 200 hard-reset performed, master came back online |
| ~09:00 | Alerts begin firing: TargetDown (apiserver), CoreDNSNoHealthyPods, LarkAlertAdapterDown, KubePodCrashLooping |
| 11:25 | Investigation started — identified kube-state-metrics and Grafana sidecars in CrashLoopBackOff |
| 11:28 | Root cause identified: pods cannot reach ClusterIP 10.43.0.1:443 (API server) |
| 14:08 | Deeper investigation: Prometheus targets all down, PrometheusOperatorWatchErrors firing |
| 14:20 | Identified true root cause: NetworkPolicy `allow-egress-monitoring` blocks egress to 10.0.1.10:6443 |
| 14:32 | Restarted k3s/k3s-agent on all 3 nodes to refresh networking |
| 14:33 | Patched NetworkPolicy to allow port 6443 egress to API server |
| 14:35 | All targets up, all pods Running, only Watchdog alert remaining (expected) |
| 14:38 | Permanent fix pushed to Git repo (ArgoCD source of truth) |

---

## Root Cause

**Two contributing factors:**

### 1. VM Reboot Failure (Trigger)
The k8s-master VM (Proxmox VM 200) failed to gracefully reboot at 08:45. The QEMU guest agent/ACPI shutdown timed out, requiring a hard reset. This temporarily disrupted API server availability.

### 2. NetworkPolicy Misconfiguration (Root Cause)
The `allow-egress-monitoring` NetworkPolicy (deployed 2 days prior via ArgoCD) had a flaw:

- It allowed egress to `10.43.0.0/16` (ClusterIP range) — which should cover the `kubernetes` service at `10.43.0.1`
- However, **kube-router** (the network policy controller) evaluates policies **after DNAT** — meaning traffic to `10.43.0.1:443` is seen as traffic to `10.0.1.10:6443` (the actual API server endpoint)
- The policy only allowed ports 9100, 10250, 10255 to `10.0.1.x/24`
- Port 6443 was not included, so API server traffic was **REJECTED**

This meant that after the master rebooted and pods restarted, they could never re-establish connections to the API server from the monitoring namespace.

---

## Impact

| Service | Impact |
|---------|--------|
| kube-state-metrics | CrashLoopBackOff — no cluster metrics |
| Grafana sidecars | CrashLoopBackOff — dashboards not loading |
| Prometheus | All scrape targets down — no metrics collection |
| Prometheus Operator | Cannot list nodes — no target discovery |
| Lark Alert Adapter | Intermittent — alerts delayed |
| ArgoCD repo-server | Exited (Completed state) |
| CoreDNS monitoring | Target unreachable from Prometheus |

**User-facing impact:** No monitoring data collected for ~6 hours. Alert notifications were delayed/missing during the outage.

---

## Resolution

1. Restarted k3s-agent on worker-01 and worker-02, k3s on master
2. Deleted stuck pods (kube-state-metrics, Grafana, Prometheus, Prometheus Operator, ArgoCD repo-server)
3. Patched NetworkPolicy `allow-egress-monitoring` to add port 6443 to the `10.0.1.x/24` egress rule
4. Pushed permanent fix to Git repo: `https://github.com/DerbSwag/company-lab-infra` (commit `35e0bba`)

---

## Lessons Learned

1. **kube-router evaluates NetworkPolicy after DNAT** — ClusterIP-based allow rules are insufficient when the policy controller sees post-DNAT addresses. Always include the actual node IP + port in egress rules.
2. **NetworkPolicy changes need connectivity testing** — Before deploying deny-all + allow-list policies, verify that critical paths (API server, DNS) remain functional from all namespaces.
3. **VM graceful shutdown** — Install/verify qemu-guest-agent on all VMs and increase shutdown timeout to prevent hard-reset scenarios.

---

## Action Items

- [x] Add port 6443 egress rule to other namespaces with deny-egress policies (default, zabbix, infra) if pods there need API access
- [x] Add pre-deploy validation (e.g., CI test) for NetworkPolicy changes to catch API server connectivity issues
- [x] Configure Proxmox VM shutdown timeout to 120s for k8s-master
- [x] Ensure qemu-guest-agent is installed on all K8s VMs (pending reboot to activate)
- [x] Added PrometheusRule alert for "Prometheus has 0 active targets" as an early warning
