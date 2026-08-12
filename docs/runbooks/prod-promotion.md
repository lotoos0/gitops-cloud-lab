# Prod Promotion Runbook

Prod never deploys automatically. A human picks a dev tag and opens a PR —
that PR is the deploy.

```
dev image tag
  -> prod values PR
  -> merge
  -> Argo CD syncs prod
  -> prod /version shows the promoted tag
```

## 1. Read the current dev tag

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
```

## 2. Pick the tag to promote

Usually the current dev tag — the one that's been running long enough to
trust. Confirm dev is `Synced + Healthy` first:

```bash
kubectl get application demo-api-dev -n argocd
```

## 3. Create a promotion branch

```bash
git checkout main && git pull
git checkout -b issue-19-promote-sha-xxxxxxx-to-prod
```

## 4. Update prod values

Edit `gitops/envs/prod/values.yaml`, set `image.tag` to the tag from step 1.

## 5. Commit

```bash
git add gitops/envs/prod/values.yaml
git commit -m "chore: promote demo-api sha-xxxxxxx to prod"
git push -u origin issue-19-promote-sha-xxxxxxx-to-prod
```

## 6. Open a PR

```bash
gh pr create --title "Promote demo-api sha-xxxxxxx to prod" --body "..."
```

## 7. Review the diff

```bash
gh pr diff
```

It should touch exactly one line: `image.tag` in `gitops/envs/prod/values.yaml`.
If it touches anything else, stop and figure out why before merging.

## 8. Squash merge

```bash
gh pr merge --squash
```

**Known constraint:** `main` has no branch protection. Nothing stops a direct
push that skips the PR. The PR is a discipline, not an enforced gate — treat
it as one anyway.

## 9. Verify Argo CD synced prod

Argo CD polls Git every ~3 minutes:

```bash
kubectl get application demo-api-prod -n argocd -w
```

## 10. Verify prod `/version`

```bash
kubectl port-forward svc/demo-api-prod -n demo-api-prod 8081:80
curl http://localhost:8081/version
```

Should return the promoted tag.

## Rollback

Same pattern as dev rollback (`docs/RUNBOOK_ROLLBACK.md`), just on the prod
values file:

```bash
git log --oneline gitops/envs/prod/values.yaml
git revert <bad-commit> --no-edit
git push
```

Argo CD syncs prod back to the previous tag automatically. No `kubectl apply`,
no `helm upgrade` from a laptop — Git is the only lever.
