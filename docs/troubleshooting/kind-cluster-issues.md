# Troubleshooting — kind cluster issues

Real problems I ran into while setting up this lab on a local kind cluster.
Every entry has the root cause and a fix — written down so I don't spend
another hour staring at the same error six months from now.

---

## 1. ImagePullBackOff — `imagePullPolicy: Always` in a cluster without internet

### Symptom

Pods stuck in `ImagePullBackOff` even though the image was already loaded
into the cluster via `kind load docker-image`. Kubernetes somehow managed to
forget that the image is sitting right there.

```
Events:
  Warning  Failed  kubelet  Failed to pull image "...":
    dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

### Root cause

`imagePullPolicy: Always` tells Kubernetes to hit the remote registry on
every pod start to verify the digest — even when a perfectly good local copy
is sitting in the node cache. In a kind cluster with no reliable external DNS,
that registry lookup blows up.

This hit **7 components** at once:
- 6 Argo CD deployments (`argocd-server`, `argocd-applicationset-controller`,
  `argocd-dex-server`, `argocd-notifications-controller`, `argocd-redis`,
  `argocd-repo-server`) — all pulling from `quay.io/argoproj/argocd:v3.4.4`,
  `ghcr.io/dexidp/dex`, and `public.ecr.aws/.../redis`
- 1 Argo CD StatefulSet (`argocd-application-controller`)
- The demo-api Helm chart (default `pullPolicy: Always` in
  `deploy/helm/demo-api/values.yaml`)

### Fix

**Argo CD components** — patch all 6 deployments and the StatefulSet in one
loop, then handle the init container separately:

```bash
for deploy in argocd-server argocd-applicationset-controller argocd-dex-server \
              argocd-notifications-controller argocd-redis argocd-repo-server; do
  kubectl patch deployment $deploy -n argocd --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
done

kubectl patch statefulset argocd-application-controller -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

`argocd-dex-server` also has an init container (`copyutil`) that needs the
same treatment — it's a separate patch path:

```bash
kubectl patch deployment argocd-dex-server -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

**demo-api Helm chart** — 1-line change in `deploy/helm/demo-api/values.yaml`:

```yaml
image:
  pullPolicy: IfNotPresent  # was: Always
```

Commit and push — Argo CD picks it up and rolls out the change automatically.
No manual kubectl apply needed.

### Why `IfNotPresent` is right here and `Always` isn't

`Always` makes sense in production where you want a hard guarantee that
the running image matches the current registry state. In a local kind cluster,
images are loaded manually and the cluster may have no internet access at all.
`IfNotPresent` uses the local copy when it's there and only pulls when it's
genuinely missing. That's exactly the behaviour you want in a lab.

---

## 2. CoreDNS — external DNS resolution dies inside the cluster

### Symptom

Pods can't resolve external hostnames (`github.com`, `quay.io`, `ghcr.io`).
Shows up in pod logs as:

```
dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving
```

or in kubelet events as:

```
dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

This blocked **2 things** simultaneously:
- Argo CD `repo-server` from fetching the GitHub repository at all
- Kubernetes from pulling images (before the `IfNotPresent` fix above)

### Root cause

CoreDNS by default forwards external queries to `/etc/resolv.conf` on the
node — which here pointed to my local router at `192.168.33.1`. The router
returned `SERVFAIL` for any query coming from the kind cluster's Docker
network. Probably a firewall rule or split-horizon DNS on the local network.
Either way, the cluster couldn't see outside.

### Fix

Patch the CoreDNS `ConfigMap` to route external queries to Google's public DNS
instead of the local router — **1 line changed** in the config:

```bash
kubectl edit configmap coredns -n kube-system
```

Change:

```
forward . /etc/resolv.conf {
```

to:

```
forward . 8.8.8.8 8.8.4.4 {
```

Then restart CoreDNS so the change takes effect:

```bash
kubectl rollout restart deployment/coredns -n kube-system
```

### Verification

After the restart, check that Argo CD `repo-server` logs stop showing
`server misbehaving` and start showing `manifest cache hit` entries instead.
If you see cache hits, DNS is working.

---

## 3. `kind load docker-image` — wrong cluster name

### Symptom

```
ERROR: no nodes found for cluster "kind"
```

### Root cause

`kind load docker-image` defaults to a cluster named `kind`. This cluster
was created with a custom name, so the default falls flat:

```bash
kind get clusters
# gitops-cloud-lab
```

### Fix

Always pass `--name` explicitly when the cluster isn't named `kind`:

```bash
kind load docker-image <image> --name gitops-cloud-lab
```

That's it. No magic — just a missing flag.

---

## 4. GHCR private packages — `docker pull` needs authentication

### Symptom

```
Error response from daemon: denied: denied
```

When trying to pull `ghcr.io/<user>/demo-api:<tag>` without being logged in.

### Fix

Use the GitHub CLI token to authenticate Docker in one command:

```bash
gh auth token | docker login ghcr.io -u <github-username> --password-stdin
```

After that, pull the image and load it into kind:

```bash
docker pull ghcr.io/<user>/demo-api:<tag>
kind load docker-image ghcr.io/<user>/demo-api:<tag> --name gitops-cloud-lab
```
