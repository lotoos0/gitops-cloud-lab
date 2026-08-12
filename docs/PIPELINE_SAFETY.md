# Pipeline safety: what v0.2 fixed

v0.1 delivered code correctly, then a rollback test found a wonderfully rude
edge case: reverting the GitOps tag could trigger a fresh build that overwrote
the rollback. The system technically supported `git revert`; it just tried to
argue with it immediately afterwards.

> **Why I wrote this down:** a safety claim deserves the failure mode, the
> exact controls and the proof. “Fixed the pipeline” is not enough information
> for the next person holding the pager — even when that person is also me.

## The original race

```text
revert a commit that changed only dev values
  -> CI starts
  -> image-build starts
  -> gitops-update writes a new image tag
  -> the intended rollback tag is overwritten
```

One values-only commit caused **3 unnecessary workflow runs** and could undo
the operator's desired state. v0.2 added **3 controls**: 1 path filter and 2
different concurrency policies.

## Control 1: run CI only for application changes

`ci.yml` filters both `push` and `pull_request` events:

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

A rollback changes `gitops/envs/dev/values.yaml`, which does not match
`apps/demo-api/**`. GitHub therefore allocates **0 CI runners**, and the two
`workflow_run` stages downstream receive no new successful CI run to follow.

## Controls 2 and 3: serialize delivery intentionally

The image build preserves work already in progress:

```yaml
concurrency:
  group: demo-api-image-build-main
  cancel-in-progress: false
```

Interrupting a registry push is a poor way to save seconds, so a running build
finishes.

The GitOps update uses the opposite policy:

```yaml
concurrency:
  group: demo-api-gitops-update-main
  cancel-in-progress: true
```

If rapid pushes create multiple desired-state updates, the newest one wins and
older work may be cancelled. Artifacts are preserved; stale declarations are
not. Same keyword, different risk — hence the different settings.

## The rollback proof

### Starting state

A change to `apps/demo-api/app/main.py` ran the complete pipeline. Dev reached:

```yaml
image:
  tag: sha-98b8274
```

Argo CD deployed `sha-98b8274`.

### Action

The generated GitOps commit was reverted:

```bash
git revert 06c797a --no-edit
git push
```

That new commit touched exactly **1 file**:
`gitops/envs/dev/values.yaml`.

### Observed result

The last workflow runs remained the ones from the earlier code push:

```text
completed  success  GitOps update         workflow_run  2026-06-29T10:35:37Z
completed  success  Build and push image  workflow_run  2026-06-29T10:33:55Z
completed  success  CI                    push          2026-06-29T10:33:23Z
```

The revert was pushed at about `10:36Z` and created **0 new workflow runs**.

| Check | Observed result |
| --- | --- |
| CI runs after the revert | `0` |
| new images built | `0` |
| new automated tag commits | `0` |
| dev tag after the revert | `sha-a6e5648` |
| Argo CD | `Synced` and `Healthy` |
| `/version` | `{"version":"sha-a6e5648"}` |

That is the behavior the design promised: one revert changed desired state,
and the pipeline politely stayed out of the way.

## Known constraints

### The bot writes directly to `main`

`gitops-update.yml` uses `GITHUB_TOKEN` with `contents: write`. This was a
deliberate v0.2 decision. If `main` later requires every change to arrive
through a PR, the current workflow will fail because its token cannot bypass
that rule by default.

There are **3 sensible next options**:

1. Keep `main` unprotected in this lab.
2. Use a GitHub App installation token with the required policy access.
3. Make `gitops-update` open a PR.

Branch-protection work remains outside v0.2.

### Image builds are serialized, not fully FIFO

With `cancel-in-progress: false`, GitHub keeps the running build and at most one
pending run per concurrency group. Given 3 fast commits, the middle pending run
may be replaced by the newest. Full FIFO queuing is not implemented in v0.2;
the trade-off is documented so nobody mistakes a concurrency guard for a
message broker wearing a YAML hat.
