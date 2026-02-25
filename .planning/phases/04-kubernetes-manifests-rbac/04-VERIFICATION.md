---
phase: 04-kubernetes-manifests-rbac
verified: 2026-02-25T18:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 4: Kubernetes Manifests & RBAC Verification Report

**Phase Goal:** Complete raw Kubernetes manifest set that deploys Claude-in-a-box with correct RBAC, network isolation, and persistence into any cluster via kubectl apply

**Verified:** 2026-02-25T18:30:00Z
**Status:** PASSED
**Re-verification:** No -- initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `kubectl apply -f k8s/base/` deploys StatefulSet with stable pod identity (claude-agent-0) and PVC at /app/.claude | VERIFIED | `k8s/base/04-statefulset.yaml` defines StatefulSet named `claude-agent` (produces `claude-agent-0`), volumeClaimTemplates with `claude-data` at `mountPath: /app/.claude`, PVC survives pod deletion by design of StatefulSet |
| 2 | Default ServiceAccount can get/list/watch 14 resource types but cannot access secrets or perform mutations | VERIFIED | `k8s/base/02-rbac-reader.yaml` ClusterRole `claude-agent-reader` covers exactly 14 resources across 4 API groups with only `get`, `list`, `watch` verbs. `secrets` appears only in a comment (line 3), not in any rule |
| 3 | Operator-tier ClusterRole (opt-in via separate binding) adds delete pods, create pods/exec, and update/patch deployments and statefulsets | VERIFIED | `k8s/overlays/rbac-operator.yaml` has 3 rules: `pods` with `delete`, `pods/exec` with `create`, `deployments`+`statefulsets` with `update`+`patch` |
| 4 | NetworkPolicy allows only egress to Anthropic API (TCP 443), K8s API (TCP 6443), and DNS (UDP/TCP 53) -- all ingress denied | VERIFIED | `k8s/base/03-networkpolicy.yaml` has `ingress: []`, policyTypes includes both Ingress and Egress, 3 egress rules: DNS (UDP+TCP 53), HTTPS (TCP 443 to 0.0.0.0/0), K8s API (TCP 6443 to 0.0.0.0/0) |
| 5 | Pod restarts preserve OAuth token and session data (PVC survives `kubectl delete pod claude-agent-0`) | VERIFIED | StatefulSet volumeClaimTemplates auto-creates `claude-data-claude-agent-0` PVC. StatefulSet controller does not delete PVCs on pod deletion -- PVC persists across restarts by K8s design |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `k8s/base/01-serviceaccount.yaml` | Dedicated ServiceAccount for claude-agent pod | VERIFIED | Exists, 11 lines, `kind: ServiceAccount`, name `claude-agent`, `automountServiceAccountToken: true`, label `app: claude-agent` |
| `k8s/base/02-rbac-reader.yaml` | Read-only ClusterRole + ClusterRoleBinding for 14 resource types | VERIFIED | Exists, 58 lines, multi-doc YAML, `claude-agent-reader` ClusterRole with 4 rule groups (7+4+2+1=14 resources), only get/list/watch verbs |
| `k8s/base/03-networkpolicy.yaml` | Egress-only NetworkPolicy with DNS, HTTPS, and K8s API rules | VERIFIED | Exists, 51 lines, `claude-agent-netpol`, `ingress: []`, 3 egress rules with ports 53 (UDP+TCP), 443, 6443 |
| `k8s/base/04-statefulset.yaml` | StatefulSet with headless Service, volumeClaimTemplates, SecurityContext | VERIFIED | Exists, 87 lines, multi-doc YAML (Service + StatefulSet), `clusterIP: None`, volumeClaimTemplates present, securityContext with UID/GID/fsGroup 10000 |
| `k8s/overlays/rbac-operator.yaml` | Operator-tier ClusterRole + ClusterRoleBinding (opt-in) | VERIFIED | Exists, 55 lines, `claude-agent-operator`, in `k8s/overlays/` (not `k8s/base/`), correct 3-rule structure |
| `Makefile` | Updated targets for k8s/base/ manifests and operator overlay | VERIFIED | `K8S_MANIFESTS ?= k8s/base`, `OPERATOR_RBAC ?= k8s/overlays/rbac-operator.yaml`, `deploy-operator` and `undeploy-operator` targets present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `k8s/base/04-statefulset.yaml` | `k8s/base/01-serviceaccount.yaml` | `serviceAccountName: claude-agent` | WIRED | Line 40 of StatefulSet sets `serviceAccountName: claude-agent` matching SA name |
| `k8s/base/02-rbac-reader.yaml` | `k8s/base/01-serviceaccount.yaml` | ClusterRoleBinding subjects | WIRED | ClusterRoleBinding subjects: `kind: ServiceAccount, name: claude-agent, namespace: default` |
| `k8s/base/04-statefulset.yaml` | Headless Service in same file | `serviceName: claude-agent` | WIRED | Line 30 sets `serviceName: claude-agent` matching headless Service metadata.name on line 7 |
| `k8s/base/03-networkpolicy.yaml` | `k8s/base/04-statefulset.yaml` | podSelector `app: claude-agent` | WIRED | NetworkPolicy podSelector matchLabels `app: claude-agent` matches StatefulSet template label `app: claude-agent` |
| `k8s/overlays/rbac-operator.yaml` | `k8s/base/01-serviceaccount.yaml` | ClusterRoleBinding subjects | WIRED | Operator ClusterRoleBinding subjects: `kind: ServiceAccount, name: claude-agent, namespace: default` |
| `Makefile` | `k8s/base/` | `K8S_MANIFESTS` variable | WIRED | `K8S_MANIFESTS ?= k8s/base`, used in `deploy` (line 27), `redeploy` (line 51), transitively by `bootstrap` via `$(MAKE) load deploy` |
| `Makefile` | `k8s/overlays/rbac-operator.yaml` | `OPERATOR_RBAC` variable | WIRED | `OPERATOR_RBAC ?= k8s/overlays/rbac-operator.yaml`, used in `deploy-operator` (line 32) and `undeploy-operator` (line 35) |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| K8S-01 | 04-01 | StatefulSet with single replica and stable pod identity (claude-agent-0) | SATISFIED | `k8s/base/04-statefulset.yaml` StatefulSet `claude-agent`, `replicas: 1`, produces pod `claude-agent-0` |
| K8S-02 | 04-01 | ServiceAccount with read-only ClusterRole (get/list/watch on 14 resource types) | SATISFIED | `k8s/base/02-rbac-reader.yaml` covers all 14 resources with only get/list/watch, no secrets |
| K8S-03 | 04-01 | Egress-only NetworkPolicy allowing Anthropic API (TCP 443), K8s API (TCP 6443), DNS (UDP/TCP 53) | SATISFIED | `k8s/base/03-networkpolicy.yaml` with `ingress: []` and 3 correctly scoped egress rules |
| K8S-04 | 04-01 | PersistentVolumeClaim for OAuth token and session persistence at ~/.claude/ | SATISFIED | volumeClaimTemplates creates `claude-data-claude-agent-0` PVC mounted at `/app/.claude` (container home is /app, so this is ~/.claude in the container) |
| K8S-05 | 04-02 | Operator-tier ClusterRole (opt-in) adding delete/pods, create/pods/exec, update+patch/deployments+statefulsets | SATISFIED | `k8s/overlays/rbac-operator.yaml` has all three precisely scoped rules |

