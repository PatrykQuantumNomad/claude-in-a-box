# Phase 5: Integration Testing - Research

**Researched:** 2026-02-25
**Domain:** KIND-based integration test suite -- BATS testing framework, Calico CNI for NetworkPolicy enforcement, kubectl exec/auth assertions, PVC persistence validation
**Confidence:** HIGH

## Summary

Phase 5 produces an automated integration test suite that validates the complete Claude-in-a-box system works end-to-end in a KIND cluster. The test suite covers five categories: RBAC (reader and operator tiers), networking (DNS, HTTPS egress, K8s API access), tool verification (30+ debugging tools), persistence (PVC data survives pod deletion), and Remote Control connectivity (outbound HTTPS to Anthropic API).

The core technical challenge has two parts: (1) KIND's default CNI (kindnet) does NOT enforce NetworkPolicy, so Calico must be installed for networking tests to be meaningful, and (2) the test suite must be shell-based because all assertions are against a running Kubernetes cluster using kubectl, curl, dig, and similar tools. This makes BATS (Bash Automated Testing System) the standard choice -- it is purpose-built for testing CLI tools and shell workflows, produces TAP-compliant output, and is widely used for Kubernetes integration testing.

The existing project already has all the infrastructure needed: KIND cluster config (`kind/cluster.yaml`), Makefile targets (`bootstrap`, `deploy`), K8s manifests (`k8s/base/`), and a tool verification script (`scripts/verify-tools.sh`). The test suite adds a `tests/` directory with BATS test files organized by category, a modified KIND cluster config that disables the default CNI for Calico, and a `make test` target that orchestrates the full test run.

**Primary recommendation:** Use BATS (bats-core) with plain kubectl/curl assertions (no bats-detik -- overkill for this scope), a separate KIND cluster config with Calico CNI for NetworkPolicy enforcement, and organize tests as one `.bats` file per test category.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEV-04 | KIND integration test suite validating RBAC, networking, tool verification, persistence, and Remote Control connectivity | BATS test framework with 5 test files (one per category), Calico CNI for NetworkPolicy enforcement, kubectl auth can-i for RBAC, kubectl exec for in-pod assertions, PVC write/delete/verify cycle for persistence |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bats-core | 1.13.0 | Bash test framework | TAP-compliant, purpose-built for CLI/shell testing, widely used for K8s integration tests |
| Calico | 3.31.4 | CNI with NetworkPolicy enforcement | KIND's default CNI (kindnet) does not enforce NetworkPolicy; Calico is the standard open-source CNI that does |
| kubectl | (already in image) | K8s API assertions | Built into the claude-in-a-box image; used for auth can-i, exec, get, describe |
| curl/dig/ping | (already in image) | Networking assertions | Built into the claude-in-a-box image; used for DNS, HTTPS egress, connectivity tests |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| bats-support + bats-assert | BATS helper libraries for richer assertions | Optional -- plain `[ "$status" -eq 0 ]` is sufficient for this test suite; these add `assert_output`, `assert_line`, `refute_output` |
| timeout (coreutils) | Wrap curl/wget with explicit timeouts for blocked egress tests | When testing that egress is blocked (curl to non-allowed port should timeout, not hang) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| BATS | Python pytest + subprocess | More powerful assertions but heavier dependency; BATS is simpler for pure shell/kubectl commands |
| BATS | bats-detik (K8s-specific BATS lib) | Natural language K8s assertions but adds dependency for minimal benefit; tests here are straightforward kubectl commands |
| Calico | Cilium | Both enforce NetworkPolicy; Calico has better KIND documentation and smaller resource footprint |
| Separate test KIND config | Modify existing KIND config | Keeps existing dev workflow untouched; test config adds Calico-specific settings |

### Installation

BATS is installed locally on the developer machine (not in the container). No npm install needed -- use git submodule or direct clone:

```bash
# Option 1: Git clone into tests/
git clone --depth 1 https://github.com/bats-core/bats-core.git tests/bats

# Option 2: Use bats already on system (brew install bats-core)
# Option 3: npm install -g bats (if preferred)
```

