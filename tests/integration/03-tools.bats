#!/usr/bin/env bats
# Tool verification tests.
# Runs the existing verify-tools.sh script inside the pod to validate
# all 32+ debugging tools are present and functional.

load helpers

setup_file() {
  wait_for_pod
}

@test "tools: all debugging tools are installed and functional" {
  run exec_in_pod /usr/local/bin/verify-tools.sh
  echo "$output"
  [ "$status" -eq 0 ]
}
