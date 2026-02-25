---
phase: 06-intelligence-layer
plan: 02
subsystem: infra
tags: [kubernetes, claude-md, entrypoint, shell, docker, mcp, skills]

# Dependency graph
requires:
  - phase: 06-intelligence-layer/01
    provides: MCP config, DevOps skills staged in /opt/claude-skills/, Dockerfile with skills COPY
provides:
  - generate-claude-md.sh script for cluster context discovery at startup
  - Entrypoint skills staging from /opt/claude-skills/ to PVC-mounted /app/.claude/skills/
  - Entrypoint CLAUDE.md generation before Claude Code exec
  - Dockerfile wiring for generate-claude-md.sh
affects: [07-production-packaging, 08-documentation]

# Tech tracking
tech-stack:
  added: [jq (K8s API parsing), curl (K8s API calls)]
  patterns: [ServiceAccount token auth for K8s API, standalone mode fallback, non-fatal pre-exec setup]

key-files:
  created: [scripts/generate-claude-md.sh]
  modified: [scripts/entrypoint.sh, docker/Dockerfile]

key-decisions:
  - "Standalone mode exits 0 (not 1) -- Docker Compose is a valid deployment target, not an error"
  - "CLAUDE.md generation failure is non-fatal -- entrypoint continues to Claude Code even if K8s API is unreachable"
  - "Skills staging only on first start (checks for /app/.claude/skills/ existence) to preserve user modifications"

patterns-established:
  - "Pre-exec setup pattern: entrypoint runs setup steps (skills staging, context generation) before exec-ing into main process"
  - "Standalone detection via ServiceAccount token path existence"

requirements-completed: [DOC-02]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 6 Plan 2: CLAUDE.md Generation and Entrypoint Wiring Summary

**generate-claude-md.sh queries K8s API for cluster context and writes /app/CLAUDE.md at startup, with entrypoint wiring for skills staging and pre-exec setup**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T20:02:04Z
- **Completed:** 2026-02-25T20:03:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created generate-claude-md.sh that queries K8s API via ServiceAccount token for cluster version, node count, namespace, and writes a context-rich /app/CLAUDE.md
- Standalone mode detection writes a minimal fallback CLAUDE.md when no ServiceAccount token exists (Docker Compose / local)
- Wired skills staging into entrypoint: copies /opt/claude-skills/ to PVC-mounted /app/.claude/skills/ on first start
- Wired CLAUDE.md generation into entrypoint before mode dispatch (non-fatal on failure)
- Updated Dockerfile to COPY and chmod generate-claude-md.sh

## Task Commits

Each task was committed atomically:

1. **Task 1: Create generate-claude-md.sh script** - `12e4d79` (feat)
2. **Task 2: Wire skills staging and CLAUDE.md generation into entrypoint and Dockerfile** - `671ce54` (feat)

## Files Created/Modified
- `scripts/generate-claude-md.sh` - Queries K8s API and writes /app/CLAUDE.md with cluster context, MCP tools, skills, CLI tools, and guidelines
- `scripts/entrypoint.sh` - Added skills staging and CLAUDE.md generation sections between validate_auth and mode dispatch
- `docker/Dockerfile` - Added COPY and chmod for generate-claude-md.sh

## Decisions Made
- Standalone mode exits 0 (not 1) -- Docker Compose is a valid deployment target, not an error
- CLAUDE.md generation failure is non-fatal -- entrypoint continues to Claude Code even if K8s API is unreachable
- Skills staging only triggers on first start (checks for /app/.claude/skills/ existence) to preserve user modifications after initial deploy

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 6 (Intelligence Layer) is now complete: MCP config (06-01) + skills + CLAUDE.md generation (06-02)
- Ready for Phase 7 (Production Packaging): Helm chart and CI/CD pipeline
- All Dockerfile changes are cumulative and compatible with existing build chain

## Self-Check: PASSED

All key files verified on disk. All commit hashes found in git log.

---
*Phase: 06-intelligence-layer*
*Completed: 2026-02-25*
