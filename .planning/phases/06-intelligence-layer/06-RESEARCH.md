# Phase 6: Intelligence Layer - Research

**Researched:** 2026-02-25
**Domain:** MCP server configuration, Claude Code skills, container startup context population
**Confidence:** HIGH

## Summary

Phase 6 adds the "intelligence layer" that transforms the containerized Claude Code from a generic CLI tool into a Kubernetes-aware DevOps agent. Three capabilities are required: (1) structured Kubernetes API access via an MCP server configured in `.mcp.json`, (2) a curated DevOps skills library in `.claude/skills/`, and (3) auto-populated CLAUDE.md with cluster context at startup.

The key technical decision is which Kubernetes MCP server to use. Two credible options exist: Red Hat's `kubernetes-mcp-server` (Go-based, npm package `kubernetes-mcp-server`) and Flux159's `mcp-server-kubernetes` (TypeScript/Bun-based, npm package `mcp-server-kubernetes`). Research strongly favors Red Hat's implementation for this use case because it natively supports `--cluster-provider in-cluster` auto-detection (critical for running inside a pod), has a first-class `--read-only` flag that exposes only `readOnlyHint=true` annotated tools, requires zero external dependencies (no kubectl needed -- it talks directly to the Kubernetes API server), and is distributed as a single native binary. Flux159's version requires kubectl to be installed, needs SSE transport mode workarounds for in-pod operation (the default stdio mode crashes in containerized environments without a terminal), and its "non-destructive" mode is less restrictive than true read-only.

**Primary recommendation:** Use Red Hat's `kubernetes-mcp-server` (npm: `kubernetes-mcp-server@latest`) with `--read-only` and `--cluster-provider in-cluster` flags, configured via `.mcp.json` at project scope.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INT-01 | MCP server configuration (.mcp.json) pre-wired for kubernetes-mcp-server with read-only mode | Red Hat's kubernetes-mcp-server has native `--read-only` flag and `.mcp.json` project-scope format is documented by Claude Code official docs. In-cluster auto-detection via `--cluster-provider in-cluster` eliminates kubeconfig management. |
| INT-02 | Curated DevOps skills library for pod diagnosis, log analysis, incident triage, and network debugging | Claude Code skills use `.claude/skills/<name>/SKILL.md` format with YAML frontmatter. Skills can reference MCP tools and include supporting files like templates and scripts. |
| DOC-02 | CLAUDE.md project context file auto-populated with cluster environment at startup | Entrypoint script runs before `exec claude`, so a pre-exec shell function can query Kubernetes API via the ServiceAccount token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/` and write CLAUDE.md to `/app/CLAUDE.md`. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| kubernetes-mcp-server (Red Hat/containers) | latest (npm: `kubernetes-mcp-server@latest`) | Kubernetes API access via MCP protocol | Go-native binary, no kubectl dependency, first-class `--read-only` and `--cluster-provider in-cluster` flags, maintained by Red Hat/containers org |
| Claude Code Skills | Built-in | DevOps skill definitions | Native `.claude/skills/` directory format with YAML frontmatter, auto-loaded when relevant |
| Claude Code .mcp.json | Built-in | MCP server registration | Project-scope config checked into version control, team-shared |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| kubectl | Already in image (v1.35.1) | Fallback CLI for complex queries | Skills can shell out to kubectl when MCP tools lack specific functionality |
| jq | Already in image (v1.8.1) | JSON processing in entrypoint | Parsing Kubernetes API responses during CLAUDE.md generation |
| curl | Already in image | HTTP requests to K8s API | Querying cluster info during startup for CLAUDE.md population |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| kubernetes-mcp-server (Red Hat) | mcp-server-kubernetes (Flux159) | Flux159 requires kubectl, needs SSE transport hack for in-pod use, "non-destructive" mode less restrictive than true read-only. Red Hat version talks directly to K8s API, auto-detects in-cluster config. |
| kubernetes-mcp-server (Red Hat) | kubectl-mcp-server (rohitg00) | Less mature, fewer features, less active maintenance |
| Shell scripts for skills | Python scripts | Shell is already available in the image, no additional runtime needed. Keep it simple. |

**Installation:**

The MCP server runs via npx at runtime (Node.js already in image). No additional install needed beyond the `.mcp.json` configuration file.

```bash
# Verification (run inside container):
npx -y kubernetes-mcp-server@latest --help
```

## Architecture Patterns

### Recommended Project Structure
```
# Files added/modified by Phase 6
.mcp.json                           # MCP server config (project root, checked in)
.claude/skills/                     # DevOps skills directory
  pod-diagnosis/
    SKILL.md                        # Pod diagnosis skill
  log-analysis/
    SKILL.md                        # Log analysis skill
  incident-triage/
    SKILL.md                        # Incident triage skill
  network-debugging/
    SKILL.md                        # Network debugging skill
