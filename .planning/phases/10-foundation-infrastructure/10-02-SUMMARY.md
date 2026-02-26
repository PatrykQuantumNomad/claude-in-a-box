---
phase: 10-foundation-infrastructure
plan: 02
subsystem: infra
tags: [github-actions, github-pages, astro-deploy, ci-cd, cname, dockerignore]

# Dependency graph
requires:
  - phase: 10-foundation-infrastructure/01
    provides: Astro project scaffold in site/ with working build
provides:
  - GitHub Pages deploy workflow triggered by site/ changes
  - CI pipeline isolation via paths-ignore
  - Custom domain CNAME for remotekube.patrykgolabek.dev
  - Docker build context exclusion for site/
affects: [11-page-content-components, 12-polish-deployment]

# Tech tracking
tech-stack:
  added: [withastro/action@v5, actions/deploy-pages@v4]
  patterns: [path-based-workflow-isolation, cname-in-public-dir]

key-files:
  created:
    - .github/workflows/deploy-site.yaml
    - site/public/CNAME
  modified:
    - .github/workflows/ci.yaml
    - .dockerignore

key-decisions:
  - "Path-based workflow isolation: deploy-site triggers on site/**, CI ignores site/**"
  - "CNAME in site/public/ so it persists across Astro builds (copied to dist/)"
  - "withastro/action@v5 with path: ./site for subdirectory builds"

patterns-established:
  - "Workflow isolation: site changes → deploy-site.yaml, infra changes → ci.yaml"
  - "Custom domain via CNAME file in public/ directory"

requirements-completed: [SITE-02, SITE-03, SITE-04, SITE-05]

# Metrics
duration: 3min
completed: 2026-02-26
---

# Phase 10 Plan 02: CI/CD Isolation Summary

**GitHub Pages deploy workflow with path-based CI isolation, custom domain CNAME, and Docker context exclusion**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-26T11:49:00Z
- **Completed:** 2026-02-26T11:55:46Z
- **Tasks:** 2 (1 auto + 1 checkpoint)
- **Files modified:** 4

## Accomplishments
- Deploy workflow triggers only on site/ changes, builds with withastro/action@v5, deploys to GitHub Pages
- CI pipeline ignores site/ changes via paths-ignore on both push and pull_request triggers
- Custom domain CNAME file persists across deploys via site/public/CNAME
- Docker build context excludes site/ directory preventing image bloat
- GitHub Pages source configured to "GitHub Actions" (manual)
- DNS CNAME record created for remotekube.patrykgolabek.dev (manual)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create deploy workflow, update CI paths, add CNAME and .dockerignore** - `3d39691` (feat)
2. **Task 2: Configure GitHub Pages source and DNS CNAME record** - Manual checkpoint (no commit)

## Files Created/Modified
- `.github/workflows/deploy-site.yaml` - GitHub Pages deploy workflow with site/ path filter
- `.github/workflows/ci.yaml` - Added paths-ignore for site/** on push and pull_request
- `.dockerignore` - Added site/ exclusion
- `site/public/CNAME` - Custom domain: remotekube.patrykgolabek.dev

## Decisions Made
- Path-based workflow isolation instead of separate repos or manual triggers
- CNAME in site/public/ (Astro copies public/ contents to dist/ during build)
- withastro/action@v5 handles npm install, build, and Pages artifact upload in one step

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - manual steps (GitHub Pages source + DNS CNAME) completed during checkpoint.

## Next Phase Readiness
- Phase 10 complete: site scaffold + CI/CD isolation + custom domain all in place
- Ready for Phase 11: Page Content & Components
- First deploy will happen when code is pushed to main with site/ changes

## Self-Check: PASSED

- .github/workflows/deploy-site.yaml: FOUND
- site/public/CNAME: FOUND
- Commits with "10-02": 1 found (3d39691)

---
*Phase: 10-foundation-infrastructure*
*Completed: 2026-02-26*
