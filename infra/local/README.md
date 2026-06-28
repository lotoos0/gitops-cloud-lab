# infra/local

Terraform skeleton for local infrastructure. Right now it's intentionally minimal — just enough to prove the IaC pattern exists and `terraform validate` passes.

Cloud infrastructure (`infra/aws/`) is coming in v0.4. This directory will grow into a full local bootstrap (kind cluster creation, namespace setup, GHCR pull secret) before that.

## What's here

| File | Purpose |
|------|---------|
| `providers.tf` | Terraform version constraints + null provider |
| `variables.tf` | `cluster_name` variable (default: `gitops-cloud-lab`) |
| `main.tf` | Placeholder null_resource — will become kind cluster bootstrap |

## Usage

```bash
terraform init
terraform validate
terraform fmt -check
```

No `terraform apply` needed yet — there's nothing to provision locally via Terraform in v0.1. The kind cluster is managed through the Makefile (`make cluster-up`).
