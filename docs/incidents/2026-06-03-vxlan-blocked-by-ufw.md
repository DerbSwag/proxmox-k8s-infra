# Incident: VXLAN blocked by UFW - Zabbix Web Unreachable

**Date:** 2026-06-03
**Duration:** ~30 min (detection to resolution)
**Severity:** High
**Impact:** Zabbix web UI (`192.0.2.10:30080/zabbix.php`) completely unreachable

## Symptoms

- `http://192.0.2.10:30080/zabbix.php` returned connection refused
- TCP test to port 30080 failed from workstation
- Pods running, Service/NodePort configured correctly

## Root Cause

UFW `INPUT` policy set to `DROP` on all cluster nodes. VXLAN overlay traffic (UDP 8472) between nodes was silently blocked, breaking cross-node pod networking.

Additional finding: `cni0` bridge on worker-01 had a stale pod-network bridge address. It was fixed by restarting `k3s-agent`.

Workers also couldn't rejoin cluster because TCP 6443 (API server) was blocked by the same firewall policy.

## Timeline

1. Zabbix web reported unreachable
2. Pods/Service confirmed healthy — NetworkPolicy suspected
3. Discovered cross-node ping failure (master → worker pod IPs)
4. Identified UFW INPUT DROP policy blocking VXLAN UDP 8472
5. Added iptables rules → cross-node networking restored
6. Deleted CrashLoopBackOff web pod → new pod started successfully (HTTP 200)
7. Persisted rules via UFW

## Resolution

Added UFW rules on all nodes:

```bash
# All nodes - VXLAN overlay
sudo ufw allow from 192.0.2.x/24 to any port 8472 proto udp

# Master only - API server
sudo ufw allow from 192.0.2.x/24 to any port 6443 proto tcp
```

Also restarted `k3s-agent` on worker-01 to fix stale cni0 bridge IP.

## Probable Trigger

UFW default policy was changed to DROP during security hardening (11-13 May 2026) but k3s required ports (UDP 8472, TCP 6443) were not whitelisted. The cluster continued working because existing VXLAN/TCP connections were allowed by conntrack (state ESTABLISHED).

Around 19-23 May, linux-lab VM (101) was created on Proxmox which likely caused a node reboot or network disruption. Once connections dropped, new VXLAN/API server connections were blocked by UFW → cluster networking broke.

## Lessons Learned

- UFW default policy should never block inter-node cluster traffic
- Required ports for k3s: TCP 6443, UDP 8472 (VXLAN), TCP 10250 (kubelet)
- NetworkPolicy analysis wasted time — always verify L3/L4 connectivity first
- Consider adding a startup check script that validates inter-node connectivity

## Prevention

- Added UFW rules persistently (survive reboot)
- Consider documenting all required firewall ports in `docs/architecture.md`
- Add inter-node connectivity check to `scripts/morning-check.sh`
