# Phase 2: Entrypoint & Authentication - Research

**Researched:** 2026-02-25
**Domain:** Container entrypoint scripting, Claude Code CLI modes, OAuth authentication, Kubernetes health probes
**Confidence:** MEDIUM (auth persistence in containers has known issues; health probe approach is novel)

## Summary

Phase 2 builds the entrypoint script that sits between tini (PID 1, already configured in Phase 1) and Claude Code. The entrypoint must: (1) route to one of three startup modes based on `CLAUDE_MODE` env var, (2) use `exec` to hand off PID to Claude Code for proper signal handling, (3) authenticate via `CLAUDE_CODE_OAUTH_TOKEN` with fallback to interactive login, (4) expose HTTP health endpoints for Kubernetes liveness/readiness probes, and (5) produce human-readable auth failure messages.

The primary technical challenge is authentication. Claude Code OAuth persistence in Docker containers has multiple known bugs (issues #22066, #12447, #21765, #8938, #1736). The recommended container approach is: use `CLAUDE_CODE_OAUTH_TOKEN` env var (generated via `claude setup-token`, valid for 1 year) combined with `hasCompletedOnboarding: true` in `~/.claude.json` (already set in Phase 1 Dockerfile). The `claude auth status` command exits 0 if authenticated and 1 if not, providing a reliable health check primitive. For HTTP probes, a lightweight background health server using `nc` (netcat, already installed in the image) is the simplest approach that avoids adding dependencies.

**Primary recommendation:** Use a bash entrypoint script that validates auth, starts a minimal netcat-based health server in the background, then `exec`s into the appropriate Claude Code command based on `CLAUDE_MODE`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ENT-01 | Entrypoint supports three startup modes via CLAUDE_MODE env var (remote-control, interactive, headless) | CLI reference confirms `claude remote-control`, `claude` (interactive), `claude -p` (headless/print mode) as distinct invocations |
| ENT-02 | Entrypoint uses exec to hand off PID 1 to Claude Code for correct SIGTERM handling | Docker signal handling best practices confirm `exec` replaces shell PID with child process, enabling direct SIGTERM delivery. Tini already handles zombie reaping |
| ENT-03 | Authentication via CLAUDE_CODE_OAUTH_TOKEN env var with fallback to interactive login | Official docs confirm CLAUDE_CODE_OAUTH_TOKEN is read at startup; `claude auth status` (exit 0/1) validates auth state; `hasCompletedOnboarding: true` already set in Phase 1 image |
| ENT-04 | Liveness and readiness probes for Kubernetes pod lifecycle management | `claude auth status` provides auth health check; netcat-based HTTP server or exec probe scripts provide K8s-compatible probe endpoints |
| ENT-05 | Auth failure detection with actionable error messages (not raw 401 JSON) | Entrypoint can intercept `claude auth status` exit code 1 and print structured remediation guidance before exiting |
</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 5.x (Ubuntu 24.04 default) | Entrypoint script language | Already in image; no additional dependencies; exec builtin for PID handoff |
| netcat-openbsd (nc) | Ubuntu 24.04 default | Minimal HTTP health endpoint server | Already installed in Phase 1 image; zero-dependency TCP listener |
| curl | Ubuntu 24.04 default | Health probe client (for HEALTHCHECK directive) | Already installed in Phase 1 image |
| Claude Code CLI | 2.0.25 (pinned in Phase 1) | Primary application process | `claude`, `claude -p`, `claude remote-control` subcommands |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| jq | 1.8.1 (pinned in Phase 1) | Parse `claude auth status` JSON output | Auth validation in entrypoint |
| tini | 0.19.0 (pinned in Phase 1) | PID 1 init process, zombie reaping, signal forwarding | Already configured as ENTRYPOINT in Dockerfile |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| netcat HTTP server | Python http.server | Heavier; Python not in image; adds dependency |
| netcat HTTP server | socat | More capable but not installed; nc already present |
| bash entrypoint | Node.js entrypoint | More robust error handling but adds startup latency; bash simpler for mode dispatch |
| exec probe (kubectl exec) | HTTP probe | exec probes avoid needing a server; but HTTP probes are more standard for K8s and work with Docker HEALTHCHECK too |

## Architecture Patterns

### Recommended Project Structure

```
scripts/
  entrypoint.sh          # Main entrypoint script (ENT-01, ENT-02, ENT-03, ENT-05)
  healthcheck.sh         # Health probe script (ENT-04) -- used by both K8s exec probes and Docker HEALTHCHECK
  health-server.sh       # Background HTTP health server for K8s HTTP probes (ENT-04)
  verify-tools.sh        # Existing tool verification (Phase 1)
docker/
  Dockerfile             # Updated to COPY entrypoint scripts and set new ENTRYPOINT/CMD
```

### Pattern 1: Mode-Dispatch Entrypoint with Exec Handoff

**What:** A bash entrypoint script that reads `CLAUDE_MODE`, validates authentication, starts health infrastructure, then `exec`s into the appropriate Claude Code invocation.

**When to use:** Always -- this is the single entrypoint for the container.

**Example:**
```bash
#!/usr/bin/env bash
# Source: Docker signal handling best practices + Claude Code CLI reference
set -euo pipefail

CLAUDE_MODE="${CLAUDE_MODE:-interactive}"
HEALTH_PORT="${HEALTH_PORT:-8080}"

# --- Auth validation ---
validate_auth() {
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "[entrypoint] OAuth token provided via CLAUDE_CODE_OAUTH_TOKEN"
        export CLAUDE_CODE_OAUTH_TOKEN
        return 0
    fi

    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "[entrypoint] API key provided via ANTHROPIC_API_KEY"
        return 0
    fi

    # Check if credentials file exists with valid tokens
    if [ -f "${HOME}/.claude/.credentials.json" ]; then
        echo "[entrypoint] Found existing credentials file"
        return 0
    fi

    # No auth method found -- only allow interactive mode for login
    if [ "$CLAUDE_MODE" != "interactive" ]; then
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
    fi

    echo "[entrypoint] No credentials found; interactive login will be prompted"
    return 0
}

# --- Start health server ---
start_health_server() {
    /usr/local/bin/health-server.sh "$HEALTH_PORT" &
    HEALTH_PID=$!
    echo "[entrypoint] Health server started on port ${HEALTH_PORT} (PID: ${HEALTH_PID})"
}

# --- Mode dispatch with exec ---
validate_auth
start_health_server

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
        echo "[entrypoint] Starting Claude Code in headless mode (waiting for stdin)"
        # Headless mode: keep container alive, respond to piped prompts
        exec claude -p --output-format json --dangerously-skip-permissions
        ;;
    *)
        echo "[entrypoint] ERROR: Unknown CLAUDE_MODE '${CLAUDE_MODE}'"
        echo "  Valid modes: remote-control, interactive, headless"
        exit 1
        ;;
esac
```

### Pattern 2: Dual-Probe Health Architecture

**What:** Separate liveness and readiness checks -- liveness confirms the Claude Code process exists, readiness confirms authentication is valid.

**When to use:** Kubernetes deployments with pod lifecycle management.

**Liveness probe script (healthcheck.sh):**
```bash
#!/usr/bin/env bash
# Liveness: Is the Claude Code process running?
# Returns 0 (healthy) or 1 (unhealthy)
pgrep -f "claude" > /dev/null 2>&1
```

**Readiness probe script (readiness.sh):**
```bash
#!/usr/bin/env bash
# Readiness: Is Claude Code authenticated and ready to serve?
# claude auth status exits 0 if logged in, 1 if not
claude auth status > /dev/null 2>&1
```

**HTTP health server (health-server.sh):**
```bash
#!/usr/bin/env bash
# Minimal HTTP health server using netcat
# Responds to /healthz (liveness) and /readyz (readiness)
PORT="${1:-8080}"

while true; do
    RESPONSE=""
    REQUEST=$(echo -e "HTTP/1.0 200 OK\r\n\r\nhealthy" | nc -l -p "$PORT" -q 1 2>/dev/null || true)

    # Parse request path
    PATH_REQUESTED=$(echo "$REQUEST" | head -1 | awk '{print $2}')

    case "$PATH_REQUESTED" in
        /healthz)
            if pgrep -f "claude" > /dev/null 2>&1; then
                echo -e "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\nhealthy"
            else
                echo -e "HTTP/1.0 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nunhealthy"
            fi
            ;;
        /readyz)
            if claude auth status > /dev/null 2>&1; then
                echo -e "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\nready"
            else
                echo -e "HTTP/1.0 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nnot ready"
            fi
            ;;
        *)
            echo -e "HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\n\r\nnot found"
            ;;
    esac
done
```

### Pattern 3: Exec Probe Alternative (No HTTP Server Needed)

**What:** Use Kubernetes exec probes instead of HTTP probes, eliminating the need for a background health server entirely.

**When to use:** When simplicity is preferred over HTTP probe compatibility. Docker HEALTHCHECK can also use exec commands.

**Example K8s manifest snippet:**
```yaml
livenessProbe:
  exec:
    command: ["/usr/local/bin/healthcheck.sh"]
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
readinessProbe:
  exec:
    command: ["/usr/local/bin/readiness.sh"]
  initialDelaySeconds: 15
  periodSeconds: 30
  timeoutSeconds: 10
```

**Dockerfile HEALTHCHECK directive:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]
```

### Anti-Patterns to Avoid

- **Shell wrapper without exec:** Starting Claude Code as a child of a shell script means SIGTERM goes to the shell, not Claude Code. The shell may not forward it. Always use `exec` to replace the shell process.
- **Polling auth status in a tight loop:** `claude auth status` spawns a Node.js process each time. Calling it too frequently (< 10s intervals) wastes resources. Use 30s+ intervals for probes.
- **Baking tokens into the image:** Never `ENV CLAUDE_CODE_OAUTH_TOKEN=...` in the Dockerfile. Tokens must be injected at runtime via env vars or mounted secrets.
- **Running health server as PID 1:** The health server must be a background process. Claude Code (via exec) must be the foreground process receiving signals from tini.
- **Ignoring the onboarding flag:** Setting `CLAUDE_CODE_OAUTH_TOKEN` alone is insufficient. The `hasCompletedOnboarding: true` in `~/.claude.json` is required to skip the setup wizard. Phase 1 already sets this, so no action needed -- just verify it stays in place.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PID 1 init / signal forwarding | Custom signal trap in bash | tini (already in image) | Handles zombie reaping, signal forwarding, and edge cases that trap handlers miss |
| OAuth token refresh | Custom token refresh logic | Claude Code's built-in refresh (via mounted credentials) or long-lived setup-token | Token refresh is handled internally; `setup-token` provides 1-year tokens |
| JSON parsing in bash | sed/awk regex on JSON | jq (already in image) | Correct JSON parsing handles edge cases; jq is the standard tool |
| Full HTTP server | Python/Node.js server for health endpoints | nc (netcat) one-liners or K8s exec probes | Container already has nc; exec probes need zero infrastructure |

**Key insight:** The entrypoint script is glue code -- it should be thin. All heavy lifting (authentication, API communication, session management) is done by Claude Code itself. The entrypoint only needs to: validate, dispatch, and get out of the way via exec.

## Common Pitfalls

### Pitfall 1: OAuth Token Not Recognized Without Onboarding Flag

**What goes wrong:** Container starts with `CLAUDE_CODE_OAUTH_TOKEN` set, but Claude Code prompts for theme selection and authentication method instead of starting.
**Why it happens:** `CLAUDE_CODE_OAUTH_TOKEN` handles authentication but does not bypass the first-run onboarding wizard. A separate `hasCompletedOnboarding: true` flag is needed in `~/.claude.json`.
**How to avoid:** Phase 1 already writes `{"hasCompletedOnboarding": true}` to `/app/.claude.json`. Verify this file exists and has correct content in the entrypoint before starting Claude Code.
**Warning signs:** Container logs show theme selection prompt or "Welcome to Claude Code" messages.

### Pitfall 2: Signal Not Reaching Claude Code

**What goes wrong:** `docker stop` sends SIGTERM, but Claude Code doesn't shut down gracefully within 60s, leading to SIGKILL.
**Why it happens:** Entrypoint script runs Claude Code as a child process (no `exec`), so SIGTERM goes to the shell which may not forward it.
**How to avoid:** Always use `exec claude ...` as the last command in the entrypoint. The `exec` builtin replaces the shell process with Claude Code, so SIGTERM goes directly to it. Tini (PID 1) handles forwarding from Docker to the exec'd process.
**Warning signs:** `docker stop` takes full 60s grace period; `docker inspect` shows exit code 137 (SIGKILL) instead of 0 or 143 (SIGTERM).

### Pitfall 3: OAuth Token Expiration in Long-Running Containers

**What goes wrong:** After hours of running, Claude Code starts failing with `401 authentication_error: "OAuth token has expired"`.
**Why it happens:** Standard OAuth tokens from `/login` expire in 2-4 hours. Container has no browser for re-authentication. Refresh token mechanism has known bugs (#12447, #21765).
**How to avoid:** Use `claude setup-token` (not `/login`) to generate a long-lived token valid for 1 year. Pass this as `CLAUDE_CODE_OAUTH_TOKEN`. Document this requirement clearly.
**Warning signs:** Container works initially but fails after a few hours with 401 errors.

### Pitfall 4: Health Server Blocking Exec

**What goes wrong:** Background health server is started but `exec` replaces the entire process, killing the background job.
**Why it happens:** `exec` replaces the current process image -- all background children of the current shell are orphaned and may be killed.
**How to avoid:** Two approaches: (a) Use exec probes instead of HTTP probes (no background server needed), or (b) Start the health server via a subprocess that tini manages. The cleanest approach is Pattern 3 (exec probes), which eliminates this issue entirely.
**Warning signs:** Health endpoint stops responding shortly after container starts; `docker logs` shows health server started but probes fail.

### Pitfall 5: Headless Mode Requires Prompt Input

**What goes wrong:** Container starts in headless mode (`claude -p`) but exits immediately because no prompt was provided.
**Why it happens:** `claude -p` expects a prompt either as an argument or on stdin. Without one, it exits.
**How to avoid:** For a long-running headless container, the entrypoint should either: (a) use `claude -p` with a specific task, or (b) run in a loop reading prompts from a named pipe or API. For the initial implementation, headless mode should accept the prompt via `CLAUDE_PROMPT` env var or stdin pipe.
**Warning signs:** Container exits immediately with exit code 0 in headless mode.

### Pitfall 6: Auth Status Check Adds Startup Latency

**What goes wrong:** Entrypoint calls `claude auth status` before starting Claude Code, adding 3-5 seconds of Node.js startup time.
**Why it happens:** `claude auth status` spawns a full Node.js process to check credentials.
**How to avoid:** For the fast path (token provided via env var), skip the `claude auth status` check. Only run it in the readiness probe, not as a blocking startup gate. The entrypoint can do a lightweight file-existence check for credentials instead.
**Warning signs:** Container takes 5+ seconds to start even with valid auth.

## Code Examples

### ENT-01: Mode Dispatch Mapping

From the CLI reference (code.claude.com/docs/en/cli-reference):

```bash
# Three modes map to three Claude Code invocations:

