---
phase: 13-fix-stagger-animation
plan: 01
subsystem: ui
tags: [motion, animation, inView, stagger, astro]

# Dependency graph
requires:
  - phase: 12-polish-deployment
    provides: "motion inView/animate/stagger setup in BaseLayout.astro"
provides:
  - "Corrected inView stagger callback using (element) parameter"
  - "All 10 cards (6 FeatureCards + 4 UseCaseCards) animate on scroll"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "motion inView callback receives DOM Element directly, not IntersectionObserverEntry"

key-files:
  created: []
  modified:
    - site/src/layouts/BaseLayout.astro

key-decisions:
  - "Two-character fix matching existing line 60 pattern -- no architectural changes needed"

patterns-established:
  - "inView callbacks use (element) parameter, not ({ target }) destructuring"

requirements-completed: [DESIGN-02]

# Metrics
duration: 1min
completed: 2026-02-26
---

# Phase 13 Plan 01: Fix inView Stagger Callback Summary

**Fixed inView stagger callback from `({ target })` to `(element)`, restoring scroll animations for all 10 feature/use-case cards**

## Performance

- **Duration:** 34 seconds
- **Started:** 2026-02-26T18:19:28Z
- **Completed:** 2026-02-26T18:20:02Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Fixed the inView stagger callback signature from `({ target })` to `(element)` matching the correct API
- Both inView callbacks (reveal-section on line 60, reveal-stagger on line 69) now use consistent `(element)` signatures
- Build passes with zero errors
- Cards will no longer be stuck at opacity 0 -- they animate into view on scroll as intended

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix inView stagger callback signature and verify build** - `bc84bf9` (fix)

**Plan metadata:** `29ec566` (docs: complete plan)

## Files Created/Modified

- `site/src/layouts/BaseLayout.astro` - Fixed inView stagger callback parameter from `({ target })` to `(element)` on lines 69-70

## Decisions Made

None - followed plan as specified. The fix was a straightforward two-line change matching the existing correct pattern on line 60.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DESIGN-02 gap closure complete -- stagger animations now work correctly
- v1.1 Landing Page milestone fully shipped with all gaps closed
- No further phases planned

## Self-Check: PASSED

- FOUND: 13-01-SUMMARY.md
- FOUND: bc84bf9 (task commit)
- FOUND: site/src/layouts/BaseLayout.astro

---
*Phase: 13-fix-stagger-animation*
*Completed: 2026-02-26*
