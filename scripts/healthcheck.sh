#!/usr/bin/env bash
# Liveness probe: Is the Claude Code process running?
# Used by: Docker HEALTHCHECK, Kubernetes exec liveness probe
# Returns: 0 (healthy) or 1 (unhealthy)
[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0
pgrep -f "claude" > /dev/null 2>&1
