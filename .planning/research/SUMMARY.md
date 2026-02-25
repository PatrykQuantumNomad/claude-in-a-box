# Project Research Summary

**Project:** Claude In A Box — Containerized AI Agent Deployment
**Domain:** Kubernetes DevOps debugging toolkit with Claude Code as the AI agent runtime
**Researched:** 2026-02-25
**Confidence:** HIGH

## Executive Summary

Claude In A Box is a purpose-built, production-deployable container image that ships Claude Code alongside 30+ DevOps debugging tools, Kubernetes manifests, and a Helm chart — enabling engineers to debug Kubernetes clusters interactively from a phone or browser via Claude Code's Remote Control feature. The pattern is well-established: run Claude Code as a non-root process inside a Kubernetes StatefulSet, provide in-cluster `kubectl` access via a scoped ServiceAccount, and use the Remote Control relay (outbound HTTPS to Anthropic API, no inbound ports needed) as the operator interface. The unique competitive position is the combination of a pre-configured Claude Code container with in-cluster RBAC, a curated debugging toolkit, and phone-first access — no competitor delivers all three.

The recommended build approach uses Ubuntu 24.04 LTS as the base, a multi-stage Dockerfile that fetches static binaries in a downloader stage and copies them onto the runtime image, the native Claude Code installer (not the deprecated npm package), tini as PID 1, and a content-addressed image tagging strategy to prevent stale-image issues in KIND. For Kubernetes deployment, a StatefulSet with `replicas: 1` and a `volumeClaimTemplate` is the correct primitive because it provides stable pod identity and PVC affinity for OAuth token persistence — a Deployment loses the token on every pod restart. The Helm chart is the production packaging layer, with raw Kubernetes manifests used for local KIND development.

The three risks that could kill the project if ignored are: (1) OAuth authentication persistence — Claude Code has multiple known issues with credentials not surviving container restarts; the mitigation is to use `claude setup-token` to generate long-lived tokens passed as `CLAUDE_CODE_OAUTH_TOKEN` environment variables; (2) PID 1 signal handling — the entrypoint script must use `exec` to replace the shell with the Claude Code process, and tini must be installed as a safety net; (3) KIND image staleness — every rebuild must be followed by `kind load docker-image` into the named cluster, enforced by a single Makefile `make deploy` target. All three must be addressed in Phase 1, before any other work proceeds.

## Key Findings

### Recommended Stack

Ubuntu 24.04 LTS is the only viable base image given the requirement for 30+ tools including those needing glibc (tcpdump, strace). Alpine's musl libc creates incompatibilities with Go static binaries and glibc-linked tools that are not worth the ~60MB size savings. Docker Engine 29.x with BuildKit (default) enables multi-stage builds with `--mount=type=cache` for reproducible, fast builds. The target image size is under 2GB compressed (~560-680MB estimated), well within reach with disciplined layer management.

**Core technologies:**
- Ubuntu 24.04 LTS: Base image — only option that supports the full glibc-dependent debugging toolkit
- Claude Code CLI (native installer): AI agent runtime — npm installation is officially deprecated; native installer has no Node.js dependency
- tini 0.19.0: PID 1 init — required for correct SIGTERM forwarding to Claude Code; alternative to `exec` pattern
- kubectl 1.35.x: Kubernetes CLI — must match within one minor version of the target cluster
- Helm 4.1.x: Kubernetes package manager — Helm 4 released Nov 2025, Helm 3 security fixes end Nov 2026, start with 4 for new projects
- KIND 0.31.0: Local Kubernetes — official K8s testing tool, 30-second startup, amd64/arm64 support
- jq 1.8.1 / yq 4.52.4: JSON/YAML processing — install from GitHub releases, not apt (repo versions lag by 1-2 majors)
- k9s 0.50.18, stern 1.33.1, kubectx 0.9.5: K8s TUI/log/context tools — single static binaries, no dependencies

**Critical version requirements:**
- kubectl must match target cluster within ±1 minor version
- kustomize 5.8.1 specifically adds Helm 4 compatibility; earlier versions have Helm 4 issues
- Docker Compose v5.1.x uses the Compose Specification; avoid legacy v2/v3 format configs
- KIND 0.27.0+ required for containerd 2.x transfer API; older KIND fails with current Docker

