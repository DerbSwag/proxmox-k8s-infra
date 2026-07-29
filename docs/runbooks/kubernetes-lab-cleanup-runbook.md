# Kubernetes Lab Cleanup Runbook

Public-safe cleanup runbook for temporary Kubernetes lab resources.

This runbook intentionally uses placeholders and avoids real namespaces, hostnames, IP addresses, and object UIDs.

---

## Goal

Clean temporary lab resources while preserving stateful data that may still be needed for backup, restore, or evidence review.

---

## Cleanup Rules

- Run inventory commands before deleting anything.
- Confirm whether the resource is GitOps-managed.
- Delete temporary pods and jobs before deleting higher-level resources.
- Delete stateless demo resources before stateful resources.
- Preserve PVCs unless backup and restore/integrity verification are complete.
- Re-run inventory after cleanup and record the final state.
- Use `--ignore-not-found` for repeatable cleanup commands.

---

## Inventory

```bash
kubectl get ns
kubectl -n <namespace> get all,pvc,ingress,networkpolicy,cronjob,job
kubectl -n argocd get applications.argoproj.io
kubectl -n monitoring get prometheusrule
```

Questions before deletion:

- Is this namespace still needed?
- Is this resource managed by Argo CD?
- Does this resource own a PVC?
- Is there backup/restore evidence for the data?
- Is this only a temporary test pod/job?

---

## Safe Cleanup Order

### 1. Delete Temporary Pods And Jobs

```bash
kubectl -n <namespace> delete pod <temporary-pod> --ignore-not-found
kubectl -n <namespace> delete job <temporary-job> --ignore-not-found
```

### 2. Delete Temporary GitOps Application

```bash
kubectl -n argocd get application <app-name>
kubectl -n argocd delete application <app-name> --cascade=background
```

### 3. Delete Temporary Namespace

Only do this for isolated demo namespaces that do not contain required data.

```bash
kubectl delete namespace <temporary-namespace> --ignore-not-found
```

### 4. Delete Stateless Demo Resources

```bash
kubectl -n <namespace> delete ingress <name> --ignore-not-found
kubectl -n <namespace> delete service <name> --ignore-not-found
kubectl -n <namespace> delete deployment <name> --ignore-not-found
kubectl -n <namespace> delete pod <name> --ignore-not-found
```

### 5. Delete PVCs Only When Safe

Do not delete PVCs until backup and restore/integrity verification are complete.

```bash
kubectl -n <namespace> get pvc
kubectl -n <namespace> delete pvc <pvc-name> --ignore-not-found
```

---

## Preserve By Default

Preserve these unless the lab objective explicitly requires removal:

- database PVCs
- backup PVCs
- stateful application PVCs
- long-running baseline services
- GitOps-managed resources that will be recreated automatically

---

## Dangerous Patterns

Avoid these unless you intentionally accept data loss:

```bash
kubectl delete namespace <stateful-namespace>
kubectl -n <namespace> delete pvc --all
kubectl delete crd --all
git reset --hard
```

---

## Final Verification

```bash
kubectl get ns
kubectl -n <namespace> get all,pvc,ingress,cronjob,job
kubectl -n argocd get applications.argoproj.io
```

Record:

- what was deleted
- what was preserved
- why PVCs were kept or removed
- whether backup verification was completed
- any follow-up action needed

