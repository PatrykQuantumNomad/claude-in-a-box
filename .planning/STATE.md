# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-25)

**Core value:** Deploy once, control from anywhere -- an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.
**Current focus:** Phase 6 in progress -- MCP config and DevOps skills delivered (06-01), entrypoint wiring next (06-02)

## Current Position

Phase: 6 of 8 (Intelligence Layer)
Plan: 1 of 2 in current phase (06-01 complete)
Status: Plan 06-01 complete -- MCP config, 4 DevOps skills, and Dockerfile updates shipped
Last activity: 2026-02-25 -- Completed 06-01 (MCP config, DevOps skills library, Dockerfile updates)

Progress: [███████░░░] 68%

## Performance Metrics

**Velocity:**
- Total plans completed: 11
- Average duration: 3min
- Total execution time: 0.57 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-container-foundation | 2/2 | 10min | 5min |
| 02-entrypoint-authentication | 2/2 | 8min | 4min |
| 03-local-development-environment | 2/2 | 8min | 4min |
| 04-kubernetes-manifests-rbac | 2/2 | 4min | 2min |
| 05-integration-testing | 2/2 | 4min | 2min |
| 06-intelligence-layer | 1/2 | 2min | 2min |

**Recent Trend:**
- Last 5 plans: 04-01 (2min), 04-02 (2min), 05-01 (2min), 05-02 (2min), 06-01 (2min)
- Trend: stable/improving

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: 8 phases derived from 26 requirements at comprehensive depth
- Roadmap: Phase 5 (Integration Testing) and Phase 6 (Intelligence Layer) can run in parallel
- 01-01: UID 10000/GID 10000 per CONTEXT.md (overrides ROADMAP UID 1000 reference)
- 01-01: Separate RUN per tool download for Docker layer caching
- 01-01: Node.js via direct binary download from nodejs.org
- 01-01: Claude Code via npm with DISABLE_INSTALLATION_CHECKS=1 for deprecation warning suppression
- 01-01: No exact apt version pins -- Ubuntu 24.04 tag is the version pin
- 01-02: Fixed claude symlink to @anthropic-ai/claude-code/cli.js (original .bin/claude path doesn't exist)
- 01-02: Fixed vim.tiny binary name in verify-tools.sh (vim-tiny package provides vim.tiny not vim)
- 02-01: No claude auth status in entrypoint (file/env checks only, avoids 3-5s Node.js latency)
- 02-01: Exec probes over HTTP health server (avoids orphaned background process problem)
- 02-01: Headless mode requires CLAUDE_PROMPT env var (single-prompt execution pattern)
- 02-02: Added validate_mode() before validate_auth() for correct error routing
- 03-01: Both liveness and readiness probes use healthcheck.sh (pgrep-based, no auth required in dev)
- 03-01: Bare Pod manifest for Phase 3; StatefulSet deferred to Phase 4
- 03-02: Volume mount at /app/.claude (container user home is /app, not /home/agent)
- 04-01: No namespace manifest -- default namespace does not need explicit creation
- 04-01: CIDR 0.0.0.0/0 for egress 443/6443 -- Anthropic IPs rotate, API server IP varies per cluster
- 04-01: Python YAML validation instead of kubectl dry-run (no cluster context available at plan time)
- 04-02: Operator overlay in k8s/overlays/ not k8s/base/ -- directory separation ensures opt-in semantics
- 04-02: POD_MANIFEST variable kept for backward compat but no longer used by deploy/redeploy
- 04-02: Python YAML validation instead of kubectl dry-run (consistent with 04-01)
- 05-01: Calico 3.31.4 as CNI for NetworkPolicy enforcement in KIND (kindnet does not enforce)
- 05-01: BATS v1.13.0 cloned locally into tests/bats/ (gitignored, not committed)
- 05-01: FELIX_IGNORELOOSERPF=true for KIND compatibility with Calico RPF checks
- 05-01: test-setup reuses bootstrap pattern with KIND_TEST_CONFIG for Calico-enabled cluster
- 05-02: One @test per RBAC resource for granular pass/fail visibility (22 individual RBAC tests)
- 05-02: Operator overlay applied in first operator test, removed in teardown_file for clean state
- 05-02: Remote Control tests validate network path only (HTTPS + TLS) -- full testing requires real OAuth token
- 05-02: Persistence test uses deterministic marker string with retry loop for exec path readiness
- 06-01: Skills staged to /opt/claude-skills/ (not /app/.claude/skills/) to survive PVC overlay at /app/.claude/
- 06-01: MCP server invoked via npx (not direct binary) for kubernetes-mcp-server npm package
- 06-01: mcp__kubernetes__* wildcard permission grants all MCP kubernetes tools without prompting

### Pending Todos

None yet.

### Blockers/Concerns

- Research flag: Claude Code OAuth persistence in containers has known issues (anthropics/claude-code#22066, #12447, #21765). Validate `CLAUDE_CODE_OAUTH_TOKEN` and `claude setup-token` behavior early in Phase 2.
- RESOLVED: MCP server selection -- using kubernetes-mcp-server via npx with --read-only and --cluster-provider in-cluster (06-01).
- Research flag: Helm 4.x chart API has breaking changes from Helm 3. Verify compatibility in Phase 7.

## Session Continuity

Last session: 2026-02-25
Stopped at: Completed 06-01-PLAN.md (MCP config, DevOps skills library, Dockerfile updates)
Resume file: .planning/phases/06-intelligence-layer/06-01-SUMMARY.md
