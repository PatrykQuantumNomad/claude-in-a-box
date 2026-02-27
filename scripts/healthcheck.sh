#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh - Liveness Probe (Docker HEALTHCHECK + Kubernetes)
# =============================================================================
#
# Determines whether the Claude Code process is still running. Used by both
# Docker's HEALTHCHECK instruction (standalone mode) and the Kubernetes exec
# liveness probe defined in the Helm chart's StatefulSet template.
#
# How it differs from readiness.sh:
#   - Liveness (this script): Is the process alive? If not, Kubernetes
#     restarts the container. Lightweight -- no Node.js startup cost.
#   - Readiness (readiness.sh): Is the process authenticated and ready to
#     serve? If not, Kubernetes removes the pod from service endpoints.
#     Heavier -- spawns Node.js to verify credentials.
#
# How it works:
#   Uses `pgrep -f "claude"` to search for any running process whose command
#   line contains the string "claude". This matches the Claude Code Node.js
#   process started by the entrypoint. The -f flag matches against the full
#   command line, not just the process name.
#
# CLAUDE_TEST_MODE bypass:
#   When CLAUDE_TEST_MODE=true, the probe returns 0 immediately. CI test
#   pods run `sleep infinity` instead of Claude, so there is no "claude"
#   process to find -- but the container is healthy for test purposes.
#
# Exit codes:
#   0 - Claude process is running (or CLAUDE_TEST_MODE=true)
#   1 - No Claude process found (container should be restarted)
#
# See also: readiness.sh (readiness probe -- checks auth, not just process)
# =============================================================================

[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0

# Match any process with "claude" in its command line (e.g., node .../claude-code/cli.js)
pgrep -f "claude" > /dev/null 2>&1
