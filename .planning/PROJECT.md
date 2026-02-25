# Claude In A Box

## What This Is

A containerized Claude Code deployment image pre-configured with Remote Control and a curated DevOps debugging toolkit (32+ tools), purpose-built for Kubernetes and Docker Compose environments. When deployed inside a cluster, Claude Code gains direct access to the internal network, APIs, and services. Operators connect from their phone (Claude mobile app) or browser (claude.ai/code) via Remote Control — turning any device into a full cluster operations terminal. Ships with Helm chart, CI/CD pipeline, and integration test suite.

## Core Value

Deploy once, control from anywhere — an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.

## Requirements

### Validated

- ✓ Multi-stage Dockerfile producing a deployment-ready image with Ubuntu 24.04 base, Claude Code CLI, and full debugging toolkit — v1.0
- ✓ Entrypoint script supporting multiple startup modes (remote-control, interactive, headless) with graceful SIGTERM handling — v1.0
- ✓ KIND cluster configuration (1 control plane + 2 workers) with idempotent bootstrap, teardown, and redeploy scripts — v1.0
- ✓ Kubernetes manifests: StatefulSet, ServiceAccount, ClusterRole (read-only), ClusterRoleBinding, NetworkPolicy, ConfigMap, PVC — v1.0
- ✓ Docker Compose reference file for standalone deployments — v1.0
- ✓ Makefile wrapping all KIND and build scripts for developer workflow automation — v1.0
- ✓ OAuth authentication via CLAUDE_CODE_OAUTH_TOKEN env var with token persistence via PVC — v1.0
- ✓ RBAC operator tier (opt-in) for active debugging operations (pod restart, exec, rollout restart) — v1.0
- ✓ Helm chart with 3 security profiles (readonly, operator, airgapped) for production deployments — v1.0
- ✓ MCP server configuration (.mcp.json) pre-wired for kubernetes-mcp-server with read-only mode — v1.0
- ✓ CI/CD pipeline with Docker build, Trivy vulnerability scanning, SBOM generation, and KIND-based integration tests — v1.0
- ✓ 35-test BATS integration suite validating RBAC, networking, tool verification, persistence, and Remote Control — v1.0
- ✓ 4 DevOps skills for pod diagnosis, log analysis, incident triage, and network debugging — v1.0
- ✓ README.md with setup guide, architecture diagram, 3 deployment methods, and troubleshooting — v1.0
- ✓ CLAUDE.md auto-populated at startup with cluster name, namespace, node count, and available tools — v1.0

### Active

- [ ] Multi-cluster support for managing multiple Kubernetes contexts
- [ ] Observability integration with Grafana/Prometheus dashboards for session metrics
- [ ] GitOps integration via ArgoCD Application definition for self-deploying Claude In A Box

### Out of Scope

- Mobile app development — relies on existing Claude iOS/Android app via Remote Control
- Custom Anthropic API proxy — uses standard outbound HTTPS to Anthropic API
- Multi-tenant session sharing — each deployment instance runs a single Claude Code session
- Team/Enterprise plan support — Remote Control is currently Pro/Max only
- Windows container support — Linux containers only
- Inbound port exposure — Remote Control uses outbound HTTPS only, no ingress needed
- Auto-remediation / self-healing — human-in-the-loop via Remote Control IS the safety model
- Full ClusterAdmin permissions — RBAC wildcards violate K8s security best practices
- Built-in web UI / dashboard — Remote Control via claude.ai/code IS the web UI
- Real-time event streaming — on-demand queries via MCP are more token-efficient

## Context

Shipped v1.0 with 1,945 lines of project code across Shell, YAML, Dockerfile, Helm templates, and BATS tests.

Tech stack: Docker (multi-stage build), Kubernetes (StatefulSet, RBAC, NetworkPolicy), Helm v3, GitHub Actions, BATS, KIND with Calico CNI, kubernetes-mcp-server via MCP.

Image: 1.42GB with 32+ tools. Non-root (UID 10000), tini PID 1.

Three deployment methods: KIND local dev (`make bootstrap`), Docker Compose standalone (`docker compose up`), Helm production (`helm install`).

Known considerations:
- OAuth persistence in containers has known upstream issues (anthropics/claude-code#22066, #12447, #21765)
- `human_needed` runtime verifications for KIND bootstrap and Docker Compose flows (verified statically, not yet run by human)

## Constraints

- **Auth method**: OAuth flow only — API keys do not support Remote Control
- **Plan requirement**: Anthropic Pro or Max subscription required
- **Image size**: Under 2GB compressed to remain practical for CI/CD pulls (achieved 1.42GB)
- **Security**: Non-root execution, no secrets baked into image, read-only root filesystem where possible
- **Tool versions**: All installations use explicit version pins for reproducible builds
- **KIND compatibility**: Never use `:latest` tags; always load images explicitly after rebuild
- **Session limit**: One remote session per Claude Code instance
- **Network timeout**: Extended outages (~10 minutes) will timeout Remote Control sessions

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Ubuntu 24.04 LTS base image | Familiar, good apt ecosystem for tool installation, solid debugging baseline | ✓ Good — 1.42GB image, all 32+ tools install cleanly |
| Full debugging toolkit (no trimming) | Completeness over image size — include all listed tools even near 2GB limit | ✓ Good — 1.42GB well under 2GB limit |
| KIND for local dev/testing | Production-fidelity Kubernetes without cloud costs, cluster config is a deliverable | ✓ Good — Calico CNI enables real NetworkPolicy testing |
| Interactive OAuth login for first run | Simplest auth UX — exec into container, run `claude /login`, token persists via volume | ✓ Good — CLAUDE_CODE_OAUTH_TOKEN env var also supported |
| Personal project going open source | Build for own use first, open source for community | ✓ Good — comprehensive README and Helm chart ready |
| 9 phases in roadmap (expanded from 8) | Phase 9 added for tech debt cleanup from milestone audit | ✓ Good — all audit items closed |
| KIND bootstrap as priority path | First working e2e: build image → create KIND cluster → deploy → verify Claude Code running | ✓ Good — Phase 3 validated full pipeline early |
| Exec probes over HTTP health server | Avoids orphaned background process inside container | ✓ Good — healthcheck.sh and readiness.sh are simple pgrep-based |
| Skills staged to /opt/claude-skills/ | Survives PVC overlay at /app/.claude/ mount point | ✓ Good — entrypoint copies to PVC on first start |
| Calico CNI for test cluster | kindnet does not enforce NetworkPolicy; Calico does | ✓ Good — 5 networking tests validate real policy enforcement |
| Separate test cluster name | Dev and test KIND clusters must coexist without collision | ✓ Good — claude-in-a-box-test isolates test environment |
| BATS integration tests in CI | 35 tests must run automatically, not just manually | ✓ Good — parallel CI job with KIND + Calico |

---
*Last updated: 2026-02-25 after v1.0 milestone*
