# ADR 0001 — Local-first cluster with kind, GitOps via Argo CD + yq

## Status

Accepted

## Context

I needed a local Kubernetes environment for a GitOps lab. Requirements:
- spins up fast, no cloud cost, runs on a single developer machine
- mirrors a real delivery flow: CI → image → explicit GitOps update → CD sync
- simple enough that the flow is the focus, not the infrastructure

I looked at 3 local cluster options and 2 CD approaches.

### Local cluster candidates

| Option | Why I looked at it | Why I passed |
|--------|--------------------|--------------|
| `minikube` | most popular, tons of docs | heavier resource usage, more flags to manage |
| `k3d` | fast, k3s-based, solid choice | less common in enterprise CI/CD examples |
| `kind` | lightweight, used in many OSS projects and GitHub Actions CI | — picked this one |

**Winner: kind** — fast to start, well-documented, widely used in GitOps tooling examples, and the name makes me smile every time.

### GitOps image update candidates

| Option | Why I looked at it | Why I passed |
|--------|--------------------|--------------|
| Argo CD Image Updater | automates image tag detection | adds a second controller, hides the update step from Git history |
| **GitHub Actions + yq** | explicit update committed to Git | — picked this one |

The whole point of this lab is to see the full flow. If image tag updates happen automatically in the background, I lose half the story. With `yq`, every tag change is a visible commit in `gitops/envs/dev/values.yaml` — auditable, revertable, and easy to explain to anyone reading the repo.

## Decision

- **Local cluster:** `kind`, single node, cluster name `gitops-cloud-lab`
- **CD tool:** Argo CD — watches `gitops/envs/dev/values.yaml`, no auto-image-update plugins
- **GitOps update:** GitHub Actions + `yq` — 1 workflow, 1 yq command, 1 commit back to main
- **Environments in v0.1:** dev only — `gitops/envs/dev/` is the only env directory
- **Cloud infra:** `infra/aws/` intentionally excluded from v0.1, returns in v0.4

## Consequences

- **Rollback** = `git revert` on the GitOps commit. No kubectl, no helm, full history.
- **Adding staging/prod** = new `gitops/envs/<env>/` directory + new Argo CD Application. No structural changes needed.
- **Moving to a cloud cluster** = swap the kubeconfig. Argo CD config, Helm chart, and GitOps values stay exactly the same.
- **The yq commit is always visible** — anyone reading `git log` can see exactly which image tag was deployed and when.
