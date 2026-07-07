# Contributing

This is a personal lab repo, so there's no team to impress — but I still want a clean, traceable history. After 16+ issues and 2 versions shipped, the pattern that worked is simple: one issue, one branch, one PR, one squash commit.

No Jira. No release trains. No ceremonies.

## Basic rule

```text
1 issue = 1 branch = 1 PR = 1 squash commit on main
```

This makes it trivial to answer "why does this line exist?" — you follow the commit to the PR, the PR to the issue, the issue to the PASS criteria. The whole story is there.

## Branch naming

3 prefixes cover everything this project does:

```text
fix/<issue-number>-short-name
feature/<issue-number>-short-name
docs/<issue-number>-short-name
```

Real examples from this repo:

```text
fix/14-limit-ci-to-demo-api-changes
fix/15-delivery-concurrency-guards
docs/16-rollback-proof
feature/18-prod-gitops-env
docs/21-fresh-machine-bootstrap
```

The issue number in the branch name is the single most useful piece of information — it ties everything together without any extra tooling.

## PR flow

```bash
git checkout main
git pull

git checkout -b fix/14-limit-ci-to-demo-api-changes

# make changes

git add .
git commit -m "fix(ci): limit CI to demo-api changes"

git push -u origin fix/14-limit-ci-to-demo-api-changes
```

Then:

1. Open a PR.
2. Link the issue.
3. Verify the PASS criteria from the issue.
4. Squash merge into `main`.
5. Delete the branch.

Step 3 is the one that actually matters. If the PASS criteria aren't met, the PR doesn't merge — no exceptions.

## Merge strategy

**Squash merge. Always.**

Every issue gets exactly 1 clean commit on `main`. The messy WIP commits stay in the PR and disappear after merge. `git log` on `main` should read like a changelog, not a therapy session.

## Squash commit format

```text
type(scope): short description (#issue-number)
```

Real examples:

```text
fix(ci): limit CI to demo-api changes (#14)
fix(delivery): add workflow concurrency guards (#15)
docs(rollback): document v0.2 rollback proof (#16)
feature(gitops): add prod environment (#18)
docs(bootstrap): add fresh machine bootstrap runbook (#21)
```

Types used in this project:

```text
fix
feature
docs
chore
refactor
```

Scopes that make sense here:

```text
ci
delivery
gitops
argocd
bootstrap
rollback
docs
```

The `(#issue-number)` at the end is what GitHub uses to auto-close the issue on merge. Don't skip it.

## Main branch

Don't push directly to `main` during normal work. The flow is:

```text
branch -> PR -> squash merge -> delete branch
```

Honest caveat:

```text
main does not have branch protection yet.
```

So nothing technically stops a direct push. I'm choosing not to do it anyway — the PR flow exists for traceability, not bureaucracy. A history full of raw direct commits is harder to read and impossible to revert cleanly.

## GitOps bot exception

`gitops-update.yml` is allowed to push directly to `main`. This is intentional.

That commit comes from `github-actions[bot]` via `GITHUB_TOKEN` and is part of the automated delivery loop:

```text
image built
-> yq updates gitops/envs/dev/values.yaml
-> bot commits image.tag change to main
-> Argo CD syncs the new desired state
```

Bot commits look like this:

```text
chore: update demo-api image tag to sha-xxxxxxx
```

This is not a violation of the PR flow — it's the GitOps mechanism working as designed. Dev is supposed to be automatic. Prod is not.

## Direct human commits

Occasionally one happens — usually during debugging or a quick emergency fix. That's fine, it's a lab.

When it does happen: leave the commit in history and drop a note in the relevant issue or runbook explaining why. Don't clean it up by amending or force-pushing — that's worse than the original sin.

Just don't make it the default.

## Before opening a PR

Check the issue PASS criteria. All of them.

For GitOps changes, the expected end state after merge is:

```text
Synced + Healthy
```

For promotion changes, the full verification chain is:

```text
gitops/envs/prod/values.yaml
-> Argo CD prod sync
-> prod /version returns the promoted tag
```

If it's not there yet, the PR isn't ready.

## What not to include in PRs

Don't mix unrelated work. Combining things like:

```text
CI fix + docs cleanup + prod promotion
```

...makes the commit history useless and rollbacks painful. If 1 of those 3 things needs to be reverted, you're reverting all 3.

Small slices:

```text
one problem
one issue
one PR
one proof
```

## Project style

This repo values proof over theory. Saying "it should work" isn't done. Done means:

```text
implemented
documented if needed
tested against PASS criteria
proved with real output when the issue asks for proof
```

If an issue asks for a screenshot or a terminal output in `docs/outputs/`, it goes in `docs/outputs/`. That's the receipt.
