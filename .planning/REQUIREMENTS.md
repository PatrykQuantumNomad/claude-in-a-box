# Requirements: Claude In A Box

**Defined:** 2026-02-25
**Core Value:** Deploy once, control from anywhere -- an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Container Image

- [x] **IMG-01**: Multi-stage Dockerfile produces a deployment-ready image with Ubuntu 24.04 base under 2GB compressed
- [x] **IMG-02**: Claude Code CLI installed via npm with pinned version and auto-updater disabled
- [x] **IMG-03**: Full debugging toolkit (30+ tools) installed as static binaries with pinned versions
- [x] **IMG-04**: Container runs as non-root user (UID 10000) with tini as PID 1
- [x] **IMG-05**: Tool verification script confirms all tools execute correctly as non-root
- [ ] **IMG-06**: CI pipeline with container vulnerability scanning (Trivy) and SBOM generation

### Entrypoint & Lifecycle

- [x] **ENT-01**: Entrypoint supports three startup modes via CLAUDE_MODE env var (remote-control, interactive, headless)
- [x] **ENT-02**: Entrypoint uses exec to hand off PID 1 to Claude Code for correct SIGTERM handling
- [x] **ENT-03**: Authentication via CLAUDE_CODE_OAUTH_TOKEN env var with fallback to interactive login
- [x] **ENT-04**: Liveness and readiness probes for Kubernetes pod lifecycle management
- [x] **ENT-05**: Auth failure detection with actionable error messages (not raw 401 JSON)

### Kubernetes Deployment

- [x] **K8S-01**: StatefulSet with single replica and stable pod identity (claude-agent-0)
- [x] **K8S-02**: ServiceAccount with read-only ClusterRole (get/list/watch on pods, services, deployments, events, nodes, namespaces, configmaps, ingresses, PVCs, jobs, cronjobs, statefulsets, daemonsets, replicasets)
- [x] **K8S-03**: Egress-only NetworkPolicy allowing Anthropic API (TCP 443), K8s API server (TCP 6443), and DNS (UDP/TCP 53)
- [x] **K8S-04**: PersistentVolumeClaim for OAuth token and session persistence at ~/.claude/
- [x] **K8S-05**: Operator-tier ClusterRole (opt-in) adding delete on pods, create on pods/exec, update/patch on deployments and statefulsets
- [ ] **K8S-06**: Helm chart with parameterized templates and security profile values files (values-readonly.yaml, values-operator.yaml, values-airgapped.yaml)

### Local Development

- [ ] **DEV-01**: KIND cluster configuration with 1 control plane + 2 worker nodes
- [ ] **DEV-02**: Idempotent bootstrap, teardown, and redeploy scripts for KIND cluster
- [ ] **DEV-03**: Makefile wrapping build-load-deploy chain (make build, load, deploy, bootstrap, teardown, redeploy)
- [x] **DEV-04**: KIND integration test suite validating RBAC, networking, tool verification, persistence, and Remote Control connectivity
- [ ] **DEV-05**: Docker Compose reference file for standalone non-Kubernetes deployments

### Intelligence Layer

- [ ] **INT-01**: MCP server configuration (.mcp.json) pre-wired for kubernetes-mcp-server with read-only mode
- [ ] **INT-02**: Curated DevOps skills library for pod diagnosis, log analysis, incident triage, and network debugging

### Documentation

- [ ] **DOC-01**: README.md with setup guide, architecture overview, and usage instructions
- [ ] **DOC-02**: CLAUDE.md project context file auto-populated with cluster environment at startup

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Multi-Cluster

- **MULTI-01**: Support for multiple kubeconfig contexts for fleet debugging
- **MULTI-02**: Per-cluster RBAC configuration via Helm values

### Observability

- **OBS-01**: Grafana/Prometheus dashboards for Claude Code session metrics
- **OBS-02**: Integration with cluster log aggregation (Fluentd, Loki)

### GitOps

- **GITOPS-01**: ArgoCD Application definition for self-deploying Claude In A Box
- **GITOPS-02**: ArgoCD ApplicationSet for fleet deployment

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auto-remediation / self-healing | AI agent mutating production resources without human approval is a liability; human-in-the-loop via Remote Control IS the safety model |
| Full ClusterAdmin permissions | Hallucinated kubectl commands can delete namespaces; RBAC wildcards violate K8s security best practices |
| Built-in web UI / dashboard | Remote Control via claude.ai/code IS the web UI; building another duplicates effort |
| Multi-LLM support | Product identity is Claude; K8sGPT and kagent serve multi-LLM market |
| Custom fine-tuned model | Anthropic doesn't offer Claude fine-tuning; CLAUDE.md + skills achieve the same goal |
| Real-time event streaming | Thousands of events/minute would exhaust tokens; on-demand queries via MCP are better |
| Mobile app development | Relies on existing Claude iOS/Android app via Remote Control |
| Team/Enterprise plan support | Remote Control is currently Pro/Max only |
| Windows containers | Linux containers only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMG-01 | Phase 1: Container Foundation | Complete |
| IMG-02 | Phase 1: Container Foundation | Complete |
| IMG-03 | Phase 1: Container Foundation | Complete |
| IMG-04 | Phase 1: Container Foundation | Complete |
| IMG-05 | Phase 1: Container Foundation | Complete |
| IMG-06 | Phase 7: Production Packaging | Pending |
| ENT-01 | Phase 2: Entrypoint & Authentication | Complete |
| ENT-02 | Phase 2: Entrypoint & Authentication | Complete |
| ENT-03 | Phase 2: Entrypoint & Authentication | Complete |
| ENT-04 | Phase 2: Entrypoint & Authentication | Complete |
| ENT-05 | Phase 2: Entrypoint & Authentication | Complete |
| K8S-01 | Phase 4: Kubernetes Manifests & RBAC | Complete |
| K8S-02 | Phase 4: Kubernetes Manifests & RBAC | Complete |
| K8S-03 | Phase 4: Kubernetes Manifests & RBAC | Complete |
| K8S-04 | Phase 4: Kubernetes Manifests & RBAC | Complete |
| K8S-05 | Phase 4: Kubernetes Manifests & RBAC | Complete |
| K8S-06 | Phase 7: Production Packaging | Pending |
| DEV-01 | Phase 3: Local Development Environment | Pending |
| DEV-02 | Phase 3: Local Development Environment | Pending |
| DEV-03 | Phase 3: Local Development Environment | Pending |
| DEV-04 | Phase 5: Integration Testing | Complete |
| DEV-05 | Phase 3: Local Development Environment | Pending |
| INT-01 | Phase 6: Intelligence Layer | Pending |
| INT-02 | Phase 6: Intelligence Layer | Pending |
| DOC-01 | Phase 8: Documentation & Release | Pending |
| DOC-02 | Phase 6: Intelligence Layer | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-02-25*
*Last updated: 2026-02-25 after roadmap creation*
