# Pipeline Safety — v0.2

## The problem discovered in v0.1

After v0.1 shipped a working GitOps flow, a rollback test revealed a bug.

`git revert` on a commit that changed only `gitops/envs/dev/values.yaml` triggered the full delivery pipeline:

```
git revert values.yaml commit
  -> CI fires
  -> image-build fires
  -> gitops-update fires
  -> gitops-update writes a NEW image tag to values.yaml
  -> rollback tag gets overwritten
```

The core promise — _rollback = git revert_ — was functionally true, but had a race condition that made it unreliable.

---

## What v0.2 fixed

### Fix 1 — CI path filter (`ci.yml`)

Added `paths` filter to the `push` and `pull_request` triggers:

```yaml
on:
  push:
    branches: ["main"]
    paths:
      - "apps/demo-api/**"
  pull_request:
    branches: ["main"]
    paths:
      - "apps/demo-api/**"
```

GitHub Actions evaluates which files changed in the commit. If none of them match `apps/demo-api/**`, the workflow is skipped entirely — no runner is allocated, no downstream workflows are triggered.

A `git revert` on `values.yaml` only touches `gitops/envs/dev/values.yaml`. That path does not match. CI does not fire.

### Fix 2 — Concurrency guards

**`image-build.yml`** — `cancel-in-progress: false`

```yaml
concurrency:
  group: demo-api-image-build-main
  cancel-in-progress: false
```

We never interrupt a running build or push. Killing a `docker push` mid-flight can leave an incomplete or inconsistent image in GHCR.

**`gitops-update.yml`** — `cancel-in-progress: true`

```yaml
concurrency:
  group: demo-api-gitops-update-main
  cancel-in-progress: true
```

If multiple gitops-update runs are queued (e.g. from rapid pushes), only the newest desired state matters. Older queued runs are cancelled.

---

## Rollback proof

### Setup

A code change was pushed to `apps/demo-api/app/main.py` to trigger the full pipeline.

After the pipeline completed, `gitops/envs/dev/values.yaml` contained:

```yaml
image:
  tag: sha-98b8274
```

Argo CD synced and deployed `sha-98b8274`.

### Rollback

The gitops-update commit was reverted:

```bash
git revert 06c797a --no-edit
git push
```

This commit changed only `gitops/envs/dev/values.yaml`.

### Results

GitHub Actions run list after the revert push — no new CI run appeared:

```
completed  success  GitOps update        workflow_run  2026-06-29T10:35:37Z  (from previous push)
completed  success  Build and push image  workflow_run  2026-06-29T10:33:55Z  (from previous push)
completed  success  CI                   push          2026-06-29T10:33:23Z  (from previous push)
```

The revert pushed at ~10:36Z produced no new workflow runs.

| Check | Result |
|-------|--------|
| CI triggered after revert | No |
| New image built | No |
| New `chore: update demo-api image tag` commit | No |
| `values.yaml` tag after revert | `sha-a6e5648` (rollback tag) |
| Argo CD status | `Synced + Healthy` |
| `curl /version` | `{"version":"sha-a6e5648"}` |

---

## Known constraints

### `gitops-update` commits directly to `main`

The automated GitOps update workflow pushes directly to `main` using `GITHUB_TOKEN` with `contents: write`. This is a deliberate decision for v0.2.

If branch protection is enabled on `main` in the future (e.g. "require pull request before merge"), `gitops-update` will break because `GITHUB_TOKEN` cannot bypass branch protection by default.

Options for when that becomes relevant:
1. Keep `main` without branch protection in this lab.
2. Switch from `GITHUB_TOKEN` to a GitHub App installation token.
3. Change `gitops-update` to open a PR instead of pushing directly.

Branch protection is out of scope for v0.2.

### `cancel-in-progress: false` on image-build

With `cancel-in-progress: false`, GitHub holds at most one pending run per concurrency group. If three fast commits arrive, the middle pending run can be replaced by the newest one.

Full FIFO queuing via `queue: max` is out of scope for v0.2.
