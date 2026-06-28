# GitOps Cloud Lab

Small local-first DevOps lab showing Kubernetes application delivery with GitOps.

## Goal

Prove the workflow:

Code change → CI → image build → GitOps values update → Argo CD sync → Kubernetes deployment → rollback by git revert.

## Stack

- kind
- GitHub Actions
- Docker
- GHCR
- Helm
- Argo CD
- Terraform

## MVP success metric

A code change triggers CI, builds a Docker image, updates `gitops/envs/dev/values.yaml` with `yq`, Argo CD syncs the change, and `/version` returns the new image tag.

No manual `kubectl apply` or `helm upgrade` is used for application deployment.