scripts/
  entrypoint.sh                     # Modified: add CLAUDE.md generation before exec
  generate-claude-md.sh             # New: cluster context discovery script
docker/
  Dockerfile                        # Modified: COPY skills and .mcp.json into image
```

### Pattern 1: Project-Scope .mcp.json for MCP Server Registration
**What:** Claude Code reads `.mcp.json` at project root to discover MCP servers. Project-scope means it is checked into version control and shared with all users.
**When to use:** Always -- this is how MCP servers are configured for containerized Claude Code.
**Example:**
```json
// Source: https://code.claude.com/docs/en/mcp (official Claude Code docs)
{
  "mcpServers": {
    "kubernetes": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "kubernetes-mcp-server@latest",
        "--read-only",
        "--cluster-provider", "in-cluster"
      ],
      "env": {}
    }
  }
}
```

### Pattern 2: Skills with YAML Frontmatter
**What:** Each skill is a directory under `.claude/skills/` with a `SKILL.md` entry point containing YAML frontmatter and markdown instructions.
**When to use:** For all four required DevOps skills.
**Example:**
```yaml
# Source: https://code.claude.com/docs/en/skills
---
name: pod-diagnosis
description: Diagnose pod issues including CrashLoopBackOff, ImagePullBackOff, OOMKilled, pending pods, and readiness probe failures. Use when investigating why a pod is unhealthy or not starting.
---

## Pod Diagnosis Workflow

When diagnosing a pod issue:

1. **Get pod status**: Use the kubernetes MCP tools to list pods and identify the problematic pod
2. **Check events**: Look at pod events for scheduling, pulling, or startup errors
3. **Read logs**: Fetch container logs (current and previous) for crash details
4. **Inspect describe**: Get full pod description for resource limits, node assignment, and conditions
5. **Check related resources**: Verify the parent deployment/statefulset, service selectors, and configmaps

### Common Failure Patterns

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| CrashLoopBackOff | App crash, OOM, misconfiguration | Check logs (previous), resource limits |
| ImagePullBackOff | Bad image name, missing secret, registry auth | Check image name, imagePullSecrets |
| Pending | No schedulable nodes, resource pressure | Check events, node capacity |
| OOMKilled | Memory limit exceeded | Check resource limits vs actual usage |
| Readiness probe failure | App not ready, wrong probe config | Check probe config, app startup time |
```

### Pattern 3: Entrypoint Pre-exec CLAUDE.md Generation
**What:** Before the entrypoint `exec`s into Claude Code, run a shell function that queries the Kubernetes API and writes `/app/CLAUDE.md`.
**When to use:** Every container startup.
**Example:**
```bash
# Source: Kubernetes in-cluster auth pattern
# The ServiceAccount token is auto-mounted at:
#   /var/run/secrets/kubernetes.io/serviceaccount/token
#   /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
#   /var/run/secrets/kubernetes.io/serviceaccount/namespace

