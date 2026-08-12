# Issue #22 proof: a real production promotion

This is the receipt for the PR-based dev-to-prod flow. I first moved dev to
`sha-8f1a2ee`, then promoted that exact artifact through
[PR #30](https://github.com/lotoos0/gitops-cloud-lab/pull/30). The extra dev
change was necessary because bootstrap testing had left dev and prod on the
same earlier tag; promoting it again would have proved only that Git accepts an
empty diff. Charming, but not useful.

> **What this proves:** **1 source tag**, **1 changed values line**, **1 merged
> PR**, **1 healthy prod Application** and **1 matching runtime response**. It
> used **0** laptop-side `kubectl apply` or `helm upgrade` commands.

## 1. Source tag from healthy dev

```text
$ yq e '.image.tag' gitops/envs/dev/values.yaml
sha-8f1a2ee
```

Before promotion, `demo-api-dev` reported `Synced` and `Healthy` on this tag.

## 2. The complete promotion diff

Exactly **1 line** changed in `gitops/envs/prod/values.yaml`: **1 deletion** and
**1 addition**.

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

Repository, environment and chart configuration stayed unchanged. The
promotion moved the artifact reference and kept its hands to itself.

## 3. PR and merge evidence

- **PR:** [#30 — Promote demo-api sha-8f1a2ee to prod](https://github.com/lotoos0/gitops-cloud-lab/pull/30)
- **Result:** squash-merged; source branch deleted

```text
title:  Promote demo-api sha-8f1a2ee to prod
state:  MERGED
number: 30
url:    https://github.com/lotoos0/gitops-cloud-lab/pull/30
additions: 1
deletions: 1
```

## 4. Argo CD reconciliation evidence

Argo CD picked up the merged desired state without a manual deployment:

```text
$ kubectl get application demo-api-prod -n argocd
NAME            SYNC STATUS   HEALTH STATUS
demo-api-prod   Synced        Healthy
```

## 5. Runtime evidence

```text
$ curl -s http://localhost:8081/version
{"service":"demo-api","version":"sha-8f1a2ee","environment":"prod","commit":"8f1a2ee0b39dc5f035fcb43cca6ba995166a884c"}
```

The three identifiers line up: desired tag `sha-8f1a2ee`, runtime version
`sha-8f1a2ee`, and full commit beginning `8f1a2ee`. The response also says
`prod`, so this is the production deployment—not dev wearing a fake moustache.
