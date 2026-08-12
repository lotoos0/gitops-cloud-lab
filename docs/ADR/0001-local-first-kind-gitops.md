# ADR 0001: local kind cluster and explicit GitOps updates

- **Status:** Accepted
- **Decision scope:** local cluster and image-tag delivery
- **Initial environment:** dev in v0.1; prod added in v0.3

## Context

I wanted a Kubernetes lab that starts on one developer machine, costs no cloud
money and still demonstrates the real chain from CI to image to desired state
to reconciliation. The delivery mechanics had to stay visible; the cluster
itself did not need to audition for a hyperscaler.

> **Decision principle:** optimize for a flow the reader can inspect, explain
> and revert. Convenience matters, but hidden state makes a poor teaching aid.

I compared **3 local cluster options** and **2 image-update approaches**.

## Local cluster options

| Option | Advantage | Reason not selected |
| --- | --- | --- |
| `minikube` | mature and widely documented | more resource and driver choices than this lab needs |
| `k3d` | fast, lightweight k3s distribution | less representative of the OSS and CI examples I wanted to mirror |
| `kind` | small, disposable, common in CI | selected |

I selected `kind`: one node, cluster name `gitops-cloud-lab`. It starts quickly,
uses familiar Kubernetes APIs and, yes, the name is pleasantly optimistic.

## Image-update options

| Option | Advantage | Trade-off |
| --- | --- | --- |
| Argo CD Image Updater | detects and updates tags automatically | adds another controller and hides part of the learning path |
| GitHub Actions + `yq` | records every selected tag in Git | requires an explicit workflow and bot commit |

I selected GitHub Actions plus `yq`. Each dev delivery changes exactly **1
field**, `image.tag`, and records it in `gitops/envs/dev/values.yaml`. That
makes the deployed artifact auditable and rollback a normal Git operation.

## Decision

- Run a single-node `kind` cluster named `gitops-cloud-lab`.
- Use Argo CD to reconcile a shared Helm chart from `main`.
- Use **3 GitHub Actions workflows** for testing, image publication and the
  explicit dev tag update.
- Keep environment-specific desired state in separate values files.
- Do not add an automatic image-update controller.
- Keep cloud infrastructure outside the completed local-first design.

The system now has **2 environments**. Dev tags update automatically after the
pipeline succeeds; prod receives a verified dev tag through a human PR. Argo CD
then reconciles both using the same chart.

## Consequences

### Benefits

- Every deployed tag is visible in Git history.
- Rollback is `git revert`, with no hidden cluster mutation.
- Dev and prod reuse one chart while keeping separate values and namespaces.
- Moving the control plane later does not require redesigning the application
  or GitOps layout.

### Costs and limits

- The workflow bot needs write access to update dev values.
- Branch protection would require a different bot identity or PR-based update.
- Argo CD polls rather than receiving an immediate deployment command, so sync
  commonly adds up to about **3 minutes**.
- Local DNS required a documented CoreDNS workaround on the author's network.

I accept those costs because they keep the central lesson intact: Git contains
the desired state, and every transition leaves a readable trail.
