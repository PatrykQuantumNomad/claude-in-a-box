# Phase 3: Local Development Environment - Research

**Researched:** 2026-02-25
**Domain:** KIND (Kubernetes IN Docker), Makefile automation, Docker Compose
**Confidence:** HIGH

## Summary

Phase 3 delivers a one-command local Kubernetes development environment using KIND (Kubernetes IN Docker) v0.31.0. The phase creates four workflow entry points: `make bootstrap` (full cluster setup from scratch), `make teardown` (clean destruction), `make redeploy` (rebuild and reload without cluster recreation), and `docker compose up` (standalone non-Kubernetes mode). All scripts must be idempotent -- safe to run multiple times without side effects.

The existing project has a working Docker image (`claude-in-a-box:dev`) built from `docker/Dockerfile` with build context at the project root. The image runs as non-root user `agent` (UID 10000/GID 10000) with tini as PID 1, and supports three modes via `CLAUDE_MODE` env var: `remote-control`, `interactive`, and `headless`. The entrypoint validates auth via env vars and credential files (no `claude auth status` call). All this exists and is verified from Phases 1 and 2.

The core technical challenge is wiring the KIND cluster lifecycle (create, load image, deploy pod, wait for ready) into idempotent shell scripts wrapped by a Makefile. A minimal Kubernetes Pod or Deployment manifest is needed for Phase 3 -- the full StatefulSet, RBAC, NetworkPolicy, and PVC come in Phase 4. The Docker Compose file provides a simple alternative for users who want to run the container without Kubernetes.

**Primary recommendation:** Use KIND v0.31.0 with a YAML config defining 1 control-plane + 2 workers, wrap all operations in idempotent bash scripts under `scripts/kind/`, expose through a project-root Makefile with `.PHONY` targets, and use `imagePullPolicy: IfNotPresent` with a versioned `:dev` tag to avoid the `:latest` pull trap.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEV-01 | KIND cluster configuration with 1 control plane + 2 worker nodes | KIND v0.31.0 YAML config with `kind: Cluster`, `apiVersion: kind.x-k8s.io/v1alpha4`, three nodes with roles `control-plane` and `worker` |
| DEV-02 | Idempotent bootstrap, teardown, and redeploy scripts for KIND cluster | Bash scripts using `kind get clusters \| grep` for existence checks, `kind delete cluster` (already idempotent), and build-load-deploy chain |
| DEV-03 | Makefile wrapping build-load-deploy chain | `.PHONY` targets for `build`, `load`, `deploy`, `bootstrap`, `teardown`, `redeploy` with configurable variables |
| DEV-05 | Docker Compose reference file for standalone non-Kubernetes deployments | Docker Compose v2 YAML with image build, environment variables, healthcheck, and volume mounts |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| KIND | v0.31.0 | Local K8s clusters using Docker container "nodes" | Official Kubernetes SIG tool for local testing; used by Kubernetes CI itself |
| GNU Make | 3.81+ | Task runner and dependency graph | Universal on macOS/Linux; zero install; standard for Kubernetes projects (kubebuilder, operator-sdk) |
| Docker Compose | v2 (Compose Spec) | Standalone container orchestration | Ships with Docker Desktop; standard for non-K8s local dev |
| kubectl | (matches cluster) | K8s API client | Already in the container image; KIND sets kubeconfig automatically |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| docker | 20.10+ | Container builds and KIND backend | Required by KIND; already installed for Phase 1/2 |
| bash | 3.2+ | Script execution | Entrypoint scripts already use bash; maintain consistency |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| KIND | minikube | minikube is single-node by default, heavier VM-based; KIND is lighter and matches CI patterns better |
| KIND | k3d (k3s in Docker) | k3d uses k3s (not full K8s); KIND uses upstream K8s which matches production better |
| Makefile | Taskfile (task) | Taskfile is cleaner YAML syntax but requires installing Go binary; Make is universally available |
| Makefile | Just | Similar tradeoff -- requires installation; Make requires nothing |

**Installation (prerequisites check, not install):**
```bash
# KIND must be installed by the user -- not bundled
kind version    # expect v0.31.0+
docker version  # expect 20.10+
kubectl version --client  # expect 1.28+
```

## Architecture Patterns