# remote-control: Long-running, accessible from claude.ai/code and mobile app
# Requires: Pro or Max subscription, OAuth authentication
claude remote-control --verbose

# interactive: Standard REPL for terminal sessions (kubectl exec, tmux, etc.)
# Supports: All auth methods
claude --dangerously-skip-permissions

# headless: Non-interactive, single prompt, exits after response
# Supports: All auth methods; --output-format for structured output
claude -p "your prompt here" --output-format json --dangerously-skip-permissions
```

### ENT-02: Exec Handoff Pattern

From Docker signal handling best practices:

```bash
# BAD: Claude runs as child process; shell eats SIGTERM
#!/bin/bash
claude --dangerously-skip-permissions
# Shell is still PID; SIGTERM hits shell, not claude

# GOOD: exec replaces shell with claude; SIGTERM goes to claude
#!/bin/bash
exec claude --dangerously-skip-permissions
# Shell process is replaced; claude IS the process now
```

### ENT-03: Authentication Validation

From official Claude Code docs (code.claude.com/docs/en/authentication, code.claude.com/docs/en/cli-reference):

```bash
# Check auth status (exit code 0 = authenticated, 1 = not)
claude auth status
echo $?  # 0 or 1

# Get JSON auth details
claude auth status  # Returns JSON by default
claude auth status --text  # Human-readable format

