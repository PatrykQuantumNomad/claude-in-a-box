# Claude In A Box

## What This Is

A containerized Claude Code deployment image pre-configured with Remote Control and a curated DevOps debugging toolkit, purpose-built for Kubernetes and Docker Compose environments. When deployed inside a cluster, Claude Code gains direct access to the internal network, APIs, and services. Operators connect from their phone (Claude mobile app) or browser (claude.ai/code) via Remote Control — turning any device into a full cluster operations terminal.

## Core Value

Deploy once, control from anywhere — an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Multi-stage Dockerfile producing a deployment-ready image with Ubuntu 24.04 base, Claude Code CLI, and full debugging toolkit
- [ ] Entrypoint script supporting multiple startup modes (remote-control, interactive, headless) with graceful SIGTERM handling
- [ ] KIND cluster configuration (1 control plane + 2 workers) with idempotent bootstrap, teardown, and redeploy scripts
- [ ] Kubernetes manifests: StatefulSet, ServiceAccount, ClusterRole (read-only), ClusterRoleBinding, NetworkPolicy, ConfigMap, PVC
- [ ] Docker Compose reference file for standalone deployments with Docker socket mount
- [ ] Makefile wrapping all KIND and build scripts for developer workflow automation
- [ ] Interactive OAuth login flow for first-run authentication inside the container with token persistence via volume mount
- [ ] RBAC operator tier (opt-in) for active debugging operations (pod restart, exec, rollout restart)
- [ ] Helm chart for parameterized production Kubernetes deployments
- [ ] MCP server configuration (.mcp.json) pre-wired for kubernetes-mcp-server and common cluster tools
- [ ] CI/CD pipeline with automated image builds, vulnerability scanning, and KIND-based integration tests
- [ ] KIND integration test suite validating bootstrap, RBAC, networking, tool verification, persistence, and Remote Control
- [ ] Custom Claude Code skills for common DevOps tasks (log analysis, incident triage, manifest validation)
- [ ] Multi-cluster support for managing multiple Kubernetes contexts
- [ ] Observability integration with Grafana/Prometheus dashboards for session metrics
- [ ] GitOps integration via ArgoCD Application definition for self-deploying Claude In A Box
- [ ] README.md with setup guide, architecture overview, and usage instructions
- [ ] CLAUDE.md project context file for AI agents working on the repository

### Out of Scope

- Mobile app development — relies on existing Claude iOS/Android app via Remote Control
- Custom Anthropic API proxy — uses standard outbound HTTPS to Anthropic API
- Multi-tenant session sharing — each deployment instance runs a single Claude Code session
- Team/Enterprise plan support — Remote Control is currently Pro/Max only
- Windows container support — Linux containers only
- Inbound port exposure — Remote Control uses outbound HTTPS only, no ingress needed

## Context

- Claude Code Remote Control enables the core value proposition: outbound-only HTTPS relay to Anthropic API, no inbound ports, session sync across devices, auto-reconnect on network drops
- Remote Control requires Pro or Max plan subscription (not API keys, not Team/Enterprise)
- Authentication is via OAuth flow through claude.ai (`claude /login`), not API keys
- KIND (Kubernetes in Docker) is the local development and testing environment — the KIND cluster is itself a deliverable
- KIND uses containerd internally, so `:latest` tags are never re-pulled from cache — explicit version tags required
- Images must be explicitly loaded into KIND via `kind load docker-image` after every rebuild
- The debugging toolkit includes 30+ tools across Kubernetes, networking, system diagnostics, container runtime, and observability categories
- All tools must work as non-root user inside the container
- Target image size: under 2GB compressed, with full toolkit included (completeness over size)

## Constraints

- **Auth method**: OAuth flow only — API keys do not support Remote Control
- **Plan requirement**: Anthropic Pro or Max subscription required
- **Image size**: Under 2GB compressed to remain practical for CI/CD pulls
- **Security**: Non-root execution, no secrets baked into image, read-only root filesystem where possible
- **Tool versions**: All installations use explicit version pins for reproducible builds
- **KIND compatibility**: Never use `:latest` tags; always load images explicitly after rebuild
- **Session limit**: One remote session per Claude Code instance
- **Network timeout**: Extended outages (~10 minutes) will timeout Remote Control sessions

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Ubuntu 24.04 LTS base image | Familiar, good apt ecosystem for tool installation, solid debugging baseline | — Pending |
| Full debugging toolkit (no trimming) | Completeness over image size — include all listed tools even near 2GB limit | — Pending |
| KIND for local dev/testing | Production-fidelity Kubernetes without cloud costs, cluster config is a deliverable | — Pending |
| Interactive OAuth login for first run | Simplest auth UX — exec into container, run `claude /login`, token persists via volume | — Pending |
| Personal project going open source | Build for own use first, open source for community | — Pending |
| All 3 phases in roadmap | Map full vision (Foundation → Hardening → Extensions) but build Foundation first | — Pending |
| KIND bootstrap as priority path | First working e2e: build image → create KIND cluster → deploy → verify Claude Code running | — Pending |

---
*Last updated: 2026-02-25 after initialization*
