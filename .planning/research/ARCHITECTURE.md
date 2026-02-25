# Architecture Research

**Domain:** Containerized AI Agent Deployment with DevOps Debugging Toolkit
**Researched:** 2026-02-25
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        OPERATOR LAYER                                   │
│                                                                         │
│   Phone (Claude App)  /  Browser (claude.ai/code)                       │
│            │                      │                                     │
│            └──────────┬───────────┘                                     │
│                       │ Remote Control (outbound HTTPS relay)           │
│                       ▼                                                 │
│              Anthropic API Servers                                      │
│                       │                                                 │
└───────────────────────┼─────────────────────────────────────────────────┘
                        │ outbound HTTPS only
┌───────────────────────┼─────────────────────────────────────────────────┐
│                       │       DEPLOYMENT LAYER                          │
│  ┌────────────────────┼────────────────────────────────────────────┐    │
│  │                    ▼     CONTAINER IMAGE                        │    │
│  │  ┌──────────────────────────────────────┐                      │    │
│  │  │         ENTRYPOINT (PID 1)           │                      │    │
│  │  │  Mode: remote-control | interactive  │                      │    │
│  │  │        | headless                    │                      │    │
│  │  │  Signal: SIGTERM trap + exec         │                      │    │
│  │  └──────────┬───────────────────────────┘                      │    │
│  │             │                                                  │    │
│  │  ┌──────────▼───────────────────────────┐                      │    │
│  │  │         CLAUDE CODE CLI              │                      │    │
│  │  │  - Remote Control session            │                      │    │
│  │  │  - OAuth token (from PVC)            │                      │    │
│  │  │  - MCP server connections            │                      │    │
│  │  └──────────┬───────────────────────────┘                      │    │
│  │             │                                                  │    │
│  │  ┌──────────▼───────────────────────────┐                      │    │
│  │  │      MCP SERVER (in-process)         │                      │    │
│  │  │  kubernetes-mcp-server (Go binary)   │                      │    │
│  │  │  - In-cluster config auto-detect     │                      │    │
│  │  │  - Read-only or operator mode        │                      │    │
│  │  └──────────┬───────────────────────────┘                      │    │
│  │             │                                                  │    │
│  │  ┌──────────▼───────────────────────────┐                      │    │
│  │  │       DEBUGGING TOOLKIT (30+)        │                      │    │
│  │  │  kubectl, helm, k9s, stern, kubens   │                      │    │
│  │  │  curl, dig, nslookup, tcpdump, ss    │                      │    │
│  │  │  htop, strace, jq, yq, bat          │                      │    │
│  │  │  crictl, nerdctl, trivy, grype       │                      │    │
│  │  └──────────────────────────────────────┘                      │    │
│  │                                                                │    │
│  │  Base: Ubuntu 24.04 LTS | Non-root user | Multi-stage build   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              KUBERNETES ORCHESTRATION                          │    │
│  │                                                                │    │
│  │  StatefulSet (replicas: 1)                                    │    │
│  │     ├── ServiceAccount ──► ClusterRole(Binding)               │    │
│  │     ├── PVC (volumeClaimTemplate) ──► auth token + state      │    │
│  │     ├── ConfigMap ──► entrypoint config, .mcp.json            │    │
│  │     └── NetworkPolicy ──► egress-only (443/TCP + 53/UDP)      │    │
│  │                                                                │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              DOCKER COMPOSE (ALTERNATIVE)                      │    │
│  │                                                                │    │
│  │  Single service                                                │    │
│  │     ├── Named volume ──► auth token + state                   │    │
│  │     ├── docker.sock bind mount ──► host Docker access          │    │
│  │     └── Environment variables ──► mode, config                │    │
│  │                                                                │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                     LOCAL DEVELOPMENT LAYER                              │
│                                                                         │
│  ┌──────────────────────┐  ┌───────────────────────────────────────┐    │
│  │    KIND CLUSTER       │  │          MAKEFILE                    │    │
│  │  1 control + 2 worker │  │  build ──► docker build multi-stage │    │
│  │  containerd runtime   │  │  load  ──► kind load docker-image   │    │
│  │  kubeadm bootstrap    │  │  deploy ──► kubectl apply           │    │
│  │  explicit image load  │  │  cluster-up ──► kind create cluster │    │
│  │  never use :latest    │  │  cluster-down ──► kind delete       │    │
│  └──────────────────────┘  │  test  ──► integration suite         │    │
│                             │  clean ──► full teardown             │    │
│                             └───────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Dockerfile** | Produces deployment-ready image with all tools, Claude Code CLI, and non-root user | Multi-stage build: stage 1 fetches/compiles tools, stage 2 copies artifacts onto Ubuntu 24.04 base |
| **Entrypoint script** | Process lifecycle (PID 1), mode selection, signal handling, health checks | Bash script with `trap` + `exec`, mode dispatch via `$CLAUDE_MODE` env var |
| **Claude Code CLI** | AI agent runtime, Remote Control relay, MCP client | npm-installed `@anthropic-ai/claude-code`, runs as foreground process via `exec` |
| **MCP Server** | Structured Kubernetes API access for Claude | `kubernetes-mcp-server` Go binary with `--read-only` and in-cluster auto-config |
| **Debugging Toolkit** | 30+ CLI tools for network, K8s, system, container diagnostics | apt-get + direct binary downloads with pinned versions |
| **StatefulSet** | Pod identity, restart resilience, PVC association | Single replica, `volumeClaimTemplates` for auth persistence |
| **ServiceAccount + RBAC** | K8s API permissions scoped to debugging needs | ClusterRole with `get/list/watch` on core resources; operator tier adds `create/delete/patch` |
| **NetworkPolicy** | Network segmentation -- egress-only, no inbound | Allow port 443/TCP (Anthropic API) + port 53/UDP (DNS), deny all ingress |
| **ConfigMap** | Externalized configuration for entrypoint and MCP | Startup mode, tool verification list, `.mcp.json` template |
| **PVC** | Persistent storage for OAuth tokens and session state | 1Gi volume at `~/.claude/` surviving pod restarts |
| **KIND cluster config** | Local development Kubernetes environment | YAML config: 1 control-plane + 2 workers, containerd, explicit image loading |
| **Makefile** | Developer workflow automation | Targets chaining build, load, deploy, test, teardown |
| **Docker Compose file** | Standalone non-K8s deployment | Single service with named volume + optional docker.sock mount |
| **Helm chart** | Parameterized production K8s deployment | Values-driven templates with `rbac.create`, `serviceAccount.create`, resource limits |

