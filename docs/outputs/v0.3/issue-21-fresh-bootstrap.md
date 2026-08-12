# Issue #21: fresh-machine bootstrap runbook — proof

`make bootstrap` chains `kind-create → fix-coredns → argocd-install → argocd-apps-apply → verify`
so a brand new machine can go from nothing to two synced Argo CD apps with one command. To prove
it actually works end to end, both logs below come from a real run on a machine with no prior
cluster: `docs/RUNBOOK_DEPLOY.md` was followed step by step, output was captured with `tee`, and
`verify` was run separately afterwards to double-check the apps synced and served traffic.

Along the way this run also caught a real bug: `kubectl apply` on the Argo CD install manifest
blew past the 262144-byte annotation limit on the `applicationsets.argoproj.io` CRD (its
`last-applied-configuration` annotation duplicates the whole manifest as JSON). Fixed in
`Makefile:26` by switching `argocd-install` to `kubectl apply --server-side`, which skips that
annotation entirely. The log below is the run _after_ that fix, so it goes clean.

## `make bootstrap` — full run

```
$ make bootstrap 2>&1 | tee /tmp/bootstrap-run.log
kind create cluster --name gitops-cloud-lab
Creating cluster "gitops-cloud-lab" ...
 • Ensuring node image (kindest/node:v1.36.1) 🖼  ...
 ✓ Ensuring node image (kindest/node:v1.36.1) 🖼
 • Preparing nodes 📦   ...
 ✓ Preparing nodes 📦
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing CNI 🔌  ...
 ✓ Installing CNI 🔌
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-gitops-cloud-lab"
You can now use your cluster with:

kubectl cluster-info --context kind-gitops-cloud-lab

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
./infra/local/scripts/fix-coredns.sh
==> Checking kubectl connectivity...
==> Checking namespace kube-system exists...
==> Reading current CoreDNS Corefile...
==> Patching forward target: /etc/resolv.conf -> 8.8.8.8 8.8.4.4
Warning: resource configmaps/coredns is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
configmap/coredns configured
==> Restarting CoreDNS to pick up the change...
deployment.apps/coredns restarted
Waiting for deployment spec update to be observed...
Waiting for deployment spec update to be observed...
Waiting for deployment "coredns" rollout to finish: 0 out of 2 new replicas have been updated...
Waiting for deployment "coredns" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
deployment "coredns" successfully rolled out
==> CoreDNS pods:
NAME                      READY   STATUS    RESTARTS   AGE
coredns-7d57794cb-689sz   1/1     Running   0          12s
coredns-7d57794cb-vq2wk   1/1     Running   0          12s
==> Done. CoreDNS is patched and Running.
kubectl create namespace argocd
namespace/argocd created
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io serverside-applied
serviceaccount/argocd-application-controller serverside-applied
serviceaccount/argocd-applicationset-controller serverside-applied
serviceaccount/argocd-dex-server serverside-applied
serviceaccount/argocd-notifications-controller serverside-applied
serviceaccount/argocd-redis serverside-applied
serviceaccount/argocd-repo-server serverside-applied
serviceaccount/argocd-server serverside-applied
role.rbac.authorization.k8s.io/argocd-application-controller serverside-applied
role.rbac.authorization.k8s.io/argocd-applicationset-controller serverside-applied
role.rbac.authorization.k8s.io/argocd-dex-server serverside-applied
role.rbac.authorization.k8s.io/argocd-notifications-controller serverside-applied
role.rbac.authorization.k8s.io/argocd-redis serverside-applied
role.rbac.authorization.k8s.io/argocd-server serverside-applied
clusterrole.rbac.authorization.k8s.io/argocd-application-controller serverside-applied
clusterrole.rbac.authorization.k8s.io/argocd-applicationset-controller serverside-applied
clusterrole.rbac.authorization.k8s.io/argocd-server serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-application-controller serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-dex-server serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-notifications-controller serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-redis serverside-applied
rolebinding.rbac.authorization.k8s.io/argocd-server serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/argocd-server serverside-applied
configmap/argocd-cm serverside-applied
configmap/argocd-cmd-params-cm serverside-applied
configmap/argocd-gpg-keys-cm serverside-applied
configmap/argocd-notifications-cm serverside-applied
configmap/argocd-rbac-cm serverside-applied
configmap/argocd-ssh-known-hosts-cm serverside-applied
configmap/argocd-tls-certs-cm serverside-applied
secret/argocd-notifications-secret serverside-applied
secret/argocd-secret serverside-applied
service/argocd-applicationset-controller serverside-applied
service/argocd-dex-server serverside-applied
service/argocd-metrics serverside-applied
service/argocd-notifications-controller-metrics serverside-applied
service/argocd-redis serverside-applied
service/argocd-repo-server serverside-applied
service/argocd-server serverside-applied
service/argocd-server-metrics serverside-applied
deployment.apps/argocd-applicationset-controller serverside-applied
deployment.apps/argocd-dex-server serverside-applied
deployment.apps/argocd-notifications-controller serverside-applied
deployment.apps/argocd-redis serverside-applied
deployment.apps/argocd-repo-server serverside-applied
deployment.apps/argocd-server serverside-applied
statefulset.apps/argocd-application-controller serverside-applied
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-redis-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-server-network-policy serverside-applied
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s
deployment.apps/argocd-server condition met
kubectl apply -f gitops/apps/demo-api-dev-application.yaml
application.argoproj.io/demo-api-dev created
kubectl apply -f gitops/apps/demo-api-prod-application.yaml
application.argoproj.io/demo-api-prod created
==> Cluster access
kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:37663
CoreDNS is running at https://127.0.0.1:37663/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
==> Argo CD pods
kubectl get pods -n argocd
NAME                                                READY   STATUS            RESTARTS   AGE
argocd-application-controller-0                     0/1     Running           0          13s
argocd-applicationset-controller-5b768d786f-z7dvl   1/1     Running           0          14s
argocd-dex-server-6fb56f4676-4tpt8                  0/1     PodInitializing   0          14s
argocd-notifications-controller-574dd5f54d-zjf4m    1/1     Running           0          14s
argocd-redis-6d79dcbc5b-hpdcr                       1/1     Running           0          14s
argocd-repo-server-fb87d8994-lrmkt                  0/1     PodInitializing   0          14s
argocd-server-795d58f54b-nzwzk                      1/1     Running           0          13s
==> Argo CD Applications
kubectl get applications -n argocd
NAME            SYNC STATUS   HEALTH STATUS
demo-api-dev
demo-api-prod
==> demo-api-dev pods (namespace: demo-api)
kubectl get pods -n demo-api -l app=demo-api-dev
No resources found in demo-api namespace.
==> demo-api-prod pods (namespace: demo-api-prod)
kubectl get pods -n demo-api-prod -l app=demo-api-prod
No resources found in demo-api-prod namespace.
```

