# Architecture

## The big picture

The whole point is to have Git as the single source of truth and let Argo CD do the heavy lifting of reconciling the cluster state. Here's how the pieces connect:

```
developer
  │
  │ git push (1 code change)
  ▼
GitHub — main branch
  │
  ├─► [workflow: ci]            — installs deps, runs tests, blocks on failure
  │
  ├─► [workflow: image-build]   — builds Docker image, pushes to GHCR
  │                               tag format: sha-<7-char commit SHA>
  │
  └─► [workflow: gitops-update] — yq writes new image.tag to gitops/envs/dev/values.yaml
                                   commits as "chore: update demo-api image tag to sha-xxxx"
                                   pushes to main
                                        │
                                        ▼
                                  Argo CD (running in kind cluster)
                                    │ polls Git every ~3 minutes
                                    │ detects the values.yaml change
                                    ▼
                                  helm upgrade → Kubernetes Deployment updated
                                    │
                                    ▼
                                  /version returns the new tag
```

3 workflows, 1 cluster, 1 values file driving everything.

## Components

| Component | What it does |
|-----------|-------------|
| `apps/demo-api` | Python FastAPI app — 3 endpoints: `/health`, `/ready`, `/version` |
| `deploy/helm/demo-api` | Helm chart with `Deployment` + `Service`, parametrized by `image.tag` |
| `gitops/envs/dev/values.yaml` | The single source of truth for dev — only file Argo CD reads for image tag |
| `gitops/apps/demo-api-application.yaml` | Argo CD Application manifest pointing to the Helm chart + dev values |
| `infra/local/` | Terraform skeleton for local bootstrap (kind cluster, namespaces) |
| `.github/workflows/` | 3 pipelines: `ci.yml`, `image-build.yml`, `gitops-update.yml` |

## Rollback

No special tooling needed. Rollback is just reverting the GitOps commit:

```bash
git log --oneline gitops/envs/dev/values.yaml   # find the tag commit you want to undo
git revert <commit-sha>                          # revert it — creates a new commit
git push                                         # Argo CD detects the revert and syncs back
```

Argo CD picks up the reverted `values.yaml` within ~3 minutes and rolls the deployment back to the previous image tag. Full audit trail in Git, zero kubectl.

## What's explicitly out of scope in v0.1

| What | Returns when |
|------|-------------|
| `infra/aws/` | v0.4 |
| `gitops/envs/prod/` | v0.3 |
| `/metrics` endpoint | v0.5 |
| Argo CD Image Updater | not planned — explicit yq update is a feature, not a limitation |