**Recommended approach for this project:** Bundle bats-core as a git submodule or download into `tests/bats/` so the test suite is self-contained with zero external dependencies. The Makefile `test` target can handle setup automatically.

## Architecture Patterns

### Recommended Test Structure

```
tests/
  integration/
    helpers.bash         # Shared setup, helper functions, constants
    01-rbac.bats         # RBAC reader + operator tier tests
    02-networking.bats   # DNS, HTTPS egress, K8s API, blocked port tests
    03-tools.bats        # Tool verification inside running pod
    04-persistence.bats  # PVC data survives pod delete/recreate
    05-remote-control.bats  # Outbound HTTPS connectivity to Anthropic API
  bats/                  # bats-core (git submodule or downloaded)
kind/
  cluster.yaml           # Existing dev cluster (kindnet CNI)
  cluster-test.yaml      # Test cluster (Calico CNI, disableDefaultCNI)
```

### Pattern 1: Test File with Shared Helpers

**What:** Each `.bats` file sources a shared `helpers.bash` for common setup (pod name, namespace, timeout values) and utility functions (wait_for_pod, exec_in_pod).
**When to use:** Always -- avoids duplicating kubectl wait/exec boilerplate across test files.

```bash
# tests/integration/helpers.bash
POD_NAME="claude-agent-0"
NAMESPACE="default"
SA_NAME="claude-agent"
KUBECTL_TIMEOUT="30s"

# Wait for pod to be ready
wait_for_pod() {
    kubectl wait --for=condition=Ready "pod/${POD_NAME}" \
        -n "${NAMESPACE}" --timeout=120s
}

# Execute command inside the claude-agent pod
exec_in_pod() {
    kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- "$@"
}
```

### Pattern 2: RBAC Testing with kubectl auth can-i --as

**What:** Use `kubectl auth can-i` with `--as=system:serviceaccount:<ns>:<sa>` to impersonate the ServiceAccount and verify permissions without needing to exec into the pod.
**When to use:** For RBAC tests -- this runs from the test machine, not inside the pod. Faster and more reliable than exec.

```bash
# tests/integration/01-rbac.bats
load helpers

@test "reader: can list pods" {
    run kubectl auth can-i list pods \
        --as="system:serviceaccount:${NAMESPACE}:${SA_NAME}"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "reader: cannot get secrets" {
    run kubectl auth can-i get secrets \
        --as="system:serviceaccount:${NAMESPACE}:${SA_NAME}"
    [ "$status" -eq 0 ]
    [ "$output" = "no" ]
}

@test "reader: cannot delete pods" {
    run kubectl auth can-i delete pods \
        --as="system:serviceaccount:${NAMESPACE}:${SA_NAME}"
    [ "$status" -eq 0 ]
    [ "$output" = "no" ]
}
```

### Pattern 3: In-Pod Networking Tests via kubectl exec

**What:** Use `kubectl exec` to run networking commands (dig, curl) inside the claude-agent pod, testing from the pod's network namespace.
**When to use:** For networking tests that must run from the pod's perspective (DNS resolution, egress through NetworkPolicy).

```bash
# tests/integration/02-networking.bats
load helpers

@test "dns: resolves kubernetes.default.svc.cluster.local" {
    run exec_in_pod dig +short kubernetes.default.svc.cluster.local
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "egress: can reach Anthropic API on port 443" {
    run exec_in_pod curl -sf --max-time 10 -o /dev/null \
        -w "%{http_code}" https://api.anthropic.com/v1/messages
    # 401 is expected (no auth token) but proves connectivity
    [[ "$output" =~ ^(401|403|200) ]] || [ "$status" -eq 0 ]
}
```

### Pattern 4: Persistence Test via Delete/Recreate Cycle

**What:** Write a marker file to the PVC, delete the pod, wait for StatefulSet to recreate it, verify the file still exists.
**When to use:** For persistence tests. StatefulSet controller automatically recreates the pod with the same PVC.

