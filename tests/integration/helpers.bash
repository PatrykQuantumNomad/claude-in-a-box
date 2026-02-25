# Shared test helpers for BATS integration tests.
# Source this file in .bats tests: load helpers
#
# Provides constants and utility functions for interacting with the
# claude-agent pod running in the KIND test cluster.

# -- Constants ----------------------------------------------------------------
POD_NAME="claude-agent-0"
NAMESPACE="default"
SA_NAME="claude-agent"
SA_FULL="system:serviceaccount:${NAMESPACE}:${SA_NAME}"
EXEC_TIMEOUT=30

# -- Functions ----------------------------------------------------------------

# Wait for the claude-agent pod to reach Ready state.
wait_for_pod() {
  kubectl wait --for=condition=Ready "pod/${POD_NAME}" \
    -n "${NAMESPACE}" --timeout=120s
}

# Execute a command inside the claude-agent pod.
# Usage: exec_in_pod <command> [args...]
exec_in_pod() {
  kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- "$@"
}

# Check if the service account has a specific permission.
# Usage: can_i <verb> <resource>
# Returns: "yes" or "no"
can_i() {
  local verb="$1"
  local resource="$2"
  kubectl auth can-i "${verb}" "${resource}" --as="${SA_FULL}" 2>/dev/null
}

# Check permission for resources with API group (e.g., deployments.apps).
# Semantic alias for can_i -- same implementation, clearer intent for grouped resources.
# Usage: can_i_resource <verb> <resource.group>
# Returns: "yes" or "no"
can_i_resource() {
  local verb="$1"
  local resource="$2"
  kubectl auth can-i "${verb}" "${resource}" --as="${SA_FULL}" 2>/dev/null
}

# Assert that the service account CAN perform an action.
# Usage: assert_can <verb> <resource>
# Fails the test if permission is denied.
assert_can() {
  local verb="$1"
  local resource="$2"
  local result
  result=$(can_i "${verb}" "${resource}")
  if [ "${result}" != "yes" ]; then
    echo "FAIL: expected 'yes' for can-i ${verb} ${resource}, got '${result}'" >&2
    return 1
  fi
}

# Assert that the service account CANNOT perform an action.
# Usage: assert_cannot <verb> <resource>
# Fails the test if permission is granted.
assert_cannot() {
  local verb="$1"
  local resource="$2"
  local result
  result=$(can_i "${verb}" "${resource}")
  if [ "${result}" != "no" ]; then
    echo "FAIL: expected 'no' for can-i ${verb} ${resource}, got '${result}'" >&2
    return 1
  fi
}
