# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-25)

**Core value:** Deploy once, control from anywhere -- an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.
**Current focus:** Phase 4 in progress -- Kubernetes Manifests & RBAC

## Current Position

Phase: 4 of 8 (Kubernetes Manifests & RBAC)
Plan: 1 of 2 in current phase (04-01 complete)
Status: Executing phase -- 04-01 base manifests done, 04-02 operator RBAC remaining
Last activity: 2026-02-25 -- Completed 04-01 (Base K8s manifests)

Progress: [████░░░░░░] 43%

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 4min
- Total execution time: 0.43 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-container-foundation | 2/2 | 10min | 5min |
| 02-entrypoint-authentication | 2/2 | 8min | 4min |
| 03-local-development-environment | 2/2 | 8min | 4min |
| 04-kubernetes-manifests-rbac | 1/2 | 2min | 2min |

**Recent Trend:**
- Last 5 plans: 02-01 (2min), 02-02 (6min), 03-01 (4min), 03-02 (4min), 04-01 (2min)
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

### Pending Todos

None yet.

### Blockers/Concerns

- Research flag: Claude Code OAuth persistence in containers has known issues (anthropics/claude-code#22066, #12447, #21765). Validate `CLAUDE_CODE_OAUTH_TOKEN` and `claude setup-token` behavior early in Phase 2.
- Research flag: MCP server selection (Red Hat Go vs Flux159 Node.js) needs hands-on evaluation in Phase 6.
- Research flag: Helm 4.x chart API has breaking changes from Helm 3. Verify compatibility in Phase 7.

## Session Continuity

Last session: 2026-02-25
Stopped at: Completed 04-01-PLAN.md (Base K8s manifests)
Resume file: .planning/phases/04-kubernetes-manifests-rbac/04-01-SUMMARY.md
