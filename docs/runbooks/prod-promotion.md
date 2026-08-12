# Production promotion

Production does not build a second image and does not follow dev automatically.
A human selects an image already proven in dev, changes **1 line** in prod
values and ships that decision through **1 PR**. The PR is the deploy gate.

> **Why I designed it this way:** dev should be quick; prod should be
> deliberate. Promoting the same immutable `sha-xxxxxxx` artifact separates
> “is this image valid?” from “are we ready to run it in prod?”

## Before you start

You need:

- an up-to-date local `main`;
- `yq` to read values;
- `kubectl` access to the local cluster;
- GitHub CLI access if you use the example `gh` commands;
- an issue number for the promotion trail.

## 1. Read and verify the dev tag

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
kubectl get application demo-api-dev -n argocd
```

Record the exact tag, for example `sha-8f1a2ee`. Continue only when dev reports
`Synced` and `Healthy` and `/version` returns that tag:

```bash
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
curl http://localhost:8080/version
```

## 2. Create a focused branch

Replace the placeholders with the real issue and tag:

```bash
git checkout main
git pull
git checkout -b feature/<issue-number>-promote-sha-xxxxxxx-to-prod
```

## 3. Change exactly one field

In `gitops/envs/prod/values.yaml`, set `image.tag` to the verified dev tag. Then
inspect the scoped diff:

```bash
git diff -- gitops/envs/prod/values.yaml
```

Expected change: **1 deletion and 1 addition** on the `tag:` line. If the diff
contains a repository name, environment label or another file, stop. A
promotion should move one artifact reference, not redecorate the building.

## 4. Commit and open the PR

```bash
git add gitops/envs/prod/values.yaml
git commit -m "chore: promote demo-api sha-xxxxxxx to prod"
git push -u origin feature/<issue-number>-promote-sha-xxxxxxx-to-prod
gh pr create \
  --title "Promote demo-api sha-xxxxxxx to prod" \
  --body "Promotes the dev-verified tag to prod. Closes #<issue-number>."
```

Review the final patch:

```bash
gh pr diff
```

The PR should contain the same **1-line values change** you already inspected.

## 5. Squash-merge

After review and checks:

```bash
gh pr merge --squash --delete-branch
```

Honest constraint: `main` currently has no branch protection. The PR is a
documented human control, not an enforced platform control. I still use it
because an unenforced audit trail is more useful than no audit trail at all.

## 6. Verify production

Argo CD usually detects the merged change within about **3 minutes**:

```bash
kubectl get application demo-api-prod -n argocd -w
```

When it reports `Synced` and `Healthy`, check the deployed metadata:

```bash
kubectl port-forward svc/demo-api-prod -n demo-api-prod 8081:80
curl http://localhost:8081/version
```

The proof has **3 matching values**:

1. `gitops/envs/prod/values.yaml` contains the selected tag.
2. Argo CD reports the prod Application healthy and synced.
3. Prod `/version` returns that tag with `"environment":"prod"`.

## Roll back a bad promotion

Find and revert the promotion commit:

```bash
git log --oneline gitops/envs/prod/values.yaml
git revert <bad-promotion-commit> --no-edit
git push
```

Argo CD reconciles the previous prod tag. Do not use laptop-side `kubectl
apply`, `kubectl set image` or `helm upgrade`; those commands bypass the Git
decision and invite self-healing to reverse your emergency fix.

For the complete verification pattern, see the [rollback runbook](../RUNBOOK_ROLLBACK.md).
