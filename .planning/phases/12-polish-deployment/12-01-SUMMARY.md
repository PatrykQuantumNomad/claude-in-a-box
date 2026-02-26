---
phase: 12-polish-deployment
plan: 01
subsystem: ui
tags: [motion, animations, scroll-reveal, css, astro]

# Dependency graph
requires:
  - phase: 11-page-content
    provides: Section components (Features, Architecture, Quickstart, UseCases) and UI cards (FeatureCard, UseCaseCard)
provides:
  - Scroll-triggered reveal animations on all below-fold sections
  - Staggered card reveal animations for Features and UseCases grids
  - CSS .reveal-section and .reveal-card initial hidden states with prefers-reduced-motion fallback
  - Motion library installed and tree-shaken animation script in BaseLayout
affects: [12-polish-deployment]

# Tech tracking
tech-stack:
  added: [motion 12.34.3]
  patterns: [inView observer for scroll-triggered animations, compositor-only CSS transforms for zero CLS, prefers-reduced-motion accessibility fallback]

key-files:
  created: []
  modified:
    - site/package.json
    - site/src/styles/global.css
    - site/src/components/sections/Features.astro
    - site/src/components/sections/Architecture.astro
    - site/src/components/sections/Quickstart.astro
    - site/src/components/sections/UseCases.astro
    - site/src/components/ui/FeatureCard.astro
    - site/src/components/ui/UseCaseCard.astro
    - site/src/layouts/BaseLayout.astro

key-decisions:
  - "Used motion vanilla JS API (animate/inView/stagger) instead of React wrappers -- keeps Astro zero-JS island architecture"
  - "Compositor-only properties (opacity + transform) for zero cumulative layout shift"
  - "Hero excluded from animations intentionally -- above fold content must be visible immediately"
  - "60KB raw / 21.65KB gzipped JS bundle acceptable -- standard motion tree-shake output for animate+inView+stagger"

patterns-established:
  - "Scroll reveal pattern: add .reveal-section to section root, .reveal-stagger to grid container, .reveal-card to individual cards"
  - "CSS initial hidden state (.reveal-section/.reveal-card opacity:0 translateY) with prefers-reduced-motion fallback to visible"

requirements-completed: [DESIGN-02]

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 12 Plan 01: Scroll Animations Summary

**Scroll-triggered fade-up reveal animations on 4 below-fold sections using motion's inView/animate/stagger API with zero CLS and prefers-reduced-motion fallback**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T15:49:22Z
- **Completed:** 2026-02-26T15:51:13Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Installed motion 12.34.3 and configured CSS initial hidden states for reveal elements
- Added reveal-section class to all 4 below-fold sections (Features, Architecture, Quickstart, UseCases)
- Added staggered card reveal to Features and UseCases grids with 100ms delay between cards
- Animation script in BaseLayout uses inView observer triggering at 15% visibility with smooth deceleration easing
- Hero section correctly excluded -- always visible above fold
- prefers-reduced-motion users see all content immediately without animation

## Task Commits

Each task was committed atomically:

1. **Task 1: Install motion and add CSS initial hidden states** - `0307bb7` (chore)
2. **Task 2: Add reveal classes to section components and animation script to BaseLayout** - `e0e4a59` (feat)

## Files Created/Modified
- `site/package.json` - Added motion 12.34.3 dependency
- `site/package-lock.json` - Lock file updated for motion + 3 sub-dependencies
- `site/src/styles/global.css` - Added .reveal-section/.reveal-card initial hidden states and prefers-reduced-motion fallback
- `site/src/components/sections/Features.astro` - Added reveal-section on section, reveal-stagger on grid
- `site/src/components/sections/Architecture.astro` - Added reveal-section on section
- `site/src/components/sections/Quickstart.astro` - Added reveal-section on section (preserved id="quickstart" and scroll-mt-8)
- `site/src/components/sections/UseCases.astro` - Added reveal-section on section, reveal-stagger on grid
- `site/src/components/ui/FeatureCard.astro` - Added reveal-card to class:list array
- `site/src/components/ui/UseCaseCard.astro` - Added reveal-card to root div
- `site/src/layouts/BaseLayout.astro` - Added animation script importing animate, inView, stagger from motion

## Decisions Made
- Used motion vanilla JS API (animate/inView/stagger) instead of React wrappers -- keeps Astro zero-JS island architecture intact
- Compositor-only properties (opacity + transform/translateY) ensure zero cumulative layout shift from animations
- Hero excluded from animations intentionally -- above fold content must be immediately visible
- 60KB raw / 21.65KB gzipped JS bundle is acceptable -- standard tree-shake output for the three motion functions used

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All scroll animations are live and building successfully
- Ready for 12-02: SEO/OG meta tags, Twitter Card, OG image, sitemap, robots.txt
- No blockers for final plan execution

## Self-Check: PASSED

All 9 modified files verified present. Both task commits (0307bb7, e0e4a59) verified in git log. SUMMARY.md exists.

---
*Phase: 12-polish-deployment*
*Completed: 2026-02-26*
