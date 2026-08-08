# 90-Day Flagship Project Plan

## Objective

Evolve this repository into a production-like DevOps portfolio that can be
explained end-to-end in ten minutes:

```text
Git change -> CI -> immutable container image -> Argo CD -> k3s
-> HTTPS ingress -> metrics, logs, and alerts -> backup and restore
```

The outcome is not merely a running lab. It is a reproducible system with
evidence, operational documentation, and clear engineering decisions.

## Working Rules

- This repository is the single flagship project for the next 90 days.
- Prefer finishing, documenting, and validating existing components over
  adding unrelated tools or labs.
- Every two weeks, publish a reviewed deliverable that can be demonstrated.
- Treat Git as the deployment source of truth; avoid undocumented manual
  changes to live resources.
- For every component, be able to explain its purpose, failure mode,
  verification method, and rollback or recovery path.

## Delivery Plan

| Sprint | Days | Focus | Deliverable |
| --- | ---: | --- | --- |
| 1 | 1-14 | Baseline and application | Current-state assessment, architecture, FastAPI workload |
| 2 | 15-28 | Delivery path | CI build/push, Argo CD deployment, rollback evidence |
| 3 | 29-42 | Edge and resilience | Ingress/TLS validation and repeatable application incidents |
| 4 | 43-56 | Observability | Metrics, logs, dashboards, and tested alerts |
| 5 | 57-70 | Recovery | Backup freshness, checksum, restore drill, retention review |
| 6 | 71-90 | Portfolio and interview | Curated README, demo, case studies, and STAR stories |

## Sprint 1: Baseline And Application

### Goals

- Document the current platform rather than assuming its state.
- Make the FastAPI workload a clear, reproducible example.
- Create the first architecture diagram and problem statement.

### Tasks

1. Create `docs/current-state-assessment.md` from read-only cluster checks.
2. Update the README with the problem, intended outcome, and system flow.
3. Define FastAPI endpoints: `/`, `/health`, `/ready`, and `/metrics`.
4. Review Dockerfile, `.dockerignore`, non-root runtime, and image tagging.
5. Make Kubernetes manifests or Helm values reproducible through Argo CD.
6. Audit the current ingress and TLS implementation; do not claim TLS until it
   has been verified in the lab.
7. Run and document three isolated failure drills:
   - invalid image reference (`ImagePullBackOff`),
   - failing application process (`CrashLoopBackOff`),
   - Service selector or target-port mismatch (no usable endpoints).

### Sprint 1 Definition Of Done

- FastAPI is reachable through the intended ingress path.
- Health, readiness, and metrics endpoints have documented purposes.
- The workload deploys from Git through Argo CD.
- The repository contains a current-state assessment and architecture draft.
- Three incident reports use: symptom -> evidence -> root cause -> resolution
  -> prevention.
- The platform can be explained without reading operational notes.

## Sprint 2: CI/CD And GitOps

- Run tests before building the application image.
- Publish images with immutable version or commit-SHA tags; avoid relying on
  `latest`.
- Update the GitOps desired state deliberately and verify Argo CD reconciliation.
- Demonstrate a rollback to a known-good revision.

Evidence: workflow run, deployed image reference, Argo CD sync history, and
rollback verification.

## Sprint 3: Traffic, TLS, And Failure Handling

- Document Browser -> Ingress -> Service -> Pod -> FastAPI traffic flow.
- Implement or validate TLS using the lab's actual supported approach.
- Write concise troubleshooting guides for image, application, and service/
  ingress failures.
- Record only public-safe evidence; never publish internal addresses, tokens,
  or screenshots with private topology.

## Sprint 4: Observability

- Verify Prometheus discovers the application metric endpoint.
- Add useful Grafana panels for availability, latency or request behaviour,
  resource use, and backup health where applicable.
- Use Loki for application and workload-log investigation.
- Test at least one actionable alert end-to-end, then retire any temporary
  alert rule with a documented cleanup check.

Evidence: query examples, alert condition, alert delivery evidence, and the
associated runbook.

## Sprint 5: Backup And Recovery

- Review scope: application data, Kubernetes state, VM or host recovery, and
  off-host copies.
- Monitor backup success and freshness rather than job creation alone.
- Verify archive integrity with a checksum where applicable.
- Restore into an isolated temporary target and validate expected data.
- Review retention and perform cleanup only after validation succeeds.

Evidence: restore result, query or service validation, and idempotent cleanup
steps.

## Sprint 6: Portfolio And Interview Readiness

- Curate the README around one end-to-end engineering story.
- Add an architecture diagram with public-safe labels.
- Select the most useful incidents and runbooks; link rather than duplicate.
- Record a five-to-ten-minute walkthrough privately and refine unclear parts.
- Write STAR stories for deployment, observability, incident response, and
  backup/restore.
- Apply to relevant roles while continuing to improve only evidence-backed gaps.

## Review Questions (Every 14 Days)

1. What is complete and demonstrable?
2. What can be explained without notes?
3. Which evidence exposed an actual knowledge gap?
4. What work did not improve the flagship project?
5. What is the single deliverable for the next sprint?

## Final Definition Of Done

- A reviewer can understand the architecture, deployment path, operations,
  failure handling, and recovery approach from this repository.
- The application lifecycle is reproducible from Git and uses verifiable image
  versions.
- Monitoring, alerting, and restore evidence are documented.
- Sensitive environment details remain excluded.
- The project can be presented confidently in ten minutes without notes.
