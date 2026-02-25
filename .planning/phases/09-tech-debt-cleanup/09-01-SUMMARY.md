---
phase: 09-tech-debt-cleanup
plan: 01
subsystem: infra
tags: [docker, dockerignore, kubernetes, helm, readiness-probe, requirements]

# Dependency graph
requires:
  - phase: 01-container-foundation
    provides: Dockerfile and docker/.dockerignore
  - phase: 02-entrypoint-authentication
    provides: readiness.sh probe script
  - phase: 04-kubernetes-manifests-rbac
    provides: StatefulSet manifest with probes
  - phase: 07-production-packaging
    provides: Helm chart with values and golden files
  - phase: 08-documentation-release
    provides: README.md
provides:
  - Correct .dockerignore at repo root excluding .git, .planning, tests/, etc. from build context
  - Auth-aware readiness probe (readiness.sh) in production manifests
  - All 26 v1 requirements marked complete in REQUIREMENTS.md
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ".dockerignore negation pattern (!.claude/skills/) to allow specific subdirectories through exclusion"

key-files:
  created:
    - .dockerignore
  modified:
    - k8s/base/04-statefulset.yaml
    - helm/claude-in-a-box/values.yaml
    - helm/claude-in-a-box/tests/golden/values.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-readonly.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-operator.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-airgapped.golden.yaml
    - README.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "Added !.claude/skills/ negation pattern to .dockerignore to avoid breaking COPY directive"

patterns-established: []

requirements-completed: [DEV-01, DEV-02, DEV-03, DEV-05, DOC-01]

# Metrics
duration: 3min
completed: 2026-02-25
---

# Phase 9 Plan 1: Tech Debt Cleanup Summary

**Fixed Docker build context bloat via repo-root .dockerignore, wired auth-aware readiness.sh probe in StatefulSet/Helm, corrected README Helm label, and marked all 26 v1 requirements complete**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-25T22:44:43Z
- **Completed:** 2026-02-25T22:48:15Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Moved .dockerignore from docker/ (dead location) to repo root with comprehensive exclusions, reducing build context size
- Changed readiness probe from healthcheck.sh to readiness.sh in StatefulSet and Helm values (timeoutSeconds: 10) for auth-aware readiness checking
- Fixed README Helm verification section to use correct label selector app=claude-in-a-box
- Marked all 26 v1 requirements as complete in REQUIREMENTS.md (DEV-01, DEV-02, DEV-03, DEV-05, DOC-01 were the remaining 5)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix .dockerignore location and exclusions** - `5ff0b3f` (fix)
2. **Task 2: Wire readiness.sh as readiness probe in StatefulSet and Helm** - `528943d` (fix)
3. **Task 3: Fix README Helm label and update REQUIREMENTS.md checkboxes** - `06c58be` (fix)

## Files Created/Modified
- `.dockerignore` - New file at repo root with build context exclusions
- `docker/.dockerignore` - Deleted (dead code, Docker never read from this location)
- `k8s/base/04-statefulset.yaml` - readinessProbe changed to readiness.sh with timeoutSeconds: 10
- `helm/claude-in-a-box/values.yaml` - readinessProbe changed to readiness.sh with timeoutSeconds: 10
- `helm/claude-in-a-box/tests/golden/values.golden.yaml` - Regenerated with readiness.sh
- `helm/claude-in-a-box/tests/golden/values-readonly.golden.yaml` - Regenerated with readiness.sh
- `helm/claude-in-a-box/tests/golden/values-operator.golden.yaml` - Regenerated with readiness.sh
- `helm/claude-in-a-box/tests/golden/values-airgapped.golden.yaml` - Regenerated with readiness.sh
- `README.md` - Line 243 changed from app=claude-agent to app=claude-in-a-box
- `.planning/REQUIREMENTS.md` - 5 checkboxes marked [x], 5 traceability rows marked Complete

## Decisions Made
- Added `!.claude/skills/` negation pattern to .dockerignore because the plan's `.claude` exclusion would block the Dockerfile's `COPY .claude/skills/` directive. Cross-checking all COPY sources caught this before build failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added !.claude/skills/ negation to .dockerignore**
- **Found during:** Task 1 (Fix .dockerignore location and exclusions)
- **Issue:** Plan specified excluding `.claude` directory, but Dockerfile line 276 COPYs `.claude/skills/` into the image. The `.claude` exclusion would cause a "COPY failed" build error.
- **Fix:** Added `!.claude/skills/` negation pattern after `.claude` exclusion to allow skills through while excluding the rest of .claude/
- **Files modified:** .dockerignore
- **Verification:** `docker build -f docker/Dockerfile -t claude-in-a-box:test .` succeeds, skills COPY works
- **Committed in:** 5ff0b3f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential fix to prevent Docker build failure. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All v1 requirements marked complete
- Plan 09-02 remains for additional tech debt items
- Project is at 94% completion (15/16 plans done before this plan, 16/17 after including this)

## Self-Check: PASSED

- FOUND: .dockerignore
- FOUND: docker/.dockerignore deleted
- FOUND: 09-01-SUMMARY.md
- FOUND: commit 5ff0b3f
- FOUND: commit 528943d
- FOUND: commit 06c58be

---
*Phase: 09-tech-debt-cleanup*
*Completed: 2026-02-25*
