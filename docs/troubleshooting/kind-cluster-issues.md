# Troubleshooting — kind cluster issues

Problems encountered while running this lab on a local kind cluster.
Each entry has a root cause and a fix, in case they show up again.

---

## 1. ImagePullBackOff — `imagePullPolicy: Always` in a cluster without internet access

### Symptom

Pods stuck in `ImagePullBackOff` even though the image was already loaded into the cluster via `kind load docker-image`.

```
Events:
  Warning  Failed  kubelet  Failed to pull image "...":
    dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

### Root cause

`imagePullPolicy: Always` tells Kubernetes to contact the remote registry on every pod start to verify the image digest — even when a local copy is present. In a kind cluster without reliable external DNS, the registry lookup fails.

This affected:
- All Argo CD components (`quay.io/argoproj/argocd:v3.4.4`, `ghcr.io/dexidp/dex`, `public.ecr.aws/.../redis`)
- The demo-api Helm chart (default `pullPolicy: Always` in `deploy/helm/demo-api/values.yaml`)

### Fix

**For Argo CD components** — patch each deployment and the StatefulSet in-place:

```bash
for deploy in argocd-server argocd-applicationset-controller argocd-dex-server \
              argocd-notifications-controller argocd-redis argocd-repo-server; do
  kubectl patch deployment $deploy -n argocd --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
done

kubectl patch statefulset argocd-application-controller -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

`argocd-dex-server` also has an init container (`copyutil`) that needs the same patch:

```bash
kubectl patch deployment argocd-dex-server -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

**For demo-api** — change the Helm chart default in `deploy/helm/demo-api/values.yaml`:

```yaml
image:
  pullPolicy: IfNotPresent  # was: Always
```

Commit and push. Argo CD will roll out the change automatically.

### Why `IfNotPresent` is the right default for a kind lab

`Always` makes sense in production where you want to guarantee the image matches the current registry state. In a local kind cluster, images are loaded manually via `kind load docker-image` and the cluster may have no internet access. `IfNotPresent` uses the local copy if it exists and only pulls when it's missing.

---

## 2. CoreDNS — external DNS resolution fails inside the cluster

### Symptom

Pods can't resolve external hostnames (`github.com`, `quay.io`, `ghcr.io`). The error appears in pod logs as:

```
dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving
```

or in kubelet events as:

```
dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

This blocked:
- Argo CD `repo-server` from fetching the GitHub repository
- Kubernetes from pulling images (before `IfNotPresent` was set)

### Root cause

CoreDNS by default forwards external DNS queries to `/etc/resolv.conf` on the node, which in this setup pointed to the local router (`192.168.33.1`). The router returned `SERVFAIL` for external domain queries from the kind cluster's Docker network — likely a firewall or a split-horizon DNS issue on the local network.

### Fix

Patch the CoreDNS `ConfigMap` to forward external queries to a public DNS server instead of the local router:

```bash
kubectl edit configmap coredns -n kube-system
```

Change the `forward` line from:

```
forward . /etc/resolv.conf {
```

to:

```
forward . 8.8.8.8 8.8.4.4 {
```

Then restart CoreDNS to pick up the change:

```bash
kubectl rollout restart deployment/coredns -n kube-system
```

### Verification

After the restart, check that Argo CD `repo-server` logs no longer show `server misbehaving` and start showing `manifest cache hit` entries.

---

## 3. `kind load docker-image` — wrong cluster name

### Symptom

```
ERROR: no nodes found for cluster "kind"
```

### Root cause

`kind load docker-image` defaults to a cluster named `kind`. If the cluster was created with a custom name, the command needs an explicit `--name` flag.

```bash
kind get clusters
# gitops-cloud-lab
```

### Fix

Always pass `--name` when the cluster is not named `kind`:

```bash
kind load docker-image <image> --name gitops-cloud-lab
```

---

## 4. GHCR private packages — `docker pull` requires authentication

### Symptom

```
Error response from daemon: denied: denied
```

When trying to pull `ghcr.io/<user>/demo-api:<tag>` without being logged in.

### Fix

Use the GitHub CLI token to authenticate:

```bash
gh auth token | docker login ghcr.io -u <github-username> --password-stdin
```

After logging in, `docker pull` works. Then load the image into kind:

```bash
docker pull ghcr.io/<user>/demo-api:<tag>
kind load docker-image ghcr.io/<user>/demo-api:<tag> --name gitops-cloud-lab
```
