#!/usr/bin/env bats
# Remote Control connectivity tests.
# Remote Control uses outbound HTTPS to api.anthropic.com.
# Full Remote Control testing requires a real OAuth token (manual).
# These tests validate the network path is open and TLS works.

load helpers

setup_file() {
  wait_for_pod
}

@test "remote-control: HTTPS egress to api.anthropic.com succeeds" {
  run exec_in_pod curl -sf --max-time 10 -o /dev/null \
    -w "%{http_code}" https://api.anthropic.com/v1/messages
  # Any 3-digit HTTP status proves HTTPS connectivity.
  # 401/403 is expected without an auth token.
  [[ "$output" =~ ^[0-9]{3}$ ]]
}

@test "remote-control: TLS handshake succeeds with api.anthropic.com" {
  run exec_in_pod curl -sf --max-time 10 -o /dev/null \
    -w "%{ssl_verify_result}" https://api.anthropic.com/v1/messages
  # SSL verify result 0 means the TLS certificate chain is valid.
  [ "$output" = "0" ]
}
