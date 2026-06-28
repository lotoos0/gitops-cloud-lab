# Architecture

## Overview

```
developer
  │
  │ git push
  ▼
GitHub (main branch)
  │
  ├─► GitHub Actions CI         — runs tests
  │
  ├─► GitHub Actions image-build — builds Docker image, pushes to GHCR with tag sha-<commit>
  │
  └─► GitHub Actions gitops-update — yq updates image.tag in gitops/envs/dev/values.yaml,
                                      commits and pushes to main
                                          │
                                          ▼
                                    Argo CD (in kind)
                                      │ polls Git every ~3 min
                                      ▼
                                    Helm sync → Kubernetes Deployment (kind)
```

## Components

| Component | Role |
|-----------|------|
| `apps/demo-api` | Python FastAPI app with `/health`, `/ready`, `/version` |
| `deploy/helm/demo-api` | Helm chart — parametrized by `image.tag` |
| `gitops/envs/dev/values.yaml` | Single source of truth for dev desired state |
| `gitops/apps/demo-api-application.yaml` | Argo CD Application manifest |
| `infra/local` | Terraform skeleton for local setup (kind, namespaces) |
| `.github/workflows` | CI, image build, GitOps update pipelines |

## Rollback

```
git log gitops/envs/dev/values.yaml   # find previous tag commit
git revert <commit-sha>               # revert the GitOps commit
git push                              # Argo CD picks up the revert and syncs
```
