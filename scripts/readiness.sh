#!/usr/bin/env bash
# =============================================================================
# readiness.sh - Kubernetes Readiness Probe
# =============================================================================
#
# Determines whether the Claude Code process is authenticated and ready to
# accept work. Called by the Kubernetes exec readiness probe defined in the
# Helm chart's StatefulSet template.
#
# How it works:
#   Runs `claude auth status`, which spawns a Node.js process to verify that
#   the current OAuth token or API key is valid. This is a heavier check than
#   the liveness probe (healthcheck.sh) because it validates credentials, not
#   just process existence.
#
# Performance note:
#   Each invocation spawns a Node.js runtime (~3-5 seconds startup latency).
#   The Kubernetes probe periodSeconds MUST be 30s or higher to avoid
#   overlapping probes that spike CPU and memory on the container.
#
# CLAUDE_TEST_MODE bypass:
#   When CLAUDE_TEST_MODE=true, the probe returns 0 immediately without
#   checking auth. This exists because CI integration test pods have no
#   authentication credentials -- they only need the container running for
#   kubectl exec access, not a working Claude session.
#
# Exit codes:
#   0 - Authenticated and ready (or CLAUDE_TEST_MODE=true)
#   1 - Not authenticated or auth check failed
#
# See also: healthcheck.sh (liveness probe -- checks process, not auth)
# =============================================================================

[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0

# Verify the Claude OAuth/API key is valid by querying auth status.
# Stdout/stderr suppressed -- only the exit code matters to Kubernetes.
claude auth status > /dev/null 2>&1
