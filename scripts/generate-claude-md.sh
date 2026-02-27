#!/usr/bin/env bash
# =============================================================================
# Claude In A Box - CLAUDE.md Generator
# Queries the Kubernetes API at startup and writes /app/CLAUDE.md with
# cluster context so Claude Code knows its environment.
#
# Idempotent: Runs on every container start via entrypoint.sh and overwrites
# the previous CLAUDE.md. This ensures cluster metadata (node count, K8s
# version, namespace) stays current even if the cluster changes between pod
# restarts.
# =============================================================================
set -euo pipefail

# -- Constants ----------------------------------------------------------------
CLAUDE_MD_PATH="/app/CLAUDE.md"
SA_TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
SA_CA_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
SA_NS_PATH="/var/run/secrets/kubernetes.io/serviceaccount/namespace"
K8S_API="https://kubernetes.default.svc"

# -- Helpers ------------------------------------------------------------------

# k8s_get <path>
#   Queries the Kubernetes API using the ServiceAccount token and CA cert.
#   Returns {} on failure to keep downstream jq pipelines safe.
k8s_get() {
    local path="$1"
    local token
    token=$(cat "$SA_TOKEN_PATH")
    curl -s --max-time 5 \
        --cacert "$SA_CA_PATH" \
        -H "Authorization: Bearer ${token}" \
        "${K8S_API}${path}" 2>/dev/null || echo "{}"
}

# =============================================================================
# Standalone Mode Detection
# If no ServiceAccount token exists, we are running outside Kubernetes
# (Docker Compose, local Docker, etc.). Write a minimal CLAUDE.md.
# =============================================================================
if [ ! -f "$SA_TOKEN_PATH" ]; then
    cat > "$CLAUDE_MD_PATH" << 'STANDALONE_EOF'
# Claude In A Box

You are running in standalone mode (Docker Compose or local).
No Kubernetes cluster access is available.

## Available Tools
- Standard CLI tools: kubectl, helm, k9s, stern, kubectx, jq, yq, curl, dig, nmap, etc.
- Run `verify-tools.sh` for the complete list.
STANDALONE_EOF
    echo "[claude-md] Generated CLAUDE.md: standalone mode (no K8s access)"
    exit 0
fi

# =============================================================================
# Cluster Context Discovery
# Query the Kubernetes API for cluster metadata.
# =============================================================================
K8S_VERSION=$(k8s_get "/version" | jq -r '.gitVersion // "unknown"')
NODE_COUNT=$(k8s_get "/api/v1/nodes" | jq -r '.items | length // 0')
NAMESPACE=$(cat "$SA_NS_PATH" 2>/dev/null || echo "unknown")
POD_NAME="${HOSTNAME:-unknown}"
CLUSTER_NAME="${CLUSTER_NAME:-unknown}"

# =============================================================================
# Write CLAUDE.md
# =============================================================================
cat > "$CLAUDE_MD_PATH" << CLAUDE_EOF
# Claude In A Box - DevOps Agent

You are a Kubernetes DevOps agent running inside the cluster. Use MCP tools for structured queries instead of shelling out to kubectl.

## Cluster Environment

| Property       | Value               |
|----------------|---------------------|
| K8s Version    | ${K8S_VERSION}      |
| Namespace      | ${NAMESPACE}        |
| Cluster Name   | ${CLUSTER_NAME}     |
| Node Count     | ${NODE_COUNT}       |
| Pod Name       | ${POD_NAME}         |

## Available MCP Tools

The **kubernetes-mcp-server** is configured in read-only mode. Use MCP tool calls to query cluster resources instead of shelling out to kubectl.

Accessible resource types:
- pods, services, deployments, events
- nodes, namespaces, configmaps, ingresses
- PVCs, jobs, cronjobs
- statefulsets, daemonsets, replicasets

## Available Skills

Pre-built DevOps skills are available for structured workflows:

- **pod-diagnosis** -- Diagnose unhealthy pods: CrashLoopBackOff, ImagePullBackOff, OOMKilled, pending scheduling
- **log-analysis** -- Analyze container logs for errors, patterns, and anomalies
- **incident-triage** -- Triage production incidents by correlating events, pod status, and resource metrics
- **network-debugging** -- Debug service connectivity, DNS resolution, and network policy issues

## CLI Tools

Standard DevOps CLI tools are installed:
- **kubectl**, **helm**, **k9s**, **stern**, **kubectx**, **kubens**
- **jq**, **yq**, **curl**, **dig**, **nmap**, **tcpdump**
- Run \`verify-tools.sh\` for the complete list.

## Guidelines

1. **Prefer MCP over kubectl** -- MCP tools provide structured output and are safer than shell commands.
2. **Check events with pod status** -- Always correlate pod status with recent events for accurate diagnosis.
3. **Use skills for structured workflows** -- Skills provide step-by-step diagnostic runbooks tuned for common issues.
4. **Read-only access by default** -- The ServiceAccount has read-only RBAC. Mutations require operator-tier privileges.
CLAUDE_EOF

echo "[claude-md] Generated CLAUDE.md: K8s ${K8S_VERSION}, ${NODE_COUNT} nodes, ns=${NAMESPACE}"
