#!/usr/bin/env bash
# =============================================================================
# Claude In A Box - Container Entrypoint
# Validates authentication, dispatches to the correct Claude Code mode,
# and uses exec to hand off the process for direct signal delivery.
#
# Supported modes:
#   interactive    - Local dev or `kubectl attach`. Opens the Claude REPL for
#                    live terminal interaction. Default mode.
#   remote-control - Phone/web access via `claude remote-control`. Exposes a
#                    remote session you can connect to from any device.
#   headless       - One-shot scripted tasks. Runs a single prompt from
#                    CLAUDE_PROMPT env var and exits with JSON output.
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
            echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'"
            echo "  Valid modes: remote-control, interactive, headless"
            exit 1
            ;;
    esac
}

# =============================================================================
# Auth Validation
# Checks for credentials via env vars or credential files.
# Does NOT call `claude auth status` (avoids 3-5s Node.js startup latency).
# =============================================================================
validate_auth() {
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "[entrypoint] OAuth token provided via CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "[entrypoint] API key provided via ANTHROPIC_API_KEY"
        return 0
    fi

    if [ -f "${HOME}/.claude/.credentials.json" ]; then
        echo "[entrypoint] Found existing credentials file"
        return 0
    fi

    if [ "$CLAUDE_MODE" = "interactive" ]; then
        echo "[entrypoint] No credentials found; interactive login will be prompted"
        return 0
    fi

    # Non-interactive mode with no auth -- print remediation and exit
    echo ""
    echo "========================================="
    echo "  AUTHENTICATION REQUIRED"
    echo "========================================="
    echo ""
    echo "  No authentication credentials found."
    echo "  Claude Code cannot start in '${CLAUDE_MODE}' mode without auth."
    echo ""
    echo "  To fix this, do ONE of the following:"
    echo ""
    echo "  1. Set CLAUDE_CODE_OAUTH_TOKEN env var:"
    echo "     Run 'claude setup-token' on your local machine,"
    echo "     then pass the token to the container:"
    echo "     -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-..."
    echo ""
    echo "  2. Set ANTHROPIC_API_KEY env var:"
    echo "     -e ANTHROPIC_API_KEY=sk-ant-..."
    echo ""
    echo "  3. Mount credentials from host:"
    echo "     -v ~/.claude:/app/.claude"
    echo ""
    echo "  4. Start in interactive mode to log in:"
    echo "     -e CLAUDE_MODE=interactive"
    echo "========================================="
    echo ""
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
# Stage DevOps Skills into PVC
# Skills are baked into the image at /opt/claude-skills/ but the PVC mounted
# at /app/.claude/ overlays the container filesystem. Copy skills into the
# PVC-mounted directory if they are not already present.
# =============================================================================
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
            echo "[entrypoint] ERROR: Headless mode requires CLAUDE_PROMPT env var"
            echo "  Set CLAUDE_PROMPT to the prompt you want Claude to execute."
            echo "  Example: -e CLAUDE_PROMPT='List all pods in the default namespace'"
            exit 1
        fi
        echo "[entrypoint] Starting Claude Code in headless mode"
        # exec replaces this shell so signals from tini (PID 1) reach Claude directly
        exec claude -p "$CLAUDE_PROMPT" --output-format json --dangerously-skip-permissions
        ;;
    *)
        echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'"
        echo "  Valid modes: remote-control, interactive, headless"
        exit 1
        ;;
esac
