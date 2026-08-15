# Troubleshooting

Start with the exact symptom, then apply the narrowest fix. Kubernetes has
enough moving parts without debugging by horoscope.

## First checks

```bash
kubectl get applications -n argocd
kubectl get pods -A
```

If the problem is not obvious, check recent events:

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

## Workflow chain stops

| Problem | Cause / next check |
| --- | --- |
| image build never starts | inspect `CI`; all 4 tests must pass |
| GitOps update never starts | inspect `Build and push image`; GHCR push must succeed |
| dev tag does not change | inspect `GitOps update` for write or `yq` errors |
| rollback starts no workflows | expected: values changes do not match `apps/demo-api/**` |

## Argo CD is not healthy

**Problem:** `OutOfSync` means Git has not been applied; `Degraded` means the
desired workload exists but is unhealthy.

**Cause:** Git polling can take about **3 minutes**. Longer failures usually
mean repository access, image pull or application health problems.

**Fix:** inspect the Application and workload:

```bash
kubectl describe application demo-api-dev -n argocd
kubectl get pods -n demo-api
kubectl describe pod <pod-name> -n demo-api
kubectl logs <pod-name> -n demo-api
```

If the Application reports a repository access error, inspect repo-server:

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

**Verify:** `kubectl get application demo-api-dev -n argocd` reports `Synced`
and `Healthy`, and the pod is `Running`. For prod, replace names with
`demo-api-prod`.

## External DNS fails

**Problem:** Argo CD cannot read GitHub or pods cannot pull images:

```text
dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving
```

**Cause:** on the network used for this lab, the kind node's resolver returned
`SERVFAIL` for Docker-network requests.

**Fix:** run `make fix-coredns`. The script switches CoreDNS to **2 public
resolvers**, `8.8.8.8` and `8.8.4.4`, then restarts it. This is a local
workaround, not a universal Kubernetes setting.

**Verify:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

CoreDNS should be `Running`, with no new resolver errors.

## Pod is `ImagePullBackOff`

**Problem:** read the exact pull error with
`kubectl describe pod <pod-name> -n <namespace>`.

**Cause and fix:**

- `server misbehaving`: apply the CoreDNS fix above.
- `denied`: confirm the GHCR package is public and the requested image tag
  exists.

- local image ignored: confirm `imagePullPolicy: IfNotPresent`, then run:

  ```bash
  kind load docker-image <image> --name gitops-cloud-lab
  ```

**Verify:** the affected pod reaches `Running`.

## kind targets the wrong cluster

**Problem:** `ERROR: no nodes found for cluster "kind"`.

**Cause:** without `--name`, kind assumes the cluster is named `kind`.

**Fix and verify:**

```bash
kind get clusters
kind load docker-image <image> --name gitops-cloud-lab
```
