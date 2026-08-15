# Architecture

Git is the desired-state ledger for this lab. GitHub Actions builds the artifact
and records its tag; Argo CD reads that state and reconciles Kubernetes. CI
therefore needs no cluster credentials and issues no deployment command.

> **Design principle:** every hand-off should be visible: test result, image
> tag, Git change and cluster state. Hidden automation is convenient right up
> to the moment somebody has to explain it.

## Overview

```mermaid
flowchart TB
    Push["Push app change<br/>to main"]
    Tests["CI<br/>4 pytest tests"]
    Build["Build image<br/>sha-xxxxxxx"]
    Registry["GHCR<br/>immutable image"]
    DevTag["Commit dev<br/>image.tag"]
    ArgoDev["Argo CD<br/>sync dev"]
    Dev["DEV<br/>demo-api namespace"]
    Promotion["Human-reviewed PR<br/>copy verified tag"]
    ProdTag["Commit prod<br/>image.tag"]
    ArgoProd["Argo CD<br/>sync prod"]
    Prod["PROD<br/>demo-api-prod namespace"]

    Push --> Tests
    Tests -->|pass| Build
    Build --> Registry
    Registry --> DevTag
    DevTag --> ArgoDev
    ArgoDev --> Dev
    Dev -.->|verify| Promotion
    Promotion --> ProdTag
    ProdTag --> ArgoProd
    ArgoProd --> Prod
```

Dev follows the automated path; prod receives the verified dev tag through a
human-reviewed PR.

## Components

| Component | Responsibility |
| --- | --- |
| `apps/demo-api` | FastAPI service with 3 endpoints and 4 tests |
| GitHub Actions | tests, builds and commits the dev image tag |
| GHCR | stores `demo-api:sha-<7-character-commit>` images |
| Git | holds the dev and prod desired state |
| Helm | renders one shared Deployment and Service definition |
| Argo CD | reconciles Git into the two Kubernetes namespaces |

Both Applications track `main` and use `deploy/helm/demo-api`. Environment
separation comes from values and namespaces, not duplicated charts:

| Environment | Values | Application | Namespace |
| --- | --- | --- | --- |
| dev | `gitops/envs/dev/values.yaml` | `demo-api-dev` | `demo-api` |
| prod | `gitops/envs/prod/values.yaml` | `demo-api-prod` | `demo-api-prod` |

## Delivery

### Development

Only a push under `apps/demo-api/**` starts `CI`. A successful run triggers the
image build for that exact commit. After GHCR receives the image,
`gitops-update.yml` changes only `image.tag` in dev values and commits it to
`main`.

Argo CD renders the shared chart and updates the dev workload. Automated sync,
pruning, self-healing and namespace creation are enabled, so manual cluster
changes are treated as drift.

### Production

Production neither rebuilds the application nor follows dev automatically. A
human-reviewed PR copies the verified tag to prod values; after merge, Argo CD
deploys that same artifact to `demo-api-prod`. Automation proves the image; a
person chooses when to promote it.

## Pipeline safety

Three controls keep delivery and rollback from racing each other:

1. `ci.yml` runs only when `apps/demo-api/**` changes. A values-only rollback
   starts **0 new CI runs**.
2. `image-build.yml` uses `cancel-in-progress: false`, so an active registry
   push finishes instead of leaving a partial hand-off.
3. `gitops-update.yml` uses `cancel-in-progress: true`, so a newer desired-state
   update may replace stale pending work.

The two downstream workflows use `workflow_run` and proceed only after upstream
success. A failed test creates no image; a failed build creates no tag update.

The bot requires `contents: write` to update dev values directly on `main`.
Enforced branch protection would require a GitHub App token or a PR-based dev
update; neither is part of this lab.

## Design decisions

| Decision | Why | Trade-off |
| --- | --- | --- |
| single-node kind cluster | fast, local and close to the Kubernetes API used in CI | not a production control plane |
| SHA-based image tags | tie the deployed artifact to one source commit | tags remain a project convention rather than registry-enforced immutability |
| GitHub Actions updates dev values | every selected tag becomes an auditable Git change | bot needs repository write access |
| Argo CD owns deployment | CI stays outside the cluster and drift is corrected | Git polling can add about 3 minutes |
| one chart, two values files | avoids duplicated templates while separating environments | both environments share chart changes |
| PR-based prod promotion | promotes the tested artifact with a human audit trail | the gate is procedural without branch protection |

I chose explicit Git tag updates instead of Argo CD Image Updater because the
commit itself records what should run. Less magic, more receipts.
