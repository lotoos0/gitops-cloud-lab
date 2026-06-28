# ADR 0001 — Local-first with kind and GitOps via Argo CD

## Status

Accepted

## Context

We need a local Kubernetes environment for a GitOps lab that:
- starts fast with no cloud cost
- mirrors a real delivery flow (CI → image → GitOps update → CD sync)
- is simple enough to run on a single developer machine

Options considered:
- `minikube` — heavier, more features than needed
- `k3d` — good alternative, but kind is more widely used in CI/CD documentation
- `kind` — lightweight, well-documented, used in many OSS projects

For GitOps sync we need a CD tool that watches Git and applies Helm charts:
- Flux — valid choice, but Argo CD has a UI and is more common in job postings
- Argo CD Image Updater — automates tag updates, but adds complexity; we want to own the update step explicitly via `yq`

## Decision

- Local cluster: **kind** (single node, named `gitops-cloud-lab`)
- CD tool: **Argo CD** — watches `gitops/envs/dev/values.yaml` only, no auto-image-update
- GitOps update mechanism: **GitHub Actions + yq** — explicit, auditable, no magic
- Environments in v0.1: **dev only**
- Cloud infra (`infra/aws/`): **excluded from v0.1**, returns in v0.4

## Consequences

- Rollback is `git revert` on the GitOps commit — visible in history, no kubectl needed
- Adding prod or staging is a new `gitops/envs/<env>/` directory — no structural change required
- Switching to a cloud cluster later requires only changing the kubeconfig — Argo CD config stays the same
