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
#     restarts the container. Lightweight -- single pgrep call.
#   - Readiness (readiness.sh): Is the process authenticated and ready to
#     serve? If not, Kubernetes removes the pod from service endpoints.
#     Heavier -- runs `claude auth status` subprocess.
#
# How it works:
#   Uses `pgrep -f "claude"` to search for any running process whose command
#   line contains the string "claude". This matches the Claude Code native
#   binary started by the entrypoint. The -f flag matches against the full
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

set -euo pipefail

[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0

# Match any process with "claude" in its command line (native claude binary)
pgrep -f "bin/claude" > /dev/null 2>&1