generate_claude_md() {
    local SA_TOKEN SA_CA SA_NS K8S_API CLUSTER_INFO K8S_VERSION NODE_COUNT NAMESPACE

    SA_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)" || true
    SA_CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    SA_NS="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)" || SA_NS="unknown"
    K8S_API="https://kubernetes.default.svc"

    if [ -z "$SA_TOKEN" ]; then
        echo "[entrypoint] WARNING: No ServiceAccount token found, skipping CLAUDE.md generation"
        return 0
    fi

    # Query cluster info
    K8S_VERSION=$(curl -s --cacert "$SA_CA" -H "Authorization: Bearer $SA_TOKEN" \
        "$K8S_API/version" | jq -r '.gitVersion // "unknown"' 2>/dev/null) || K8S_VERSION="unknown"

    NODE_COUNT=$(curl -s --cacert "$SA_CA" -H "Authorization: Bearer $SA_TOKEN" \
        "$K8S_API/api/v1/nodes" | jq '.items | length' 2>/dev/null) || NODE_COUNT="unknown"

    # Write CLAUDE.md
    cat > /app/CLAUDE.md << EOF
# Claude In A Box - Cluster Context

## Environment
- **Cluster**: Kubernetes ${K8S_VERSION}
- **Namespace**: ${SA_NS}
- **Node count**: ${NODE_COUNT}
- **Pod**: ${HOSTNAME:-unknown}