`verify` ran here at the tail end of `bootstrap`, only ~14 seconds after the Argo CD Applications
were created — the applicationset controller hadn't picked them up yet and the app pods hadn't
scheduled, so both show up empty. That's a race in `verify`'s timing, not a bootstrap failure: the
second log below, taken about a minute later, shows everything settled and healthy.

## `verify` — rerun ~1 minute later, everything settled

```
## kubectl get pods -A
NAMESPACE            NAME                                                     READY   STATUS    RESTARTS   AGE
argocd               argocd-application-controller-0                          1/1     Running   0          84s
argocd               argocd-applicationset-controller-5b768d786f-z7dvl        1/1     Running   0          85s
argocd               argocd-dex-server-6fb56f4676-4tpt8                       1/1     Running   0          85s
argocd               argocd-notifications-controller-574dd5f54d-zjf4m         1/1     Running   0          85s
argocd               argocd-redis-6d79dcbc5b-hpdcr                            1/1     Running   0          85s
argocd               argocd-repo-server-fb87d8994-lrmkt                       1/1     Running   0          85s
argocd               argocd-server-795d58f54b-nzwzk                           1/1     Running   0          84s
demo-api-prod        demo-api-prod-64ff84cc9c-h582n                           1/1     Running   0          41s
demo-api             demo-api-dev-6644f7cd5f-cq98d                            1/1     Running   0          40s
kube-system          coredns-7d57794cb-689sz                                  1/1     Running   0          98s
kube-system          coredns-7d57794cb-vq2wk                                  1/1     Running   0          98s
kube-system          etcd-gitops-cloud-lab-control-plane                      1/1     Running   0          105s
kube-system          kindnet-5c6n4                                            1/1     Running   0          98s
kube-system          kube-apiserver-gitops-cloud-lab-control-plane            1/1     Running   0          105s
kube-system          kube-controller-manager-gitops-cloud-lab-control-plane   1/1     Running   0          105s
kube-system          kube-proxy-45xxw                                         1/1     Running   0          98s
kube-system          kube-scheduler-gitops-cloud-lab-control-plane            1/1     Running   0          105s
local-path-storage   local-path-provisioner-855c7b7774-sjjvw                  1/1     Running   0          98s

## Argo CD Applications
NAME            SYNC STATUS   HEALTH STATUS
demo-api-dev    Synced        Healthy
demo-api-prod   Synced        Healthy

## dev /version
Forwarding from 127.0.0.1:8080 -> 8000
Forwarding from [::1]:8080 -> 8000
Handling connection for 8080
{"service":"demo-api","version":"sha-a6e5648","environment":"dev","commit":"a6e564833b0f9a2764ef1180d776b79de3b4560f"}
## prod /version
Forwarding from 127.0.0.1:8081 -> 8000
Forwarding from [::1]:8081 -> 8000
Handling connection for 8081
{"service":"demo-api","version":"sha-a6e5648","environment":"prod","commit":"a6e564833b0f9a2764ef1180d776b79de3b4560f"}
```

Both apps `Synced` / `Healthy`, both `/version` endpoints answer with the right `environment`
label — dev and prod are genuinely isolated deployments of the same commit, not one namespace
pretending to be two.