## Recommended Project Structure

```
claude-in-a-box/
├── Dockerfile                    # Multi-stage image build
├── Makefile                      # Developer workflow targets
├── docker-compose.yml            # Standalone deployment
├── README.md                     # Setup guide + architecture overview
├── CLAUDE.md                     # AI agent context for the repo
├── scripts/
│   ├── entrypoint.sh             # Container entrypoint (PID 1)
│   ├── healthcheck.sh            # Liveness/readiness probe
│   ├── verify-tools.sh           # Post-build tool verification
│   └── kind/
│       ├── cluster-up.sh         # Idempotent KIND cluster create
│       ├── cluster-down.sh       # KIND cluster teardown
│       ├── deploy.sh             # Build + load + apply manifests
│       └── kind-config.yaml      # KIND cluster topology
├── k8s/
│   ├── namespace.yaml            # Dedicated namespace
│   ├── statefulset.yaml          # Core workload
│   ├── serviceaccount.yaml       # Pod identity
│   ├── clusterrole-reader.yaml   # Read-only RBAC
│   ├── clusterrole-operator.yaml # Opt-in write RBAC
│   ├── clusterrolebinding.yaml   # Bind SA to role
│   ├── networkpolicy.yaml        # Egress-only rules
│   ├── configmap.yaml            # Entrypoint config + .mcp.json
│   └── pvc.yaml                  # Auth token persistence
├── helm/
│   └── claude-in-a-box/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── statefulset.yaml
│           ├── serviceaccount.yaml
│           ├── clusterrole.yaml
│           ├── clusterrolebinding.yaml
│           ├── networkpolicy.yaml
│           └── configmap.yaml
├── tests/
│   ├── test-bootstrap.sh         # KIND cluster creation
│   ├── test-rbac.sh              # Permission verification
│   ├── test-networking.sh        # Egress-only enforcement
│   ├── test-tools.sh             # Tool availability
│   ├── test-persistence.sh       # PVC token survival
│   └── test-remote-control.sh    # Session connectivity
├── .mcp.json                     # MCP server config (project scope)
└── .github/
    └── workflows/
        └── ci.yml                # Build, scan, test pipeline
```

