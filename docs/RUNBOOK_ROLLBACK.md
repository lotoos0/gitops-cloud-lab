# Rollback Runbook

Rolling back is boring on purpose. No special tooling, no kubectl magic — just `git revert`. Argo CD does the rest.

## When to use this

You pushed a change, the pipeline ran, Argo CD synced, and now something is broken. `/version` shows the new tag but the app misbehaves. You want to go back to the previous image tag.

## Step 1 — Find the GitOps commit you want to undo

```bash
git log --oneline gitops/envs/dev/values.yaml
```

Output will look something like:

```
332180b chore: update demo-api image tag to sha-3cf5f25   ← the bad one
a1b2c3d chore: update demo-api image tag to sha-abc1234   ← the good one (target)
```

You want to revert the bad commit (`332180b` in this example).

## Step 2 — Revert it

```bash
git revert 332180b --no-edit
git push
```

This creates a new commit that undoes the `values.yaml` change. The bad image tag is gone, the previous tag is back. Full audit trail stays intact.

## Step 3 — Wait for Argo CD to sync (~3 min)

Argo CD polls Git every ~3 minutes. Once it detects the reverted `values.yaml`, it will sync the cluster back to the previous desired state — no intervention needed.

You can watch the status in the Argo CD UI or:

```bash
kubectl get pods -n demo-api -w
```

## Step 4 — Verify

```bash
curl http://<your-service-endpoint>/version
```

The response should show the previous image tag (e.g. `sha-abc1234`).

## What NOT to do

```bash
# Don't do this:
kubectl set image deployment/demo-api demo-api=ghcr.io/lotoos0/demo-api:sha-abc1234

# Or this:
helm upgrade demo-api ./deploy/helm/demo-api --set image.tag=sha-abc1234
```

Both of these bypass Git and put the cluster in a state that doesn't match `gitops/envs/dev/values.yaml`. Argo CD will immediately show `OutOfSync` and will revert your change on the next sync. Don't fight Argo CD — let Git win.
