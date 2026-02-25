---
phase: 01-container-foundation
plan: 01
subsystem: infra
tags: [docker, dockerfile, multi-stage, ubuntu, claude-code, sre-tools, tini, non-root]

requires:
  - phase: none
    provides: first phase - no dependencies
provides:
  - Multi-stage Dockerfile producing deployment-ready image
  - Tool verification script for 39 tools (35 active + 4 privileged)
  - .dockerignore for build context exclusions
affects: [02-entrypoint-authentication, 03-local-development, all-subsequent-phases]

tech-stack:
  added: [docker, ubuntu-24.04, node-22, claude-code, tini, kubectl, helm, k9s, stern, kubectx, jq, yq, trivy, grype]
  patterns: [multi-stage-build, non-root-container, pid1-init, version-pinning, architecture-aware-downloads]

key-files:
  created: [docker/Dockerfile, docker/.dockerignore, scripts/verify-tools.sh]
  modified: []

key-decisions:
  - "Used UID 10000/GID 10000 per CONTEXT.md locked decision (overrides ROADMAP's UID 1000 reference)"
  - "Separate RUN commands per tool download for better Docker layer caching"
  - "Node.js installed via direct binary download from nodejs.org (not nvm or nodesource)"
  - "Claude Code installed via npm per locked decision, with DISABLE_INSTALLATION_CHECKS=1 to suppress deprecation warning"
  - "apt packages not pinned to exact versions -- Ubuntu 24.04 tag acts as the version pin"

patterns-established:
  - "ARG version pinning: All tool versions declared as global ARGs before first FROM, redeclared in each stage"
  - "Architecture-aware downloads: TARGETARCH with case statements for naming convention mismatches (e.g., Trivy uses 64bit/ARM64)"
  - "Privileged tool handling: Tools needing capabilities (strace, tcpdump, perf, bpftrace) checked for existence only in verify-tools.sh"
  - "Claude Code pre-configuration: .claude.json for onboarding bypass, settings.json for permissions, ENV vars for telemetry/updater"

requirements-completed: [IMG-01, IMG-02, IMG-03, IMG-04, IMG-05]

duration: 2min
completed: 2026-02-25
---

# Phase 1 Plan 1: Multi-Stage Dockerfile and Tool Verification Summary

**3-stage Dockerfile with 13 pinned tool versions, 39-tool verification script, and non-root agent user (UID 10000) with tini PID 1 and pre-configured Claude Code**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T15:10:37Z
- **Completed:** 2026-02-25T15:12:52Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Created 261-line multi-stage Dockerfile with 3 stages (tools-downloader, claude-installer, runtime)
- Declared 13 global ARG version pins covering all static binary tools
- Installed 32+ tools: 10 static binaries downloaded with architecture-aware URLs + 20+ apt packages
- Created 168-line verify-tools.sh with 39 check_tool invocations covering every installed tool
- Pre-configured Claude Code with onboarding bypass, permission grants, and telemetry disabled
- Zero `:latest` tags in entire Dockerfile

## Task Commits

Each task was committed atomically:

1. **Task 1: Create multi-stage Dockerfile with all tools, Claude Code, and non-root user** - `7439f77` (feat)
2. **Task 2: Create tool verification script** - `59d1f50` (feat)

**Plan metadata:** `a8797cd` (docs: complete plan)

## Files Created/Modified

- `docker/Dockerfile` - 261-line multi-stage Dockerfile with 3 stages, 13 ARG version pins, 32+ tools, non-root user, tini entrypoint
- `docker/.dockerignore` - Build context exclusions (.git, .planning, .claude, *.md, LICENSE)
- `scripts/verify-tools.sh` - 168-line tool verification script with 39 checks, privileged tool skip handling, and summary reporting

## Decisions Made

- **UID 10000 over UID 1000:** CONTEXT.md locks UID 10000/GID 10000 as a deliberate security choice (high UIDs avoid host user collision). ROADMAP references "UID 1000" but CONTEXT.md is authoritative.
- **Separate RUN per tool download:** Each static binary download is a separate RUN command for Docker layer caching. Changing one tool version only re-downloads that tool, not all 10.
- **Node.js direct binary:** Downloaded from nodejs.org directly rather than using nvm or nodesource apt repo. Simpler in Docker, no external repo dependency.
- **No exact apt version pins:** Ubuntu 24.04 tag is the version pin for apt packages. Exact pins (e.g., `curl=8.5.0-2`) break when security updates change versions.
- **DISABLE_INSTALLATION_CHECKS=1:** Added to suppress npm deprecation warning for Claude Code installation (npm is deprecated but functional per locked decision).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Dockerfile ready for `docker build` in Plan 01-02 (build verification)
- verify-tools.sh ready to be copied into image and executed as runtime verification
- All success criteria for Phase 1 can now be validated: image build, tool verification, non-root user, tini PID 1

## Self-Check: PASSED

- docker/Dockerfile: FOUND
- docker/.dockerignore: FOUND
- scripts/verify-tools.sh: FOUND
- Commits matching 01-01: 2 (7439f77, 59d1f50)

---
*Phase: 01-container-foundation*
*Completed: 2026-02-25*
