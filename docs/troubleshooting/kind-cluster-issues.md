# Troubleshooting the local kind cluster

These are **4 failures I actually hit** while running the lab, with symptoms,
root causes and repeatable fixes. This is a field notebook, not a collection of
confident guesses.

> **How to use it:** match the exact error first, then apply the narrowest fix.
> Kubernetes has enough moving parts without treating every warning as a group
> project.

## 1. `ImagePullBackOff` with a locally loaded image

### Symptom

The image is present after `kind load docker-image`, but the pod still tries the
registry and fails:

```text
Warning  Failed  kubelet  Failed to pull image "...":
  dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

### Root cause

`imagePullPolicy: Always` tells Kubernetes to contact the registry on every pod
start, even when the node already has the image. With broken external DNS, that
verification fails before the local copy can help.

The incident affected **7 Argo CD workloads** — 6 Deployments and 1 StatefulSet
— plus the demo-api chart.

### Fix

For the 6 Argo CD Deployments:

```bash
for deploy in argocd-server argocd-applicationset-controller argocd-dex-server \
              argocd-notifications-controller argocd-redis argocd-repo-server; do
  kubectl patch deployment "$deploy" -n argocd --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
done
```

For the Application controller StatefulSet:

```bash
kubectl patch statefulset argocd-application-controller -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

Dex also has an init container named `copyutil`:

```bash
kubectl patch deployment argocd-dex-server -n argocd --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

The repository's Helm default is already:

```yaml
image:
  pullPolicy: IfNotPresent
```

For this local lab, `IfNotPresent` uses the node copy and contacts the registry
only when the image is missing. Production policy is a separate decision; do
not export a lab workaround without reviewing its assumptions.

## 2. CoreDNS cannot resolve external hosts

### Symptom

Pods cannot resolve `github.com`, `quay.io` or `ghcr.io`:

```text
dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving
```

or:

```text
dial tcp: lookup quay.io on 172.23.0.1:53: server misbehaving
```

This blocks Argo CD repository access and registry pulls.

### Root cause

CoreDNS forwarded external requests through the node's `/etc/resolv.conf`. In
the recorded setup, that route ended at `192.168.33.1`, whose DNS service
returned `SERVFAIL` to requests from the kind Docker network. A firewall or
split-horizon DNS rule is the likely network-level cause.

### Preferred fix

Use the idempotent repository script:

```bash
make fix-coredns
```

It changes:

```text
forward . /etc/resolv.conf {
```

to:

```text
forward . 8.8.8.8 8.8.4.4 {
```

and restarts the CoreDNS Deployment.

### Manual fallback

If you are diagnosing the mechanism itself:

```bash
kubectl edit configmap coredns -n kube-system
kubectl rollout restart deployment/coredns -n kube-system
```

Make the same one-line `forward` change shown above. Prefer the script for
normal bootstrap because manual editor sessions make rather poor runbooks.

### Verification

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

CoreDNS should be `Running`, and new repo-server messages should stop reporting
DNS failures.

## 3. `kind load docker-image` targets the wrong cluster

### Symptom

```text
ERROR: no nodes found for cluster "kind"
```

### Root cause

Without `--name`, kind assumes the cluster is literally named `kind`. This lab
uses `gitops-cloud-lab`.

Confirm the name:

```bash
kind get clusters
# gitops-cloud-lab
```

Then pass it explicitly:

```bash
kind load docker-image <image> --name gitops-cloud-lab
```

One flag, one problem gone. Occasionally infrastructure is merciful.

## 4. A private GHCR package rejects `docker pull`

### Symptom

```text
Error response from daemon: denied: denied
```

### Root cause

The package is private and Docker has no GHCR credentials for the GitHub user.

### Fix

Pipe the existing GitHub CLI token directly into Docker login:

```bash
gh auth token | docker login ghcr.io -u <github-username> --password-stdin
```

Do not print or paste the token into the terminal history. After login:

```bash
docker pull ghcr.io/<user>/demo-api:<tag>
kind load docker-image ghcr.io/<user>/demo-api:<tag> --name gitops-cloud-lab
```

If the package is meant to be public, fixing its visibility may be cleaner than
teaching every fresh machine a secret handshake.
