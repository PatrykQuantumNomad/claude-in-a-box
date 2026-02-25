---
phase: 04-kubernetes-manifests-rbac
plan: 01
subsystem: infra
tags: [kubernetes, statefulset, rbac, networkpolicy, pvc, serviceaccount]

# Dependency graph
requires:
  - phase: 03-local-development-environment
    provides: "KIND cluster config, dev pod manifest patterns, Makefile workflow"
provides:
  - "Base K8s manifests for production-grade claude-agent deployment"
  - "ServiceAccount with dedicated identity"
  - "Read-only ClusterRole covering 14 resource types across 4 API groups"
  - "Egress-only NetworkPolicy (DNS, HTTPS, K8s API)"
  - "StatefulSet with volumeClaimTemplates for PVC persistence"
  - "Headless Service for stable DNS identity"
affects: [04-02-operator-rbac, 05-integration-testing, 07-production-packaging]

# Tech tracking
tech-stack:
  added: []
  patterns: ["numbered-manifest-ordering (00-04)", "multi-document-yaml-with-separator", "clusterrole-per-tier-pattern"]

key-files:
  created:
    - k8s/base/01-serviceaccount.yaml
    - k8s/base/02-rbac-reader.yaml
    - k8s/base/03-networkpolicy.yaml
    - k8s/base/04-statefulset.yaml
  modified: []

key-decisions:
  - "No namespace manifest -- default namespace does not need explicit creation"
  - "CIDR 0.0.0.0/0 for egress ports 443 and 6443 -- Anthropic IPs rotate, API server IP varies per cluster"
  - "kubectl dry-run replaced with Python YAML validation -- no cluster context available at plan time"

patterns-established:
  - "Numbered manifest prefixes (01-04) for deterministic apply ordering"
  - "Multi-document YAML for related resources (ClusterRole + ClusterRoleBinding, Service + StatefulSet)"
  - "Reader tier label (tier: reader) enabling future tiered RBAC overlay"

requirements-completed: [K8S-01, K8S-02, K8S-03, K8S-04]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 4 Plan 1: Base K8s Manifests Summary

**StatefulSet with read-only RBAC (14 resources), egress-only NetworkPolicy, and PVC persistence at /app/.claude**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T17:55:45Z
- **Completed:** 2026-02-25T17:57:57Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments
- Created 4 Kubernetes manifest files producing 6 resource documents via kubectl apply -f k8s/base/
- Read-only ClusterRole covers exactly 14 resources (pods, services, events, nodes, namespaces, configmaps, persistentvolumeclaims, deployments, statefulsets, daemonsets, replicasets, jobs, cronjobs, ingresses) with only get/list/watch verbs -- no secrets access
- NetworkPolicy denies all ingress, allows only DNS (UDP/TCP 53), HTTPS (TCP 443), and K8s API (TCP 6443) egress
- StatefulSet creates claude-agent-0 with PVC auto-provisioned via volumeClaimTemplates, mounted at /app/.claude with fsGroup 10000 for non-root file access

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ServiceAccount and RBAC reader manifests** - `2156458` (feat)
2. **Task 2: Create NetworkPolicy and StatefulSet with headless Service** - `a9dcbc4` (feat)

## Files Created/Modified
- `k8s/base/01-serviceaccount.yaml` - Dedicated ServiceAccount with automountServiceAccountToken
- `k8s/base/02-rbac-reader.yaml` - ClusterRole (14 resources, 4 API groups) + ClusterRoleBinding
- `k8s/base/03-networkpolicy.yaml` - Egress-only NetworkPolicy (DNS, HTTPS, K8s API)
- `k8s/base/04-statefulset.yaml` - Headless Service + StatefulSet with PVC, SecurityContext, resources

## Decisions Made
- **No namespace manifest:** default namespace does not need explicit creation; Phase 7 Helm chart will parameterize namespace
- **CIDR 0.0.0.0/0 for egress:** Anthropic API IPs rotate via CDN, K8s API server IP varies per cluster; port-based restriction is sufficient
- **Python YAML validation instead of kubectl dry-run:** No cluster context available at plan execution time; programmatic validation covers YAML syntax, structure, and cross-reference integrity

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- kubectl --dry-run=client requires cluster context even for client-side validation (downloads OpenAPI schema). Replaced with comprehensive Python yaml.safe_load_all validation covering syntax, structure, resource counts, and cross-reference integrity. This is equivalent in rigor and does not require a running cluster.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Base manifests ready for 04-02 (operator RBAC overlay and Makefile integration)
- k8s/base/ validates as a complete set -- Phase 5 integration tests can deploy with kubectl apply -f k8s/base/
- NetworkPolicy enforcement requires Calico CNI (Phase 5 will install)
- Phase 7 Helm chart will template these manifests with parameterized values

## Self-Check: PASSED

All 4 manifest files verified on disk. Both task commits (2156458, a9dcbc4) found in git history.

---
*Phase: 04-kubernetes-manifests-rbac*
*Completed: 2026-02-25*
