---
phase: 05-integration-testing
plan: 02
subsystem: testing
tags: [bats, rbac, networkpolicy, persistence, remote-control, integration-testing]

# Dependency graph
requires:
  - phase: 05-integration-testing
    plan: 01
    provides: "BATS framework, test helpers (wait_for_pod, exec_in_pod, assert_can, assert_cannot), Makefile test targets"
  - phase: 04-kubernetes-manifests-rbac
    provides: "StatefulSet, RBAC ClusterRoles, NetworkPolicy, and operator overlay manifests tested by this suite"
  - phase: 01-container-foundation
    provides: "verify-tools.sh script executed inside the pod by 03-tools.bats"
provides:
  - "22 RBAC tests covering 14 reader resources, 4 deny cases, and 4 operator tier permissions"
  - "5 networking tests validating DNS, HTTPS egress, K8s API access, and blocked port enforcement"
  - "3 tool verification tests running verify-tools.sh and kubectl inside the pod"
  - "3 persistence tests validating PVC data survives pod deletion and recreation"
  - "2 Remote Control connectivity tests verifying HTTPS and TLS to api.anthropic.com"
  - "Complete 35-test integration suite runnable via make test"
affects: [07-production-packaging, 08-documentation-release]

# Tech tracking
tech-stack:
  added: []
  patterns: [bats-test-per-resource, sa-impersonation-rbac, exec-in-pod-networking, pvc-delete-recreate-cycle]

key-files:
  created:
    - tests/integration/01-rbac.bats
    - tests/integration/02-networking.bats
    - tests/integration/03-tools.bats
    - tests/integration/04-persistence.bats
    - tests/integration/05-remote-control.bats
  modified: []

key-decisions:
  - "One @test per RBAC resource for granular pass/fail visibility (22 tests vs fewer grouped tests)"
  - "Operator overlay applied in first operator test and removed in teardown_file for clean state"
  - "Remote Control tests validate network path only (HTTPS + TLS) since full testing requires real OAuth token"
  - "Persistence test uses unique marker string for deterministic assertion after pod recreation"

patterns-established:
  - "RBAC test pattern: one assert_can/assert_cannot call per @test for each verb+resource pair"
  - "Networking test pattern: exec_in_pod with curl/dig for in-pod network assertions"
  - "Persistence test pattern: write marker -> delete pod -> wait_for_pod -> verify marker survives"

requirements-completed: [DEV-04]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 5 Plan 2: Integration Test Suite Summary

**35-test BATS integration suite covering RBAC (22 tests), networking (5), tools (3), persistence (3), and Remote Control (2) with full SA impersonation and in-pod assertions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T18:39:00Z
- **Completed:** 2026-02-25T18:41:05Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Complete RBAC test coverage: all 14 reader-tier resources (get/list/watch), 4 deny cases (secrets, mutations), and 4 operator-tier permissions with overlay apply/teardown
- Networking tests validate DNS resolution (internal + external), HTTPS egress to Anthropic API, K8s API server access, and blocked port enforcement via NetworkPolicy
- Persistence test performs the full write-delete-wait-verify cycle proving PVC data survives StatefulSet pod recreation
- Remote Control connectivity validated via HTTPS status code and TLS certificate chain verification to api.anthropic.com
- All 35 tests runnable via `make test` producing TAP-compliant output

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RBAC and networking test files** - `1510a08` (test)
2. **Task 2: Create tools, persistence, and remote-control test files** - `9b984fd` (test)

## Files Created/Modified
- `tests/integration/01-rbac.bats` - 22 RBAC tests: 14 reader ALLOW, 4 reader DENY, 4 operator tier with overlay lifecycle
- `tests/integration/02-networking.bats` - 5 networking tests: DNS internal/external, HTTPS egress, K8s API, blocked port
- `tests/integration/03-tools.bats` - 3 tool tests: verify-tools.sh execution, kubectl cluster access, kubectl version
- `tests/integration/04-persistence.bats` - 3 persistence tests: PVC write, pod delete/recreate survival, cleanup
- `tests/integration/05-remote-control.bats` - 2 connectivity tests: HTTPS status code and TLS handshake to api.anthropic.com

## Decisions Made
- One @test per RBAC resource for granular failure identification -- 22 individual tests rather than grouped tests that could mask which resource failed
- Operator overlay applied in first operator @test block (kubectl apply is idempotent) and removed in teardown_file to leave clean state for subsequent test runs
- Remote Control tests validate only network path (HTTPS response + TLS cert chain) since full Remote Control testing requires a real OAuth token which is a manual step
- Persistence test uses a unique deterministic marker string ("persist-test-12345") rather than timestamp for reliable assertion after pod recreation
- Retry loop (5 attempts with 2s sleep) after wait_for_pod in persistence test to handle exec path readiness lag after pod recreation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 5 is fully complete -- `make test-setup` creates a Calico-enabled KIND cluster and `make test` runs all 35 integration tests
- All 5 ROADMAP success criteria for Phase 5 are covered: RBAC (criteria 2), networking (criteria 3), persistence (criteria 4), tools (criteria 5), and make test runner (criteria 1)
- Phase 6 (Intelligence Layer) and Phase 7 (Production Packaging) can now proceed

## Self-Check: PASSED

All 5 created files verified on disk. All 2 task commits verified in git log.

---
*Phase: 05-integration-testing*
*Completed: 2026-02-25*
