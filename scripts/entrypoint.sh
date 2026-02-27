#!/usr/bin/env bash
# =============================================================================
# Claude In A Box - Container Entrypoint
# Validates authentication, dispatches to the correct Claude Code mode,
# and uses exec to hand off the process for direct signal delivery.
#
# Authentication:
#   Run /login inside Claude Code to authenticate via browser OAuth.
#   Credentials are stored in the PVC at /app/.claude/ and persist
#   across pod restarts. Only needed once per PVC.
#
# Supported modes:
#   interactive    - Local dev or `kubectl attach`. Opens the Claude REPL for
#                    live terminal interaction. Default mode.
#   remote-control - Phone/web access via `claude remote-control`. Exposes a
#                    remote session you can connect to from any device.
#                    Requires Max plan and /login credentials in PVC.
#   headless       - One-shot scripted tasks. Runs a single prompt from
#                    CLAUDE_PROMPT env var and exits with JSON output.
#                    Requires /login credentials in PVC.
# =============================================================================
set -euo pipefail

CLAUDE_MODE="${CLAUDE_MODE:-interactive}"

# =============================================================================
# Mode Validation
# Reject unknown modes before any other checks.
# =============================================================================
validate_mode() {
    case "$CLAUDE_MODE" in
        remote-control|interactive|headless)
            return 0
            ;;
        *)
            echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'" >&2
            echo "  Valid modes: remote-control, interactive, headless" >&2
            exit 1
            ;;
    esac
}

# =============================================================================
# Auth Validation
# Checks for credentials in the PVC (from a previous /login).
# Does NOT call `claude auth status` (avoids subprocess startup latency).
# =============================================================================
validate_auth() {
    if [ -f "${HOME}/.claude/.credentials.json" ]; then
        echo "[entrypoint] Found existing credentials in PVC"
        return 0
    fi

    if [ "$CLAUDE_MODE" = "interactive" ]; then
        echo "[entrypoint] No credentials found -- run /login after attaching"
        return 0
    fi

    # Non-interactive mode with no credentials -- print remediation and exit
    cat >&2 << 'AUTH_EOF'

=========================================
  AUTHENTICATION REQUIRED
=========================================

  No credentials found in PVC.

  To authenticate, start in interactive mode first:

  1. kubectl attach claude-agent-0 -it
  2. Run /login inside Claude Code
  3. Complete the OAuth flow in your browser
  4. Credentials are saved to the PVC

  Then switch to your desired mode:
    kubectl set env statefulset/claude-agent CLAUDE_MODE=remote-control
    (Note: remote-control is coming soon on Linux — server-side feature gate)

=========================================

AUTH_EOF
    echo "[entrypoint] ERROR: Claude Code cannot start in '${CLAUDE_MODE}' mode without auth." >&2
    echo "[entrypoint] Run /login in interactive mode first to save credentials to PVC." >&2
    exit 1
}

# =============================================================================
# Onboarding Flag Check
# =============================================================================
if [ ! -f /app/.claude.json ] || ! grep -q "hasCompletedOnboarding" /app/.claude.json 2>/dev/null; then
    echo "[entrypoint] WARNING: /app/.claude.json missing or incomplete -- Claude Code may show onboarding wizard"
fi

# =============================================================================
# Validate Mode (reject unknown modes before auth check)
# =============================================================================
validate_mode

# =============================================================================
# Test Mode
# When CLAUDE_TEST_MODE=true, skip auth and Claude startup. Keep container
# alive for CI integration tests that only need kubectl exec access.
# =============================================================================
if [ "${CLAUDE_TEST_MODE:-}" = "true" ]; then
    echo "[entrypoint] TEST MODE: skipping auth and Claude startup"
    /usr/local/bin/generate-claude-md.sh || echo "[entrypoint] WARNING: CLAUDE.md generation failed (non-fatal)"
    echo "[entrypoint] TEST MODE: container ready -- sleeping indefinitely"
    exec sleep infinity
fi

# =============================================================================
# Validate Authentication
# =============================================================================
validate_auth

# =============================================================================
# Stage Settings and Skills into PVC
# The PVC mounted at /app/.claude/ overlays the container filesystem, so files
# baked into the image at /app/.claude/ are hidden. Copy them from staging
# locations (/app/.claude-settings.json, /opt/claude-skills/) into the PVC.
# Settings are always refreshed (image may have updated config).
# Skills are only copied on first start.
# =============================================================================
if [ -f /app/.claude-settings.json ]; then
    cp /app/.claude-settings.json /app/.claude/settings.json
    echo "[entrypoint] Staged settings.json into PVC"
fi

if [ -d /opt/claude-skills ] && [ ! -d /app/.claude/skills ]; then
    echo "[entrypoint] Staging DevOps skills into PVC..."
    cp -r /opt/claude-skills /app/.claude/skills
    echo "[entrypoint] Skills staged: $(ls /app/.claude/skills/ 2>/dev/null | tr '\n' ' ')"
elif [ -d /app/.claude/skills ]; then
    echo "[entrypoint] Skills already present in PVC"
fi

# =============================================================================
# Generate CLAUDE.md with cluster context
# Must run before exec so Claude Code has context at startup.
# Failures are non-fatal (standalone mode has no K8s access).
# =============================================================================
echo "[entrypoint] Generating CLAUDE.md with cluster context..."
/usr/local/bin/generate-claude-md.sh || echo "[entrypoint] WARNING: CLAUDE.md generation failed (non-fatal)"

# =============================================================================
# Mode Dispatch with exec
# exec replaces this shell process with Claude Code so that signals
# from tini (PID 1) are delivered directly to Claude Code.
# =============================================================================
case "$CLAUDE_MODE" in
    remote-control)
        echo "[entrypoint] Starting Claude Code in remote-control mode"
        # exec replaces this shell so signals from tini (PID 1) reach Claude directly
        exec claude remote-control --verbose
        ;;
    interactive)
        echo "[entrypoint] Starting Claude Code in interactive mode"
        # exec replaces this shell so signals from tini (PID 1) reach Claude directly
        exec claude --dangerously-skip-permissions
        ;;
    headless)
        if [ -z "${CLAUDE_PROMPT:-}" ]; then
            echo "[entrypoint] ERROR: Headless mode requires CLAUDE_PROMPT env var" >&2
            echo "  Set CLAUDE_PROMPT to the prompt you want Claude to execute." >&2
            echo "  Example: -e CLAUDE_PROMPT='List all pods in the default namespace'" >&2
            exit 1
        fi
        echo "[entrypoint] Starting Claude Code in headless mode"
        # exec replaces this shell so signals from tini (PID 1) reach Claude directly
        exec claude -p "$CLAUDE_PROMPT" --output-format json --dangerously-skip-permissions
        ;;
    *)
        echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'" >&2
        echo "  Valid modes: remote-control, interactive, headless" >&2
        exit 1
        ;;
esac
