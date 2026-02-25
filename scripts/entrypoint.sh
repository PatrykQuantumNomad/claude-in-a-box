#!/usr/bin/env bash
# =============================================================================
# Claude In A Box - Container Entrypoint
# Validates authentication, dispatches to the correct Claude Code mode,
# and uses exec to hand off the process for direct signal delivery.
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
# Validate Authentication
# =============================================================================
validate_auth

# =============================================================================
# Mode Dispatch with exec
# exec replaces this shell process with Claude Code so that signals
# from tini (PID 1) are delivered directly to Claude Code.
# =============================================================================
case "$CLAUDE_MODE" in
    remote-control)
        echo "[entrypoint] Starting Claude Code in remote-control mode"
        exec claude remote-control --verbose
        ;;
    interactive)
        echo "[entrypoint] Starting Claude Code in interactive mode"
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
        exec claude -p "$CLAUDE_PROMPT" --output-format json --dangerously-skip-permissions
        ;;
    *)
        echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'"
        echo "  Valid modes: remote-control, interactive, headless"
        exit 1
        ;;
esac
