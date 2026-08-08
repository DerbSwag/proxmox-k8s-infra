# 90-Day Flagship Project Execution Calendar

Use this as a focused execution checklist for the flagship project. Complete
the day only when its evidence is committed or recorded. If a task exposes a
real blocker, record the evidence and move the unfinished item into the next
day; do not hide it by starting an unrelated project.

## Operating Rhythm

- Spend the first 10 minutes stating the hypothesis and expected result.
- Spend the last 10 minutes committing documentation, evidence, or a concise
  follow-up task.
- Never commit credentials, private addresses, backup files, kubeconfig files,
  or raw screenshots with internal topology.
- Every 14th day is a review day, not a feature-expansion day.

## Days 1-14 — Understand The Existing Platform

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 1 | Inventory nodes, namespaces, workloads, storage classes, ingress, and Argo CD Applications using read-only commands. | Raw private notes plus a public-safe facts list. |
| 2 | Write `docs/current-state-assessment.md`: confirmed facts, unknowns, and how each unknown will be checked. | Assessment committed. |
| 3 | Write the project problem statement, intended users, non-goals, and success criteria. | README draft updated. |
| 4 | Draw the current architecture: Proxmox, k3s, GitOps, application, observability, and recovery boundaries. | Public-safe diagram draft. |
| 5 | Audit the existing FastAPI application and identify endpoint, dependency, configuration, and image gaps. | Short application design note. |
| 6 | Implement or validate `/`, `/health`, `/ready`, and `/metrics`; state what each endpoint proves. | Local or cluster test results. |
| 7 | Review Dockerfile and `.dockerignore`; use a non-root runtime and a pinned base image where practical. | Reproducible image build command. |
| 8 | Build and run the image locally or in the lab; verify every endpoint. | Image tag and endpoint checks. |
| 9 | Review Deployment manifest: labels, selector, probes, resources, and replica count. | Manifest rationale recorded. |
| 10 | Review Service and Ingress path from client to Pod. | Diagram or command evidence of endpoints. |
| 11 | Decide whether current TLS is valid, missing, or intentionally deferred; document the evidence. | TLS decision recorded, not assumed. |
| 12 | Confirm Argo CD owns the application path and identify the desired-state source. | Application sync/health evidence. |
| 13 | Write a short deployment guide from Git change to running workload. | `docs/deployment-guide.md` draft. |
| 14 | Review: explain the platform for ten minutes without notes; list three unclear concepts. | Sprint review and next-sprint adjustments. |

## Days 15-28 — Make Delivery Reproducible

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 15 | Define application test scope: unit, lint, dependency, and container build checks. | CI acceptance criteria. |
| 16 | Add or refine FastAPI tests for health and readiness behaviour. | Tests run locally. |
| 17 | Add CI lint/test workflow stages. | Green CI run. |
| 18 | Add container image build stage. | Build artifact or log evidence. |
| 19 | Choose registry and immutable image tag convention (release or commit SHA). | Convention documented. |
| 20 | Add authenticated image push without exposing credentials. | Successful private workflow evidence. |
| 21 | Update GitOps image reference through an intentional Git change. | Commit links image to desired state. |
| 22 | Verify Argo CD detects and reconciles the change. | Sync status and deployed image reference. |
| 23 | Verify rollout status, readiness, and application endpoint after deployment. | Deployment verification checklist. |
| 24 | Create a known-good release marker or tag. | Rollback target identified. |
| 25 | Trigger a safe bad deployment using an isolated change. | Expected failed rollout evidence. |
| 26 | Roll back through Git/GitOps; do not use undocumented live mutation. | Healthy previous revision. |
| 27 | Document CI/CD and rollback troubleshooting. | Runbook committed. |
| 28 | Review: explain Git push to Pod lifecycle and perform one clean deployment. | Sprint review. |

## Days 29-42 — Traffic, TLS, And Failure Drills

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 29 | Trace client to Ingress controller, Service, EndpointSlice, Pod, and process. | Annotated traffic-flow diagram. |
| 30 | Validate Service selectors and EndpointSlices for the healthy application. | Endpoint evidence. |
| 31 | Validate Ingress class, host/path rules, and controller events. | Ingress verification note. |
| 32 | If TLS is in scope, validate issuer, certificate, and renewal state; otherwise document the lab limitation. | Evidence-backed TLS status. |
| 33 | Create an invalid-image drill in an isolated workload. | `ImagePullBackOff` evidence. |
| 34 | Diagnose it with Pod events; restore the valid image by GitOps. | Incident report draft. |
| 35 | Create an application-process failure in an isolated workload. | `CrashLoopBackOff` evidence. |
| 36 | Diagnose previous logs, probe behaviour, and restart state; fix through Git. | Incident report draft. |
| 37 | Create a Service selector mismatch in an isolated workload. | Empty endpoint evidence. |
| 38 | Diagnose Service, labels, and EndpointSlices; restore service. | Incident report draft. |
| 39 | Turn the three drills into concise troubleshooting decision trees. | Troubleshooting guide. |
| 40 | Validate resource cleanup: no temporary failing resources remain. | Final state inventory. |
| 41 | Link incidents and troubleshooting guide from the README. | Navigable documentation. |
| 42 | Review: explain how traffic fails at each layer and how evidence narrows cause. | Sprint review. |

