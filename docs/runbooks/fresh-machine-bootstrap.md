# Fresh Machine Bootstrap

Proves this repo is enough to go from nothing to a working dev + prod GitOps
setup — no steps hiding in someone's shell history.

```
fresh machine / clean cluster
    -> kind cluster
    -> CoreDNS fix
    -> Argo CD install
    -> apply dev + prod Applications
    -> verify dev
    -> verify prod
```

## Prerequisites

- Docker
- kind
- kubectl
- helm
- make

## Steps

1. Create the kind cluster:

   ```bash
   make kind-create
   ```

2. Fix CoreDNS (needed before anything tries to reach GitHub/GHCR/quay.io - see `docs/troubleshooting/coredns.md`):
   ```bash
   make fix-coredns
   ```
3. Install Argo CD:
   ```bash
   make argocd-install
   ```
4. Apply the dev and prod Argo CD Applications:
   ```bash
   make argocd-apps-apply
   ```
5. Verify everything is up:

   ```bash
   make verify
   ```

   Or all five in one shot:

   ```bash
   make bootstrap
   ```

## Manual diagnostic commands:

```bash
kubectl get pods -A
kubectl get applications -n argocd
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80 &
curl http://localhost:8080/version
```

If Argo CD components or app pods sit in `ImagePullBackOff`, see `docs/troubleshooting/kind-cluster-issues.md #1`.

## Clean-up

```bash
make kind-delete
```
