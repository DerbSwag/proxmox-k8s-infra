# Kubernetes Operations Lab Sources

Portable, public-safe manifests reconstructed from the completed operations lab.

## Included patterns

- PostgreSQL StatefulSet with a PVC and an externalized password.
- CronJob database backup, backup PVC, and temporary reader pod.
- Synthetic backup failures and a PrometheusRule to validate alert delivery.
- Least-privilege RBAC, Helm, Kustomize, and ingress-only NetworkPolicy examples.

## Safety and use

These are templates, not a production deployment. Replace every `<...>` value,
create the referenced secret outside source control, and review storage,
retention, access control, and ingress settings before applying.

Validation chain: `backup job -> archive -> checksum -> temporary restore -> query -> cleanup`.
See [the operations lab](../../../docs/labs/kubernetes-operations-lab.md) for procedures.
