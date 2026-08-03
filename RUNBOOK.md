# Public Runbook Summary

This file is a public-safe summary of operational runbooks used in the lab. Detailed command logs, real hostnames, internal IPs, webhook endpoints, and environment-specific credentials are intentionally excluded.

## Runbook Principles

- Start with inventory before deleting resources.
- Prefer read-only checks before restarts or destructive actions.
- Capture evidence before cleanup.
- Preserve stateful PVCs unless backup and restore are verified.
- Keep public examples generic; keep real operational values in private documentation.

## Common Incident Patterns

| Pattern | Public-safe response |
| --- | --- |
| Node disk pressure | Identify large directories, prune unused container images, rotate logs, then expand disk if needed |
| Node NotReady | Check kubelet/k3s-agent status, inspect events, confirm network reachability, then restart only when evidence supports it |
| Pod CrashLoopBackOff | Review previous logs, describe events, check image, config, secret, probes, and resource limits |
| DNS failure | Test DNS from an isolated pod, inspect CoreDNS, then review NetworkPolicy egress rules |
| API server blocked by policy | Test in-cluster API reachability and confirm post-DNAT policy behavior |
| GitOps OutOfSync | Read Argo CD Application conditions, compare desired/live state, then sync or allow self-heal |
| Alert not delivered | Validate alert state, receiver routing, adapter logs, and outbound egress policy |
| Backup verification | Check latest backup timestamp, file count, size, checksum, and remote copy status |
| Proxmox HDD storage error | Disable the new storage, keep source backups, inspect kernel I/O errors, and verify hardware before reuse |

## Safe Cleanup Pattern

```text
1. List resources.
2. Confirm ownership and whether the resource is GitOps-managed.
3. Delete temporary pods/jobs first.
4. Delete stateless demo resources.
5. Keep PVCs unless backup and restore are verified.
6. Re-run inventory commands and record the final state.
```

## Proxmox Storage Safety Pattern

```text
1. Confirm the target disk identity before wiping.
2. Add new storage only after mount and filesystem validation.
3. Copy backups before deleting source backups.
4. Verify target copy with file counts, sizes, and checksum/dry-run comparison.
5. If kernel logs show disk I/O errors, disable the storage and stop using the disk.
6. Use read-only disk testing first when hardware errors are suspected.
7. Keep auto-mount disabled until hardware is reseated, tested, or replaced.
```

## Dangerous Cleanup Pattern

Avoid broad deletion commands unless the lab objective explicitly accepts data loss:

```text
kubectl delete namespace <stateful-namespace>
kubectl -n <namespace> delete pvc --all
kubectl delete crd --all
git reset --hard
```

## Secrets

Public examples must not contain:

- kubeconfig files
- real `.tfvars`
- webhook URLs
- passwords
- API tokens
- unseal keys
- private sealed-secrets keys

Use placeholders such as:

```text
<CONTROL_PLANE_IP>
<WORKER_IP>
<WEBHOOK_URL>
<SNMP_COMMUNITY>
<SECRET_NAME>
```

## Portfolio Notes

The purpose of this runbook is to show operational reasoning, not to publish live operational access instructions. Internal command details belong in the private source-of-truth repository.
