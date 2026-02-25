#!/usr/bin/env bats
# Networking tests for DNS resolution, HTTPS egress, K8s API access,
# and blocked port enforcement via NetworkPolicy.
# All tests run from inside the claude-agent pod to validate
# NetworkPolicy rules from k8s/base/03-networkpolicy.yaml.

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
  run exec_in_pod curl -sf --max-time 10 -o /dev/null \
    -w "%{http_code}" https://api.anthropic.com/v1/messages
  # Any 3-digit HTTP status proves TCP 443 egress works.
  # 401/403 is expected without an auth token.
  [[ "$output" =~ ^[0-9]{3}$ ]]
}

@test "egress: can reach K8s API server" {
  run exec_in_pod kubectl get --raw /healthz
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "egress: blocked on non-allowed port 8080" {
  # Use short timeout -- expect timeout or connection refused from NetworkPolicy.
  run exec_in_pod curl -sf --max-time 3 -o /dev/null http://1.1.1.1:8080
  [ "$status" -ne 0 ]
}
