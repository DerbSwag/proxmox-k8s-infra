# Kubernetes Operations Lab

Public-safe summary of Kubernetes operations labs completed in a private k3s environment.

Internal values such as real IP addresses, node names, dashboard UIDs, alert UIDs, credentials, webhook URLs, backup filenames, and raw command output are intentionally omitted or generalized.

---

## Scope

This lab validates day-2 Kubernetes operations, not only application deployment.

Validated workflow:

```text
workloads -> storage -> backup -> monitoring -> logging -> alerting -> GitOps -> drift/self-heal -> cleanup -> remote backup verification
```

---

## Validated Kubernetes Operations Labs

- Kubernetes workload and storage
- PostgreSQL CronJob backup
- Prometheus alert rule
- Grafana namespace dashboard
- Loki log dashboard
- Grafana-managed log alert
- Argo CD repo auth recovery
- GitOps self-heal and drift detection
- Cleanup/runbook
- Remote backup checksum verification

---

## Kubernetes Workload And Storage

Validated:

- Namespace-scoped application deployment.
- Service exposure with ClusterIP and NodePort patterns.
- Ingress routing pattern for an HTTP workload.
- PersistentVolumeClaim usage for stateless and stateful workload practice.
- PostgreSQL StatefulSet with persistent data volume.
- CronJob-based database backup into a backup PVC.

Key lessons:

- Stateful workloads require different cleanup rules than stateless demo workloads.
- PVC ownership must be checked before cleanup.
- CronJobs should be suspended during lab pauses to avoid unnecessary job history and storage growth.

---

## PostgreSQL Backup Workflow

Validated:

- PostgreSQL dump created by a Kubernetes CronJob.
- Backup output stored on a dedicated backup PVC.
- Backup retention behavior tested by keeping a limited number of SQL dumps.
- Temporary reader pod used to inspect and export backup files from the PVC.

Public-safe command pattern:

```bash
kubectl -n <namespace> get cronjob <backup-cronjob>
kubectl -n <namespace> create job <manual-job> --from=cronjob/<backup-cronjob>
kubectl -n <namespace> logs job/<manual-job>
kubectl -n <namespace> exec <reader-pod> -- ls -lh /backups
kubectl -n <namespace> cp <reader-pod>:/backups/<backup-file>.sql ./<backup-file>.sql
```

Key lessons:

- A PVC backup is still inside the cluster storage boundary.
- Backup evidence should include timestamp, size, and integrity verification.
- Temporary helper pods must be removed after evidence collection.

---

## Remote Backup Verification

Validated:

- Latest PostgreSQL dump exported from backup PVC.
- Backup copied to a remote host outside the Kubernetes namespace.
- Local and remote checksums compared successfully.
- Temporary reader pod removed after export.

Public-safe verification pattern:

```bash
sha256sum <backup-file>.sql
scp <backup-file>.sql <user>@<remote-host>:/path/to/remote-backups/
ssh <user>@<remote-host> "sha256sum /path/to/remote-backups/<backup-file>.sql"
```

Key lessons:

- Remote copy plus checksum is stronger evidence than "backup job succeeded".
- Restore testing is the next step after checksum verification.
- Public documentation should not publish real backup files or database dumps.

---

## Prometheus Metrics And Alerting

Validated:

- Prometheus targets were checked through the Prometheus API.
- Kubernetes metrics were queried with PromQL.
- Backup failure metric was tested with a synthetic failed job.
- PrometheusRule alert fired and reached Alertmanager.

PromQL examples:

```promql
up
kube_job_status_failed{namespace="<namespace>", job_name=~"<backup-job-prefix>.*"} > 0
```

Alert pattern:

```yaml
alert: LabBackupJobFailed
expr: kube_job_status_failed{namespace="<namespace>", job_name=~"<backup-job-prefix>.*"} > 0
for: 0m
labels:
  severity: warning
```

Key lessons:

- Test alert rules with known synthetic failures.
- Confirm the metric returns data before debugging the alert pipeline.
- PrometheusRule discovery depends on rule selectors and namespace selectors.

---

## Grafana Metrics Dashboard

Validated dashboard panels:

- Pod CPU
- Pod Memory
- Backup Failed
- CronJob Suspended

PromQL examples:

```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="<namespace>", container!="", pod!=""}[5m]))
sum by (pod) (container_memory_working_set_bytes{namespace="<namespace>", container!="", pod!=""})
kube_job_status_failed{namespace="<namespace>", job_name=~"<backup-job-prefix>.*"}
kube_cronjob_spec_suspend{namespace="<namespace>", cronjob="<backup-cronjob>"}
```

