#!/usr/bin/env bash
# Readiness probe: Is Claude Code authenticated and ready to serve?
# Used by: Kubernetes exec readiness probe
# Returns: 0 (ready) or 1 (not ready)
# Note: This spawns a Node.js process (~3-5s). Use 30s+ probe intervals per research guidance.
[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0
claude auth status > /dev/null 2>&1
