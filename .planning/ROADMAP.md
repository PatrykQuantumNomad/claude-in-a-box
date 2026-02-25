# Roadmap: Claude In A Box

## Overview

Claude In A Box delivers a containerized Claude Code deployment image with a curated DevOps toolkit, Kubernetes manifests, and Helm chart for production cluster debugging via Remote Control. The build follows a strict dependency chain: container image first (everything references it), then local dev environment (everything is tested against it), then Kubernetes primitives, integration validation, intelligence layer, production packaging, and finally documentation. Eight phases deliver 26 requirements from image build to public release.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Container Foundation** - Multi-stage Dockerfile producing deployment-ready image with Ubuntu 24.04, Claude Code, and 30+ debugging tools
- [x] **Phase 2: Entrypoint & Authentication** - Startup modes, signal handling, OAuth authentication, health probes, and error UX
- [x] **Phase 3: Local Development Environment** - KIND cluster, bootstrap scripts, Makefile workflow, and Docker Compose standalone deployment
- [x] **Phase 4: Kubernetes Manifests & RBAC** - StatefulSet, tiered RBAC, NetworkPolicy, PVC persistence, and operator-tier opt-in
- [x] **Phase 5: Integration Testing** - KIND-based test suite validating RBAC, networking, tools, persistence, and Remote Control
- [x] **Phase 6: Intelligence Layer** - MCP server configuration, DevOps skills library, and cluster-aware CLAUDE.md
- [ ] **Phase 7: Production Packaging** - Helm chart with security profiles and CI/CD pipeline with vulnerability scanning
- [ ] **Phase 8: Documentation & Release** - README with setup guide, architecture overview, and usage instructions

## Phase Details

### Phase 1: Container Foundation
**Goal**: A reproducible Docker image that builds under 2GB, runs Claude Code as non-root, and contains all 30+ debugging tools verified at runtime
**Depends on**: Nothing (first phase)
**Requirements**: IMG-01, IMG-02, IMG-03, IMG-04, IMG-05
**Success Criteria** (what must be TRUE):
  1. `docker build` produces an image under 2GB compressed with no build errors
  2. `docker run <image> claude --version` prints Claude Code version as UID 10000 (non-root)
  3. `docker run <image> verify-tools.sh` confirms all 30+ tools execute successfully as non-root
  4. Image uses multi-stage build with pinned versions for every binary (no `:latest`, no unpinned `apt-get install`)
  5. tini is PID 1 inside the container (`docker exec <container> cat /proc/1/cmdline` shows tini)
**Plans**: 2 plans

Plans:
- [x] 01-01: Multi-stage Dockerfile, .dockerignore, and verify-tools.sh
- [x] 01-02: Build image, verify all success criteria, fix issues

### Phase 2: Entrypoint & Authentication
**Goal**: Container starts correctly in all three modes, handles signals for graceful shutdown, authenticates via token or interactive flow, and reports health to orchestrators
**Depends on**: Phase 1
**Requirements**: ENT-01, ENT-02, ENT-03, ENT-04, ENT-05
**Success Criteria** (what must be TRUE):
  1. Setting `CLAUDE_MODE=remote-control|interactive|headless` starts Claude Code in the corresponding mode
  2. Sending SIGTERM to the container triggers graceful Claude Code shutdown (no SIGKILL needed within 60s grace period)
  3. Setting `CLAUDE_CODE_OAUTH_TOKEN` env var authenticates Claude Code without interactive login
  4. Exec-based liveness and readiness probe scripts exit 0/1 reflecting Claude Code process health and authentication state
  5. Auth failure produces a human-readable error message with remediation steps (not raw API JSON)
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Create entrypoint, health probe scripts, and update Dockerfile
- [x] 02-02-PLAN.md — Build image, verify all Phase 2 success criteria, fix issues

### Phase 3: Local Development Environment
**Goal**: One-command local Kubernetes environment where the Claude-in-a-box image deploys, runs, and is accessible for development and testing
**Depends on**: Phase 2
**Requirements**: DEV-01, DEV-02, DEV-03, DEV-05
**Success Criteria** (what must be TRUE):
  1. `make bootstrap` creates a KIND cluster (1 control plane + 2 workers), builds the image, loads it, and deploys Claude-in-a-box with pod reaching Ready state
  2. `make teardown` destroys the KIND cluster cleanly and `make bootstrap` recreates it idempotently
  3. `make redeploy` rebuilds the image, loads into KIND, and restarts the pod without cluster recreation
  4. `docker compose up` starts Claude-in-a-box in standalone mode without Kubernetes
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — KIND cluster config, dev pod manifest, and Makefile (DEV-01, DEV-02, DEV-03)
- [x] 03-02-PLAN.md — Docker Compose standalone deployment file (DEV-05)

