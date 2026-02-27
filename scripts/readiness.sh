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
#   Runs `claude auth status` to verify that the session credentials (from
#   /login) are valid. This is a heavier check than the liveness probe
#   (healthcheck.sh) because it validates credentials, not just process
#   existence.
#
# Performance note:
#   Each invocation spawns a subprocess. The Kubernetes probe periodSeconds
#   should be 30s or higher to avoid overlapping probes.
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

set -euo pipefail

[ "${CLAUDE_TEST_MODE:-}" = "true" ] && exit 0

# Verify the Claude session credentials are valid by querying auth status.
# Stdout/stderr suppressed -- only the exit code matters to Kubernetes.
claude auth status > /dev/null 2>&1
