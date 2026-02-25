# Phase 1: Container Foundation - Context

**Gathered:** 2026-02-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-stage Dockerfile producing a deployment-ready image with Ubuntu 24.04, Claude Code (npm), and a full SRE/DevOps debugging toolkit. Container runs as non-root. Entrypoint, authentication, health probes, and runtime configuration are Phase 2. MCP/skills configuration is Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Debugging toolkit selection
- Full SRE/DevOps toolkit: network (curl, dig, nmap, tcpdump), process (htop, strace), K8s (kubectl, helm, k9s, stern, kubectx), log analysis (jq, yq), and standard Linux utilities
- Database clients included: psql, mysql, redis-cli
- Performance profiling tools included (perf, bpftrace or similar)
- Security scanning tools included (trivy, grype or similar)
- No cloud CLIs baked in (no aws/gcloud/az) — users mount or install at runtime
- All tools installed as static binaries with pinned versions where possible

### Base image & build strategy
- Base image: ubuntu:24.04 (full, not minimal)
- No strict image size limit — functionality over size, optimize later
- Multi-stage build with 3+ stages: tools compilation, Claude Code install, final runtime assembly
- All tool versions pinned as Docker ARG variables at the top of the Dockerfile
- No `:latest` tags, no unpinned `apt-get install`

### Claude Code installation
- Install via npm: `npm install -g @anthropic-ai/claude-code@<version>`
- Node.js 22 LTS included in the image
- Auto-updater disabled at build time via env vars/config
- Base settings baked into image at build time:
  - Telemetry disabled
  - Non-interactive mode enabled
  - Common tool permissions pre-approved (bash, read, write) so Claude Code doesn't prompt
- Auth configuration is Phase 2 scope, skills/MCP is Phase 6 scope

### Non-root user setup
- User: `agent` with UID 10000 / GID 10000 (high IDs for security)
- Home directory: `/app`
- Writable paths: `/app`, `/tmp`, `/var/log` — everything else effectively read-only
- All Linux capabilities dropped (document in Dockerfile or compose)
- Filesystem remains writable (not read-only root FS)
- Tools needing root (strace, tcpdump, perf): documented as requiring `--privileged` or added capabilities at runtime — no setcap workarounds
- tini as PID 1 for proper signal handling

### Claude's Discretion
- Exact tool list beyond the categories specified (researcher should identify the standard set)
- Layer caching optimization strategy
- Specific multi-stage build stage boundaries
- Tool binary download sources and verification approach
- Node.js installation method (nodesource, nvm, or direct binary)

</decisions>

<specifics>
## Specific Ideas

- High UID/GID (10000) chosen deliberately for security — avoids collision with host users
- /app as home directory signals this is an application container, not a user environment
- Cloud CLIs explicitly excluded to keep the image focused — users who need them can extend or mount

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-container-foundation*
*Context gathered: 2026-02-25*