## Available Tools
...
EOF
    echo "[entrypoint] Generated CLAUDE.md with cluster context"
}
```

### Anti-Patterns to Avoid
- **Shelling out to kubectl in .mcp.json:** The MCP server should talk directly to the K8s API. Using kubectl as an intermediary adds latency, failure modes, and auth complexity.
- **Putting MCP config in user scope (~/.claude.json):** Project-scope `.mcp.json` is the correct location for container deployments because it is baked into the image and does not depend on the PVC-mounted `~/.claude/` directory.
- **Over-scoped skills:** Each skill should cover ONE domain (pod diagnosis, log analysis, etc.), not a single monolithic "devops" skill. Claude's skill auto-loading works better with focused descriptions.
- **Blocking on MCP server startup for CLAUDE.md:** The CLAUDE.md generation should use raw curl/kubectl against the K8s API, NOT the MCP server. The MCP server starts later when Claude Code initializes.
- **Hardcoding cluster name:** Use Kubernetes API discovery at runtime, not build-time constants.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Kubernetes API access for Claude | Custom kubectl wrapper scripts | kubernetes-mcp-server with MCP protocol | MCP provides structured tool interface, error handling, pagination, secret masking; custom scripts are fragile and unstructured |
| MCP server registration | Manual JSON in ~/.claude.json | `.mcp.json` at project root | Project-scope is the standard pattern, auto-discovered, version-controllable |
| Skill format | Custom prompt files | `.claude/skills/<name>/SKILL.md` with frontmatter | Claude Code natively loads, indexes, and auto-invokes skills; custom format would not integrate |
| Cluster info discovery | Hardcoded environment variables | Runtime ServiceAccount token + K8s API queries | ServiceAccount tokens are auto-mounted, API responses are always current |
| Read-only enforcement | RBAC-only protection | Both RBAC (K8S-02) AND `--read-only` flag on MCP server | Defense in depth: RBAC enforces at API server level, `--read-only` enforces at MCP tool level |

**Key insight:** The MCP protocol exists precisely to give LLMs structured, safe access to external systems. Hand-rolling kubectl wrapper scripts throws away the protocol's error handling, tool discovery, schema validation, and secret masking.

## Common Pitfalls

### Pitfall 1: MCP Server Starts Before Cluster is Ready
**What goes wrong:** The MCP server process starts but cannot connect to the Kubernetes API server, causing all tool calls to fail.
**Why it happens:** In KIND or new clusters, the API server may not be fully ready when the pod starts.
**How to avoid:** The MCP server auto-retries connections. Ensure the pod's readiness probe passes only when Claude Code is fully running. The existing healthcheck.sh handles this.
**Warning signs:** Claude reports "connection refused" or "no such host" errors from MCP tools.

### Pitfall 2: .mcp.json Not Found by Claude Code
**What goes wrong:** Claude Code starts but does not load any MCP servers -- no kubernetes tools available.
**Why it happens:** `.mcp.json` must be in the project root (the directory where Claude Code starts). If Claude Code's working directory is not `/app` or `.mcp.json` is not at `/app/.mcp.json`, it will not be found.
**How to avoid:** COPY `.mcp.json` to `/app/.mcp.json` in the Dockerfile. Verify with `WORKDIR /app` (already set). The entrypoint already uses `/app` as home.
**Warning signs:** Running `/mcp` in Claude Code shows no servers, or `claude mcp list` returns empty.

### Pitfall 3: npx Downloads on Every Startup
**What goes wrong:** Each container start triggers a fresh npm download of kubernetes-mcp-server, adding 10-30s latency and requiring internet access.
**Why it happens:** `npx -y` downloads packages on demand if not cached.
**How to avoid:** Pre-install the package in the Dockerfile: `RUN npm install -g kubernetes-mcp-server@latest` and use the direct binary path in `.mcp.json` instead of npx. OR pre-warm the npx cache during build.
**Warning signs:** Slow MCP server startup, failures in air-gapped environments.

### Pitfall 4: CLAUDE.md Overwritten by PVC Mount
**What goes wrong:** The PVC mounted at `/app/.claude/` does not affect `/app/CLAUDE.md`, but if someone mounts a volume at `/app/`, the generated CLAUDE.md gets shadowed.
**Why it happens:** Volume mounts overlay the container filesystem.
**How to avoid:** The PVC only mounts at `/app/.claude/` (per K8S-04), not at `/app/`. CLAUDE.md at `/app/CLAUDE.md` is safe. Verify the StatefulSet volumeMount path is specifically `/app/.claude`.
**Warning signs:** CLAUDE.md has stale or missing cluster info after pod restart.

### Pitfall 5: Skills Not Auto-Loading
**What goes wrong:** Claude Code does not auto-invoke skills even when the user asks about pod issues or log analysis.
**Why it happens:** Skill descriptions are too vague, or there are too many skills exceeding the character budget (2% of context window).
**How to avoid:** Write focused, keyword-rich descriptions. Keep each SKILL.md under 500 lines. Use 4 separate skills, not one mega-skill.
**Warning signs:** User has to explicitly type `/pod-diagnosis` instead of Claude suggesting it.

### Pitfall 6: ServiceAccount Token Not Mounted
**What goes wrong:** CLAUDE.md generation fails because `/var/run/secrets/kubernetes.io/serviceaccount/token` does not exist.
**Why it happens:** `automountServiceAccountToken: false` in the pod spec, or running in Docker Compose (no Kubernetes).
**How to avoid:** The existing StatefulSet does NOT set `automountServiceAccountToken: false`, so the default (true) applies. For Docker Compose, make CLAUDE.md generation gracefully degrade (skip if no token found).
**Warning signs:** Entrypoint logs show "No ServiceAccount token found, skipping CLAUDE.md generation".

## Code Examples

Verified patterns from official sources:

### .mcp.json Configuration (INT-01)
```json
// Source: https://code.claude.com/docs/en/mcp
// Combined with: https://github.com/containers/kubernetes-mcp-server/blob/main/docs/getting-started-claude-code.md
{
  "mcpServers": {
    "kubernetes": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "kubernetes-mcp-server@latest",
        "--read-only",
        "--cluster-provider", "in-cluster"
      ],
      "env": {}
    }
  }
}
```

**Alternative with pre-installed binary (recommended for production):**
```json
{
  "mcpServers": {
    "kubernetes": {
      "type": "stdio",
      "command": "kubernetes-mcp-server",
      "args": [
        "--read-only",
        "--cluster-provider", "in-cluster"
      ],
      "env": {}
    }
  }
}
```

### Claude Code Settings with MCP Permission (INT-01)
```json
// Source: https://code.claude.com/docs/en/mcp
// Extend existing /app/.claude/settings.json
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write",
      "mcp__kubernetes__*"
    ],
    "defaultMode": "bypassPermissions"
  },
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
```

### DevOps Skill Template (INT-02)
```yaml
# Source: https://code.claude.com/docs/en/skills
---
name: log-analysis
description: Analyze Kubernetes pod and container logs to identify errors, warnings, and patterns. Use when investigating application errors, crash causes, or performance issues in pod logs.
---

## Log Analysis Workflow

When analyzing logs:

