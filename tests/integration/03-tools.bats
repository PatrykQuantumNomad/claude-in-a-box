#!/usr/bin/env bats
# Tool verification tests.
# Runs the existing verify-tools.sh script inside the pod to validate
# all 30+ debugging tools, plus kubectl cluster access checks.

load helpers

setup_file() {
  wait_for_pod
}

@test "tools: verify-tools.sh passes inside pod" {
  run exec_in_pod /usr/local/bin/verify-tools.sh
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "tools: kubectl is configured for cluster access" {
  run exec_in_pod kubectl get pods -n default
  [ "$status" -eq 0 ]
}

@test "tools: kubectl client version matches expected" {
  run exec_in_pod kubectl version --client --output=json
  [ "$status" -eq 0 ]
  [[ "$output" == *"clientVersion"* ]]
}
