#!/usr/bin/env bash
# =============================================================================
# verify-tools.sh - Claude In A Box Tool Verification
# Confirms all 32+ installed tools execute correctly as non-root.
#
# Called during the Dockerfile build to catch missing tools at image build
# time, and available at runtime via `verify-tools.sh` for on-demand checks.
#
# Exit codes:
#   0 - All non-privileged tools pass (SKIP does not count as failure)
#   1 - One or more non-privileged tools failed
#
# Privileged tools (strace, tcpdump, perf, bpftrace) require elevated
# capabilities at runtime. They are checked for binary existence only.
# =============================================================================

set -euo pipefail

PASS=0
FAIL=0
SKIP=0
ERRORS=()

# check_tool - Verify a single tool
#
# Arguments:
#   $1 - Tool name (display name)
#   $2 - Command to execute for verification
#   $3 - (optional) "true" if tool requires elevated privileges
#
# Privileged tools: binary existence is verified but execution is skipped,
# since they require CAP_NET_RAW, CAP_SYS_PTRACE, or similar capabilities.
check_tool() {
    local name="$1"
    local cmd="$2"
    local privileged="${3:-false}"

    if [ "$privileged" = "true" ]; then
        # Privileged tools - check binary exists but skip execution test
        if command -v "$name" &>/dev/null; then
            echo "[SKIP] $name (requires elevated privileges)"
            ((SKIP++)) || true
        else
            echo "[FAIL] $name - binary not found"
            ERRORS+=("$name: binary not found (privileged tool)")
            ((FAIL++)) || true
        fi
        return
    fi

    if eval "$cmd" &>/dev/null 2>&1; then
        echo "[PASS] $name"
        ((PASS++)) || true
    else
        echo "[FAIL] $name"
        ERRORS+=("$name: command failed: $cmd")
        ((FAIL++)) || true
    fi
}

echo "=== Claude In A Box - Tool Verification ==="
echo "Running as: $(whoami) (UID: $(id -u))"
echo ""

# =============================================================================
# Network tools (9 checks)
# =============================================================================
echo "--- Network Tools ---"
check_tool "curl" "curl --version"
check_tool "dig" "dig -v 2>&1"
check_tool "nmap" "nmap --version"
check_tool "tcpdump" "tcpdump --version" "true"   # needs CAP_NET_RAW
check_tool "wget" "wget --version"
check_tool "netcat" "nc -h 2>&1"
check_tool "ip" "ip -V 2>&1"
check_tool "ss" "ss -V 2>&1"
check_tool "ping" "ping -c 1 127.0.0.1"
echo ""

# =============================================================================
# Process/system tools (6 checks)
# =============================================================================
echo "--- Process/System Tools ---"
check_tool "htop" "htop --version"
check_tool "strace" "strace -V" "true"            # needs CAP_SYS_PTRACE
check_tool "ps" "ps --version 2>&1"
check_tool "top" "command -v top"                  # top -v may exit non-zero
check_tool "perf" "perf version" "true"            # needs privileges
check_tool "bpftrace" "bpftrace --version" "true"  # needs privileges
echo ""

# =============================================================================
# Kubernetes tools (6 checks)
# =============================================================================
echo "--- Kubernetes Tools ---"
check_tool "kubectl" "kubectl version --client"
check_tool "helm" "helm version"
check_tool "k9s" "k9s version --short"
check_tool "stern" "stern --version"
check_tool "kubectx" "kubectx --help"
check_tool "kubens" "kubens --help"
echo ""

# =============================================================================
# Data/log tools (3 checks)
# =============================================================================
echo "--- Data/Log Tools ---"
check_tool "jq" "jq --version"
check_tool "yq" "yq --version"
check_tool "less" "less --version"
echo ""

# =============================================================================
# Database clients (3 checks)
# =============================================================================
echo "--- Database Clients ---"
check_tool "psql" "psql --version"
check_tool "mysql" "mysql --version"
check_tool "redis-cli" "redis-cli --version"
echo ""

# =============================================================================
# Security scanning tools (2 checks)
# =============================================================================
echo "--- Security Scanning ---"
check_tool "trivy" "trivy --version"
check_tool "grype" "grype version"
echo ""

# =============================================================================
# Standard utilities (8 checks)
# =============================================================================
echo "--- Standard Utilities ---"
check_tool "git" "git --version"
check_tool "vim.tiny" "vim.tiny --version"
check_tool "nano" "nano --version"
check_tool "unzip" "unzip -v 2>&1 | head -1"
check_tool "file" "file --version"
check_tool "tree" "tree --version"
check_tool "rg" "rg --version"
check_tool "bash" "bash --version"
echo ""

# =============================================================================
# Claude Code (2 checks)
# =============================================================================
echo "--- Claude Code ---"
check_tool "claude" "claude --version"
check_tool "node" "node --version"
echo ""

# =============================================================================
# Results
# =============================================================================
TOTAL=$((PASS + FAIL + SKIP))
echo "=== Results ==="
echo "PASS: $PASS | FAIL: $FAIL | SKIP (privileged): $SKIP"
echo "Total tools: $TOTAL"

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "=== Failures ==="
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
    exit 1
fi

echo ""
echo "All tools verified successfully."
exit 0