### Recommended Project Structure
```
project-root/
├── docker/
│   └── Dockerfile           # Existing from Phase 1
├── scripts/
│   ├── entrypoint.sh        # Existing from Phase 2
│   ├── healthcheck.sh       # Existing from Phase 2
│   ├── readiness.sh         # Existing from Phase 2
│   └── verify-tools.sh      # Existing from Phase 1
├── kind/
│   ├── cluster.yaml         # KIND cluster config (DEV-01)
│   └── pod.yaml             # Minimal pod manifest for dev testing
├── Makefile                  # Top-level task runner (DEV-03)
└── docker-compose.yaml       # Standalone mode (DEV-05)
```

**Rationale:** Keep KIND-specific configs in `kind/` separate from production K8s manifests (which will live in `k8s/` in Phase 4). The Makefile lives at project root (convention). Docker Compose file at project root (convention).

### Pattern 1: Idempotent Cluster Lifecycle
**What:** Scripts that check state before acting -- create only if not exists, delete only if exists, always succeed regardless of starting state.
**When to use:** All KIND operations (bootstrap, teardown).
**Example:**
```bash
# Source: KIND quick-start docs + idempotent bash patterns
CLUSTER_NAME="claude-in-a-box"

# Idempotent create
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    kind create cluster --name "${CLUSTER_NAME}" --config kind/cluster.yaml --wait 60s
else
    echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation"
fi

# Idempotent delete (KIND's delete is already idempotent -- no error if missing)
kind delete cluster --name "${CLUSTER_NAME}"
```

### Pattern 2: Build-Load-Deploy Chain
**What:** Sequential pipeline: docker build -> kind load -> kubectl apply -> kubectl wait.
**When to use:** `make redeploy` (rebuild without cluster recreation).
**Example:**
```bash
IMAGE_NAME="claude-in-a-box"
IMAGE_TAG="dev"
CLUSTER_NAME="claude-in-a-box"
NAMESPACE="default"

# Build
docker build -f docker/Dockerfile -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# Load into KIND (replaces existing image on all nodes)
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "${CLUSTER_NAME}"

# Apply manifest (idempotent -- kubectl apply is safe to repeat)
kubectl apply -f kind/pod.yaml

# Force pod restart to pick up new image
kubectl delete pod -l app=claude-agent -n "${NAMESPACE}" --ignore-not-found
# Wait for new pod to become ready
kubectl wait --for=condition=Ready pod -l app=claude-agent -n "${NAMESPACE}" --timeout=120s
```

### Pattern 3: Versioned Tag with IfNotPresent
**What:** Use a specific tag (`:dev`) instead of `:latest` and set `imagePullPolicy: IfNotPresent` in the pod manifest.
**When to use:** All KIND-loaded local images.
**Why:** The `:latest` tag defaults `imagePullPolicy` to `Always`, which makes Kubernetes try to pull from a remote registry -- failing because the image only exists locally. Using `:dev` with `IfNotPresent` tells Kubernetes to use the locally-loaded image.
**Example:**
```yaml
# kind/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: claude-agent-0
  labels:
    app: claude-agent
spec:
  containers:
  - name: claude-agent
    image: claude-in-a-box:dev
    imagePullPolicy: IfNotPresent
    env:
    - name: CLAUDE_MODE
      value: "interactive"
```

### Pattern 4: Makefile Variable Convention
**What:** Define configurable variables at the top, use `.PHONY` for all targets, chain targets for compound operations.
**When to use:** The project Makefile.
**Example:**
```makefile
# Variables
IMAGE_NAME    ?= claude-in-a-box
IMAGE_TAG     ?= dev
CLUSTER_NAME  ?= claude-in-a-box
NAMESPACE     ?= default
KIND_CONFIG   ?= kind/cluster.yaml

.PHONY: build load deploy bootstrap teardown redeploy help

build:
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

load:
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

deploy:
	kubectl apply -f kind/pod.yaml
	kubectl wait --for=condition=Ready pod -l app=claude-agent -n $(NAMESPACE) --timeout=120s

bootstrap: build
	@# Create cluster if not exists, then load and deploy
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG) --wait 60s; \
	else \
		echo "Cluster '$(CLUSTER_NAME)' already exists"; \
	fi
	$(MAKE) load deploy

teardown:
	kind delete cluster --name $(CLUSTER_NAME)

redeploy: build load
	kubectl delete pod -l app=claude-agent -n $(NAMESPACE) --ignore-not-found
	kubectl wait --for=condition=Ready pod -l app=claude-agent -n $(NAMESPACE) --timeout=120s
```

