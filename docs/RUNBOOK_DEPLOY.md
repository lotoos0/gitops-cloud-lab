# Deploy Runbook

There is no deploy button. The deployment happens automatically when you push code. This runbook explains what's actually happening under the hood and what to do if something gets stuck.

## The automatic flow (happy path)

```
git push to main
  ↓
CI (GitHub Actions: ci.yml)
  — runs pytest, 4 tests
  — if tests fail: pipeline stops, nothing gets deployed
  ↓
Build and push image (image-build.yml)
  — triggered by CI success via workflow_run
  — builds Docker image from apps/demo-api/
  — pushes to ghcr.io/lotoos0/demo-api:sha-<7-char-SHA>
  ↓
GitOps update (gitops-update.yml)
  — triggered by image-build success
  — yq writes new image.tag to gitops/envs/dev/values.yaml
  — commits: "chore: update demo-api image tag to sha-xxxx"
  — pushes to main
  ↓
Argo CD (in kind cluster)
  — polls Git every ~3 minutes
  — detects values.yaml change
  — runs helm upgrade with new image tag
  — deployment rolls out new pods
  ↓
curl /version → returns new tag ✅
```

Total time from `git push` to `/version` returning the new tag: **~3–5 minutes**.

## Bootstrap (first time only)

These steps are needed once to get the cluster and Argo CD running. After that, all deployments are automatic.

```bash
# 1. Create the kind cluster
make cluster-up

# 2. Install Argo CD
make argocd-install

# 3. Wait for Argo CD to be ready (~2 min)
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

# 4. Apply the Argo CD Application manifest
kubectl apply -f gitops/apps/demo-api-application.yaml

# 5. Get the initial Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Check deployment status

```bash
# Argo CD app status
kubectl get applications -n argocd

# Pods
kubectl get pods -n demo-api

# Logs
kubectl logs -l app=demo-api -n demo-api
```

## If the pipeline gets stuck

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| image-build not triggered | CI failed | Check ci.yml run, fix the test |
| gitops-update not triggered | image-build failed | Check image-build run logs |
| Argo CD shows OutOfSync | values.yaml drifted from cluster | Let Argo CD auto-sync, or click Sync in UI |
| Argo CD shows Degraded | Pod crashing | Check `kubectl logs`, likely app issue |