```bash
# tests/integration/04-persistence.bats
load helpers

@test "persistence: data survives pod deletion" {
    # Write marker file
    exec_in_pod sh -c 'echo "persistence-test-marker" > /app/.claude/test-marker.txt'

    # Delete pod (StatefulSet will recreate it)
    kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}"

    # Wait for pod to be ready again
    wait_for_pod

    # Verify marker file exists
    run exec_in_pod cat /app/.claude/test-marker.txt
    [ "$status" -eq 0 ]
    [ "$output" = "persistence-test-marker" ]
}
```

### Anti-Patterns to Avoid

- **Running tests without Calico:** If you skip Calico installation, all NetworkPolicy tests will pass vacuously because kindnet allows all traffic. This gives false confidence.
- **Hardcoding IP addresses in tests:** K8s API server IP varies per cluster. Use DNS names (kubernetes.default.svc.cluster.local) or kubectl commands, not IP addresses.
- **Testing Remote Control with actual auth:** Remote Control requires a real Anthropic OAuth token. Integration tests should only verify outbound HTTPS connectivity to Anthropic API endpoints (TCP 443 reachable), not actual session establishment.
- **Sequential test dependencies across files:** Each BATS file should be independently runnable. Don't require 01-rbac.bats to run before 02-networking.bats. Use `setup_file()` to establish preconditions.
- **Missing timeouts on blocked egress tests:** When testing that egress is blocked, `curl` or `wget` will hang indefinitely without `--max-time` or `--timeout`. Always set explicit short timeouts (1-5 seconds) for negative tests.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shell test framework | Custom test runner with pass/fail counting | BATS (bats-core) | TAP output, setup/teardown, retries, timeouts, file-level and test-level hooks |
| RBAC permission checking | kubectl exec into pod + kubectl auth can-i | kubectl auth can-i --as=system:serviceaccount:... | Runs from test machine, no exec needed, standard K8s API |
| NetworkPolicy enforcement | iptables rules or custom proxy | Calico CNI | Standard K8s NetworkPolicy API, works with existing manifests |
| Waiting for pod ready | sleep loops | kubectl wait --for=condition=Ready | Built-in, idempotent, has timeout |
| Tool verification | New per-tool check scripts | Existing verify-tools.sh via kubectl exec | Already written and tested in Phase 1 |

**Key insight:** The test infrastructure builds on everything from Phases 1-4. The verify-tools.sh script from Phase 1, the RBAC manifests from Phase 4, the StatefulSet/PVC from Phase 4, and the Makefile from Phase 3 are all test targets. The test suite validates them, it does not recreate them.

## Common Pitfalls

### Pitfall 1: Calico Pods Not Ready After Installation