### Expected Features

The full feature breakdown is in `.planning/research/FEATURES.md`.

**Must have (table stakes) — launch blockers:**
- Docker image with Claude Code, kubectl, and 30+ debugging tools — the product itself
- Helm chart with read-only RBAC (two-tier ClusterRole: reader + operator) — deployable into any cluster
- Docker Compose file — non-Kubernetes on-ramp
- Remote Control documentation and setup — the core workflow (phone-first debugging)
- CLAUDE.md with cluster-aware context — entrypoint script auto-populates environment info
- Session persistence via PVC — conversations must survive pod restarts
- KIND local development setup — one-command local environment; doubles as CI harness
- Health checks / readiness probes — K8s pod lifecycle management

**Should have (competitive differentiators) — add after validation:**
- Curated DevOps skills library — pre-built skills for pod diagnosis, network debugging, incident triage
- MCP server integration (`kubernetes-mcp-server`) — structured K8s API access reduces hallucinations
- Operator-tier RBAC with audit logging — mutation capabilities with human-reviewable trail
- Helm security profile values files — `values-readonly.yaml`, `values-operator.yaml`, `values-airgapped.yaml`
- Container image scanning and SBOM — required before enterprise adoption push

**Defer (v2+) — post product-market fit:**
- Multi-cluster support — single-cluster experience must be polished first
- Custom Go-based MCP server — only if existing Node.js MCP servers prove insufficient
- Kubernetes Operator with CRDs — kagent-style fleet management, massive scope
- External observability integration (Prometheus, Grafana, Loki) — defer until skills library matures

**Anti-features to explicitly reject:**
- Auto-remediation / self-healing — production mutations by AI agent without human approval is a liability
- Full cluster admin permissions — hallucinated kubectl commands can delete namespaces; no wildcards in RBAC
- Built-in web UI — Remote Control is already the UI; building another duplicates effort
- Multi-LLM support — product identity is Claude; K8sGPT and kagent already serve multi-LLM

### Architecture Approach

The architecture is a three-layer system: (1) Operator Layer — phone/browser accessing Anthropic's relay servers over HTTPS; (2) Deployment Layer — the container image with Claude Code CLI, an in-process MCP server, and the debugging toolkit, wrapped in a StatefulSet with RBAC and NetworkPolicy; (3) Local Development Layer — KIND cluster managed by a Makefile. The container only needs outbound HTTPS (port 443) and DNS (port 53); no inbound ports are required. This egress-only model is the key to the security posture.

The full project structure, data flow diagrams, and architectural patterns are documented in `.planning/research/ARCHITECTURE.md`.

**Major components:**
1. **Dockerfile (multi-stage)** — Downloader stage fetches static binaries; runtime stage copies onto Ubuntu 24.04, creates non-root user, installs Claude Code via native installer
2. **Entrypoint script** — Bash with `trap` + `exec`; dispatches on `$CLAUDE_MODE` (remote-control | interactive | headless); must exec to replace shell as PID 1
3. **StatefulSet + volumeClaimTemplate** — Single replica with stable pod identity; PVC at `~/.claude/` persists OAuth token across restarts
4. **Tiered RBAC** — `claude-reader` ClusterRole (get/list/watch, no secrets) as default; `claude-operator` ClusterRole (adds delete pods, exec, patch deployments) as explicit opt-in
5. **NetworkPolicy (egress-only)** — Allow port 443 (Anthropic API) + port 53 UDP/TCP (DNS) + port 6443 (K8s API server); deny all ingress
6. **MCP server (kubernetes-mcp-server)** — Runs as Claude Code child process via stdio transport; in-cluster config auto-detected; `--read-only` flag matches RBAC tier
7. **Helm chart** — Parameterized templates of the K8s manifests; values-driven RBAC tier, resource limits, security context
8. **KIND + Makefile** — `make build | load | deploy | cluster-up | cluster-down | test`; enforces build-load-deploy chain

### Critical Pitfalls

Full pitfall documentation with recovery strategies in `.planning/research/PITFALLS.md`.

1. **KIND image staleness** — After `docker build`, the KIND containerd store still has the old image; pod runs stale code silently. Prevention: always `kind load docker-image <image>:<tag> --name <cluster>` after every build; use git-SHA tags never `:latest`; set `imagePullPolicy: Never`; wrap in single Makefile `make deploy` target.

