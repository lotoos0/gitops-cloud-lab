# GitOps Cloud Lab

A small local-first DevOps lab that proves a real Kubernetes delivery flow — no cloud bill, no magic, no clicking around in consoles.

## Why this exists

I wanted one place where I can demonstrate — to myself and others — that I understand the full chain from `git push` to a running pod. Not theory, not slides. A working flow.

## The flow

```
git push
  → GitHub Actions runs tests (3 workflows: ci, image-build, gitops-update)
  → Docker image built and pushed to GHCR with tag sha-<commit>
  → yq updates image.tag in gitops/envs/dev/values.yaml
  → commit + push back to main
  → Argo CD detects the Git change and syncs
  → Kubernetes on kind deploys the new version
  → curl /version returns the new tag
  → rollback = git revert (nothing else)
```

No manual `kubectl apply`. No `helm upgrade` from a laptop. Git is the only source of truth.

## Stack

| Tool | Purpose |
|------|---------|
| `kind` | local Kubernetes cluster — lightweight, fast, no surprises |
| `GitHub Actions` | CI + image build + GitOps values update (3 workflows) |
| `Docker` + `GHCR` | containerization and image registry |
| `Helm` | Kubernetes package manager |
| `Argo CD` | GitOps CD — watches the repo, syncs the cluster |
| `Terraform` | IaC skeleton (local-only in v0.1, cloud returns in v0.4) |

## What counts as success (v0.1)

- Change 1 line of code
- Push
- Wait ~3 minutes
- `curl /version` returns the new image tag
- Argo CD shows `Synced + Healthy`
- Did not touch `kubectl` or `helm` to deploy the app

## What's intentionally missing (for now)

- `infra/aws/` — cloud infra returns in v0.4
- `gitops/envs/prod/` — prod promotion returns in v0.3
- `/metrics` endpoint — monitoring returns in v0.5
- Argo CD Image Updater — I want the tag update to be explicit and visible in Git history, not automated away

## Repo layout

```
apps/demo-api/        # Python FastAPI app — /health, /ready, /version
deploy/helm/demo-api/ # Helm chart driven by image.tag from values
gitops/envs/dev/      # dev desired state — the single source of truth
gitops/apps/          # Argo CD Application manifest
infra/local/          # Terraform skeleton, local only
.github/workflows/    # 3 pipelines: ci, image-build, gitops-update
docs/                 # architecture, runbooks, ADRs
```