### Structure Rationale

- **scripts/**: Separates runtime scripts (entrypoint, healthcheck) from build-time concerns. The `kind/` subdirectory groups all local dev cluster scripts together because they are always used as a unit.
- **k8s/**: Raw Kubernetes manifests for direct `kubectl apply` workflows and KIND development. One resource per file for clear diffs and selective application.
- **helm/**: Production-grade parameterized deployment. Separated from raw manifests because Helm templates are a superset -- they generate the same resources but with values injection.
- **tests/**: Shell-based integration tests that run against a live KIND cluster. Each test file maps to one architectural concern (RBAC, networking, persistence, etc.) for targeted debugging.
- **Root-level files**: Dockerfile, Makefile, and docker-compose.yml live at root because they are primary entry points for all workflows.

## Architectural Patterns

### Pattern 1: Multi-Mode Entrypoint with Exec Handoff

**What:** A bash entrypoint script that selects behavior based on an environment variable, then uses `exec` to replace itself with the target process, ensuring proper PID 1 signal handling.

**When to use:** When a single container image must support multiple runtime modes (remote-control for production, interactive for debugging, headless for CI).

**Trade-offs:** Simple and well-understood; no init system dependency. Requires careful signal handling in bash. Mode sprawl can make the script complex -- keep modes to 3 or fewer.

**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Graceful shutdown handler
cleanup() {
    echo "Received SIGTERM, shutting down Claude Code..."
    kill -TERM "$CHILD_PID" 2>/dev/null
    wait "$CHILD_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

CLAUDE_MODE="${CLAUDE_MODE:-remote-control}"

case "$CLAUDE_MODE" in
    remote-control)
        echo "Starting Claude Code in Remote Control mode..."
        exec claude --remote-control
        ;;
    interactive)
        echo "Starting Claude Code in interactive mode..."
        exec claude
        ;;
    headless)
        echo "Starting Claude Code in headless mode..."
        exec claude --headless -p "$CLAUDE_PROMPT"
        ;;
    *)
        echo "Unknown mode: $CLAUDE_MODE"
        exit 1
        ;;
esac
```

### Pattern 2: Tiered RBAC with Opt-In Escalation

**What:** Two ClusterRoles -- a default read-only "reader" role and an opt-in "operator" role with write permissions. The deployment binds the reader role by default; operators consciously switch to the operator binding.

**When to use:** When the agent needs broad visibility (get/list/watch across namespaces) but write operations (pod restart, exec, rollout restart) are occasionally needed and should be an explicit decision.

**Trade-offs:** Principle of least privilege by default. Operator tier requires a conscious deployment change (rebinding the ClusterRoleBinding), not just a config flag, which prevents accidental escalation. Adds manifest complexity (two roles, conditional binding).

**Example:**
```yaml
# clusterrole-reader.yaml (DEFAULT)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "configmaps",
                "events", "namespaces", "nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]

---
# clusterrole-operator.yaml (OPT-IN)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-operator
rules:
  # Everything from reader, plus:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "delete"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments/rollout"]
    verbs: ["patch"]
```

### Pattern 3: Egress-Only NetworkPolicy with DNS Allowance

**What:** A NetworkPolicy that denies all ingress traffic and restricts egress to HTTPS (port 443) and DNS (port 53). This matches the Remote Control model: outbound HTTPS relay to Anthropic API, no inbound ports needed.

**When to use:** When the container only needs to reach external HTTPS endpoints and cluster-internal DNS. Remote Control eliminates the need for any inbound connectivity.

**Trade-offs:** Strong security posture -- the pod cannot be reached from other pods or external traffic. Requires explicit DNS allowance or name resolution breaks. If the agent needs to reach cluster-internal HTTP services (e.g., Prometheus API on port 9090), additional egress rules must be added per-service.

**Example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: claude-agent-egress-only
spec:
  podSelector:
    matchLabels:
      app: claude-agent
  policyTypes:
    - Ingress
    - Egress
  ingress: []  # Deny all inbound
  egress:
    - ports:
        - protocol: TCP
          port: 443    # HTTPS to Anthropic API
    - ports:
        - protocol: UDP
          port: 53     # DNS resolution
        - protocol: TCP
          port: 53     # DNS over TCP fallback
    # Allow cluster-internal API server for kubectl/MCP
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0  # Narrowed in production to API server IP
      ports:
        - protocol: TCP
          port: 6443   # K8s API server
```

### Pattern 4: StatefulSet with VolumeClaimTemplate for Token Persistence

**What:** A StatefulSet with `replicas: 1` and a `volumeClaimTemplate` that creates a PVC bound to the pod's identity. The Claude Code OAuth token is stored on this volume at `~/.claude/` so it survives pod restarts and rescheduling.

**When to use:** When the container stores authentication state that must persist across pod lifecycle events. The alternative (re-authenticating on every restart) breaks the "deploy once, control from anywhere" value proposition.

**Trade-offs:** StatefulSet over Deployment adds ordered pod management overhead, but for `replicas: 1` the difference is negligible. The PVC lifecycle is tied to the StatefulSet -- deleting the StatefulSet does NOT delete the PVC (data-safe by default). Requires a StorageClass in the cluster (KIND uses `standard` by default).

### Pattern 5: KIND Image Loading Workflow

**What:** A disciplined build-load-deploy pipeline where every image rebuild is explicitly loaded into the KIND cluster via `kind load docker-image`. Never use `:latest` tag because KIND's containerd runtime does not re-pull cached tags.

**When to use:** Always, when developing against KIND. This is not optional -- it is the only reliable way to get locally-built images into KIND nodes.

**Trade-offs:** Adds a mandatory step to the dev loop. Mitigated by the Makefile wrapping it into a single `make deploy` target. Image loading transfers the full image into each KIND node's containerd store, so large images (1.5-2GB) take 30-60 seconds per load.

**Example Makefile targets:**
```makefile
IMAGE_NAME := claude-in-a-box
IMAGE_TAG  := $(shell git rev-parse --short HEAD)
KIND_CLUSTER := claude-dev

.PHONY: build load deploy cluster-up cluster-down clean

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

load: build
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) \
		--name $(KIND_CLUSTER)

deploy: load
	kubectl apply -f k8s/

cluster-up:
	kind create cluster --name $(KIND_CLUSTER) \
		--config scripts/kind/kind-config.yaml \
		|| true  # Idempotent

cluster-down:
	kind delete cluster --name $(KIND_CLUSTER)

clean: cluster-down
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
```

## Data Flow

### Remote Control Session Flow

```
[Operator on phone/browser]
    │
    │  Opens claude.ai/code or Claude mobile app
    │  Selects active Remote Control session
    ▼
[Anthropic API Servers]
    │
    │  Relays commands/responses over HTTPS
    │  (outbound connection initiated BY the container)
    ▼
[Claude Code CLI in container]  ◄──── PID 1 entrypoint exec'd
    │
    │  Processes operator instructions
    │  Invokes tools (kubectl, curl, MCP, etc.)
    ▼
[MCP Server / CLI tools]
    │
    │  kubernetes-mcp-server: K8s API via ServiceAccount token
    │  kubectl: K8s API via in-cluster config
    │  curl/dig/etc: direct network calls (egress-allowed)
    ▼
[Kubernetes API Server / Cluster Resources]
    │
    │  Responses flow back up the chain
    ▼
[Operator sees results in real-time]
```

### Authentication Flow (First Run)

```
[Operator]
    │
    │  kubectl exec -it claude-agent-0 -- bash
    ▼
[Container shell]
    │
    │  claude /login
    ▼
[Claude Code CLI]
    │
    │  Generates OAuth URL, displays in terminal
    │  Operator copies URL to browser on any device
    ▼
[Operator's browser]
    │
    │  Completes OAuth flow at claude.ai
    │  Token returned to CLI via callback
    ▼
[Claude Code CLI]
    │
    │  Stores token at ~/.claude/ (on PVC)
    │  Token persists across pod restarts
    ▼
[Subsequent starts]
    │
    │  Entrypoint finds existing token on PVC
    │  Claude Code auto-authenticates
    │  Remote Control session resumes
```

### Build and Deploy Flow (Developer)

```
[Developer workstation]
    │
    │  make deploy   (or individual targets)
    ▼
[Docker build]
    │
    │  Stage 1: Fetch tools, download binaries
    │  Stage 2: Copy onto Ubuntu 24.04, create user
    │  Output: claude-in-a-box:<git-short-hash>
    ▼
[kind load docker-image]
    │
    │  Transfers image to all KIND nodes
    │  (containerd store, not Docker daemon)
    ▼
[kubectl apply -f k8s/]
    │
    │  Creates/updates: StatefulSet, SA, ClusterRole,
    │  ClusterRoleBinding, NetworkPolicy, ConfigMap
    ▼
[KIND cluster]
    │
    │  Pod scheduled, PVC bound, container starts
    │  Entrypoint runs in configured mode
    ▼
[Verify]
    │
    │  make test (runs integration tests against live cluster)
```

### Key Data Flows

1. **Command relay:** Operator input flows: Phone/Browser --> Anthropic API --> outbound HTTPS --> Claude Code CLI --> tool execution --> response back up. The container never opens inbound ports; it maintains a persistent outbound HTTPS connection to Anthropic.

2. **K8s API access:** Claude Code (via MCP server or kubectl) --> ServiceAccount token (auto-mounted at `/var/run/secrets/kubernetes.io/serviceaccount/`) --> K8s API server on port 6443. Permissions bounded by ClusterRole.

3. **Token persistence:** OAuth token written to `~/.claude/` directory --> backed by PVC via StatefulSet volumeClaimTemplate --> survives pod restarts, rescheduling, and node failures (if using replicated storage).

4. **Image lifecycle (KIND):** Docker build on host --> `kind load` into containerd on KIND nodes --> StatefulSet pod references image by `name:tag` (never `:latest`).

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 agent (default) | Single StatefulSet, replicas: 1. PVC for token. Standard pattern. |
| 2-5 agents (multi-cluster) | One StatefulSet per target cluster. Each has its own ServiceAccount/RBAC. Shared image, different kubeconfig contexts mounted via Secrets. |
| 10+ agents (fleet) | Helm chart with values per instance. Consider a controller/operator pattern (like Agent Sandbox) for lifecycle management. ArgoCD ApplicationSet for GitOps-driven fleet. |

### Scaling Priorities

1. **First bottleneck: Image size during KIND load.** At 1.5-2GB, loading into KIND takes 30-60 seconds. Mitigate with aggressive multi-stage build layer caching and `--no-cache` only when needed.

2. **Second bottleneck: OAuth token management at scale.** Each agent instance needs its own OAuth session (one remote session per Claude Code instance). At fleet scale, this becomes a manual burden. No automated solution exists today -- flag for future automation.

3. **Third consideration: RBAC scope drift.** As agents multiply, ClusterRole permissions may need namespace-scoping (Roles instead of ClusterRoles) to enforce blast radius per agent. Helm values should support both modes.

## Anti-Patterns

### Anti-Pattern 1: Using `:latest` Tag with KIND

**What people do:** Tag images as `claude-in-a-box:latest` and reference that in K8s manifests.
**Why it's wrong:** KIND uses containerd internally, which does not re-pull `:latest` from cache. After rebuilding, the old cached image is used. The pod runs stale code with no warning.
**Do this instead:** Use `git rev-parse --short HEAD` or a build timestamp as the image tag. Update manifests to match. The Makefile should automate this.

### Anti-Pattern 2: Running Entrypoint as Shell Form

**What people do:** Use `ENTRYPOINT ["sh", "-c", "entrypoint.sh"]` or the shell form `ENTRYPOINT entrypoint.sh`.
**Why it's wrong:** The shell becomes PID 1, not the actual process. SIGTERM goes to the shell, which does not forward it to child processes. The container gets SIGKILL after the grace period, losing session state.
**Do this instead:** Use exec form `ENTRYPOINT ["/scripts/entrypoint.sh"]` and inside the script, use `exec claude ...` to replace the shell with the Claude process as PID 1.

### Anti-Pattern 3: Baking Secrets into the Image

**What people do:** Copy API keys, OAuth tokens, or kubeconfig files into the Docker image during build.
**Why it's wrong:** Secrets are visible in image layers (`docker history`), in any registry the image is pushed to, and to anyone who pulls the image. Violates security fundamentals.
**Do this instead:** Mount secrets at runtime via K8s Secrets, PVC (for OAuth tokens), or environment variables. The image should contain zero secrets.

### Anti-Pattern 4: Using Deployment Instead of StatefulSet

**What people do:** Use a Kubernetes Deployment for the Claude agent because "it's just one pod."
**Why it's wrong:** Deployments create pods with random names and do not maintain PVC affinity. On restart, a new pod gets a new PVC (or none), losing the OAuth token. The operator must re-authenticate.
**Do this instead:** StatefulSet with `replicas: 1` gives the pod a stable name (`claude-agent-0`), stable network identity, and stable PVC binding that survives restarts.

### Anti-Pattern 5: Wildcard RBAC Permissions

**What people do:** Grant `["*"]` verbs on `["*"]` resources to the agent ServiceAccount for convenience.
**Why it's wrong:** The AI agent can now delete namespaces, modify RBAC, and escalate privileges. A single misinterpreted instruction could destroy the cluster.
**Do this instead:** Start with the read-only ClusterRole. Add specific verbs on specific resources in the operator tier. Never use wildcards. Audit with `kubectl auth can-i --list --as system:serviceaccount:claude:claude-agent`.

### Anti-Pattern 6: Skipping DNS in NetworkPolicy Egress

**What people do:** Create an egress NetworkPolicy allowing only port 443, forgetting DNS.
**Why it's wrong:** All DNS resolution fails. kubectl cannot resolve the API server hostname. curl cannot resolve any domain. The entire toolkit is broken.
**Do this instead:** Always allow port 53 (UDP and TCP) in egress rules alongside port 443.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **Anthropic API** | Outbound HTTPS (443) via Remote Control protocol | Container maintains persistent connection. Timeout after ~10 min network outage. No inbound ports needed. |
| **Docker Hub / GHCR** | Build-time only (FROM, apt-get, binary downloads) | Runtime image has no registry access needed. All tools baked in at build time. |
| **claude.ai OAuth** | One-time browser redirect flow via `claude /login` | Token stored on PVC. Requires manual `kubectl exec` for first-run auth. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **Entrypoint --> Claude Code** | `exec` replaces entrypoint process | Claude Code becomes PID 1 after exec. Entrypoint sets env vars and selects mode before handoff. |
| **Claude Code --> MCP Server** | stdio transport (stdin/stdout pipes) | `kubernetes-mcp-server` runs as a child process. Configured via `.mcp.json` with `--read-only` flag. In-cluster config auto-detected. |
| **Claude Code --> CLI tools** | Subprocess execution (kubectl, curl, etc.) | Tools are on PATH. Claude Code invokes them as needed. All run as same non-root user. |
| **Pod --> K8s API Server** | HTTPS via in-cluster ServiceAccount token | Auto-mounted at `/var/run/secrets/kubernetes.io/serviceaccount/`. Permissions bounded by ClusterRole. |
| **Pod --> Cluster DNS** | UDP/TCP port 53 to kube-dns | Required for all hostname resolution. Must be allowed in NetworkPolicy. |
| **PVC --> Pod filesystem** | Volume mount at `/home/claude/.claude/` | StatefulSet `volumeClaimTemplates` ensures 1:1 PVC-pod binding. Data persists across restarts. |
| **ConfigMap --> Pod** | Volume mount or env vars | `.mcp.json` mounted as file; startup mode set as env var `CLAUDE_MODE`. |
| **Docker Compose --> Host** | `docker.sock` bind mount (optional) | Enables container to interact with host Docker daemon. Security-sensitive -- only for standalone deployments. |

## Build Order (Dependency Chain)

The following build order respects component dependencies. Each step requires the previous steps to be complete.

```
Phase 1: Container Foundation
    Dockerfile (multi-stage)
    └── Entrypoint script
    └── Tool installation + verification script
    └── Non-root user setup
    Result: Working container image that can run Claude Code

Phase 2: Local Dev Environment
    KIND cluster config
    └── Bootstrap scripts (cluster-up, cluster-down)
    └── Makefile (build, load, deploy targets)
    Result: Developer can build image and run it in KIND

Phase 3: Kubernetes Manifests
    Namespace
    └── ServiceAccount
    └── ClusterRole (reader) + ClusterRoleBinding
    └── ConfigMap (.mcp.json, mode config)
    └── StatefulSet + PVC (volumeClaimTemplate)
    └── NetworkPolicy (egress-only)
    Result: Full K8s deployment with RBAC, persistence, network isolation

Phase 4: Integration & Hardening
    MCP server configuration (kubernetes-mcp-server)
    └── OAuth login flow + token persistence verification
    └── Remote Control session verification
    └── Integration test suite
    Result: End-to-end working system

Phase 5: Production Packaging
    Helm chart (parameterized templates from Phase 3 manifests)
    └── Docker Compose reference file
    └── CI/CD pipeline (build, scan, test)
    └── Operator RBAC tier (opt-in)
    Result: Production-deployable package

Phase 6: Extensions
    Custom Claude Code skills
    └── Multi-cluster support
    └── Observability integration
    └── ArgoCD GitOps definition
    Result: Advanced operational features
```

**Dependency rationale:** The Dockerfile must exist before anything else because every downstream component (KIND loading, K8s StatefulSet, Docker Compose) references the built image. KIND must exist before K8s manifests can be tested. K8s manifests must work before Helm can templatize them. Integration tests require all prior phases. Production packaging wraps working pieces. Extensions build on a stable foundation.

## Sources

- [Kubernetes StatefulSet documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) -- HIGH confidence
- [Kubernetes RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) -- HIGH confidence
- [Kubernetes NetworkPolicy documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/) -- HIGH confidence
- [Docker multi-stage build best practices](https://docs.docker.com/build/building/best-practices/) -- HIGH confidence
- [KIND Quick Start documentation](https://kind.sigs.k8s.io/docs/user/quick-start/) -- HIGH confidence
- [kubernetes-mcp-server (containers/kubernetes-mcp-server)](https://github.com/containers/kubernetes-mcp-server) -- HIGH confidence
- [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp) -- HIGH confidence
- [Claude Code Authentication documentation](https://code.claude.com/docs/en/authentication) -- HIGH confidence
- [Helm RBAC best practices](https://helm.sh/docs/chart_best_practices/rbac/) -- HIGH confidence
- [Agent Sandbox for Kubernetes](https://www.infoq.com/news/2025/12/agent-sandbox-kubernetes/) -- MEDIUM confidence
- [Docker signal handling patterns](https://bencane.com/shutdown-signals-with-docker-entry-point-scripts-5e560f4e2d45) -- MEDIUM confidence
- [KIND CI bootstrap patterns](https://techbloc.net/archives/4991) -- MEDIUM confidence
- [Kubernetes egress NetworkPolicy recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes) -- MEDIUM confidence
- [Claude Code headless auth issue #22992](https://github.com/anthropics/claude-code/issues/22992) -- MEDIUM confidence

---
*Architecture research for: Containerized AI Agent Deployment with DevOps Debugging Toolkit*
*Researched: 2026-02-25*
