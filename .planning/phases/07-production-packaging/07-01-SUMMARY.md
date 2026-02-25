---
phase: 07-production-packaging
plan: 01
subsystem: infra
tags: [helm, kubernetes, chart, rbac, networkpolicy, golden-test]

# Dependency graph
requires:
  - phase: 04-kubernetes-manifests-rbac
    provides: Raw K8s manifests (SA, RBAC, NetworkPolicy, StatefulSet) that templates wrap
provides:
  - Helm chart at helm/claude-in-a-box/ with apiVersion v2
  - Three security profile values files (readonly, operator, airgapped)
  - Parameterized templates wrapping raw k8s/base/ and k8s/overlays/ manifests
  - Golden file test script and baseline golden files for 4 profiles
affects: [07-production-packaging, 08-documentation-release]

# Tech tracking
tech-stack:
  added: [helm-chart-v2]
  patterns: [wrap-not-rewrite, conditional-operator-rbac, security-profile-overlays, golden-file-testing]

key-files:
  created:
    - helm/claude-in-a-box/Chart.yaml
    - helm/claude-in-a-box/values.yaml
    - helm/claude-in-a-box/values-readonly.yaml
    - helm/claude-in-a-box/values-operator.yaml
    - helm/claude-in-a-box/values-airgapped.yaml
    - helm/claude-in-a-box/templates/_helpers.tpl
    - helm/claude-in-a-box/templates/serviceaccount.yaml
    - helm/claude-in-a-box/templates/clusterrole-reader.yaml
    - helm/claude-in-a-box/templates/clusterrolebinding-reader.yaml
    - helm/claude-in-a-box/templates/networkpolicy.yaml
    - helm/claude-in-a-box/templates/service.yaml
    - helm/claude-in-a-box/templates/statefulset.yaml
    - helm/claude-in-a-box/templates/clusterrole-operator.yaml
    - helm/claude-in-a-box/templates/clusterrolebinding-operator.yaml
    - helm/claude-in-a-box/templates/NOTES.txt
    - scripts/helm-golden-test.sh
    - helm/claude-in-a-box/tests/golden/values.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-readonly.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-operator.golden.yaml
    - helm/claude-in-a-box/tests/golden/values-airgapped.golden.yaml
  modified: []

key-decisions:
  - "fullnameOverride: claude-agent in values.yaml forces resource names to match raw manifests regardless of release name"
  - "apiVersion v2 chart format (v3 is HIP-0020 proposal, not yet released)"
  - "Security profiles as minimal overlay files merged on top of values.yaml defaults"
  - "Golden file tests capture full helm template output including Helm metadata"

patterns-established:
  - "Wrap-not-rewrite: templates parameterize raw manifests without restructuring"
  - "Conditional resources: operator RBAC gated on .Values.operator.enabled"
  - "Conditional egress: each NetworkPolicy rule gated on its .enabled flag"
  - "Golden file testing: helm template output compared against stored baselines"

requirements-completed: [K8S-06]

# Metrics
duration: 3min
completed: 2026-02-25
---

# Phase 7 Plan 01: Helm Chart Summary

**Helm chart wrapping raw K8s manifests with 3 security profile overlays (readonly/operator/airgapped) and golden file validation for all 4 profiles**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-25T20:43:30Z
- **Completed:** 2026-02-25T20:46:44Z
- **Tasks:** 2
- **Files modified:** 20

## Accomplishments
- Complete Helm chart at helm/claude-in-a-box/ with apiVersion v2 that lints clean
- Default values produce 6 resources matching raw k8s/base/ manifests structurally (all named claude-agent-*)
- Operator profile adds ClusterRole + ClusterRoleBinding for mutation permissions
- Airgapped profile removes HTTPS egress and restricts K8s API CIDR to 10.96.0.1/32
- Golden file tests pass for all 4 security profiles with idempotent regeneration

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Helm chart skeleton, values files, and all templates** - `ea527ea` (feat)
2. **Task 2: Create golden file test script and generate golden files** - `f6bd066` (test)

