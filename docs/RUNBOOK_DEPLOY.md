# Deploy runbook

There is no deploy button for dev. Push application code to `main`, then the
pipeline and Argo CD do the repetitive work while you verify the result like a
responsible adult with `curl`.

> **Why this runbook exists:** automation removes keystrokes, not ownership. I
> still want the reader to know which stage owns the change and where to look
> when the happy path becomes merely aspirational.

## Expected dev delivery

```text
push a change under apps/demo-api/** to main
  -> 1. CI runs 4 pytest tests
  -> 2. image-build pushes ghcr.io/lotoos0/demo-api:sha-<7-char-SHA>
  -> 3. gitops-update writes the tag to gitops/envs/dev/values.yaml
  -> Argo CD notices the commit and renders the shared Helm chart
  -> Kubernetes replaces the dev pod
  -> /version returns the new tag
```

Budget about **3-5 minutes** from push to the updated endpoint. The path uses
**3 workflows**, changes **1 desired-state field** and requires **0 manual
cluster deployment commands**.

If a test, build or upstream workflow fails, the next stage does not run. That
is a feature. A pipeline that bravely deploys failed input is just a catapult.

## First setup

On a clean machine, use the complete bootstrap:

```bash
make bootstrap
```

It runs **5 targets** in order: `kind-create`, `fix-coredns`,
`argocd-install`, `argocd-apps-apply` and `verify`. See the
[fresh-machine bootstrap runbook](runbooks/fresh-machine-bootstrap.md) for
prerequisites, expected timing and endpoint checks.

## Verify a deployment

Check the desired tag first:

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
```

Then check all **3 runtime layers**:

```bash
# reconciliation
kubectl get application demo-api-dev -n argocd

# workload
kubectl get pods -n demo-api -l app=demo-api-dev

# deployed metadata
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
curl http://localhost:8080/version
```

Success means `Synced`, `Healthy`, a `Running` pod, and the same image tag in
Git and `/version`.

## If a stage stalls

| Symptom | First place to look | What the result means |
| --- | --- | --- |
| image build never starts | the `CI` run | all 4 tests must pass first |
| GitOps update never starts | `Build and push image` logs | no successful image means no tag to declare |
| Argo CD says `OutOfSync` | Application details and repo access | Git and cluster have not converged yet |
| Argo CD says `Degraded` | `kubectl logs -l app=demo-api-dev -n demo-api` | the desired pod exists but is unhealthy |
| pod says `ImagePullBackOff` | pod events and kind troubleshooting | registry auth, DNS or pull policy is blocking it |

For known local-cluster failures, continue with
[kind troubleshooting](troubleshooting/kind-cluster-issues.md). If the new
version is genuinely bad, stop debugging the pipeline and use the
[rollback runbook](RUNBOOK_ROLLBACK.md).

## Production is intentionally different

The automatic chain updates **dev only**. Production receives an already-built
tag through a human-reviewed values PR. Follow the
[prod promotion runbook](runbooks/prod-promotion.md); do not turn a dev push
into a surprise production hobby.
