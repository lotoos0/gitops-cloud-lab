.PHONY: help kind-create kind-delete argocd-install argocd-apps-apply fix-coredns verify bootstrap

help:
	@printf "\nUsage: make <target>\n\n"
	@printf "  %-20s %s\n" \
		"kind-create"      "Create kind cluster" \
		"kind-delete"      "Delete kind cluster" \
		"fix-coredns"       "Patch CoreDNS to forward to public DNS" \
		"argocd-install"    "Install Argo CD into cluster" \
		"argocd-apps-apply" "Apply dev + prod Argo CD Application manifests" \
		"verify"            "Check cluster, Argo CD, dev, prod are all healthy" \
		"bootstrap"         "Run the full flow: create → fix-coredns → install → apply → verify"
	@printf "\n"

kind-create:
	kind create cluster --name gitops-cloud-lab

kind-delete:
	kind delete cluster --name gitops-cloud-lab

fix-coredns:
	./infra/local/scripts/fix-coredns.sh

argocd-install:
	kubectl create namespace argocd
	kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

argocd-apps-apply:
	kubectl apply -f gitops/apps/demo-api-dev-application.yaml
	kubectl apply -f gitops/apps/demo-api-prod-application.yaml


verify:
	@echo "==> Cluster access"
	kubectl cluster-info
	@echo "==> Argo CD pods"
	kubectl get pods -n argocd
	@echo "==> Argo CD Applications"
	kubectl get applications -n argocd
	@echo "==> demo-api-dev pods (namespace: demo-api)"
	kubectl get pods -n demo-api -l app=demo-api-dev
	@echo "==> demo-api-prod pods (namespace: demo-api-prod)"
	kubectl get pods -n demo-api-prod -l app=demo-api-prod

bootstrap: kind-create fix-coredns argocd-install argocd-apps-apply verify

