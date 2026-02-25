---
phase: 05-integration-testing
plan: 01
subsystem: testing
tags: [bats, kind, calico, networkpolicy, integration-testing, makefile]

# Dependency graph
requires:
  - phase: 04-kubernetes-manifests-rbac
    provides: "StatefulSet, RBAC, NetworkPolicy manifests referenced by test helpers"
  - phase: 03-local-development-environment
    provides: "KIND cluster config and Makefile patterns extended for test targets"
provides:
  - "KIND test cluster config with Calico CNI for NetworkPolicy enforcement"
  - "Calico CNI installation script with RPF fix and CoreDNS restart"
  - "BATS test framework setup script (v1.13.0)"
  - "Shared test helpers: wait_for_pod, exec_in_pod, can_i, assert_can, assert_cannot"
  - "Makefile targets: test-setup, test, test-teardown"
affects: [05-integration-testing, 07-production-packaging]

# Tech tracking
tech-stack:
  added: [bats-core-1.13.0, calico-3.31.4, kind-cluster-test-config]
  patterns: [calico-cni-for-networkpolicy, bats-tap-output, test-helper-library]

key-files:
  created:
    - kind/cluster-test.yaml
    - scripts/install-calico.sh
    - scripts/setup-bats.sh
    - tests/integration/helpers.bash
  modified:
    - Makefile

key-decisions:
  - "Calico 3.31.4 as CNI for NetworkPolicy enforcement in KIND (kindnet does not enforce)"
  - "BATS v1.13.0 cloned locally into tests/bats/ (gitignored, not committed)"
  - "FELIX_IGNORELOOSERPF=true for KIND compatibility with Calico RPF checks"
  - "CoreDNS restart after Calico install to recover from pre-CNI scheduling"
  - "test-setup reuses bootstrap pattern with KIND_TEST_CONFIG for Calico-enabled cluster"

patterns-established:
  - "Test helper library pattern: constants + utility functions in helpers.bash loaded by all .bats files"
  - "can_i/assert_can/assert_cannot pattern for RBAC test assertions"
  - "test-setup target pattern: build -> setup-bats -> create-cluster -> install-calico -> load -> deploy"

requirements-completed: [DEV-04]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 5 Plan 1: Test Infrastructure Summary

**BATS test framework with Calico-enabled KIND cluster, shared test helpers, and Makefile test targets for integration testing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T18:32:51Z
- **Completed:** 2026-02-25T18:34:48Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- KIND test cluster config with disableDefaultCNI and Calico podSubnet for real NetworkPolicy enforcement
- Calico install script handling operator install, RPF fix for KIND nodes, and CoreDNS restart
- BATS setup script that downloads bats-core v1.13.0 locally (gitignored)
- Test helper library with pod interaction and RBAC assertion functions
- Makefile targets: test-setup (full cluster + Calico + deploy), test (BATS runner), test-teardown

## Task Commits

Each task was committed atomically:

1. **Task 1: Create KIND test cluster config and Calico install script** - `a08d2a7` (feat)
2. **Task 2: Create BATS setup script and test helpers** - `3dca5c2` (feat)
3. **Task 3: Add test and test-setup Makefile targets** - `ad0dc6b` (feat)

## Files Created/Modified
- `kind/cluster-test.yaml` - KIND cluster config with Calico CNI support (disableDefaultCNI, podSubnet 192.168.0.0/16)
- `scripts/install-calico.sh` - Calico operator install, RPF fix, CoreDNS restart
- `scripts/setup-bats.sh` - Downloads bats-core v1.13.0 into tests/bats/
- `tests/integration/helpers.bash` - Shared test utilities: POD_NAME, SA_FULL, wait_for_pod, exec_in_pod, can_i, assert_can, assert_cannot
- `Makefile` - Added KIND_TEST_CONFIG, BATS, TEST_DIR variables and test-setup, test, test-teardown targets

## Decisions Made
- Calico 3.31.4 chosen as CNI -- kindnet (KIND default) does not enforce NetworkPolicy, making it impossible to test the egress rules from Phase 4
- BATS v1.13.0 cloned locally rather than installed globally -- keeps test dependencies self-contained and reproducible
- FELIX_IGNORELOOSERPF=true applied to calico-node daemonset -- KIND nodes have loose RPF by default which breaks Calico
- CoreDNS restart included in Calico install -- pods scheduled before CNI is ready can have broken DNS
- test-setup reuses the same cluster name as bootstrap to avoid confusion, but uses KIND_TEST_CONFIG for Calico-enabled config

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Test infrastructure is complete -- Plan 05-02 can now create .bats test files that load helpers.bash and run via `make test`
- Calico CNI ensures NetworkPolicy tests will enforce real rules (not just pass vacuously)
- All helper functions (wait_for_pod, exec_in_pod, can_i, assert_can, assert_cannot) are ready for test authors

## Self-Check: PASSED

All 5 created files verified on disk. All 3 task commits verified in git log.

---
*Phase: 05-integration-testing*
*Completed: 2026-02-25*