### Anti-Patterns to Avoid
- **Using `:latest` tag with KIND:** Causes `imagePullPolicy: Always` default, Kubernetes tries to pull from registry, fails with ErrImagePull. Always use a specific tag like `:dev`.
- **Inline cluster creation in Makefile without existence check:** Running `kind create cluster` when cluster exists produces an error. Always check with `kind get clusters | grep`.
- **Using `kubectl rollout restart` on a bare Pod:** Rollout restart only works on Deployments/StatefulSets/DaemonSets, not bare Pods. For Phase 3's minimal pod manifest, use `kubectl delete pod` + `kubectl wait` instead.
- **Putting K8s manifests in `k8s/` for Phase 3:** The `k8s/` directory is for production manifests (Phase 4). Phase 3's dev-only pod manifest belongs in `kind/` to avoid confusion.
- **Hardcoding the docker build command path:** The existing convention uses `-f docker/Dockerfile` with build context `.` (project root). Maintain this convention.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local K8s cluster | Custom Docker-based K8s | KIND | KIND handles kubeadm, networking, containerd, kubeconfig -- hundreds of edge cases |
| Image loading to K8s nodes | Manual docker save/load to containerd | `kind load docker-image` | KIND handles the containerd import across all nodes automatically |
| Kubeconfig management | Manual kubeconfig file editing | KIND auto-sets kubeconfig | KIND creates context `kind-{cluster-name}` automatically |
| Pod readiness waiting | Custom polling loops | `kubectl wait --for=condition=Ready` | Built-in, handles edge cases like pod not yet existing |
| Idempotent K8s resource creation | Check-then-create scripts | `kubectl apply` | Apply is declarative and idempotent by design |

**Key insight:** KIND abstracts away the entire Kubernetes cluster lifecycle (kubeadm init, join, containerd, CNI, kubeconfig). The scripts should be thin wrappers around KIND and kubectl commands, not custom cluster management logic.

## Common Pitfalls

### Pitfall 1: The `:latest` Tag Trap
**What goes wrong:** Image loaded into KIND but pod gets `ErrImagePull` or `ImagePullBackOff`.
**Why it happens:** Using `:latest` tag (or no tag) defaults `imagePullPolicy` to `Always`, making Kubernetes try to pull from Docker Hub instead of using the locally-loaded image.
**How to avoid:** Always use a specific tag (`:dev`) and set `imagePullPolicy: IfNotPresent` in the pod manifest.
**Warning signs:** Pod status shows `ErrImagePull` or `ImagePullBackOff` after `kind load docker-image` succeeds.

### Pitfall 2: Stale Image After Rebuild
**What goes wrong:** `make redeploy` runs but pod still uses the old image.
**Why it happens:** KIND loaded the new image, but the existing pod's container was not restarted. Kubernetes won't restart a running container just because the node's image cache changed.
**How to avoid:** After `kind load docker-image`, delete the pod and let it recreate. With `imagePullPolicy: IfNotPresent` and the same tag, the new (locally-loaded) image will be used.
**Warning signs:** Code changes don't appear in the running pod after redeploy.

### Pitfall 3: Cluster Name Mismatch
**What goes wrong:** `kind load docker-image` loads to wrong cluster, or `kubectl` commands hit wrong context.
**Why it happens:** Multiple KIND clusters exist, or the `--name` flag is missing from KIND commands.
**How to avoid:** Always pass `--name ${CLUSTER_NAME}` to all KIND commands. Use a consistent cluster name variable defined once in the Makefile.
**Warning signs:** `kind get clusters` shows multiple clusters; `kubectl config current-context` doesn't match expected `kind-{cluster-name}`.

