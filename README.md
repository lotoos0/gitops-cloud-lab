# GitOps Cloud Lab

A local-first DevOps lab that takes one small FastAPI service through a real
GitOps delivery loop. No cloud bill, no mystery button, and no ceremonial
`kubectl apply` performed under a full moon.

## Project status: 100% complete

The lab is finished. The delivery flow, dev/prod split, rollback safety,
bootstrap automation, troubleshooting evidence and final documentation pass are
all complete. This docs rewrite is the last planned change — after it, the
toolbox closes and the tiny cluster gets to enjoy retirement.

“Complete” here means the defined lab scope is done, not that it contains every
platform feature ever invented. The deliberate exclusions below remain
excluded; they are boundaries, not promises for a sequel.

> **A note from me:** I built this repository to prove the whole path from a
> code change to a running pod with evidence I can inspect later. The point is
> not a large application. The point is a small system whose delivery story is
> impossible to hand-wave.

## What this lab proves

One push to `main` starts a chain with **3 GitHub Actions workflows**:

```text
git push
  -> CI runs 4 API tests
  -> image-build creates ghcr.io/lotoos0/demo-api:sha-<7-char-SHA>
  -> gitops-update changes exactly 1 field in dev values: image.tag
  -> Argo CD detects the Git change
  -> Helm renders the release
  -> Kubernetes rolls out the new pod
  -> /version reports the deployed tag
```

The current local setup has **1 kind cluster**, **2 Argo CD Applications** and
**2 isolated namespaces**:

| Environment | Argo CD Application | Namespace | Delivery rule |
| --- | --- | --- | --- |
| dev | `demo-api-dev` | `demo-api` | automatic after a successful code push |
| prod | `demo-api-prod` | `demo-api-prod` | a human promotes a tested tag through a PR |

Git stays the source of truth for both. If the cluster disagrees, Argo CD sides
with Git. It is loyal like that.

## A successful run, in numbers

- **1** application code change starts the delivery flow.
- **4** pytest checks must pass.
- **3** workflows run in order: CI, image build, GitOps update.
- **1** immutable tag is produced in the form `sha-xxxxxxx`.
- **about 3-5 minutes** gets the change from push to a responding dev pod.
- **0** manual `kubectl apply` or laptop-side `helm upgrade` commands deploy it.

The final check is delightfully unglamorous:

```bash
curl http://localhost:8080/version
```

The returned `version` must match the tag stored in
`gitops/envs/dev/values.yaml`, while Argo CD reports `Synced` and `Healthy`.

## Stack and the reason each tool is here

| Tool | Job | Why I chose it |
| --- | --- | --- |
| `kind` | local Kubernetes cluster | quick, disposable and close enough to the real API to be useful |
| GitHub Actions | CI, image build and GitOps update | makes all 3 delivery stages visible in the repository |
| Docker + GHCR | image build and registry | keeps the artifact tied to the commit SHA |
| Helm | reusable Kubernetes templates | one chart serves dev and prod with separate values |
| Argo CD | continuous reconciliation | turns Git state into cluster state and exposes drift |
| Terraform | local IaC skeleton | records the IaC boundary without pretending cloud resources exist |

## Start here

Install Docker, kind, kubectl and Make, then run:

```bash
make bootstrap
```

That target chains **5 operations**: create the cluster, patch CoreDNS, install
Argo CD, apply both Applications and print verification data. The detailed
procedure lives in [the fresh-machine bootstrap runbook](docs/runbooks/fresh-machine-bootstrap.md).

Useful follow-ups:

- [Architecture](docs/ARCHITECTURE.md) explains the moving parts and boundaries.
- [Deploy runbook](docs/RUNBOOK_DEPLOY.md) follows a change through dev.
- [Prod promotion runbook](docs/runbooks/prod-promotion.md) keeps production human-gated.
- [Rollback runbook](docs/RUNBOOK_ROLLBACK.md) uses Git instead of cluster heroics.
- [Troubleshooting](docs/troubleshooting/kind-cluster-issues.md) contains the dents I already put in the furniture.
- [Contributing](CONTRIBUTING.md) describes the issue-to-PR workflow.

## Repository map

```text
apps/demo-api/         # FastAPI service: 3 endpoints, 4 tests
deploy/helm/demo-api/  # 1 Helm chart shared by both environments
gitops/envs/           # separate desired state for dev and prod
gitops/apps/           # 2 Argo CD Application manifests
infra/local/           # Terraform skeleton + local DNS repair script
.github/workflows/     # 3-stage delivery pipeline
docs/                  # architecture, decisions, runbooks and proof
```

## Deliberate final boundaries

This is a focused lab, not a tiny platform team wearing a trench coat.

- AWS infrastructure is not part of the completed local-first scope.
- `/metrics` and monitoring are not part of the completed delivery lab.
- Argo CD Image Updater is intentionally absent: I want each tag change visible
  as a Git commit.
- `main` currently has no branch protection; the human PR discipline is
  documented, but not technically enforced.

Those exclusions are final for this project. A useful demo says what it does,
what it does not do, and—rare luxury—when it is actually done.