2. **OAuth token not persisting across restarts** — Claude Code has multiple known GitHub issues (anthropics/claude-code#22066, #12447, #21765) with credentials vanishing after container restart despite valid files on PVC. Prevention: use `claude setup-token` on host to generate long-lived token (~1 year); pass as `CLAUDE_CODE_OAUTH_TOKEN` env var; avoid relying on interactive OAuth flow in containers.

3. **PID 1 signal swallowing** — Bash entrypoint at PID 1 does not forward SIGTERM to Claude Code; Kubernetes sends SIGKILL after grace period, causing session state loss. Prevention: use `exec claude ...` as the final command in the entrypoint to replace the shell; install tini as a safety net (`ENTRYPOINT ["/usr/bin/tini", "--"]`); set `terminationGracePeriodSeconds: 60`.

4. **NetworkPolicy DNS blocking** — Restricting egress without explicitly allowing UDP/TCP port 53 to kube-dns breaks all name resolution, making kubectl, curl, and the entire toolkit non-functional. Prevention: every NetworkPolicy egress section must include a DNS allowance rule to `kube-system/kube-dns`; test with `kubectl exec <pod> -- nslookup kubernetes.default` after applying.

5. **RBAC wildcards creating security vulnerabilities** — Using `*` verbs/resources during development creates a cluster-takeover risk and makes it impossible to audit actual permission needs later. Prevention: define both ClusterRole tiers explicitly from day one; enumerate every resource and verb; never use wildcards; exclude `secrets` from both roles; test with `kubectl auth can-i --as=system:serviceaccount:<ns>:<sa>`.

6. **Image layer bloat** — Separate `RUN apt-get install` commands without same-layer cleanup produce 3-4GB images; KIND load times exceed 90 seconds. Prevention: single combined `RUN apt-get install` with `--no-install-recommends` and `rm -rf /var/lib/apt/lists/*` in the same layer; use BuildKit cache mounts; multi-stage build copies only binaries.

## Implications for Roadmap

The architecture research provides an explicit build-order dependency chain that maps directly to roadmap phases. The entrypoint must exist before K8s manifests can be tested; K8s manifests must work before Helm can templatize them; integration tests require all prior phases. The pitfalls research adds urgency: six of the eight critical pitfalls must be solved in Phase 1, or all subsequent phases build on a broken foundation.

### Phase 1: Container Foundation

**Rationale:** Every downstream component — KIND deployment, Helm chart, K8s manifests, Remote Control — references the built image. This must be correct before anything else is attempted. Six of eight critical pitfalls live here: image staleness, OAuth persistence, PID 1 signal handling, NetworkPolicy DNS, RBAC definition, and image layer bloat.

**Delivers:** A working container image that builds reproducibly, runs Claude Code as a non-root user, handles signals correctly, authenticates via `CLAUDE_CODE_OAUTH_TOKEN`, and contains all 30+ debugging tools verified at runtime.

**Addresses (from FEATURES.md):**
- Docker image with Claude Code, kubectl, and core debugging tools (P1 table stake)
- Authentication via environment variable (P1 table stake)
- Basic health checks (P1 table stake)

**Avoids (from PITFALLS.md):**
- KIND image staleness: git-SHA tags, `imagePullPolicy: Never`
- PID 1 signal swallowing: tini as ENTRYPOINT, `exec` in entrypoint script
- Image layer bloat: single combined RUN, `--no-install-recommends`, multi-stage build
- OAuth persistence: `CLAUDE_CODE_OAUTH_TOKEN` env var path, avoid interactive flow

**Key deliverables:** Dockerfile (multi-stage), entrypoint.sh (with exec + trap), verify-tools.sh, Makefile (build target), `.github/workflows/ci.yml` skeleton

---

### Phase 2: Local Development Environment

**Rationale:** Developers need a local target to test the image before investing in production Kubernetes manifests. KIND provides this AND doubles as the CI test harness. Building KIND infrastructure now means every subsequent phase can be validated locally. The Makefile must enforce the build-load-deploy chain to prevent stale-image issues.

**Delivers:** One-command local Kubernetes environment with the Claude-in-a-box image deployed and accessible. Also serves as CI/CD integration test infrastructure.

**Addresses (from FEATURES.md):**
- KIND local development setup (P1 table stake, also a competitive differentiator vs. all competitors)
- Docker Compose file (P1 table stake, simpler on-ramp)
- Session persistence via PVC (P1 table stake)

**Uses (from STACK.md):**
- KIND 0.31.0 with K8s 1.35 node images at SHA256 digest
- Docker Compose v5.1.x

**Avoids (from PITFALLS.md):**
- KIND image staleness: Makefile `make deploy` chains build, tag, load, apply, wait-for-ready
- PVC data loss: `Retain` reclaim policy, document volume lifecycle

**Key deliverables:** scripts/kind/ (cluster-up, cluster-down, deploy), kind-config.yaml (1 control + 2 workers), docker-compose.yml, Makefile (full target chain)

---

### Phase 3: Kubernetes Manifests and RBAC

**Rationale:** With a working image and local test environment, raw Kubernetes manifests can be developed and validated against KIND. The manifests form the foundation that Helm will later templatize — get them right here, and Helm is straightforward. RBAC must be defined with explicit permissions from the start; retrofitting least-privilege later is expensive.

**Delivers:** Complete raw Kubernetes manifest set that can be applied with `kubectl apply -f k8s/` to deploy Claude-in-a-box into any cluster with correct RBAC, persistence, and network isolation.

**Addresses (from FEATURES.md):**
- Kubernetes deployment manifests with Helm chart (P1 table stake)
- RBAC with least-privilege service accounts, two-tier (P1 table stake)
- Health checks and readiness probes (P1 table stake)
- NetworkPolicy egress-only (architectural requirement)

**Implements (from ARCHITECTURE.md):**
- StatefulSet with volumeClaimTemplate pattern (Pattern 4)
- Tiered RBAC with opt-in escalation (Pattern 2)
- Egress-only NetworkPolicy with DNS allowance (Pattern 3)

**Avoids (from PITFALLS.md):**
- RBAC wildcards: enumerate every resource/verb; exclude secrets; test with `kubectl auth can-i`
- NetworkPolicy DNS blocking: always include UDP/TCP 53 to kube-dns; verify with nslookup post-apply
- Non-root capability gaps: document which tools require NET_RAW; default pod spec has no added capabilities

**Key deliverables:** k8s/ directory (namespace, statefulset, serviceaccount, clusterrole-reader, clusterrole-operator, clusterrolebinding, networkpolicy, configmap, pvc), integration test suite (test-rbac.sh, test-networking.sh, test-persistence.sh, test-tools.sh)

---

### Phase 4: Integration and Hardening

**Rationale:** With working manifests, the end-to-end flow needs to be assembled and verified: OAuth login, token persistence across restarts, Remote Control session establishment, and MCP server connectivity. This phase converts individual working components into a coherent system. The CLAUDE.md cluster-aware context is built here because it depends on knowing the actual runtime environment.

**Delivers:** End-to-end working system: deploy to KIND, authenticate once, connect via Remote Control from phone/browser, use Claude to run debugging tools against the cluster.

**Addresses (from FEATURES.md):**
- Remote Control documentation and setup (P1 table stake — the core differentiating workflow)
- CLAUDE.md with cluster-aware context (P1 table stake, differentiator)
- Session persistence verification (P1 table stake)
- MCP server integration foundation (P2 differentiator — basic kubernetes-mcp-server setup)

**Avoids (from PITFALLS.md):**
- OAuth token expiration: `claude setup-token` long-lived token; document token lifetime; entrypoint logs auth method clearly
- Auth failure UX: entrypoint detects auth failure and prints actionable message (not raw 401 JSON)
- Remote Control connectivity: verify DNS + port 443 egress works; log "Remote Control session active" on connect

**Key deliverables:** CLAUDE.md template, entrypoint.sh auth detection logic, .mcp.json configuration, test-remote-control.sh, OAuth setup documentation, test-bootstrap.sh

---

### Phase 5: Production Packaging

**Rationale:** The raw manifests are validated and working. Now wrap them in Helm for production deployability. Add CI/CD pipeline, container scanning, and the Docker Compose reference deployment. The operator-tier RBAC is enabled here because it requires the foundation to be solid first, and audit logging is only meaningful when mutations are possible.

**Delivers:** Production-deployable Helm chart with security profile variants, CI/CD pipeline with image scanning, operator-tier RBAC with audit logging, SBOM publication.

**Addresses (from FEATURES.md):**
- Helm chart with opinionated defaults (extends P1 table stake into production quality)
- Helm security profile values files (P2 differentiator)
- Operator-tier RBAC with audit logging (P2 differentiator)
- Container image scanning and SBOM (P2 differentiator, enterprise prerequisite)

**Uses (from STACK.md):**
- Helm 4.1.x with kustomize 5.8.1 compatibility

**Key deliverables:** helm/claude-in-a-box/ (Chart.yaml, values.yaml, templates/), values-readonly.yaml, values-operator.yaml, values-airgapped.yaml, CI pipeline with Trivy scanning, SBOM generation

---

### Phase 6: Extensions and Differentiators

**Rationale:** With a stable, production-tested foundation, add the features that convert a working product into a differentiated one. The skills library requires real usage data to inform what to build first. The MCP server structured access makes skills more reliable by providing typed data instead of text-parsed CLI output.

**Delivers:** Curated DevOps skills library, network diagnostic tool variants (Cilium, Istio, Calico), pre-configured network debugging tools, and multi-cluster support documentation.

**Addresses (from FEATURES.md):**
- Curated DevOps skills library (P2 differentiator — key competitive advantage)
- Pre-configured network diagnostic tools (P2 differentiator)
- Multi-cluster support (P3 future consideration)

**Key deliverables:** .claude/skills/ directory with skills for: cluster health, pod failure diagnosis, network policy debugging, resource quota analysis, node troubleshooting, certificate debugging, DNS testing

---

### Phase Ordering Rationale

- **Container before Kubernetes:** Every K8s manifest references the image; the image must be correct and stable before testing manifests
- **KIND before Helm:** KIND provides a local target to develop and validate raw manifests before they are abstracted into Helm templates
- **Raw manifests before Helm:** Helm templates are parameterized versions of working manifests; template what is proven to work
- **Integration before packaging:** The end-to-end Remote Control flow must work in KIND before being packaged for production
- **Foundation before extensions:** Skills and MCP server depend on the core image, RBAC, and CLAUDE.md context being stable
- **Auth and signals in Phase 1:** These are gating — nothing else works if OAuth breaks or SIGTERM kills sessions mid-operation

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 4 (Integration):** Claude Code's Remote Control authentication flow has known GitHub issues and underdocumented behavior in headless/container environments. The `claude setup-token` flow and the exact credential file format should be validated against the current Claude Code version before implementation.
- **Phase 4 (MCP server):** The `kubernetes-mcp-server` (Red Hat Go binary) vs. `mcp-server-kubernetes` (Flux159 Node.js) decision needs hands-on testing. Behavior with `--read-only` flag, in-cluster config auto-detection, and stdio transport reliability should be validated early.
- **Phase 5 (Helm):** The Helm 4.x chart API has breaking changes from Helm 3. Verify chart compatibility with target cluster Helm versions before templating.

Phases with standard patterns (skip research-phase):

- **Phase 1 (Container Foundation):** Multi-stage Dockerfile, tini, non-root users, static binary downloads — all well-documented with high-confidence sources.
- **Phase 2 (KIND):** KIND setup, image loading, Makefile patterns — extensively documented, high confidence.
- **Phase 3 (Manifests):** StatefulSet, RBAC, NetworkPolicy — official Kubernetes documentation covers all patterns, high confidence.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All tool versions verified against official GitHub releases and docs. One caveat: skopeo 1.22.0 is from Feb 2025 — may have a newer release. |
| Features | MEDIUM-HIGH | Table stakes and differentiators are well-researched with multiple community implementations as reference. Feature prioritization is opinionated but defensible. |
| Architecture | HIGH | All patterns (StatefulSet, RBAC, NetworkPolicy, KIND workflow) backed by official Kubernetes documentation. MCP server integration is MEDIUM — fewer production references. |
| Pitfalls | HIGH | Most pitfalls verified against actual GitHub issues (anthropics/claude-code#22066, #12447, #21765) and community incident reports. Not theoretical — these are documented failures. |

**Overall confidence:** HIGH

### Gaps to Address

- **Claude Code version pinning:** The native installer's pinning mechanism (`bash -s <version>`) behavior and available pinnable versions should be confirmed early in Phase 1. If pinning is unreliable, the npm path (despite deprecation) may be needed for reproducibility.
- **OAuth long-lived token duration:** The `claude setup-token` long-lived token is documented as "~1 year" in community sources but not in official Anthropic docs. Token lifetime should be confirmed before building the health check and monitoring strategy around it.
- **MCP server selection:** Two viable MCP server implementations exist (`kubernetes-mcp-server` in Go from Red Hat; `mcp-server-kubernetes` in Node.js from Flux159). Performance, reliability, and in-cluster config behavior differences are not fully documented. Needs hands-on evaluation in Phase 4.
- **Remote Control session timeout:** The timeout behavior for Remote Control sessions after network outage (~10 min per architecture research) needs validation — if shorter, the NetworkPolicy must account for reconnection patterns.
- **containerd 2.x KIND compatibility:** KIND 0.27.0+ supports containerd 2.x, but exact version requirements should be pinned in documentation to prevent breakage as Docker Engine continues to update.

## Sources

### Primary (HIGH confidence)

- [Claude Code Setup Docs](https://code.claude.com/docs/en/setup) — native installer, npm deprecation, version pinning
- [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) — session architecture, requirements, phone-first workflow
- [Claude Code Authentication](https://code.claude.com/docs/en/authentication) — OAuth flow, headless auth patterns
- [Kubernetes StatefulSet docs](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) — PVC affinity, stable identity
- [Kubernetes RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) — least-privilege patterns
- [Kubernetes NetworkPolicy docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) — egress-only patterns
- [KIND documentation](https://kind.sigs.k8s.io/docs/user/quick-start/) — image loading, cluster config
- [Helm 4 release blog](https://helm.sh/blog/helm-4-released/) — Helm 4 support timeline
- [Docker BuildKit docs](https://docs.docker.com/build/buildkit/) — cache mounts, multi-stage builds
- [Claude Code Issue #22066](https://github.com/anthropics/claude-code/issues/22066) — OAuth persistence in Docker
- [Claude Code Issue #12447](https://github.com/anthropics/claude-code/issues/12447) — OAuth token expiration in autonomous workflows
- [Claude Code Issue #21765](https://github.com/anthropics/claude-code/issues/21765) — OAuth refresh token headless failure
- [PID 1 Signal Handling (Peter Malmgren)](https://petermalmgren.com/signal-handling-docker/) — exec pattern validation
- [DNS failure with NetworkPolicy (Otterize)](https://otterize.com/blog/dns-resolution-failure-in-kubernetes) — DNS blocking pitfall
- [iximiuz: KIND image loading](https://iximiuz.com/en/posts/kubernetes-kind-load-docker-image/) — stale image pitfall

### Secondary (MEDIUM confidence)

- [Metoro: Claude Code on Kubernetes](https://metoro.io/blog/claude-code-kubernetes) — community Helm chart reference
- [claudebox GitHub](https://github.com/RchGrav/claudebox) — Docker isolation patterns
- [kagent.dev](https://kagent.dev/) — CNCF AI agent framework, competitive positioning
- [kubernetes-mcp-server (Red Hat)](https://github.com/containers/kubernetes-mcp-server) — Go-based MCP implementation
- [mcp-server-kubernetes (Flux159)](https://github.com/Flux159/mcp-server-kubernetes) — Node.js MCP implementation
- [Pulumi: Claude Skills for DevOps](https://www.pulumi.com/blog/top-8-claude-skills-devops-2026/) — skills ecosystem patterns
- [Agent Sandbox for Kubernetes](https://github.com/kubernetes-sigs/agent-sandbox) — alpha-stage K8s-native agent lifecycle (monitor, not use)

### Tertiary (LOW confidence)

- [devops-toolkit container](https://github.com/tungbq/devops-toolkit) — reference for all-in-one DevOps containers (baseline comparison)
- [SRE Skill for Claude Code](https://github.com/geored/sre-skill) — community skill implementation patterns
- [DevOps Claude Skills marketplace](https://github.com/ahmedasmar/devops-claude-skills) — community skills collection patterns

---
*Research completed: 2026-02-25*
*Ready for roadmap: yes*