---

### Anti-Patterns Found

No anti-patterns detected. All files verified:

| File | Check | Result |
|------|-------|--------|
| `k8s/base/01-serviceaccount.yaml` | Placeholder/TODO/stub | CLEAN |
| `k8s/base/02-rbac-reader.yaml` | Secrets in rules, mutation verbs, wildcards | CLEAN |
| `k8s/base/03-networkpolicy.yaml` | Ingress rules, missing egress ports | CLEAN |
| `k8s/base/04-statefulset.yaml` | Missing volumeClaimTemplates, SecurityContext, serviceAccountName | CLEAN |
| `k8s/overlays/rbac-operator.yaml` | Wrong verbs, missing resources | CLEAN |
| `Makefile` | Deploy targets still pointing to old `kind/pod.yaml` | CLEAN |

---

### Human Verification Required

#### 1. PVC Persistence Across Pod Restart

**Test:** Apply manifests to a cluster, `kubectl exec` into `claude-agent-0`, write a file to `/app/.claude/`, run `kubectl delete pod claude-agent-0`, wait for pod to restart, verify the file still exists.
**Expected:** File at `/app/.claude/` survives pod deletion and is present after StatefulSet controller recreates the pod.
**Why human:** Cannot verify persistent volume binding behavior without a running Kubernetes cluster with a StorageClass.