# Token priority: env var > credentials file > interactive login
# CLAUDE_CODE_OAUTH_TOKEN takes precedence over ~/.claude/.credentials.json
```

### ENT-04: Kubernetes Probe Configuration

```yaml
# Source: Kubernetes probe best practices
spec:
  containers:
  - name: claude-agent
    livenessProbe:
      exec:
        command: ["/usr/local/bin/healthcheck.sh"]
      initialDelaySeconds: 10
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      exec:
        command: ["/usr/local/bin/readiness.sh"]
      initialDelaySeconds: 15
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 3
```

### ENT-05: Auth Failure Message Format

```bash
# Entrypoint detects auth failure and prints remediation steps
validate_auth_or_exit() {
    if ! claude auth status > /dev/null 2>&1; then
        cat << 'EOF'

=========================================
  AUTHENTICATION FAILED
=========================================

  Claude Code could not authenticate.
  This is usually caused by an expired or invalid token.

  To fix this:

  1. Generate a new long-lived token:
     $ claude setup-token
     (Run this on a machine with a browser)

  2. Pass the token to the container:
     $ docker run -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-... <image>

  3. Or mount credentials from an authenticated host:
     $ docker run -v ~/.claude:/app/.claude <image>

  For API key authentication:
     $ docker run -e ANTHROPIC_API_KEY=sk-ant-... <image>

  Docs: https://code.claude.com/docs/en/authentication
=========================================

EOF
        exit 1
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/login` interactive OAuth flow | `claude setup-token` for long-lived tokens | Mid-2025 | Tokens valid 1 year; no browser needed for container auth |
| `--print` flag name | `-p` / `--print` (Agent SDK CLI) | Late 2025 | Renamed from "headless mode" to "Agent SDK CLI"; `-p` flag unchanged |
| Copy `.credentials.json` between hosts | `CLAUDE_CODE_OAUTH_TOKEN` env var | Early 2025 | Env var is simpler, no file mounting needed |
| Custom OAuth refresh handling | Built-in (partial) + `setup-token` workaround | Ongoing | Refresh token bugs remain (#12447, #21765); `setup-token` avoids the issue |
| No auth subcommands | `claude auth login/logout/status` | Late 2025 | Scriptable auth management; `auth status` enables health probes |

**Deprecated/outdated:**
- Copying `.credentials.json` between machines: Unreliable due to refresh token bugs (#21765). Use `CLAUDE_CODE_OAUTH_TOKEN` env var instead.
- `/login` for container auth: Short-lived tokens expire in hours. Use `setup-token` for containers.

## Open Questions

1. **Headless mode long-running container pattern**
   - What we know: `claude -p "prompt"` exits after processing one prompt. Remote-control mode is long-running.
   - What's unclear: What is the intended pattern for a long-running headless container that processes multiple prompts? Is it a loop of `claude -p` calls, or should it use the Agent SDK?
   - Recommendation: For Phase 2, implement headless as a single-prompt execution that exits. Long-running headless patterns can be added later. The entrypoint accepts `CLAUDE_PROMPT` env var for the initial prompt.

2. **Health server background process lifecycle with exec**
   - What we know: `exec` replaces the current process, orphaning background jobs. Tini adopts orphaned processes.
   - What's unclear: Will tini correctly adopt and manage the orphaned health server process? Will the health server survive for the lifetime of the container?
   - Recommendation: Use exec probes (Pattern 3) as the primary approach. This eliminates the background server problem entirely. Add HTTP health server as a follow-up only if needed. For Docker HEALTHCHECK, use the exec-based healthcheck.sh script.

3. **claude auth status reliability and latency**
   - What we know: `claude auth status` exits 0/1 and returns JSON. It spawns a Node.js process.
   - What's unclear: How long does it take? Does it make a network call or only check local credentials? Is it reliable with `CLAUDE_CODE_OAUTH_TOKEN` (env var) vs credentials file?
   - Recommendation: Use it in readiness probes with a generous timeout (10s). For liveness, use `pgrep -f claude` which is instant. Validate actual latency during implementation.

4. **Remote-control mode in containers without browser**
   - What we know: `claude remote-control` generates a session URL and QR code. Requires Pro/Max subscription and OAuth auth (not API keys).
   - What's unclear: Does it work reliably in a headless container? Does it need TTY allocation?
   - Recommendation: Test with and without `--verbose` flag. Allocate a pseudo-TTY (`-t`) in docker run. This is a critical path for the project's core value proposition.

5. **Interaction between tini, exec, and the health background process**
   - What we know: Tini is PID 1. Entrypoint runs as a child of tini. `exec` replaces the entrypoint with Claude Code.
   - What's unclear: If we start a background process before exec, does tini see it as a child? Or does it become orphaned?
   - Recommendation: The safest pattern is: tini -> entrypoint -> background health -> exec claude. When exec replaces the shell, the background process becomes a child of tini (re-parented by the kernel). Tini will reap it when it exits. Validate this during implementation.

## Sources

### Primary (HIGH confidence)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) - Exact CLI commands, flags, exit codes, subcommands
- [Claude Code Authentication Docs](https://code.claude.com/docs/en/authentication) - Auth methods, credential management, CLAUDE_CODE_OAUTH_TOKEN
- [Claude Code Headless/Agent SDK Docs](https://code.claude.com/docs/en/headless) - `-p` flag, output formats, non-interactive usage
- [Claude Code Remote Control Docs](https://code.claude.com/docs/en/remote-control) - `claude remote-control` command, requirements, limitations
- [Claude Code DevContainer Docs](https://code.claude.com/docs/en/devcontainer) - Official container patterns, security model

### Secondary (MEDIUM confidence)
- [GitHub Issue #22066](https://github.com/anthropics/claude-code/issues/22066) - OAuth not persisting in Docker (closed as duplicate of #1736)
- [GitHub Issue #12447](https://github.com/anthropics/claude-code/issues/12447) - OAuth token expiration in long-running containers; `setup-token` workaround confirmed
- [GitHub Issue #21765](https://github.com/anthropics/claude-code/issues/21765) - Refresh token not used on remote/headless machines (open)
- [GitHub Issue #8938](https://github.com/anthropics/claude-code/issues/8938) - `setup-token`/`CLAUDE_CODE_OAUTH_TOKEN` insufficient without onboarding flag
- [GitHub Issue #1736](https://github.com/anthropics/claude-code/issues/1736) - Docker re-authentication; solution: mount ~/.claude with read-write access
- [Docker Signal Handling](https://petermalmgren.com/signal-handling-docker/) - PID 1, exec, tini signal forwarding patterns
- [tini GitHub](https://github.com/krallin/tini) - Signal forwarding, zombie reaping documentation
- [claude-code-sdk-docker](https://github.com/cabinlab/claude-code-sdk-docker) - Community container patterns, auth test scripts
- [tintinweb/claude-code-container](https://github.com/tintinweb/claude-code-container) - Community container, CLAUDE_CODE_OAUTH_TOKEN usage

### Tertiary (LOW confidence)
- [claude-did-this.com Setup Container Guide](https://claude-did-this.com/claude-hub/getting-started/setup-container-guide) - Three-phase auth approach; claims tokens expire in 8-12 hours (contradicts `setup-token` 1-year validity)
- Health server patterns using netcat - Synthesized from multiple sources; needs validation in actual container environment

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already in Phase 1 image; CLI commands verified against official docs
- Architecture: MEDIUM - Entrypoint pattern is well-established but health server + exec interaction needs validation
- Pitfalls: HIGH - Multiple verified GitHub issues document exact failure modes
- Auth patterns: MEDIUM - `CLAUDE_CODE_OAUTH_TOKEN` + onboarding flag is well-documented, but refresh token bugs (#21765) remain open

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (30 days; auth landscape is evolving but core CLI interface is stable)