Key lessons:

- Time series panels are useful for workload CPU/memory.
- Stat panels are better for binary status such as CronJob suspended state.
- Dashboard JSON can be exported as portfolio evidence after sanitization.

---

## Loki Log Dashboard

Validated:

- Loki and Promtail pods were running.
- Grafana Loki datasource was used for log panels.
- Log panels were built for namespace logs, app logs, backup logs, and error logs.

LogQL examples:

```logql
{namespace="<namespace>"}
{namespace="<namespace>", pod=~"<app-pod-regex>"}
{namespace="<namespace>"} |= "backup"
{namespace="<namespace>"} |= "error"
```

Key lessons:

- Loki queries must run against a Loki datasource, not Prometheus.
- Logs visualization should use the `logs` panel type, not a metrics time series panel.
- An empty result is different from a LogQL parse error.

---

## Grafana-Managed Loki Log Alert

Validated:

- Synthetic test pod emitted a known log pattern.
- Loki query returned the expected log line.
- Grafana-managed alert rule evaluated a numeric LogQL expression.
- Alert entered an alerting state.
- Test pod was cleaned up after evidence collection.

LogQL alert pattern:

```logql
count_over_time({namespace="<namespace>", pod="<test-pod>"} |= "LAB_LOG_ALERT_TEST" [2m])
```

Alert rule pattern:

```text
Query: count_over_time(...)
Reduce: last
Condition: above 0
Evaluate: 1m
For: 0m
Labels: severity=warning, namespace=<namespace>
```

Key lessons:

- Grafana log alerts need logs converted into a numeric series.
- Synthetic log generation is useful for verifying the alert path.
- Keep alert rules only as long as needed for evidence unless they are part of the desired monitoring baseline.

---

## Argo CD Repository Authentication Recovery

Validated:

- Multiple Argo CD Applications showed repository comparison errors.
- Repository credentials were recreated as an Argo CD repository secret.
- Secret presence was verified by checking encoded value length rather than printing credentials.
- Repo server was restarted.
- Applications were hard-refreshed and returned to healthy sync states.

Public-safe checks:

```bash
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd describe application <app-name>
kubectl -n argocd get secret <repo-secret> -o jsonpath='{.data.password}' | wc -c
kubectl -n argocd rollout restart deploy/argocd-repo-server
kubectl -n argocd annotate application <app-name> argocd.argoproj.io/refresh=hard --overwrite
```

Security lessons:

- Do not paste tokens into shared logs or documentation.
- Revoke any token that is accidentally exposed.
- Validate secret presence by length or metadata, not by printing the secret value.

---

## GitOps App Change And Self-Heal

Validated:

- A small isolated GitOps application was created for drift and self-heal testing.
- Desired state was managed by Argo CD.
- Live image change through Git was reconciled successfully.
- Manual image drift was restored by Argo CD self-heal.
- Application events showed the transition from synced state to drift and back to synced.

Evidence pattern:

```text
Synced -> OutOfSync -> Synced
Healthy -> Progressing -> Healthy
Auto Heal Attempts Count: 1
```

Key lessons:

- Image drift is clearer self-heal evidence than extra metadata labels.
- If the Argo CD CLI is unavailable or broken, the Application CRD status and events can still provide evidence.
- Isolated lab applications make drift tests safer.

---

## Cleanup And Runbook Practice

Validated:

- Inventory was captured before deletion.
- Temporary GitOps application and namespace were removed.
- Temporary pods and completed jobs were removed.
- Stateless demo resources were deleted.
- Stateful PostgreSQL workload and backup PVC were retained.

Cleanup principle:

```text
inventory first -> delete temporary resources -> delete stateless demos -> preserve stateful data -> verify final state
```

See also:

- [Kubernetes Lab Cleanup Runbook](../runbooks/kubernetes-lab-cleanup-runbook.md)

---

## Public-Safety Notes

Do not publish:

- real IP addresses
- real hostnames
- tokens or passwords
- webhook URLs
- raw kubeconfig files
- raw `kubectl describe` output with sensitive metadata
- SQL backup files
- screenshots that expose internal URLs or topology

Publish instead:

- sanitized command patterns
- generic architecture summaries
- PromQL and LogQL examples
- alert rule patterns
- lessons learned
- cleanup approach
- evidence summaries without internal identifiers

