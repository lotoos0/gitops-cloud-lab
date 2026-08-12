# CoreDNS workaround for this local lab

On the network where I built this lab, pods in kind could not resolve external
hosts through the node's `/etc/resolv.conf`. `make fix-coredns` changes the
CoreDNS forward target to **2 public resolvers**, `8.8.8.8` and `8.8.4.4`, then
restarts CoreDNS.

> **Important:** this fixes a specific local-network failure, not Kubernetes in
> general. If your cluster resolves `github.com`, `ghcr.io` and `quay.io`
> already, you do not need to collect this workaround like a souvenir.

## Recognize the failure

The usual symptoms are Argo CD or workload pods stuck in `ImagePullBackOff`, or
errors such as:

```text
dial tcp: lookup github.com on 10.96.0.10:53: server misbehaving
```

In this lab the node resolver ultimately pointed at `192.168.33.1`, which
returned `SERVFAIL` for queries coming from the kind Docker network.

## Apply the fix

Run it after `make kind-create` and before installing Argo CD:

```bash
make fix-coredns
```

The script performs **6 stages**: verifies kubectl access, confirms the
namespace, reads the Corefile, patches the forward target when needed, restarts
CoreDNS and waits for the rollout.

It is safe to rerun. If the Corefile already contains
`8.8.8.8 8.8.4.4`, the configuration patch becomes a no-op; the script still
restarts the Deployment and waits for it to become ready.

## Verify

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

CoreDNS pods should be `Running`, and fresh Argo CD logs should no longer report
`server misbehaving` for external repositories.

For the original incident, manual commands and related image-pull failures, see
[the detailed kind troubleshooting guide](kind-cluster-issues.md#2-coredns-cannot-resolve-external-hosts).