**What goes wrong:** After applying Calico manifests, calico-node pods stay in CrashLoopBackOff or Init state, blocking all pod networking including CoreDNS.
**Why it happens:** KIND nodes have loose Reverse Path Filtering (rp_filter=2) which causes Felix (Calico's dataplane agent) to fail its startup check.
**How to avoid:** After installing Calico, set `FELIX_IGNORELOOSERPF=true` on the calico-node DaemonSet, OR set rp_filter to 0 on KIND nodes via `docker exec`.
**Warning signs:** `kubectl -n calico-system get pods` shows CrashLoopBackOff. CoreDNS pods stuck in Pending or ContainerCreating.

**Recommended fix for this project:**
```bash
# After Calico install, wait for operator, then set env var
kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true 2>/dev/null || \
    kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
```
Note: Calico operator-based installs use the `calico-system` namespace. Manifest-based installs use `kube-system`. The test setup script should handle both.

### Pitfall 2: Calico Installation Race with CoreDNS

**What goes wrong:** Calico is installed but CoreDNS pods are stuck in Pending because they were scheduled before the CNI was ready.
**Why it happens:** When disableDefaultCNI is true, no CNI is available at cluster creation time. CoreDNS pods are created but cannot get IPs. Calico installation fixes the CNI, but existing Pending pods may not recover automatically.
**How to avoid:** After Calico is installed and calico-node pods are Running, restart CoreDNS if it is stuck: `kubectl -n kube-system rollout restart deployment/coredns`.
**Warning signs:** `kubectl -n kube-system get pods` shows coredns pods in Pending or ContainerCreating long after calico-node is Running.

### Pitfall 3: RBAC Tests Pass Without Operator Overlay

**What goes wrong:** Operator permission tests (delete pods, create exec, update deployments) pass even though the operator overlay is not applied.
**Why it happens:** The test is running kubectl auth can-i from the developer's kubeconfig context, which has cluster-admin permissions, instead of impersonating the ServiceAccount.
**How to avoid:** Always use `--as=system:serviceaccount:default:claude-agent` flag with `kubectl auth can-i`. This impersonates the ServiceAccount, testing its actual permissions.
**Warning signs:** All RBAC tests return "yes" regardless of which ClusterRoles are applied.

### Pitfall 4: NetworkPolicy Tests Give False Positives Without Calico

**What goes wrong:** Tests verify that egress to port 8080 is blocked, but the test passes because curl got connection refused (no server listening), not because NetworkPolicy blocked it.
**Why it happens:** Without a policy-aware CNI, NetworkPolicy has no effect. The curl failure is from "no server" not "policy blocked."
**How to avoid:** Verify Calico is running before networking tests. Use a known-reachable endpoint (like an internal ClusterIP service on an allowed port) as a positive control, then test that the same endpoint on a blocked port times out.
**Warning signs:** All networking tests pass on a cluster without Calico installed.

### Pitfall 5: Persistence Test Flakes Due to Pod Startup Time

**What goes wrong:** After deleting the pod and waiting for recreation, kubectl exec fails because the pod is Running but the container process hasn't started.
**Why it happens:** `kubectl wait --for=condition=Ready` returns when the pod has passed readiness probes, but the initial healthcheck.sh runs pgrep which matches the entrypoint.sh shell process, not necessarily a fully-running Claude Code. In test scenarios where Claude Code auth may not be configured, the pod may restart quickly.
**How to avoid:** Add a small retry loop after wait_for_pod, or use `kubectl exec ... -- echo ok` as a probe that the exec path is working.
**Warning signs:** Intermittent "error: unable to upgrade connection" or "container not running" errors in persistence tests.

### Pitfall 6: curl to Anthropic API Returns Error Without Token

**What goes wrong:** Test expects HTTP 200 from api.anthropic.com but gets 401 or 403 because no authentication token is provided.
**Why it happens:** The test is checking connectivity, not authentication. The Anthropic API returns 401/403 for unauthenticated requests.
**How to avoid:** Test connectivity by accepting any HTTP response (200, 401, 403) as proof that TCP 443 egress works. Use `-w "%{http_code}"` with curl and assert the response is a valid HTTP status code, not a timeout or connection error.
**Warning signs:** Test expects `[ "$output" = "200" ]` and fails with 401.

## Code Examples

Verified patterns from official sources and project conventions:

### KIND Cluster Config with Calico Support

```yaml
# kind/cluster-test.yaml
# Used for integration tests -- disables default CNI so Calico can be installed.
# NetworkPolicy enforcement requires Calico; kindnet does NOT enforce policies.
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: claude-in-a-box
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

### Calico Installation Script

```bash
#!/usr/bin/env bash
# install-calico.sh -- Install Calico CNI into a KIND cluster
# Source: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-3.31.4}"

echo "Installing Calico ${CALICO_VERSION}..."

# Install Calico operator and CRDs
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"

# Install Calico custom resources (configures the CNI)
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

# Wait for operator to be ready
echo "Waiting for Calico operator..."
kubectl wait --for=condition=Available deployment/tigera-operator \
    -n tigera-operator --timeout=120s

# Fix RPF check for KIND nodes
echo "Setting FELIX_IGNORELOOSERPF=true..."
kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true 2>/dev/null || \
    kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

# Wait for calico-node to be ready
echo "Waiting for calico-node pods..."
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node \
    -n calico-system --timeout=120s 2>/dev/null || \
    kubectl wait --for=condition=Ready pods -l k8s-app=calico-node \
    -n kube-system --timeout=120s

# Restart CoreDNS in case it was stuck before CNI was ready
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=60s

echo "Calico installed and ready."
```

### BATS Test Helper Library

```bash
# tests/integration/helpers.bash
# Shared constants and utility functions for all integration tests.

POD_NAME="claude-agent-0"
NAMESPACE="default"
SA_NAME="claude-agent"
SA_FULL="system:serviceaccount:${NAMESPACE}:${SA_NAME}"
EXEC_TIMEOUT=30

# Source BATS support libraries if available
if [ -f "${BATS_TEST_DIRNAME}/../bats/lib/bats-support/load.bash" ]; then
    load "${BATS_TEST_DIRNAME}/../bats/lib/bats-support/load.bash"
    load "${BATS_TEST_DIRNAME}/../bats/lib/bats-assert/load.bash"
fi

# Wait for the claude-agent pod to be Ready
wait_for_pod() {
    kubectl wait --for=condition=Ready "pod/${POD_NAME}" \
        -n "${NAMESPACE}" --timeout=120s
}

# Execute a command inside the claude-agent pod
exec_in_pod() {
    kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- "$@"
}

# Check if a kubectl auth can-i returns "yes"
can_i() {
    local verb="$1"
    local resource="$2"
    kubectl auth can-i "${verb}" "${resource}" \
        --as="${SA_FULL}" 2>/dev/null
}

# Check kubectl auth can-i with a specific API group resource
can_i_resource() {
    local verb="$1"
    local resource="$2"
    local result
    result=$(kubectl auth can-i "${verb}" "${resource}" \
        --as="${SA_FULL}" 2>/dev/null)
    echo "${result}"
}
```

### Complete RBAC Test File

```bash
# tests/integration/01-rbac.bats
# RBAC tests for reader and operator tiers.
# Tests use kubectl auth can-i with ServiceAccount impersonation.

load helpers

# -- Reader tier tests (always applied) --

@test "reader: can get pods" {
    run can_i get pods
    [ "$output" = "yes" ]
}

@test "reader: can list services" {
    run can_i list services
    [ "$output" = "yes" ]
}

@test "reader: can watch deployments" {
    run can_i watch deployments.apps
    [ "$output" = "yes" ]
}

@test "reader: can list events" {
    run can_i list events
    [ "$output" = "yes" ]
}

@test "reader: can get nodes" {
    run can_i get nodes
    [ "$output" = "yes" ]
}

@test "reader: can list namespaces" {
    run can_i list namespaces
    [ "$output" = "yes" ]
}

@test "reader: can get configmaps" {
    run can_i get configmaps
    [ "$output" = "yes" ]
}

@test "reader: can list ingresses" {
    run can_i list ingresses.networking.k8s.io
    [ "$output" = "yes" ]
}

@test "reader: can list persistentvolumeclaims" {
    run can_i list persistentvolumeclaims
    [ "$output" = "yes" ]
}

@test "reader: can list jobs" {
    run can_i list jobs.batch
    [ "$output" = "yes" ]
}

@test "reader: can list cronjobs" {
    run can_i list cronjobs.batch
    [ "$output" = "yes" ]
}

@test "reader: can list statefulsets" {
    run can_i list statefulsets.apps
    [ "$output" = "yes" ]
}

@test "reader: can list daemonsets" {
    run can_i list daemonsets.apps
    [ "$output" = "yes" ]
}

@test "reader: can list replicasets" {
    run can_i list replicasets.apps
    [ "$output" = "yes" ]
}

# -- Reader tier DENY tests --

@test "reader: cannot get secrets" {
    run can_i get secrets
    [ "$output" = "no" ]
}

@test "reader: cannot delete pods" {
    run can_i delete pods
    [ "$output" = "no" ]
}

@test "reader: cannot create pods" {
    run can_i create pods
    [ "$output" = "no" ]
}

@test "reader: cannot update deployments" {
    run can_i update deployments.apps
    [ "$output" = "no" ]
}

# -- Operator tier tests (applied separately) --

@test "operator: can delete pods" {
    # Apply operator overlay
    kubectl apply -f k8s/overlays/rbac-operator.yaml
    run can_i delete pods
    [ "$output" = "yes" ]
}

@test "operator: can create pods/exec" {
    run can_i create pods/exec
    [ "$output" = "yes" ]
}

@test "operator: can update deployments" {
    run can_i update deployments.apps
    [ "$output" = "yes" ]
}

@test "operator: can patch statefulsets" {
    run can_i patch statefulsets.apps
    [ "$output" = "yes" ]
}
```

### Networking Test Pattern

```bash
# tests/integration/02-networking.bats
# Network tests run from inside the pod to validate NetworkPolicy enforcement.

load helpers

setup_file() {
    wait_for_pod
}

@test "dns: resolves kubernetes.default.svc.cluster.local" {
    run exec_in_pod dig +short kubernetes.default.svc.cluster.local
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "dns: resolves external domain" {
    run exec_in_pod dig +short api.anthropic.com
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "egress: can reach Anthropic API on port 443" {
    # 401 expected (no auth) but proves TCP 443 egress works
    run exec_in_pod curl -sf --max-time 10 -o /dev/null \
        -w "%{http_code}" https://api.anthropic.com/v1/messages
    # Any HTTP response proves connectivity; 401/403 is expected without auth
    [[ "$output" =~ ^[0-9]{3}$ ]]
}

@test "egress: can reach K8s API server" {
    run exec_in_pod kubectl get --raw /healthz
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "egress: blocked on non-allowed port (port 8080)" {
    # Use --max-time to prevent hanging; expect timeout or connection refused
    run exec_in_pod curl -sf --max-time 3 -o /dev/null http://1.1.1.1:8080
    [ "$status" -ne 0 ]
}
```

### Tool Verification via Existing Script

```bash
# tests/integration/03-tools.bats
# Runs the existing verify-tools.sh inside the pod.

load helpers

setup_file() {
    wait_for_pod
}

@test "tools: verify-tools.sh passes inside pod" {
    run exec_in_pod /usr/local/bin/verify-tools.sh
    [ "$status" -eq 0 ]
}

@test "tools: kubectl accessible and configured" {
    run exec_in_pod kubectl version --client
    [ "$status" -eq 0 ]
}

@test "tools: kubectl can access cluster API" {
    run exec_in_pod kubectl get pods -n default
    [ "$status" -eq 0 ]
}
```

### Makefile Test Target

```makefile
# Integration test configuration
KIND_TEST_CONFIG ?= kind/cluster-test.yaml
BATS            ?= tests/bats/bin/bats
TEST_DIR        ?= tests/integration

test: ## Run integration test suite against KIND cluster
	$(BATS) --tap $(TEST_DIR)/*.bats

test-setup: build ## Create test cluster with Calico, build, load, deploy
	@if ! kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind create cluster --name $(CLUSTER_NAME) \
			--config $(KIND_TEST_CONFIG) --wait 60s; \
		scripts/install-calico.sh; \
	fi
	$(MAKE) load deploy
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Calico manifest-based install (calico.yaml) | Calico operator-based install (tigera-operator.yaml + custom-resources.yaml) | Calico 3.25+ (2023) | Operator manages lifecycle; use `kubectl create` not `kubectl apply` for CRDs |
| BATS (sstephenson/bats) | bats-core (bats-core/bats-core) | 2017 fork | Original bats abandoned; bats-core is actively maintained, adds features (retries, timeouts, file-level hooks) |
| Manual sleep loops for pod readiness | kubectl wait --for=condition=Ready | K8s 1.11+ (2018) | Built-in, timeout-aware, idempotent |
| Testing RBAC by exec into pod | kubectl auth can-i --as=system:serviceaccount:... | Always available | Runs from test machine, faster, no exec dependency |

**Deprecated/outdated:**
- `sstephenson/bats`: Abandoned since 2016. Use `bats-core/bats-core` (actively maintained, v1.13.0).
- Calico manifest install (`calico.yaml`): Still works but operator install is recommended for production. For KIND testing, either works; operator is cleaner.
- `kind.sigs.k8s.io/v1alpha3`: Old KIND config API version. Use `kind.x-k8s.io/v1alpha4`.

## Open Questions

1. **Should the test cluster be separate from the dev cluster?**
   - What we know: The test cluster needs `disableDefaultCNI: true` for Calico, but the dev cluster uses kindnet for simplicity.
   - What's unclear: Whether to modify the existing cluster config or use a separate one.
   - Recommendation: Use a separate `kind/cluster-test.yaml` for tests. Keep `kind/cluster.yaml` unchanged for dev. The `make test-setup` target uses the test config. This avoids breaking the developer's `make bootstrap` workflow.

2. **Should Calico be installed in the dev cluster too?**
   - What we know: Calico adds 2-3 minutes to cluster creation and uses ~200MB RAM per node.
   - What's unclear: Whether developers will want NetworkPolicy enforcement during regular development.
   - Recommendation: No. Keep Calico only in the test cluster. Developers who want NetworkPolicy enforcement can manually run `make test-setup` instead of `make bootstrap`.

3. **How to handle Remote Control connectivity tests without an auth token?**
   - What we know: Remote Control requires an OAuth token. Integration tests should not require real credentials.
   - What's unclear: Whether to test Remote Control at all or just verify TCP 443 connectivity.
   - Recommendation: Test only that TCP 443 egress to api.anthropic.com is successful (HTTP status received, even if 401). Document that full Remote Control testing requires a real token and is manual. The networking egress test on port 443 covers the connectivity requirement.

4. **How to handle test cleanup?**
   - What we know: Some tests modify cluster state (apply operator RBAC, delete pods, write marker files).
   - What's unclear: Whether to clean up in teardown or let the cluster be destroyed.
   - Recommendation: Tests should clean up their own state in `teardown` or `teardown_file`. However, since `make test` runs against a potentially-destroyed cluster, the operator RBAC tests should have their own setup/teardown that applies and removes the overlay.

5. **BATS installation method?**
   - What we know: BATS can be installed via npm, brew, git clone, or git submodule.
   - What's unclear: Which method is most appropriate for this project.
   - Recommendation: Download bats-core into `tests/bats/` with a setup script that the Makefile calls automatically. This keeps the project self-contained. Alternatively, check if `bats` is available on PATH and fall back to the local copy.

## Sources

### Primary (HIGH confidence)
- [Calico on KIND docs](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) - Calico 3.31 installation on KIND, cluster config, operator method
- [Kubernetes RBAC docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) - kubectl auth can-i, ServiceAccount impersonation
- [Kubernetes NetworkPolicy docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Egress rules, deny-all patterns
- [Kubernetes DNS debugging](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) - Testing DNS from inside pods
- [bats-core GitHub](https://github.com/bats-core/bats-core) - v1.13.0, TAP output, setup/teardown hooks, retries, timeouts

### Secondary (MEDIUM confidence)
- [Effective E2E Testing with BATS](https://blog.cubieserver.de/2025/effective-end-to-end-testing-with-bats/) - BATS patterns for infrastructure testing: setup_file/teardown_file, retry, annotations
- [KIND + Calico blog (alexbrand)](https://alexbrand.dev/post/creating-a-kind-cluster-with-calico-networking/) - Confirmed FELIX_IGNORELOOSERPF workaround, CoreDNS restart pattern
- [kubernetes-network-policy-recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/11-deny-egress-traffic-from-an-application.md) - Egress deny test patterns: timeout vs connection refused, DNS blocking
- [bats-detik](https://github.com/bats-core/bats-detik) - K8s-specific BATS library (evaluated but not recommended for this scope)
- [KIND issue #891](https://github.com/kubernetes-sigs/kind/issues/891) - RPF workaround confirmed for Calico on KIND

### Tertiary (LOW confidence)
- Calico resource usage estimates (~200MB per node) -- based on general community experience, not measured
- bats-core v1.13.0 release date (November 2025) -- from GitHub page, exact date not independently verified

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - BATS and Calico are the standard tools for shell-based K8s integration testing; verified via official docs
- Architecture: HIGH - Test organization and patterns based on established BATS + kubectl conventions; code examples verified against K8s API
- Pitfalls: HIGH - Calico RPF issue confirmed by KIND issue #891 and official Calico docs; RBAC impersonation verified against K8s docs; false positive patterns documented in multiple sources
- Networking test patterns: MEDIUM - Egress blocking patterns verified via kubernetes-network-policy-recipes but specific curl behavior with Calico needs runtime validation

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (BATS and K8s APIs are stable; Calico version may update)
