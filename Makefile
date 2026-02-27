# Claude In A Box - Local Development Makefile
# KIND-based build-load-deploy workflow for local Kubernetes development.

# -- Configuration -----------------------------------------------------------
IMAGE_NAME    ?= claude-in-a-box
IMAGE_TAG     ?= dev
CLUSTER_NAME  ?= claude-in-a-box
NAMESPACE     ?= default
KIND_CONFIG   ?= kind/cluster.yaml
POD_MANIFEST  ?= kind/pod.yaml
K8S_MANIFESTS ?= k8s/base
OPERATOR_RBAC ?= k8s/overlays/rbac-operator.yaml

# -- Test Configuration ------------------------------------------------------
KIND_TEST_CONFIG  ?= kind/cluster-test.yaml
TEST_CLUSTER_NAME ?= claude-in-a-box-test
BATS              ?= tests/bats/bin/bats
TEST_DIR         ?= tests/integration

.PHONY: help build load deploy deploy-operator undeploy-operator bootstrap teardown redeploy status test-setup test test-teardown

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

load: ## Load image into KIND cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

deploy: ## Apply k8s manifests and wait for pod to start
	kubectl apply -f $(K8S_MANIFESTS)
	@until kubectl get pod claude-agent-0 -n $(NAMESPACE) &>/dev/null; do sleep 1; done
	@kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s 2>/dev/null || true

deploy-operator: ## Apply operator-tier RBAC (opt-in elevated permissions)
	kubectl apply -f $(OPERATOR_RBAC)

undeploy-operator: ## Remove operator-tier RBAC
	kubectl delete -f $(OPERATOR_RBAC) --ignore-not-found

bootstrap: build ## Create KIND cluster, build image, load, and deploy
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Creating KIND cluster '$(CLUSTER_NAME)'..."; \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG) --wait 60s; \
	else \
		echo "Cluster '$(CLUSTER_NAME)' already exists, skipping creation"; \
	fi
	$(MAKE) load
	kubectl apply -f $(K8S_MANIFESTS)
	@echo ""
	@echo "==> Waiting for pod to start..."
	@until kubectl get pod claude-agent-0 -n $(NAMESPACE) &>/dev/null; do sleep 1; done
	@kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=60s 2>/dev/null || true
	@echo ""
	@echo "==> Attach and authenticate:"
	@echo "    kubectl attach claude-agent-0 -n $(NAMESPACE) -it"
	@echo ""
	@echo "    First time: run /login to authenticate (credentials persist in PVC)."

teardown: ## Destroy the KIND cluster
	kind delete cluster --name $(CLUSTER_NAME)

redeploy: build load ## Rebuild image, load into KIND, restart pod
	kubectl delete pod -l app=claude-agent -n $(NAMESPACE) --ignore-not-found
	kubectl apply -f $(K8S_MANIFESTS)
	@until kubectl get pod claude-agent-0 -n $(NAMESPACE) &>/dev/null; do sleep 1; done
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s 2>/dev/null || true

status: ## Show cluster and pod status
	@kind get clusters 2>/dev/null || echo "No clusters"
	@echo "---"
	@kubectl get pods -n $(NAMESPACE) -l app=claude-agent 2>/dev/null || echo "No pods"

# -- Test Targets -------------------------------------------------------------

test-setup: build ## Create test cluster with Calico and deploy
	scripts/setup-bats.sh
	@if ! kind get clusters 2>/dev/null | grep -q "^$(TEST_CLUSTER_NAME)$$"; then \
		echo "Creating test cluster '$(TEST_CLUSTER_NAME)' with Calico CNI..."; \
		kind create cluster --name $(TEST_CLUSTER_NAME) --config $(KIND_TEST_CONFIG) --wait 60s; \
		scripts/install-calico.sh; \
	else \
		echo "Cluster '$(TEST_CLUSTER_NAME)' already exists, skipping creation"; \
	fi
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(TEST_CLUSTER_NAME)
	kubectl apply -f $(K8S_MANIFESTS)
	kubectl set env statefulset/claude-agent CLAUDE_TEST_MODE=true -n $(NAMESPACE)
	@until kubectl get pod claude-agent-0 -n $(NAMESPACE) &>/dev/null; do sleep 1; done
	kubectl delete pod claude-agent-0 -n $(NAMESPACE) --grace-period=0 --force 2>/dev/null || true
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

test: ## Run integration test suite
	$(BATS) --tap $(TEST_DIR)/*.bats

test-teardown: ## Destroy test cluster
	kind delete cluster --name $(TEST_CLUSTER_NAME)
