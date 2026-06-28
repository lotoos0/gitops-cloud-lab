.PHONY: help cluster-up cluster-down argocd-install

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  cluster-up       Create kind cluster"
	@echo "  cluster-down     Delete kind cluster"
	@echo "  argocd-install   Install Argo CD into cluster"

cluster-up:
	kind create cluster --name gitops-cloud-lab

cluster-down:
	kind delete cluster --name gitops-cloud-lab

argocd-install:
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