1. **Identify the target**: Determine which pod(s) to investigate
2. **Fetch recent logs**: Get the last 100-500 lines of logs from the target container
3. **Check previous container**: If the pod has restarted, check previous container logs
4. **Pattern recognition**: Look for:
   - ERROR/FATAL/PANIC log levels
   - Stack traces and exception messages
   - Repeated error patterns (rate of occurrence)
   - Timestamp correlation with reported issues
   - Resource-related messages (OOM, disk full, connection refused)
5. **Cross-reference**: Check events and related pod status for context

### Log Retrieval Commands
- Use MCP kubernetes tools to fetch pod logs
- For multi-container pods, specify the container name
- Use `--previous` flag for crashed container logs
- Use `--since` for time-bounded analysis

### Output Format
Always provide:
- **Summary**: One-line description of the issue
- **Evidence**: Specific log lines that indicate the problem
- **Timeline**: When the issue started and its frequency
- **Recommendation**: Suggested next steps
```

### CLAUDE.md Generation Script (DOC-02)
```bash
#!/usr/bin/env bash
# generate-claude-md.sh - Auto-populate CLAUDE.md with cluster context
# Called by entrypoint.sh before exec-ing into Claude Code
set -euo pipefail

CLAUDE_MD_PATH="/app/CLAUDE.md"
SA_TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
SA_CA_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
SA_NS_PATH="/var/run/secrets/kubernetes.io/serviceaccount/namespace"
K8S_API="https://kubernetes.default.svc"

# --- Kubernetes context discovery ---
k8s_get() {
    local path="$1"
    curl -sf --max-time 5 \
        --cacert "$SA_CA_PATH" \
        -H "Authorization: Bearer $(cat "$SA_TOKEN_PATH")" \
        "${K8S_API}${path}" 2>/dev/null || echo "{}"
}

if [ ! -f "$SA_TOKEN_PATH" ]; then
    echo "[claude-md] No ServiceAccount token found (not running in Kubernetes?)"
    cat > "$CLAUDE_MD_PATH" << 'STANDALONE_EOF'
# Claude In A Box

You are running in standalone mode (Docker Compose or local).
No Kubernetes cluster access is available.

## Available Tools
- Standard CLI tools: kubectl, helm, k9s, stern, kubectx, jq, yq, curl, etc.
- Use `verify-tools.sh` to see all available tools.
STANDALONE_EOF
    exit 0
fi

# Gather cluster info
NAMESPACE="$(cat "$SA_NS_PATH" 2>/dev/null || echo "unknown")"
K8S_VERSION="$(k8s_get /version | jq -r '.gitVersion // "unknown"')"
NODE_COUNT="$(k8s_get /api/v1/nodes | jq '.items | length // 0')"
CLUSTER_NAME="${CLUSTER_NAME:-$(k8s_get /api/v1/namespaces/kube-system -o json | jq -r '.metadata.annotations["cluster-name"] // "unknown"' 2>/dev/null || echo "unknown")}"
POD_NAME="${HOSTNAME:-unknown}"

# List available MCP tools
MCP_TOOLS="kubernetes-mcp-server (read-only mode)"

# List available DevOps skills
SKILLS="pod-diagnosis, log-analysis, incident-triage, network-debugging"

# Write CLAUDE.md
cat > "$CLAUDE_MD_PATH" << EOF
# Claude In A Box - DevOps Agent

You are a Kubernetes DevOps agent running inside the cluster. You have direct API access to cluster resources via MCP tools. Use MCP tools for structured queries instead of shelling out to kubectl when possible.

## Cluster Environment
- **Kubernetes version**: ${K8S_VERSION}
- **Namespace**: ${NAMESPACE}
- **Node count**: ${NODE_COUNT}
- **Pod name**: ${POD_NAME}

## Available MCP Tools
- ${MCP_TOOLS}
- Tools provide read-only access: list, get, describe pods, deployments, services, events, nodes, namespaces, configmaps, ingresses, PVCs, jobs, cronjobs, statefulsets, daemonsets, replicasets

