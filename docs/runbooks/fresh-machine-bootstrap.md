# Fresh-machine bootstrap

This runbook takes a machine with no existing lab cluster to **1 kind cluster**,
**2 Argo CD Applications** and **2 running demo-api environments**. Nothing
important should be hiding in somebody's shell history — especially mine.

> **Why this exists:** “works on my machine” becomes useful only after I can
> explain how that machine got there. The bootstrap has one public entry point
> and five visible operations.

## Prerequisites

Install and make available on `PATH`:

- Docker, with the daemon running;
- kind;
- kubectl;
- Make.

The cluster also needs outbound access to GitHub and the image registries. On
the network where this lab was built, the included CoreDNS patch supplies that
missing piece.

## Fast path

From the repository root:

```bash
make bootstrap
```

That command runs these **5 targets**, in order:

```text
1. kind-create
2. fix-coredns
3. argocd-install
4. argocd-apps-apply
5. verify
```

The Makefile creates cluster `gitops-cloud-lab`, applies the DNS workaround,
installs Argo CD server-side, creates both Application resources and prints the
initial state.

## Step-by-step path

Run the same operations separately when you want to see exactly which one
complains:

```bash
make kind-create
make fix-coredns
make argocd-install
make argocd-apps-apply
make verify
```

The split path changes no behavior; it merely gives each failure its own stage
and less room to disguise itself.

## Wait for convergence

`make verify` runs immediately after the Applications are created. Argo CD may
need roughly **1 minute** before both workloads appear, and its normal Git poll
can take up to about **3 minutes**. An empty first result is therefore possible
and was observed in the recorded bootstrap proof.

Watch until both Applications report `Synced` and `Healthy`:

```bash
kubectl get applications -n argocd -w
```

Then confirm **1 pod per environment**:

```bash
kubectl get pods -n demo-api -l app=demo-api-dev
kubectl get pods -n demo-api-prod -l app=demo-api-prod
```

## Verify both endpoints

Open two terminals for the port-forwards:

```bash
kubectl port-forward svc/demo-api-dev -n demo-api 8080:80
kubectl port-forward svc/demo-api-prod -n demo-api-prod 8081:80
```

From a third terminal:

```bash
curl http://localhost:8080/version
curl http://localhost:8081/version
```

Both responses should contain the expected image tag. The first must say
`"environment":"dev"`; the second must say `"environment":"prod"`. Same
artifact is fine. Same environment label is not.

## Known local-network detour

If Argo CD or the workloads reach `ImagePullBackOff`, or logs contain
`server misbehaving`, continue with:

- [the short CoreDNS fix](../troubleshooting/coredns.md);
- [the detailed kind troubleshooting notes](../troubleshooting/kind-cluster-issues.md).

The included fix changes CoreDNS forwarding from `/etc/resolv.conf` to
`8.8.8.8 8.8.4.4`. That is a workaround for the author's network, not a new
law of Kubernetes; read the explanation before copying it into another
environment.

## Clean up

```bash
make kind-delete
```

This deletes only the kind cluster named `gitops-cloud-lab`. The repository,
GHCR images and Git history remain. The cluster is disposable; the evidence is
not.
