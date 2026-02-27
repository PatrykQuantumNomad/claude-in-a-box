#!/usr/bin/env bats
# Persistence tests.
# Validates that data written to the PVC mount at /app/.claude survives
# pod deletion and recreation by the StatefulSet controller.

load helpers

setup_file() {
  wait_for_pod
}

@test "persistence: data survives pod deletion" {
  # Write a unique marker to the PVC
  run exec_in_pod sh -c 'echo "persist-test-12345" > /app/.claude/test-marker.txt'
  [ "$status" -eq 0 ]

  # Delete the pod -- StatefulSet controller will recreate it
  kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --timeout=60s

  # Wait for the recreated pod to be ready
  wait_for_pod

  # Retry loop to ensure exec path is working after recreation
  ready=false
  for i in 1 2 3 4 5; do
    if exec_in_pod echo ok 2>/dev/null; then
      ready=true
      break
    fi
    sleep 2
  done
  [ "$ready" = "true" ] || { echo "Pod not accepting exec after 5 retries" >&2; return 1; }

  # Verify the marker file survived pod deletion
  run exec_in_pod cat /app/.claude/test-marker.txt
  [ "$status" -eq 0 ]
  [ "$output" = "persist-test-12345" ]
}

teardown_file() {
  run exec_in_pod rm -f /app/.claude/test-marker.txt
}
