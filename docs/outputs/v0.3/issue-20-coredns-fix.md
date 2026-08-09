# Issue #23: CoreDNS fix automation — proof

`infra/local/scripts/fix-coredns.sh` (wired up via `make fix-coredns`) replaces the manual
`kubectl edit configmap coredns` from `docs/troubleshooting/kind-cluster-issues.md` (section 2).
To prove it actually works, the cluster was put back into the broken state on purpose
(`forward . /etc/resolv.conf {`) before running the script twice.

## Run 1 — fixes a broken cluster

First run against the deliberately broken Corefile: it detects the stale `/etc/resolv.conf`
forward target, patches the ConfigMap, and rolls CoreDNS out successfully.

```
./infra/local/scripts/fix-coredns.sh
==> Checking kubectl connectivity...
==> Checking namespace kube-system exists...
==> Reading current CoreDNS Corefile...
==> Patching forward target: /etc/resolv.conf -> 8.8.8.8 8.8.4.4
configmap/coredns configured
==> Restarting CoreDNS to pick up the change...
deployment.apps/coredns restarted
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
deployment "coredns" successfully rolled out
==> CoreDNS pods:
NAME                       READY   STATUS        RESTARTS   AGE
coredns-6596ddbb47-dncrb   1/1     Running       0          2s
coredns-6596ddbb47-prf68   1/1     Running       0          2s
coredns-6bfb9c5478-7rlrq   1/1     Terminating   0          8s
coredns-6bfb9c5478-s5j9f   1/1     Terminating   0          8s
==> Done. CoreDNS is patched and Running.
```

## Run 2 — idempotent on an already-fixed cluster

Second run right after the first: the forward target is already `8.8.8.8 8.8.4.4`, so the
script skips the patch and only restarts the deployment — no-op on the config, safe to re-run.

```
./infra/local/scripts/fix-coredns.sh
==> Checking kubectl connectivity...
==> Checking namespace kube-system exists...
==> Reading current CoreDNS Corefile...
==> CoreDNS already forwards to 8.8.8.8 8.8.4.4 — nothing to patch.
==> Restarting CoreDNS to pick up the change...
deployment.apps/coredns restarted
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
deployment "coredns" successfully rolled out
==> CoreDNS pods:
NAME                       READY   STATUS        RESTARTS   AGE
coredns-6596ddbb47-dncrb   1/1     Terminating   0          8s
coredns-6596ddbb47-prf68   1/1     Terminating   0          8s
coredns-697f75b497-btttz   1/1     Running       0          1s
coredns-697f75b497-ljp77   1/1     Running       0          1s
==> Done. CoreDNS is patched and Running.
```
