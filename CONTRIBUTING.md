# Contributing

This is my personal lab, but I still want every change to leave a clean trail.
The rule is small enough to remember without a process consultant:

```text
1 issue = 1 branch = 1 PR = 1 squash commit on main
```

> **Why I insist on this:** the chain from commit to PR to issue to acceptance
> criteria answers “why does this line exist?” without archaeology. A readable
> history is cheaper than future-me guessing. Future-me is enthusiastic, but
> not clairvoyant.

## Name the branch

Use one of these **3 prefixes**:

```text
fix/<issue-number>-short-name
feature/<issue-number>-short-name
docs/<issue-number>-short-name
```

Examples already used in this project:

```text
fix/14-limit-ci-to-demo-api-changes
fix/15-delivery-concurrency-guards
docs/16-rollback-proof
feature/18-prod-gitops-env
docs/21-fresh-machine-bootstrap
```

The issue number is the useful bit. It connects code, discussion and proof
without adding another tool to the stack.

## Work through a PR

Start from an up-to-date `main`:

```bash
git checkout main
git pull
git checkout -b fix/14-limit-ci-to-demo-api-changes

# make and verify one focused change

git add <only-the-files-you-intend-to-change>
git commit -m "fix(ci): limit CI to demo-api changes"
git push -u origin fix/14-limit-ci-to-demo-api-changes
```

Then:

1. Open a PR and link the issue.
2. Check every acceptance criterion from the issue.
3. Add real output under `docs/outputs/` when the issue asks for proof.
4. Squash-merge into `main`.
5. Delete the merged branch.

Step 2 is the gate. A green vibe is not a test result.

## Keep `main` readable

Use this squash commit format:

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

The project uses **5 commit types**:

```text
fix | feature | docs | chore | refactor
```

Useful scopes include `ci`, `delivery`, `gitops`, `argocd`, `bootstrap`,
`rollback` and `docs`. Keep the `(#issue-number)` suffix because it links the
commit text to the work item. Use `Closes #<issue-number>` in the PR description
when the merge should close that issue automatically.

## Human changes versus bot changes

Humans follow this route:

```text
branch -> PR -> squash merge -> delete branch
```

One intentional exception exists. After a successful image build,
`gitops-update.yml` uses `GITHUB_TOKEN` to commit the new dev tag directly to
`main`:

```text
image built
  -> yq changes gitops/envs/dev/values.yaml
  -> github-actions[bot] commits image.tag
  -> Argo CD syncs dev
```

The bot commit looks like:

```text
chore: update demo-api image tag to sha-xxxxxxx
```

That direct write is the dev delivery mechanism, not a shortcut. Production is
different: a human copies a verified dev tag to prod through a PR.

## The honest branch-protection note

`main` does not currently have branch protection. A person *can* push directly;
the repository simply asks them not to during normal work. I chose traceability
before enforcement for this lab, and I document that trade-off instead of
pretending the guardrail exists.

If an emergency human commit does land on `main`, keep it in history and explain
it in the relevant issue or runbook. Do not amend or force-push the evidence
away. Two mysteries do not cancel each other out.

## Definition of done

For an ordinary change:

```text
implemented
-> tested against the issue criteria
-> documented where behavior changed
-> backed by real output when proof was requested
```

For GitOps work, the expected cluster state is:

```text
Synced + Healthy
```

For a prod promotion, verify all **3 links**:

```text
gitops/envs/prod/values.yaml contains the chosen tag
-> Argo CD reports demo-api-prod Synced + Healthy
-> prod /version returns that same tag
```

## Keep each PR small

Do not bundle unrelated work such as:

```text
CI fix + documentation cleanup + prod promotion
```

If one third must be reverted, all three come along for the ride. Prefer:

```text
one problem
one issue
one PR
one proof
```

That is the whole contribution philosophy: small changes, explicit reasons and
receipts where claims would otherwise be doing all the work.