### Pitfall 4: `kubectl wait` Before Pod Exists
**What goes wrong:** `kubectl wait` returns immediately with error because the pod doesn't exist yet.
**Why it happens:** `kubectl apply` is async -- the pod may not be created instantly, especially if the scheduler needs a moment.
**How to avoid:** Add a brief sleep (2-3s) between `kubectl apply` and `kubectl wait`, or use `kubectl wait` with `--timeout=120s` which handles the race condition in recent versions. For bare pods, verify with `kubectl get pod` first.
**Warning signs:** Script exits with "no matching resources found" error from `kubectl wait`.

### Pitfall 5: Docker Build Context Wrong Directory
**What goes wrong:** Docker COPY commands fail during build because files aren't found.
**Why it happens:** Running `docker build` from wrong directory. The existing convention is: build context is project root (`.`), Dockerfile is at `docker/Dockerfile`, and COPY paths are relative to project root.
**How to avoid:** The Makefile's `build` target should run from project root: `docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .`
**Warning signs:** `COPY scripts/entrypoint.sh ...` fails with "file not found".

### Pitfall 6: KIND Cluster Not Cleaned Up on Interrupt
**What goes wrong:** Half-created cluster left behind after Ctrl+C during bootstrap.
**Why it happens:** `kind create cluster` was interrupted mid-provisioning.
**How to avoid:** `make teardown` followed by `make bootstrap` should always work. The teardown command (`kind delete cluster`) handles partial states. Document this recovery pattern.
**Warning signs:** `kind get clusters` shows the cluster but `kubectl` commands fail.

## Code Examples

Verified patterns from official sources:

### KIND Cluster Configuration (DEV-01)
```yaml
# kind/cluster.yaml
# Source: https://kind.sigs.k8s.io/docs/user/configuration/
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: claude-in-a-box
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

### Minimal Pod Manifest for Development
```yaml
# kind/pod.yaml
# Minimal manifest for Phase 3 development testing.
# Full StatefulSet, RBAC, NetworkPolicy, PVC comes in Phase 4.
apiVersion: v1
kind: Pod
metadata:
  name: claude-agent-0
  namespace: default
  labels:
    app: claude-agent
spec:
  containers:
  - name: claude-agent
    image: claude-in-a-box:dev
    imagePullPolicy: IfNotPresent
    env:
    - name: CLAUDE_MODE
      value: "interactive"
    livenessProbe:
      exec:
        command: ["/usr/local/bin/healthcheck.sh"]
      initialDelaySeconds: 15
      periodSeconds: 30
      timeoutSeconds: 5
    readinessProbe:
      exec:
        command: ["/usr/local/bin/readiness.sh"]
      initialDelaySeconds: 30
      periodSeconds: 30
      timeoutSeconds: 10
```

Note on probes: The pod needs auth credentials to reach Ready state. For `make bootstrap` testing, either pass `CLAUDE_CODE_OAUTH_TOKEN` or accept that the pod will be Running but not Ready (liveness passes because the process runs, readiness fails because auth fails). The success criterion is "pod reaching Ready state" -- this requires valid auth or adjusting the readiness probe for dev. Recommendation: For Phase 3, remove the readiness probe from the dev manifest (or use the liveness probe for both) since we cannot assume auth credentials are available during development. The success criterion "pod reaching Ready state" should mean the pod's container is running and not crash-looping, which is covered by liveness alone.

### Docker Compose for Standalone Mode (DEV-05)
```yaml
# docker-compose.yaml
# Source: Docker Compose Specification
services:
  claude-agent:
    build:
      context: .
      dockerfile: docker/Dockerfile
    image: claude-in-a-box:dev
    container_name: claude-agent
    environment:
      - CLAUDE_MODE=${CLAUDE_MODE:-interactive}
      - CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    volumes:
      - claude-data:/app/.claude
    stdin_open: true
    tty: true
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "/usr/local/bin/healthcheck.sh"]
      interval: 30s
      timeout: 5s
      start_period: 15s
      retries: 3

volumes:
  claude-data:
```

### Makefile (DEV-03)
```makefile
# Makefile
# Source: GNU Make manual + Kubernetes project conventions

# -- Configuration -----------------------------------------------------------
IMAGE_NAME    ?= claude-in-a-box
IMAGE_TAG     ?= dev
CLUSTER_NAME  ?= claude-in-a-box
NAMESPACE     ?= default
KIND_CONFIG   ?= kind/cluster.yaml
POD_MANIFEST  ?= kind/pod.yaml