## Files Created/Modified
- `helm/claude-in-a-box/Chart.yaml` - Chart metadata (apiVersion v2, name, version)
- `helm/claude-in-a-box/values.yaml` - Default values (readonly profile, fullnameOverride: claude-agent)
- `helm/claude-in-a-box/values-readonly.yaml` - Explicit readonly overlay (matches defaults)
- `helm/claude-in-a-box/values-operator.yaml` - Operator overlay (enables mutation RBAC)
- `helm/claude-in-a-box/values-airgapped.yaml` - Airgapped overlay (restricted egress, private registry)
- `helm/claude-in-a-box/templates/_helpers.tpl` - Naming, labels, selector, serviceAccount helpers
- `helm/claude-in-a-box/templates/serviceaccount.yaml` - Conditional ServiceAccount from 01-serviceaccount.yaml
- `helm/claude-in-a-box/templates/clusterrole-reader.yaml` - Reader ClusterRole from 02-rbac-reader.yaml
- `helm/claude-in-a-box/templates/clusterrolebinding-reader.yaml` - Reader binding with Release.Namespace
- `helm/claude-in-a-box/templates/networkpolicy.yaml` - Conditional egress rules from 03-networkpolicy.yaml
- `helm/claude-in-a-box/templates/service.yaml` - Headless Service from 04-statefulset.yaml
- `helm/claude-in-a-box/templates/statefulset.yaml` - Parameterized StatefulSet from 04-statefulset.yaml
- `helm/claude-in-a-box/templates/clusterrole-operator.yaml` - Conditional operator ClusterRole from rbac-operator.yaml
- `helm/claude-in-a-box/templates/clusterrolebinding-operator.yaml` - Conditional operator binding
- `helm/claude-in-a-box/templates/NOTES.txt` - Post-install usage instructions
- `scripts/helm-golden-test.sh` - Golden file test script with --update flag
- `helm/claude-in-a-box/tests/golden/values.golden.yaml` - Default profile baseline (208 lines)
- `helm/claude-in-a-box/tests/golden/values-readonly.golden.yaml` - Readonly profile baseline (208 lines)
- `helm/claude-in-a-box/tests/golden/values-operator.golden.yaml` - Operator profile baseline (256 lines)
- `helm/claude-in-a-box/tests/golden/values-airgapped.golden.yaml` - Airgapped profile baseline (202 lines)

## Decisions Made
- fullnameOverride: "claude-agent" in values.yaml ensures resource names match raw manifests regardless of Helm release name
- apiVersion v2 chart format (Helm 4 maintains full backward compatibility; v3 is HIP-0020, not yet released)
- Security profile values files are minimal overlays -- only override values that differ from defaults
- Golden files capture full helm template output including Helm metadata labels and Source comments

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed bash arithmetic exit code in golden test script**
- **Found during:** Task 2 (golden file test script)
- **Issue:** `((PASSED++))` returns exit code 1 when PASSED is 0 (bash treats 0 as false), causing script to fail under `set -e`
- **Fix:** Changed to `PASSED=$((PASSED + 1))` which always succeeds
- **Files modified:** scripts/helm-golden-test.sh
- **Verification:** Script runs successfully with all 4 golden files passing
- **Committed in:** f6bd066 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial bash arithmetic fix. No scope creep.

## Issues Encountered
- Plan specified 7 default resources and 9 operator resources, but actual counts are 6 and 8. The plan's listing was correct (SA, CR-reader, CRB-reader, NetPol, Svc, STS = 6 items) but the numeric count was off by one. All expected resource types are present.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Helm chart is complete and ready for CI/CD pipeline integration (07-02)
- Golden file test script can be integrated into CI workflow
- helm lint --strict passes (only INFO about missing icon, no errors/warnings)

## Self-Check: PASSED

- All 20 created files verified present on disk
- Both task commits (ea527ea, f6bd066) verified in git log
- helm lint --strict: 0 errors, 0 warnings
- helm template: all 4 profiles render correctly
- Golden file tests: 4/4 pass

---
*Phase: 07-production-packaging*
*Completed: 2026-02-25*
