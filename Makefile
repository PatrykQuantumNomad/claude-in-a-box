# Claude In A Box - Local Development Makefile
# KIND-based build-load-deploy workflow for local Kubernetes development.

# -- Configuration -----------------------------------------------------------
IMAGE_NAME    ?= claude-in-a-box
IMAGE_TAG     ?= dev
CLUSTER_NAME  ?= claude-in-a-box
NAMESPACE     ?= default
KIND_CONFIG   ?= kind/cluster.yaml
POD_MANIFEST  ?= kind/pod.yaml

.PHONY: help build load deploy bootstrap teardown redeploy status

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

load: ## Load image into KIND cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

deploy: ## Apply pod manifest and wait for Ready
	kubectl apply -f $(POD_MANIFEST)
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

bootstrap: build ## Create KIND cluster, build image, load, and deploy
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Creating KIND cluster '$(CLUSTER_NAME)'..."; \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG) --wait 60s; \
	else \
		echo "Cluster '$(CLUSTER_NAME)' already exists, skipping creation"; \
	fi
	$(MAKE) load deploy

teardown: ## Destroy the KIND cluster
	kind delete cluster --name $(CLUSTER_NAME)

redeploy: build load ## Rebuild image, load into KIND, restart pod
	kubectl delete pod -l app=claude-agent -n $(NAMESPACE) --ignore-not-found
	kubectl apply -f $(POD_MANIFEST)
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

status: ## Show cluster and pod status
	@kind get clusters 2>/dev/null || echo "No clusters"
	@echo "---"
	@kubectl get pods -n $(NAMESPACE) -l app=claude-agent 2>/dev/null || echo "No pods"