## Available Skills
Use these skills for structured DevOps workflows:
- **/pod-diagnosis** - Diagnose pod health issues (CrashLoopBackOff, OOM, pending, etc.)
- **/log-analysis** - Analyze container logs for errors, patterns, and root causes
- **/incident-triage** - Structured incident response for cluster issues
- **/network-debugging** - Debug DNS, connectivity, and service mesh issues

## CLI Tools
All standard SRE/DevOps tools are available: kubectl, helm, k9s, stern, kubectx, kubens, jq, yq, curl, dig, nmap, tcpdump, strace, htop, and more.
Run \`verify-tools.sh\` for the complete list.

## Guidelines
- Prefer MCP tools over kubectl for resource queries (structured output, error handling)
- Always check events alongside pod status for full context
- When investigating issues, use the relevant skill for a structured workflow
- This agent has **read-only** Kubernetes access by default
EOF

echo "[claude-md] Generated CLAUDE.md: K8s ${K8S_VERSION}, ${NODE_COUNT} nodes, ns=${NAMESPACE}"
```

### Dockerfile Additions (adding MCP config and skills)
```dockerfile
# -- Copy MCP configuration (project scope) ------------------------------------
COPY --chown=agent:agent .mcp.json /app/.mcp.json

# -- Copy DevOps skills -------------------------------------------------------
COPY --chown=agent:agent .claude/skills/ /app/.claude/skills/

# -- Copy CLAUDE.md generator script ------------------------------------------
COPY --chown=agent:agent scripts/generate-claude-md.sh /usr/local/bin/generate-claude-md.sh
RUN chmod +x /usr/local/bin/generate-claude-md.sh
```

