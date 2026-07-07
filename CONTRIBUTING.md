# Contributing

This repo uses a small, practical Git flow.

No heavy process. No long-lived branches. One issue, one branch, one PR.

## Basic rule

```text
1 issue = 1 branch = 1 PR = 1 squash commit on main
```

Work should be easy to trace from issue → PR → final commit.

## Branch naming

Use one of these prefixes:

```text
fix/<issue-number>-short-name
feature/<issue-number>-short-name
docs/<issue-number>-short-name
```

Examples:

```text
fix/14-limit-ci-to-demo-api-changes
fix/15-delivery-concurrency-guards
docs/16-rollback-proof
feature/18-prod-gitops-env
docs/21-fresh-machine-bootstrap
```

Keep branch names short and readable.

## PR flow

Normal flow:

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

## Merge strategy

Use **squash merge**.

There should be one clean commit on `main` per issue.

## Squash commit format

Use this format:

```text
type(scope): short description (#issue-number)
```

Examples:

```text
fix(ci): limit CI to demo-api changes (#14)
fix(delivery): add workflow concurrency guards (#15)
docs(rollback): document v0.2 rollback proof (#16)
feature(gitops): add prod environment (#18)
docs(bootstrap): add fresh machine bootstrap runbook (#21)
```

Common types:

```text
fix
feature
docs
chore
refactor
```

Use a scope that explains the area:

```text
ci
delivery
gitops
argocd
bootstrap
rollback
docs
```

## Main branch

Do not push directly to `main` during normal work.

Use:

```text
branch -> PR -> squash merge -> delete branch
```

Known constraint:

```text
main does not have branch protection yet.
```

So this flow is a project convention, not a technical enforcement.

Follow it anyway.

## GitOps bot exception

The `gitops-update.yml` workflow is allowed to push directly to `main`.

That commit is created by `github-actions[bot]` using `GITHUB_TOKEN`.

This is part of the GitOps delivery mechanism:

```text
image built
-> yq updates gitops/envs/dev/values.yaml
-> bot commits image.tag change to main
-> Argo CD syncs the new desired state
```

Bot commits are not a violation of the PR flow.

Expected bot commit style:

```text
chore: update demo-api image tag to sha-xxxxxxx
```

## Direct human commits

Human direct commits to `main` are not the normal workflow.

If one happens during debugging or emergency cleanup, leave the commit in history and document the reason in the relevant issue or runbook.

Do not make it the default pattern.

## Before opening a PR

Check the issue PASS criteria.

For code changes, run the relevant local checks when possible.

For GitOps changes, verify the expected Argo CD state after merge:

```text
Synced + Healthy
```

For promotion changes, verify the promoted image tag:

```text
gitops/envs/prod/values.yaml
-> Argo CD prod sync
-> prod /version returns the promoted tag
```

## What not to include in PRs

Avoid mixing unrelated work.

Do not combine:

```text
CI fix + docs cleanup + prod promotion
```

Prefer small slices:

```text
one problem
one issue
one PR
one proof
```

## Project style

This repo values proof over theory.

A change is done when it is:

```text
implemented
documented if needed
tested against PASS criteria
proved with real output when the issue asks for proof
```