.PHONY: help build load deploy bootstrap teardown redeploy status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

load: ## Load image into KIND cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER_NAME)

deploy: ## Apply pod manifest and wait for ready
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
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

status: ## Show cluster and pod status
	@kind get clusters 2>/dev/null || echo "No clusters"
	@echo "---"
	@kubectl get pods -n $(NAMESPACE) -l app=claude-agent 2>/dev/null || echo "No pods"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Compose file `version: "3.x"` key | Top-level `services:` without `version:` key | Docker Compose v2 (2022+) | The `version` key is now deprecated; omit it from compose files |
| `docker-compose` (hyphenated CLI) | `docker compose` (plugin subcommand) | Docker Compose v2 (2022+) | `docker-compose` still works but `docker compose` is the current standard |
| KIND apiVersion `kind.sigs.k8s.io/v1alpha3` | `kind.x-k8s.io/v1alpha4` | KIND v0.11.0 (2021+) | Use `v1alpha4` for all new cluster configs |
| `minikube` for local K8s dev | KIND for CI/testing, minikube for interactive dev | Ongoing | KIND is preferred for automated workflows; minikube for interactive use |

**Deprecated/outdated:**
- `docker-compose` (hyphenated): Still works but `docker compose` (space) is the canonical form
- Compose file `version: "3.8"`: The `version` key is obsolete and ignored by Docker Compose v2
- KIND apiVersion `v1alpha3`: Superseded by `v1alpha4`

## Open Questions

1. **Pod readiness without auth credentials**
   - What we know: The readiness probe runs `claude auth status` which requires valid auth. Without `CLAUDE_CODE_OAUTH_TOKEN`, the pod will never reach Ready.
   - What's unclear: Should `make bootstrap` assume auth credentials are available, or should the dev manifest omit the readiness probe?
   - Recommendation: Use only the liveness probe (process check) in the Phase 3 dev manifest. The readiness probe is for Kubernetes service routing, which isn't needed in Phase 3. Full probes come with Phase 4's production manifests. Alternatively, use the liveness probe for both liveness and readiness (pgrep-based) to satisfy the "pod reaching Ready state" success criterion without requiring auth.

2. **Cluster name convention**
   - What we know: KIND uses the cluster name for the Docker container names and kubeconfig context (`kind-{name}`).
   - What's unclear: Whether to use `claude-in-a-box` (matches image/project) or something shorter.
   - Recommendation: Use `claude-in-a-box` to match the project name. The kubeconfig context will be `kind-claude-in-a-box`.

3. **Multi-architecture support for KIND**
   - What we know: The Dockerfile supports `TARGETARCH` for amd64/arm64. KIND uses the host architecture.
   - What's unclear: Whether `kind load docker-image` correctly handles cross-architecture images.
   - Recommendation: Build for the host architecture only in Phase 3 (no `--platform` flag). Cross-arch is a CI concern (Phase 7).

## Sources

### Primary (HIGH confidence)
- [KIND Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) - cluster creation, deletion, image loading commands, v0.31.0 current
- [KIND Configuration](https://kind.sigs.k8s.io/docs/user/configuration/) - full YAML spec for cluster config, node roles, networking
- [Docker Compose Services Reference](https://docs.docker.com/reference/compose-file/services/) - service config options, healthcheck, environment, volumes
- [kubectl wait](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/) - pod readiness waiting with timeout

### Secondary (MEDIUM confidence)
- [KIND Image Loading Pitfalls](https://iximiuz.com/en/posts/kubernetes-kind-load-docker-image/) - `:latest` tag trap, imagePullPolicy gotchas
- [Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) - grep-based existence checking patterns
- [GNU Make .PHONY](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html) - phony target declaration

### Tertiary (LOW confidence)
- None -- all findings verified against official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - KIND is the official Kubernetes SIG tool; Make and Docker Compose are universal
- Architecture: HIGH - Patterns verified against KIND and kubectl official docs; existing project conventions preserved
- Pitfalls: HIGH - `:latest` tag trap and stale image issues are well-documented across multiple sources

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (KIND and Make are stable; Docker Compose spec is stable)
