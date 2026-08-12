# Rollback runbook

Rollback is boring on purpose: create **1 revert commit**, push it, let Argo CD
restore the previous desired state. No cluster-side improvisation required.

> **My rule here:** Git caused the deployment, so Git records the recovery.
> That keeps the audit trail complete and prevents Argo CD from undoing a
> well-meant manual fix five minutes later.

## Use this when

The new tag is deployed and Argo CD is healthy, but the application behavior is
not. `/version` confirms the new image, and you need the previously declared
tag back.

If no new tag reached Git or the cluster, diagnose the delivery stage instead;
there may be nothing to roll back.

## 1. Find the bad GitOps commit

For dev:

```bash
git log --oneline gitops/envs/dev/values.yaml
```

Example:

```text
332180b chore: update demo-api image tag to sha-3cf5f25   # bad
a1b2c3d chore: update demo-api image tag to sha-abc1234   # previous good state
```

The commit to revert is `332180b`: the one that introduced the bad tag.

For prod, inspect `gitops/envs/prod/values.yaml` instead.

## 2. Revert and push

```bash
git revert 332180b --no-edit
git push
```

This does not erase history. It adds a new commit that reverses the old values
change, which is exactly the receipt an incident deserves.

## 3. Wait for reconciliation

Argo CD polls Git about every **3 minutes**. Watch the relevant Application and
pod:

```bash
kubectl get application demo-api-dev -n argocd -w
kubectl get pods -n demo-api -l app=demo-api-dev -w
```

For prod, use Application `demo-api-prod`, namespace `demo-api-prod` and label
`app=demo-api-prod`.

## 4. Verify all 3 signals

For dev:

```bash
yq e '.image.tag' gitops/envs/dev/values.yaml
kubectl get application demo-api-dev -n argocd
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
curl http://localhost:8080/version
```

You are done when:

1. Git contains the previous tag.
2. Argo CD reports `Synced` and `Healthy`.
3. `/version` returns that same previous tag.

## Do not bypass Git

Avoid these tempting commands:

```bash
kubectl set image deployment/demo-api-dev \
  demo-api=ghcr.io/lotoos0/demo-api:sha-abc1234

helm upgrade demo-api ./deploy/helm/demo-api \
  --set image.tag=sha-abc1234
```

Both create cluster state that disagrees with the repository. With self-healing
enabled, Argo CD will eventually restore the Git version anyway. Do not fight
the robot whose documented job is to win that argument.
