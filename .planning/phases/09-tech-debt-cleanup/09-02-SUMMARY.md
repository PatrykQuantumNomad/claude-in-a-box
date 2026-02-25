---
phase: 09-tech-debt-cleanup
plan: 02
subsystem: testing, infra
tags: [kind, bats, calico, ci, github-actions, integration-tests]

# Dependency graph
requires:
  - phase: 05-integration-testing
    provides: "BATS test suite, KIND test cluster config, Calico install script"
  - phase: 07-production-packaging
    provides: "CI workflow with build-scan-publish and helm-lint jobs"
provides:
  - "Test cluster isolation (claude-in-a-box-test distinct from claude-in-a-box)"
  - "TEST_CLUSTER_NAME Makefile variable for test targets"
  - "CI integration-tests job running BATS in KIND with Calico"
affects: []

# Tech tracking
tech-stack:
  added: [bats-core/bats-action@4.0.0, helm/kind-action@v1]
  patterns: [parallel-ci-jobs, test-cluster-isolation]

key-files:
  created: []
  modified:
    - kind/cluster-test.yaml
    - Makefile
    - .github/workflows/ci.yaml

key-decisions:
  - "TEST_CLUSTER_NAME variable isolates test cluster from dev cluster"
  - "integration-tests CI job runs in parallel (no needs: dependency) for faster total CI time"
  - "Image built locally in CI job to avoid GHCR auth complexity on PRs"
  - "bats-core/bats-action@4.0.0 used instead of local clone for CI"

patterns-established:
  - "Test cluster isolation: TEST_CLUSTER_NAME separate from CLUSTER_NAME prevents name collision"

requirements-completed: []

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 9 Plan 2: Test Cluster Isolation and CI Integration Tests Summary

**Test cluster renamed to claude-in-a-box-test with dedicated Makefile variable, and BATS integration tests added to CI via KIND cluster with Calico**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T22:45:31Z
- **Completed:** 2026-02-25T22:46:56Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Test cluster uses distinct name (claude-in-a-box-test) preventing collision with dev cluster (claude-in-a-box)
- Makefile test-setup and test-teardown targets use TEST_CLUSTER_NAME variable with explicit kind load (no longer delegates to $(MAKE) load which uses dev cluster name)
- CI workflow now has integration-tests job that creates KIND cluster, installs Calico, builds image, deploys manifests, and runs BATS tests on every push/PR

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix test cluster name and Makefile test targets** - `c04f480` (fix)
2. **Task 2: Add integration-tests job to CI workflow** - `47ac427` (feat)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `kind/cluster-test.yaml` - Changed cluster name from claude-in-a-box to claude-in-a-box-test
- `Makefile` - Added TEST_CLUSTER_NAME variable; updated test-setup with explicit kind load and test-teardown to use it
- `.github/workflows/ci.yaml` - Added integration-tests job with BATS, KIND, Calico, and full deploy pipeline

## Decisions Made
- TEST_CLUSTER_NAME variable isolates test cluster from dev cluster -- prevents make test-setup from skipping Calico install when dev cluster already exists
- integration-tests CI job has no needs: dependency -- runs in parallel with build-scan-publish and helm-lint for faster total CI time
- Image built locally in CI integration-tests job -- avoids GHCR auth complexity on pull requests
- Used bats-core/bats-action@4.0.0 (official GitHub Action) instead of local BATS clone for CI

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All v1.0 audit tech debt items are now closed
- CI pipeline covers linting, security scanning, SBOM generation, Helm chart validation, and integration testing
- Test and dev clusters can coexist without interference

## Self-Check: PASSED

All files verified present. All commits verified in git log.

---
*Phase: 09-tech-debt-cleanup*
*Completed: 2026-02-25*