### Entrypoint Modification (calling CLAUDE.md generator)
```bash
# Add before the mode dispatch section in entrypoint.sh:

# =============================================================================
# Generate CLAUDE.md with cluster context
# Must run before exec so Claude Code has context at startup.
# Failures are non-fatal (standalone mode has no K8s access).
# =============================================================================
echo "[entrypoint] Generating CLAUDE.md with cluster context..."
/usr/local/bin/generate-claude-md.sh || echo "[entrypoint] WARNING: CLAUDE.md generation failed (non-fatal)"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| kubectl exec wrapper scripts | MCP protocol with structured tools | 2024-2025 | Structured input/output, error handling, tool discovery, secret masking |
| .claude/commands/ directory | .claude/skills/ with SKILL.md | Claude Code 2.1.3 (Jan 2026) | Skills merged with commands; frontmatter controls invocation; auto-loading |
| Manual CLAUDE.md editing | Auto-population from cluster API | This phase | Dynamic context ensures CLAUDE.md always matches the actual cluster state |
| Flux159 mcp-server-kubernetes (Node.js) | Red Hat kubernetes-mcp-server (Go) | Mid-2025 | Native K8s API access, single binary, in-cluster auto-detection, true read-only mode |
| npx runtime download | Pre-installed binary in container | Best practice | Eliminates startup latency and internet dependency |

**Deprecated/outdated:**
- `.claude/commands/` directory: Still works but superseded by `.claude/skills/`. Use skills for new work.
- SSE transport for local MCP servers: Deprecated per Claude Code docs. Use stdio for local, HTTP for remote.

## Open Questions

1. **Pre-install vs npx for kubernetes-mcp-server**
   - What we know: npx downloads the package on every fresh start (~10-30s). Pre-installing in the Dockerfile eliminates this. The npm package is `kubernetes-mcp-server`.
   - What's unclear: Whether the npm package includes the full Go binary or just a Node.js wrapper that downloads the binary. Need to verify during implementation.
   - Recommendation: Try `npm install -g kubernetes-mcp-server@latest` in the Dockerfile first. If it works, use the binary path directly in `.mcp.json`. If it only provides a Node.js wrapper, keep using npx but pre-warm the cache during build.

2. **Cluster name discovery**
   - What we know: Kubernetes API does not have a standard "cluster name" field. Some distributions annotate `kube-system` namespace.
   - What's unclear: Best portable way to get cluster name across KIND, EKS, GKE, AKS.
   - Recommendation: Use `CLUSTER_NAME` env var if set, otherwise try `kube-system` namespace annotations, otherwise fall back to "unknown". Document that users should set `CLUSTER_NAME` env var in the StatefulSet for meaningful display.

3. **MCP tool permission auto-allow**
   - What we know: Claude Code's settings.json supports `"allow": ["mcp__kubernetes__*"]` to auto-approve all MCP tools from the kubernetes server.
   - What's unclear: Whether the exact glob pattern matches the server name `kubernetes` as configured in `.mcp.json` keys.
   - Recommendation: Test the exact permission pattern during implementation. The server name in `.mcp.json` becomes the prefix: `mcp__<server-name>__<tool-name>`.

4. **Skills directory persistence across image rebuilds**
   - What we know: Skills are COPY'd into the image at build time. The PVC mounts at `/app/.claude/`, which is a parent of `/app/.claude/skills/`.
   - What's unclear: The PVC mount at `/app/.claude/` will OVERLAY the skills directory. On first run, the PVC is empty, so `/app/.claude/skills/` from the image will NOT be visible.
   - Recommendation: **This is a critical issue.** The entrypoint must copy skills from a staging location into the PVC-mounted directory if they don't already exist. Alternative: mount PVC at a sub-path like `/app/.claude/auth/` or change skills location. This needs careful planning.

## Validation Architecture

> Note: workflow.nyquist_validation is not configured in .planning/config.json, skipping detailed validation section.

### Quick Validation Approach
| Requirement | Validation Method |
|-------------|-------------------|
| INT-01 | `claude mcp list` inside the pod shows kubernetes server as "Connected" |
| INT-01 | `/mcp` inside Claude Code shows kubernetes tools available |
| INT-02 | `ls /app/.claude/skills/*/SKILL.md` shows 4 skill files |
| INT-02 | Typing `/` in Claude Code shows pod-diagnosis, log-analysis, incident-triage, network-debugging |
| DOC-02 | `cat /app/CLAUDE.md` shows cluster version, namespace, node count |
| DOC-02 | CLAUDE.md contains correct (not stale) cluster info after pod restart |

## Sources

### Primary (HIGH confidence)
- [Claude Code MCP Documentation](https://code.claude.com/docs/en/mcp) - .mcp.json format, scopes, project-scope configuration, environment variable expansion
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) - SKILL.md format, frontmatter fields, skill directories, auto-loading behavior
- [containers/kubernetes-mcp-server GitHub](https://github.com/containers/kubernetes-mcp-server) - Go-based MCP server, --read-only flag, --cluster-provider in-cluster, toolsets, configuration
- [containers/kubernetes-mcp-server Configuration Docs](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/docs/configuration.md) - All CLI flags, TOML config, cluster_provider_strategy, read_only mode details
- [containers/kubernetes-mcp-server Claude Code Guide](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/docs/getting-started-claude-code.md) - Exact .mcp.json format with --read-only flag

### Secondary (MEDIUM confidence)
- [containers/kubernetes-mcp-server Kubernetes Guide](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/docs/getting-started-kubernetes.md) - ServiceAccount and RBAC setup (verified with official K8s docs)
- [Flux159/mcp-server-kubernetes GitHub](https://github.com/Flux159/mcp-server-kubernetes) - Alternative MCP server, evaluated and rejected for this use case
- [Flux159 Issue #182](https://github.com/Flux159/mcp-server-kubernetes/issues/182) - Confirmed Flux159 version crashes in stdio mode inside containers, requires SSE workaround

### Tertiary (LOW confidence)
- npm package version `kubernetes-mcp-server` - WebSearch indicated v0.0.51 but dates unclear; use `@latest` tag to always get current version

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - kubernetes-mcp-server (Red Hat) has official docs, verified configuration, and confirmed in-cluster support
- Architecture: HIGH - .mcp.json and skills format verified against official Claude Code docs
- Pitfalls: HIGH - PVC overlay issue (Open Question 4) identified from first-principles analysis of existing StatefulSet volumeMount
- CLAUDE.md generation: MEDIUM - Pattern is standard (ServiceAccount token + curl), but cluster name discovery is not standardized across distributions

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (MCP ecosystem evolving rapidly; re-verify versions before implementation)
