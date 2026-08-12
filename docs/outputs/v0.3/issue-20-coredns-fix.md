# Issue #23 proof: automated CoreDNS repair

`infra/local/scripts/fix-coredns.sh`, exposed as `make fix-coredns`, replaced
the manual ConfigMap edit documented in the original incident notes. I tested
it twice: first against a deliberately broken forward target, then immediately
again against the repaired state.

> **What this proves:** run 1 changes `/etc/resolv.conf` to **2 public DNS
> servers** and completes the rollout; run 2 detects the existing configuration
> and applies **0 ConfigMap changes**. Two runs, one repair, no editor séance.

## Run 1: repair the broken Corefile

Before the run, the Corefile contained `forward . /etc/resolv.conf {`. The
script detected that exact target, patched it to `8.8.8.8 8.8.4.4`, restarted
the Deployment and waited until the new CoreDNS pods were running.

```text
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

Observed result: **2 new pods** reached `1/1 Running`; **2 old pods** were
terminating as expected during the rollout.

## Run 2: verify repeatability

The second run found the desired forward target already present. It skipped the
ConfigMap patch, restarted CoreDNS and again waited for a successful rollout.

```text
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

The configuration path is idempotent: no second patch was required. The script
does intentionally restart the Deployment on every run, so “safe to rerun”
does not mean “literally no Kubernetes activity.” That distinction is small,
technical and worth being honest about.
