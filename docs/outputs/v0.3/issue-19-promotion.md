# Issue #22: prod promotion — proof

`docs/runbooks/prod-promotion.md` documents the PR-based dev-to-prod promotion flow.
This is proof it was actually followed end to end, not just written down: dev was
bumped to a fresh tag first (`sha-8f1a2ee`, so the promotion PR would have a real
diff instead of a no-op — dev and prod happened to already match on the previous
tag from bootstrap testing), then that tag was promoted to prod through
[PR #30](https://github.com/lotoos0/gitops-cloud-lab/pull/30), squash-merged, no
`kubectl apply` or `helm upgrade` from a laptop anywhere in the path.

## 1. Source dev tag

```
$ yq e '.image.tag' gitops/envs/dev/values.yaml
sha-8f1a2ee
```

Confirmed `demo-api-dev` was `Synced` / `Healthy` on this tag before promoting.

## 2. The promotion diff

Exactly one line, `gitops/envs/prod/values.yaml`:

```diff
diff --git a/gitops/envs/prod/values.yaml b/gitops/envs/prod/values.yaml
index d466b86..52266f3 100644
--- a/gitops/envs/prod/values.yaml
+++ b/gitops/envs/prod/values.yaml
@@ -1,5 +1,5 @@
 image:
   repository: ghcr.io/lotoos0/demo-api
-  tag: sha-a6e5648
+  tag: sha-8f1a2ee
 env:
   APP_ENV: prod
```

## 3. PR reference and merge

- **PR:** [#30 — Promote demo-api sha-8f1a2ee to prod](https://github.com/lotoos0/gitops-cloud-lab/pull/30)
- **State:** `MERGED`, squash, branch deleted after merge

```
title:  Promote demo-api sha-8f1a2ee to prod
state:  MERGED
number: 30
url:    https://github.com/lotoos0/gitops-cloud-lab/pull/30
additions: 1
deletions: 1
```

## 4. Argo CD synced prod

Picked up on the next poll after merge, no manual `kubectl apply`:

```
$ kubectl get application demo-api-prod -n argocd
NAME            SYNC STATUS   HEALTH STATUS
demo-api-prod   Synced        Healthy
```

## 5. Prod `/version` shows the promoted tag

```
$ curl -s http://localhost:8081/version
{"service":"demo-api","version":"sha-8f1a2ee","environment":"prod","commit":"8f1a2ee0b39dc5f035fcb43cca6ba995166a884c"}
```

`environment: prod` and `version: sha-8f1a2ee` match the promoted tag exactly —
prod moved forward through a PR, and nothing else touched the cluster by hand.
