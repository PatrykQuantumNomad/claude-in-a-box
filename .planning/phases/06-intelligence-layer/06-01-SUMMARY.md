---
phase: 06-intelligence-layer
plan: 01
subsystem: infra
tags: [mcp, kubernetes, skills, devops, debugging, container]

# Dependency graph
requires:
  - phase: 01-container-foundation
    provides: Dockerfile multi-stage build with non-root agent user
  - phase: 04-kubernetes-manifests-rbac
    provides: StatefulSet with PVC mount at /app/.claude
provides:
  - MCP server configuration for kubernetes-mcp-server with read-only access
  - Four DevOps skills (pod-diagnosis, log-analysis, incident-triage, network-debugging)
  - Dockerfile updated with MCP config, skills staging, and MCP permissions
affects: [06-02, 07-production-packaging]

# Tech tracking
tech-stack:
  added: [kubernetes-mcp-server]
  patterns: [skill-based-workflows, staging-for-pvc-overlay]

key-files:
  created:
    - .mcp.json
    - .claude/skills/pod-diagnosis/SKILL.md
    - .claude/skills/log-analysis/SKILL.md
    - .claude/skills/incident-triage/SKILL.md
    - .claude/skills/network-debugging/SKILL.md
  modified:
    - docker/Dockerfile

key-decisions:
  - "Skills staged to /opt/claude-skills/ (not /app/.claude/skills/) to survive PVC overlay"
  - "MCP server invoked via npx (not direct binary) for kubernetes-mcp-server npm package"
  - "mcp__kubernetes__* wildcard permission grants all MCP kubernetes tools without prompting"

patterns-established:
  - "PVC staging pattern: COPY to /opt/ staging, entrypoint copies into PVC on first start"
  - "Skill format: YAML frontmatter with keyword-rich description for Claude Code auto-loading"

requirements-completed: [INT-01, INT-02]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 6 Plan 1: MCP Config and DevOps Skills Summary

**kubernetes-mcp-server config with read-only in-cluster access plus 4 DevOps debugging skills for pod diagnosis, log analysis, incident triage, and network debugging**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T19:55:35Z
- **Completed:** 2026-02-25T19:57:47Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- MCP server configuration pre-wires kubernetes-mcp-server with --read-only and in-cluster ServiceAccount auth
- Four DevOps skills provide structured debugging workflows for common Kubernetes issues
- Dockerfile bakes MCP config and skills into the image with correct PVC staging pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MCP config and DevOps skills library** - `2a05234` (feat)
2. **Task 2: Update Dockerfile with MCP config, skills staging, and permissions** - `e475238` (feat)

**Plan metadata:** `0a52556` (docs: complete plan)

## Files Created/Modified
- `.mcp.json` - MCP server registration for kubernetes-mcp-server (stdio, npx, read-only, in-cluster)
- `.claude/skills/pod-diagnosis/SKILL.md` - CrashLoopBackOff, OOMKilled, pending pods diagnosis workflow
- `.claude/skills/log-analysis/SKILL.md` - Container log error investigation and pattern recognition
- `.claude/skills/incident-triage/SKILL.md` - Incident severity classification (P1-P4) and escalation criteria
- `.claude/skills/network-debugging/SKILL.md` - DNS, connectivity, NetworkPolicy, TLS debugging workflow
- `docker/Dockerfile` - Added mcp__kubernetes__* permission, COPY .mcp.json and skills staging

## Decisions Made
- Skills staged to /opt/claude-skills/ instead of /app/.claude/skills/ because the PVC mounts at /app/.claude/ and would overlay any files COPY'd there at build time
- MCP server invoked via npx (not a direct binary install) because kubernetes-mcp-server is an npm package; pre-installation deferred to Phase 7 optimization
- mcp__kubernetes__* wildcard permission added to settings.json to auto-allow all MCP kubernetes tools without per-call prompting

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MCP config and skills are baked into the image
- Plan 06-02 handles entrypoint updates to copy staged skills from /opt/claude-skills/ into PVC on first start
- Skills are ready for Claude Code auto-loading once copied into /app/.claude/skills/

## Self-Check: PASSED

All 7 key files verified on disk. Both task commits (2a05234, e475238) confirmed in git log.

---
*Phase: 06-intelligence-layer*
*Completed: 2026-02-25*