## Days 43-56 — Observability And Alerting

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 43 | Confirm Prometheus discovers the application metric endpoint. | Target and metric query evidence. |
| 44 | Choose four application signals: availability, request behaviour, error signal, and saturation/resource use. | Dashboard requirements. |
| 45 | Add dashboard panels for health and request behaviour. | Portable panel queries documented. |
| 46 | Add CPU/memory/restart panels and define normal versus concerning behaviour. | Dashboard rationale. |
| 47 | Verify application logs reach Loki with useful labels. | Public-safe LogQL examples. |
| 48 | Write LogQL queries for errors and request investigation. | Queries committed. |
| 49 | Define one actionable availability or error alert. | Alert rule and runbook link. |
| 50 | Test alert condition with a safe synthetic failure. | Alert reaches intended route. |
| 51 | Verify alert annotation contains enough investigation context. | Alert review note. |
| 52 | Create a temporary log-alert test, capture non-sensitive evidence, then remove it. | Deletion verification. |
| 53 | Add backup freshness/result signal to monitoring scope. | Metric or external-check design. |
| 54 | Review dashboard and alert noise; remove non-actionable signals. | Alert hygiene changes. |
| 55 | Write observability troubleshooting flow: metric, log, event, then root cause. | Runbook committed. |
| 56 | Review: diagnose one synthetic incident using dashboards and logs only. | Sprint review. |

## Days 57-70 — Backup And Recovery

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 57 | Define recovery scope: app data, Kubernetes state, VM/host, and off-host copy. | Backup scope table. |
| 58 | Review database backup CronJob schedule, destination, retention, and failure behaviour. | Backup design note. |
| 59 | Verify a fresh backup exists and inspect it through a temporary reader. | Archive age and file inventory. |
| 60 | Verify checksum or equivalent integrity check for an exported archive. | Integrity evidence. |
| 61 | Copy or verify an off-cluster/off-host backup according to the documented design. | Destination and checksum verification. |
| 62 | Design the isolated restore target and explicit cleanup plan. | Restore plan reviewed before execution. |
| 63 | Restore a backup into a temporary database or namespace. | Successful restore command. |
| 64 | Query expected schema/data or run an application-level validation. | Recoverability evidence. |
| 65 | Repeat validation from the off-host copy if supported. | Remote restore evidence. |
| 66 | Run idempotent cleanup and prove temporary data is removed. | Cleanup verification. |
| 67 | Review archive retention and only remove old files after restore evidence exists. | Retention decision. |
| 68 | Verify backup health/freshness monitoring and alert threshold. | Monitoring evidence. |
| 69 | Write backup and restore runbook; link failures to investigation steps. | Runbook committed. |
| 70 | Review: explain why a successful job is weaker evidence than a restore drill. | Sprint review. |

## Days 71-84 — Curate The Portfolio

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 71 | Audit repository navigation and remove or quarantine stale/internal-only material. | Public-safety review list. |
| 72 | Rewrite README opening as a hiring-manager summary: problem, architecture, outcomes. | README revision. |
| 73 | Finalize the architecture diagram with public-safe labels. | Diagram linked from README. |
| 74 | Curate deployment, observability, and recovery links into one narrative. | README journey section. |
| 75 | Select the strongest two incident case studies. | Linked, concise incident pages. |
| 76 | Add a troubleshooting index organized by symptom rather than tool. | Troubleshooting index. |
| 77 | Write STAR story: GitOps deployment and rollback. | Interview note. |
| 78 | Write STAR story: alert/incident investigation. | Interview note. |
| 79 | Write STAR story: backup/restore validation. | Interview note. |
| 80 | Record a first five-to-ten-minute walkthrough privately. | Recording and self-review notes. |
| 81 | Fix the three least-clear explanations or documentation gaps. | Focused improvements committed. |
| 82 | Rehearse common questions: Kubernetes choice, GitOps, observability, storage, recovery. | Answer notes in own words. |
| 83 | Perform a clean-clone review: can a reader navigate and understand the project? | Issues list and fixes. |
| 84 | Review: publish a release-style changelog entry and freeze scope. | Sprint review. |

## Days 85-90 — Final Validation And Job Readiness

| Day | Task | Evidence / Done condition |
| ---: | --- | --- |
| 85 | Run final documentation and public-safety review. | No internal identifiers or secrets. |
| 86 | Run final end-to-end deployment verification. | CI, Argo CD, and endpoint evidence. |
| 87 | Run final alert and restore readiness checks. | Observability and recovery checklist. |
| 88 | Record the final demo and a concise three-minute version. | Private recordings. |
| 89 | Add project achievements to resume and tailor applications for relevant roles. | Resume bullet points and target list. |
| 90 | Retrospective: document what was delivered, remaining backlog, and next 30-day maintenance cadence. | Final review and backlog. |

## Final Gate

Do not mark the project complete until you can demonstrate a deployment,
diagnose a controlled failure, explain observability, and describe a tested
restore path without reading notes.
