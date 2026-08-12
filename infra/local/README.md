# Local infrastructure

This directory is the intentionally modest Terraform corner of the lab. Today
it proves that the IaC structure and constraints are valid; it does **not**
provision the kind cluster yet.

> **My reasoning:** I would rather publish a small, truthful skeleton than a
> grand “platform” made mostly of comments. Cluster bootstrap lives in the
> Makefile, while cloud infrastructure stays outside this finished lab.

## What exists today

| File | Current responsibility |
| --- | --- |
| `providers.tf` | requires Terraform `>= 1.6` and the `hashicorp/null` provider `~> 3.0` |
| `variables.tf` | defines 1 string input, `cluster_name`, defaulting to `gitops-cloud-lab` |
| `main.tf` | declares 1 `null_resource` placeholder keyed by that cluster name |
| `scripts/fix-coredns.sh` | applies the network-specific CoreDNS repair used by bootstrap |

That is **3 Terraform files**, **1 placeholder resource** and **0 cloud
resources**. The numbers are small on purpose.

## Validate it

From this directory:

```bash
terraform init
terraform fmt -check
terraform validate
```

There is no useful `terraform apply` step yet: a `null_resource` cannot build a
cluster by sheer optimism. Use the repository Makefile instead:

```bash
make kind-create
# or run the complete 5-step local setup
make bootstrap
```

This is the final infrastructure boundary for the project: the local bootstrap
is complete through the Makefile and CoreDNS script, while `infra/aws/` was
deliberately not built. The skeleton records that choice without advertising a
future season that is not coming.