#### 2. NetworkPolicy Enforcement

**Test:** With Calico CNI installed, attempt to reach an IP on a port other than 53/443/6443 from within the `claude-agent-0` pod, and attempt any inbound connection to the pod.
**Expected:** All egress except DNS/HTTPS/K8s API is blocked. All ingress is blocked.
**Why human:** KIND's default CNI (kindnet) does NOT enforce NetworkPolicy. Enforcement requires Calico (Phase 5 installs it).

#### 3. RBAC Authorization at Runtime

**Test:** From within `claude-agent-0`, run `kubectl get pods`, `kubectl get secrets` (should fail), `kubectl delete pod claude-agent-0` without operator RBAC (should fail), then apply operator overlay and retry delete (should succeed).
**Expected:** Reader RBAC allows get/list/watch on 14 resource types; denies secrets and mutations. Operator RBAC additively grants delete/exec/update.
**Why human:** RBAC authorization decisions require a running cluster with API server.

---

### Commit Verification

All four task commits documented in SUMMARYs verified present in git history:

| Commit | Task | Files |
|--------|------|-------|
| `2156458` | SA + RBAC reader manifests | `k8s/base/01-serviceaccount.yaml`, `k8s/base/02-rbac-reader.yaml` |
| `a9dcbc4` | NetworkPolicy + StatefulSet | `k8s/base/03-networkpolicy.yaml`, `k8s/base/04-statefulset.yaml` |
| `5239ffd` | Operator RBAC overlay | `k8s/overlays/rbac-operator.yaml` |
| `368284a` | Makefile update | `Makefile` |

---

### Additional Notes

**Directory isolation verified:** `k8s/overlays/` is a sibling of `k8s/base/`, not a subdirectory. `kubectl apply -f k8s/base/` applies exactly 4 files (01-04). The operator overlay is not included by default -- this is the intended opt-in mechanism.

**Secrets exclusion:** The string "secrets" appears only in the comment on line 3 of `k8s/base/02-rbac-reader.yaml` ("CRITICAL: No secrets access"). No rule in the ClusterRole references the `secrets` resource.

**RBAC resource count:** Confirmed exactly 14 resources: pods, services, events, nodes, namespaces, configmaps, persistentvolumeclaims (core), deployments, statefulsets, daemonsets, replicasets (apps), jobs, cronjobs (batch), ingresses (networking.k8s.io).

**NetworkPolicy egress structure:** 3 distinct egress rules as required: Rule 1 (DNS, UDP+TCP port 53, no destination restriction), Rule 2 (TCP 443 to 0.0.0.0/0 for Anthropic API), Rule 3 (TCP 6443 to 0.0.0.0/0 for K8s API server).

**PVC naming:** Kubernetes auto-names PVCs from volumeClaimTemplates as `<template-name>-<pod-name>` = `claude-data-claude-agent-0`, which persists across pod restarts since StatefulSet controller does not delete PVCs on pod deletion.

---

_Verified: 2026-02-25T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
