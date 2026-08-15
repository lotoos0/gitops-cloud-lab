# Runbook

This runbook covers the **4 routine operations**: bootstrap, dev delivery, prod
promotion and rollback. Git records every deployment decision; `kubectl` is for
verification, not for bypassing Argo CD.

## Bootstrap

Install Docker, kind, kubectl and Make. Docker must be running, and the cluster
needs outbound access to GitHub and the image registries.

```bash
make bootstrap
```

The target runs **5 operations**: create cluster, patch CoreDNS, install Argo
CD, apply both Applications and print their initial state. Run them separately
to isolate a failure:

```bash
make kind-create
make fix-coredns
make argocd-install
make argocd-apps-apply
make verify
```

Argo CD may need about **1 minute** to create workloads and up to **3 minutes**
for a Git poll. Wait for both Applications, then confirm one pod per namespace:

```bash
kubectl get applications -n argocd -w
kubectl get pods -n demo-api -l app=demo-api-dev
kubectl get pods -n demo-api-prod -l app=demo-api-prod
```

Both Applications must report `Synced` and `Healthy`. Verify the endpoints by
running each port-forward in its own terminal:

```bash
# terminal 1
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
# terminal 2
kubectl port-forward svc/demo-api-prod -n demo-api-prod 8081:80
# terminal 3
curl http://localhost:8080/version
curl http://localhost:8081/version
```

The responses must contain the expected tag and the matching `dev` or `prod`
environment.

## Deploy to dev

Push a change under `apps/demo-api/**` to `main`. The pipeline publishes
`demo-api:sha-xxxxxxx` and commits the tag to dev values. Allow about **3–5
minutes**, then check Git, Argo CD and runtime:

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
kubectl get application demo-api-dev -n argocd
kubectl get pods -n demo-api -l app=demo-api-dev
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
```

From another terminal:

```bash
curl http://localhost:8080/version
```

The desired tag and `/version` must match, and the Application must be `Synced`
and `Healthy`. If the chain stops, use [Troubleshooting](TROUBLESHOOTING.md).

## Promote to prod

Production receives the image already verified in dev; it does not rebuild it.
Read the tag and confirm dev is healthy using the checks above:

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
kubectl get application demo-api-dev -n argocd
```

Create a focused branch:

```bash
git checkout main
git pull
git checkout -b feature/<issue-number>-promote-sha-xxxxxxx-to-prod
```

Copy the verified tag to `gitops/envs/prod/values.yaml`. The change should
contain only **1 deletion and 1 addition** on `image.tag`. Commit and push it:

```bash
git add gitops/envs/prod/values.yaml
git commit -m "chore: promote demo-api sha-xxxxxxx to prod"
git push -u origin feature/<issue-number>-promote-sha-xxxxxxx-to-prod
```

**Open a PR, verify that only the prod `image.tag` changed, then squash-merge
it.**

Wait for reconciliation and verify production:

```bash
kubectl get application demo-api-prod -n argocd -w
kubectl port-forward svc/demo-api-prod -n demo-api-prod 8081:80
```

From another terminal:

```bash
curl http://localhost:8081/version
```

Promotion succeeds when **3 signals** agree: the prod values tag, healthy Argo
CD status and the prod `/version` response.

## Roll back

Find the commit that introduced the bad desired tag. For a prod rollback,
inspect `gitops/envs/prod/values.yaml` instead.

```bash
git log --oneline gitops/envs/dev/values.yaml
```

Revert it and push the new commit:

```bash
git revert <bad-gitops-commit> --no-edit
git push
```

A values-only revert starts **0 new CI runs**. Argo CD restores the previous
image through the normal reconciliation path. Repeat the Git, Application and
`/version` checks from the relevant environment above.

Do not use `kubectl set image` or laptop-side `helm upgrade`. Those commands
create drift, and self-healing will restore the Git version anyway. The robot is
quite stubborn because that is literally its job.

## Clean up

```bash
make kind-delete
```

This removes only the `gitops-cloud-lab` kind cluster. Git history and GHCR
images remain available.
