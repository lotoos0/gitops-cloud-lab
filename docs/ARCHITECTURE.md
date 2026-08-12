# Architecture

This lab uses Git as the desired-state ledger and Argo CD as the patient
reconciler that keeps the cluster honest. The application is intentionally
small; the delivery path is the thing under the microscope.

> **A note from me:** I chose an explicit chain because I want every hand-off to
> be visible: test result, image tag, Git change and cluster state. “Something
> automated happened somewhere” is not an architecture diagram.

## The system at a glance

```text
developer changes apps/demo-api/**
             |
             | push to main
             v
GitHub Actions
  1. CI -------- runs 4 pytest tests
       |
       | success
       v
  2. image-build -------- builds and pushes sha-<7-char-SHA> to GHCR
       |
       | success
       v
  3. gitops-update ------- writes that tag to dev values and commits to main
                                  |
                                  v
Git: gitops/envs/dev/values.yaml
                                  |
                                  | polled about every 3 minutes
                                  v
Argo CD: demo-api-dev -> Helm -> Deployment -> /version

Human promotion PR
  copies one verified dev tag to gitops/envs/prod/values.yaml
                                  |
                                  v
Argo CD: demo-api-prod -> Helm -> Deployment -> /version
```

In short: **3 workflows**, **1 image artifact**, **2 desired-state files**,
**2 Argo CD Applications**, **2 namespaces** and **0 manual deployment
commands** in the normal path.

## Components and ownership

| Component | Owns | Does not own |
| --- | --- | --- |
| `apps/demo-api` | 3 HTTP endpoints and 4 tests | deployment decisions |
| `deploy/helm/demo-api` | Kubernetes `Deployment` and `Service` templates | environment-specific image tags |
| `gitops/envs/dev/values.yaml` | automatic dev desired state | prod promotion |
| `gitops/envs/prod/values.yaml` | human-approved prod desired state | image building |
| `gitops/apps/demo-api-*.yaml` | Argo CD source, destination and sync policy | source compilation |
| `.github/workflows/` | test, build and dev tag update | direct cluster mutation |
| `infra/local/` | local bootstrap support and Terraform direction | cloud infrastructure today |

Both Applications use the same Helm chart and track `main`, but deploy into
different namespaces: `demo-api` and `demo-api-prod`. That gives environment
separation without copying the chart and raising twins that immediately drift
apart.

## Reconciliation rules

Argo CD has automated sync, pruning, self-healing and namespace creation enabled
for both Applications. The important distinction is therefore **how Git
changes**, not whether Argo CD syncs:

- dev values change automatically after all upstream workflows succeed;
- prod values change only through a human-reviewed promotion PR.

Once either value is committed, Argo CD applies it. Production is human-gated
at Git, where the decision is reviewable and revertible.

## Rollback model

Rollback creates a new Git commit that reverses the bad desired state:

```bash
git log --oneline gitops/envs/dev/values.yaml
git revert <bad-gitops-commit> --no-edit
git push
```

For prod, use `gitops/envs/prod/values.yaml`. Argo CD normally detects the
revert within about **3 minutes** and restores the earlier image. The audit
trail stays intact, and nobody has to arm-wrestle the reconciler with an
imperative `kubectl set image`.

## Deliberate final boundaries

| Not included | Final decision |
| --- | --- |
| AWS infrastructure | outside this completed local-first lab |
| metrics and monitoring | outside the completed delivery scope |
| Argo CD Image Updater | excluded; explicit Git tag updates are part of the proof |
| enforced branch protection | not enabled; documented PR discipline is currently the control |

These are final design boundaries, not forgotten TODOs. The project is 100%
complete against its chosen scope; the table marks where the demonstration
ends, with no mysterious vNext waiting behind the curtain.