### Phase 4: Kubernetes Manifests & RBAC
**Goal**: Complete raw Kubernetes manifest set that deploys Claude-in-a-box with correct RBAC, network isolation, and persistence into any cluster via kubectl apply
**Depends on**: Phase 3
**Requirements**: K8S-01, K8S-02, K8S-03, K8S-04, K8S-05
**Success Criteria** (what must be TRUE):
  1. `kubectl apply -f k8s/` deploys a StatefulSet with stable pod identity (claude-agent-0) and PVC at ~/.claude/ persisting across pod restarts
  2. The default ServiceAccount can get/list/watch pods, services, deployments, events, nodes, namespaces, configmaps, ingresses, PVCs, jobs, cronjobs, statefulsets, daemonsets, and replicasets -- but cannot access secrets or perform mutations
  3. The operator-tier ClusterRole (opt-in via separate binding) adds delete pods, create pods/exec, and update/patch deployments and statefulsets
  4. NetworkPolicy allows only egress to Anthropic API (TCP 443), K8s API server (TCP 6443), and DNS (UDP/TCP 53) -- all ingress denied
  5. Pod restarts preserve OAuth token and session data (data on PVC survives `kubectl delete pod claude-agent-0`)
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md — Base K8s manifests: ServiceAccount, RBAC reader, NetworkPolicy, StatefulSet with PVC (K8S-01, K8S-02, K8S-03, K8S-04)
- [x] 04-02-PLAN.md — Operator RBAC overlay and Makefile integration (K8S-05)

### Phase 5: Integration Testing
**Goal**: Automated test suite that validates the complete system works end-to-end in a KIND cluster before any code is shipped
**Depends on**: Phase 4
**Requirements**: DEV-04
**Success Criteria** (what must be TRUE):
  1. `make test` runs the full integration suite against a KIND cluster and reports pass/fail for each test category (RBAC, networking, tools, persistence, Remote Control)
  2. RBAC tests verify both reader and operator tier permissions using `kubectl auth can-i` assertions
  3. Networking tests confirm DNS resolution, Anthropic API egress, and K8s API access from inside the pod
  4. Persistence tests verify OAuth token and session data survive pod deletion and recreation
  5. Tool verification tests confirm all 30+ debugging tools execute correctly inside the running pod
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Test infrastructure: KIND test cluster config, Calico CNI install, BATS setup, test helpers, Makefile targets
- [x] 05-02-PLAN.md — Test suite: RBAC, networking, tools, persistence, and Remote Control BATS test files

### Phase 6: Intelligence Layer
**Goal**: Claude Code running inside the cluster has structured Kubernetes API access via MCP and pre-built skills for common DevOps tasks, with auto-populated cluster context
**Depends on**: Phase 4
**Requirements**: INT-01, INT-02, DOC-02
**Success Criteria** (what must be TRUE):
  1. Claude Code inside the pod can use MCP tools to query Kubernetes resources (pods, deployments, services) without shelling out to kubectl
  2. Pre-built DevOps skills for pod diagnosis, log analysis, incident triage, and network debugging are available in Claude Code's skill set
  3. CLAUDE.md inside the container is auto-populated at startup with cluster name, namespace, node count, Kubernetes version, and available tools
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — MCP config, DevOps skills library, and Dockerfile updates (INT-01, INT-02)
- [x] 06-02-PLAN.md — CLAUDE.md generation script and entrypoint wiring (DOC-02)

### Phase 7: Production Packaging
**Goal**: Helm chart enables parameterized deployment into any production cluster, and CI/CD pipeline ensures every image is scanned and traceable
**Depends on**: Phase 5, Phase 6
**Requirements**: K8S-06, IMG-06
**Success Criteria** (what must be TRUE):
  1. `helm install claude-agent ./helm/claude-in-a-box` deploys a working Claude-in-a-box instance using default values
  2. Three security profile values files (values-readonly.yaml, values-operator.yaml, values-airgapped.yaml) produce correct RBAC and NetworkPolicy configurations
  3. CI pipeline builds the image, runs Trivy vulnerability scan, generates SBOM, and publishes artifacts on every push
  4. `helm template` output matches the validated raw manifests from Phase 4 (Helm wraps, not rewrites)
**Plans**: 2 plans

Plans:
- [ ] 07-01-PLAN.md — Helm chart with templates, security profile values files, and golden file tests (K8S-06)
- [x] 07-02-PLAN.md — CI pipeline with Docker build, Trivy scan, SBOM generation, and Helm validation (IMG-06)

### Phase 8: Documentation & Release
**Goal**: A new user can go from zero to running Claude-in-a-box in their cluster by following the README alone
**Depends on**: Phase 7
**Requirements**: DOC-01
**Success Criteria** (what must be TRUE):
  1. README contains quickstart instructions that a Kubernetes-literate user can follow to deploy Claude-in-a-box in under 10 minutes
  2. README includes architecture diagram showing the three-layer system (operator, deployment, local dev) and data flow
  3. README documents all three deployment methods (KIND local, Docker Compose standalone, Helm production) with working commands
  4. README covers troubleshooting for the top 5 failure modes identified during development (auth, networking, image staleness, signals, RBAC)
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8
Note: Phase 5 and Phase 6 can execute in parallel (both depend on Phase 4, neither depends on the other).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Container Foundation | 2/2 | Complete | 2026-02-25 |
| 2. Entrypoint & Authentication | 2/2 | Complete | 2026-02-25 |
| 3. Local Development Environment | 2/2 | Complete | 2026-02-25 |
| 4. Kubernetes Manifests & RBAC | 2/2 | Complete | 2026-02-25 |
| 5. Integration Testing | 2/2 | Complete | 2026-02-25 |
| 6. Intelligence Layer | 2/2 | Complete | 2026-02-25 |
| 7. Production Packaging | 1/2 | In progress | - |
| 8. Documentation & Release | 0/0 | Not started | - |
