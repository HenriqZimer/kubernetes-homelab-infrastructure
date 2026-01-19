.PHONY: help pre namespace cleanup-pvs pvs storageclass secrets cert-manager helm kyverno deploy status validate clean unseal-vault

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
BLUE   := \033[0;34m
RESET  := \033[0m

# Default target
.DEFAULT_GOAL := help

help: ## Display this help message
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BLUE)  Kubernetes Cluster Infrastructure - Makefile Help$(RESET)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Usage:$(RESET)"
	@echo "  make $(GREEN)deploy$(RESET)        # Full deployment from scratch"
	@echo "  make $(GREEN)status$(RESET)        # Check cluster status"
	@echo "  make $(GREEN)validate$(RESET)      # Validate configurations"
	@echo "  make $(GREEN)clean$(RESET)         # Clean up all resources"
	@echo ""

pre: ## Install MetalLB load balancer
	@echo "$(BLUE)📦 Installing MetalLB...$(RESET)"
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
	@kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
	@kubectl apply -f manifests/metallb/metallb-pool.yaml
	@echo "$(GREEN)✅ MetalLB installed$(RESET)"
	@echo ""

namespaces: ## Create all required namespaces
	@echo "$(BLUE)📦 Creating namespaces...$(RESET)"
	@kubectl apply -f manifests/namespace.yaml
	@echo "$(GREEN)✅ Namespaces created$(RESET)"
	@echo ""

cleanup-pvs: ## Clean up released PersistentVolumes
	@echo "$(YELLOW)🔧 Checking and cleaning up PVs...$(RESET)"
	@for pv in vault-data-pv prometheus-pv alertmanager-pv grafana-pv; do \
		if kubectl get pv $$pv >/dev/null 2>&1; then \
			STATUS=$$(kubectl get pv $$pv -o jsonpath='{.status.phase}'); \
			if [ "$$STATUS" = "Released" ]; then \
				echo "  🔓 Releasing $$pv..."; \
				kubectl patch pv $$pv --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]' 2>/dev/null || true; \
			fi; \
		fi; \
	done
	@echo "$(GREEN)✅ PVs cleaned$(RESET)"
	@echo ""

storageclass: ## Create NFS StorageClass
	@echo "$(BLUE)💾 Creating StorageClass...$(RESET)"
	@kubectl apply -f manifests/storageclass.yaml
	@echo "$(GREEN)✅ StorageClass created$(RESET)"
	@echo ""

pvs: cleanup-pvs storageclass ## Create PersistentVolumes
	@echo "$(BLUE)📦 Creating PersistentVolumes...$(RESET)"
	@kubectl apply -f manifests/persistent-volume.yaml
	@echo "$(GREEN)✅ PVs created$(RESET)"
	@echo ""

secrets: ## Apply ExternalSecrets configuration
	@echo "$(BLUE)🔐 Applying External Secrets...$(RESET)"
	@kubectl apply -f manifests/external-secrets/cluster-secret-store.yaml
	@kubectl apply -f manifests/external-secrets.yaml
	@echo "$(GREEN)✅ External Secrets applied$(RESET)"
	@echo ""

cert-manager: ## Apply cert-manager ClusterIssuer
	@echo "$(BLUE)🔒 Configuring cert-manager...$(RESET)"
	@kubectl apply -f manifests/cert-manager/
	@echo "$(GREEN)✅ cert-manager configured$(RESET)"
	@echo ""

helm: namespaces pvs secrets ## Deploy all Helm releases
	@echo "$(BLUE)🚀 Deploying Helm releases...$(RESET)"
	@helmfile apply
	@echo ""
	@echo "$(BLUE)⏳ Waiting for deployments to be ready...$(RESET)"
	@sleep 10
	@echo "$(GREEN)✅ Helm releases deployed$(RESET)"
	@echo ""

kyverno: ## Apply Kyverno policies
	@echo "$(BLUE)🛡️  Applying Kyverno policies...$(RESET)"
	@kubectl apply -f manifests/kyverno/
	@echo "$(GREEN)✅ Kyverno policies applied$(RESET)"
	@echo ""

deploy: pre helm cert-manager kyverno ## Full cluster deployment
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)  ✅ Cluster deployment completed successfully!$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Unseal Vault: make unseal-vault"
	@echo "  2. Check status: make status"
	@echo "  3. Validate: make validate"
	@echo ""

status: ## Check cluster status
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BLUE)  Cluster Status$(RESET)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Nodes:$(RESET)"
	@kubectl get nodes
	@echo ""
	@echo "$(YELLOW)Pods by Namespace:$(RESET)"
	@kubectl get pods -A | grep -E "NAMESPACE|monitoring|vault|cert-manager|external-secrets|kyverno|ingress-nginx"
	@echo ""
	@echo "$(YELLOW)PersistentVolumes:$(RESET)"
	@kubectl get pv
	@echo ""
	@echo "$(YELLOW)Certificates:$(RESET)"
	@kubectl get certificates -A
	@echo ""

validate: ## Validate Kubernetes manifests
	@echo "$(BLUE)🔍 Validating Kubernetes manifests...$(RESET)"
	@echo ""
	@for file in manifests/*.yaml manifests/**/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "$(YELLOW)Validating $$file...$(RESET)"; \
			kubectl apply --dry-run=client -f "$$file" >/dev/null 2>&1 && \
				echo "$(GREEN)  ✓ Valid$(RESET)" || \
				echo "$(RED)  ✗ Invalid$(RESET)"; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✅ Validation completed$(RESET)"
	@echo ""

unseal-vault: ## Instructions to unseal Vault
	@echo "$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(YELLOW)  Vault Unseal Instructions$(RESET)"
	@echo "$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "Run these commands with your unseal keys:"
	@echo ""
	@echo "  kubectl exec -n vault vault-0 -- vault operator unseal <KEY_1>"
	@echo "  kubectl exec -n vault vault-0 -- vault operator unseal <KEY_2>"
	@echo "  kubectl exec -n vault vault-0 -- vault operator unseal <KEY_3>"
	@echo ""
	@echo "Check Vault status:"
	@echo "  kubectl exec -n vault vault-0 -- vault status"
	@echo ""

clean: ## Clean up all resources (WARNING: Destructive operation!)
	@echo "$(RED)⚠️  WARNING: This will delete all cluster infrastructure resources!$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or wait 5 seconds to continue...$(RESET)"
	@sleep 5
	@echo ""
	@echo "$(BLUE)🗑️  Removing Helm releases...$(RESET)"
	@helmfile destroy || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting Kyverno policies...$(RESET)"
	@kubectl delete -f manifests/kyverno/ --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting cert-manager resources...$(RESET)"
	@kubectl delete -f manifests/cert-manager/ --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting ExternalSecrets...$(RESET)"
	@kubectl delete -f manifests/external-secrets.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting PVs...$(RESET)"
	@kubectl delete -f manifests/persistent-volume.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting StorageClass...$(RESET)"
	@kubectl delete -f manifests/storageclass.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(BLUE)🗑️  Deleting namespaces...$(RESET)"
	@kubectl delete -f manifests/namespace.yaml --ignore-not-found=true || true
	@echo ""
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"
	@echo ""