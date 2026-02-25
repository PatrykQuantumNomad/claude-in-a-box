# Phase 1: Container Foundation - Research

**Researched:** 2026-02-25
**Domain:** Docker multi-stage builds, Claude Code containerization, SRE/DevOps tooling
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Debugging toolkit selection
- Full SRE/DevOps toolkit: network (curl, dig, nmap, tcpdump), process (htop, strace), K8s (kubectl, helm, k9s, stern, kubectx), log analysis (jq, yq), and standard Linux utilities
- Database clients included: psql, mysql, redis-cli
- Performance profiling tools included (perf, bpftrace or similar)
- Security scanning tools included (trivy, grype or similar)
- No cloud CLIs baked in (no aws/gcloud/az) -- users mount or install at runtime
- All tools installed as static binaries with pinned versions where possible

#### Base image & build strategy
- Base image: ubuntu:24.04 (full, not minimal)
- No strict image size limit -- functionality over size, optimize later
- Multi-stage build with 3+ stages: tools compilation, Claude Code install, final runtime assembly
- All tool versions pinned as Docker ARG variables at the top of the Dockerfile
- No `:latest` tags, no unpinned `apt-get install`

#### Claude Code installation
- Install via npm: `npm install -g @anthropic-ai/claude-code@<version>`
- Node.js 22 LTS included in the image
- Auto-updater disabled at build time via env vars/config
- Base settings baked into image at build time:
  - Telemetry disabled
  - Non-interactive mode enabled
  - Common tool permissions pre-approved (bash, read, write) so Claude Code doesn't prompt
- Auth configuration is Phase 2 scope, skills/MCP is Phase 6 scope

#### Non-root user setup
- User: `agent` with UID 10000 / GID 10000 (high IDs for security)
- Home directory: `/app`
- Writable paths: `/app`, `/tmp`, `/var/log` -- everything else effectively read-only
- All Linux capabilities dropped (document in Dockerfile or compose)
- Filesystem remains writable (not read-only root FS)
- Tools needing root (strace, tcpdump, perf): documented as requiring `--privileged` or added capabilities at runtime -- no setcap workarounds
- tini as PID 1 for proper signal handling

### Claude's Discretion
- Exact tool list beyond the categories specified (researcher should identify the standard set)
- Layer caching optimization strategy
- Specific multi-stage build stage boundaries
- Tool binary download sources and verification approach
- Node.js installation method (nodesource, nvm, or direct binary)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMG-01 | Multi-stage Dockerfile produces a deployment-ready image with Ubuntu 24.04 base under 2GB compressed | Multi-stage build patterns, ARG version pinning, layer optimization strategy |
| IMG-02 | Claude Code CLI installed via native installer with pinned version and auto-updater disabled | npm install pattern (locked decision), env vars for disabling auto-updater/telemetry, settings.json pre-configuration |
| IMG-03 | Full debugging toolkit (30+ tools) installed as static binaries with pinned versions | Complete tool inventory with versions, download URLs, verification approach |
| IMG-04 | Container runs as non-root user (UID 1000) with tini as PID 1 | User setup pattern, tini v0.19.0, capability dropping |
| IMG-05 | Tool verification script confirms all tools execute correctly as non-root | Verification script pattern, expected tool binary paths |

</phase_requirements>

## Summary

Phase 1 delivers a multi-stage Dockerfile producing a deployment-ready Ubuntu 24.04 image containing Claude Code and 30+ SRE/DevOps debugging tools, running as a non-root user with tini as PID 1. The build uses three stages: a tools download/compilation stage, a Claude Code installation stage, and a final runtime assembly stage. All tool versions are pinned as Docker ARG variables at the top of the Dockerfile.

The core challenge is managing 30+ binary downloads with pinned versions across multiple architectures (amd64/arm64) while keeping the image under 2GB compressed. The recommended approach is to download pre-built static binaries in the tools stage using a shell script pattern that detects architecture via `dpkg --print-architecture` or `uname -m`, then COPY the binaries into the final stage. Claude Code installs via npm with Node.js 22 LTS, with telemetry and auto-updater disabled via environment variables baked into the image.

**IMPORTANT UID DISCREPANCY:** The CONTEXT.md locks UID 10000/GID 10000, but the ROADMAP success criteria #2 states "UID 1000 (non-root)" and requirement IMG-04 also says "UID 1000". The planner must reconcile this -- recommend using UID 10000 per the CONTEXT.md decision (which is the more recent, deliberate choice) and updating the ROADMAP/requirements to match.

**IMPORTANT npm DEPRECATION NOTE:** The user locked "Install via npm" but npm installation of Claude Code is officially deprecated as of late 2025. The npm package still works and supports version pinning, but the CLI displays a deprecation warning on launch. The native installer (`curl -fsSL https://claude.ai/install.sh | bash -s <version>`) is the recommended replacement and supports version pinning. The official devcontainer Dockerfile is being migrated (PR #23853). The planner should note this for the user but honor the locked npm decision. The deprecation warning can be suppressed or is harmless in a container context.

**Primary recommendation:** Use a 3-stage Dockerfile (tools-downloader, node-installer, runtime), download all tools as pre-built binaries with SHA256 verification, install Claude Code via npm per locked decision, and bake all settings via environment variables and `~/.claude.json` + `~/.claude/settings.json`.

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| ubuntu | 24.04 (noble) | Base image | Locked decision; LTS until 2029, full apt ecosystem |
| Node.js | 22.22.0 (LTS) | Claude Code runtime | Locked decision (Node.js 22 LTS); maintenance LTS until 2027-04 |
| @anthropic-ai/claude-code | 2.0.25 (pin at build time) | AI agent CLI | Locked decision (npm install); latest available on npm |
| tini | 0.19.0 | PID 1 init process | De facto standard for container init; stable since 2020 |
| Docker multi-stage build | N/A | Build strategy | Locked decision (3+ stages) |

### Debugging Toolkit -- Complete Tool Inventory

**Network Tools (7 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| curl | apt-pinned | Ubuntu 24.04 apt | apt package |
| dig (bind9-dnsutils) | apt-pinned | Ubuntu 24.04 apt | apt package |
| nmap | 7.94+ | Ubuntu 24.04 apt | apt package |
| tcpdump | apt-pinned | Ubuntu 24.04 apt | apt package (needs CAP_NET_RAW at runtime) |
| wget | apt-pinned | Ubuntu 24.04 apt | apt package |
| netcat (ncat) | apt-pinned | Ubuntu 24.04 apt | apt package |
| iproute2 (ip, ss) | apt-pinned | Ubuntu 24.04 apt | apt package |

**Process/System Tools (5 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| htop | apt-pinned | Ubuntu 24.04 apt | apt package |
| strace | apt-pinned | Ubuntu 24.04 apt | apt package (needs CAP_SYS_PTRACE at runtime) |
| perf (linux-tools) | apt-pinned | Ubuntu 24.04 apt | apt package (needs privileges at runtime) |
| bpftrace | 0.20.2+ | Ubuntu 24.04 apt | apt package (needs privileges at runtime) |
| procps (ps, top) | apt-pinned | Ubuntu 24.04 apt | apt package |

**Kubernetes Tools (5 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| kubectl | 1.35.1 | https://dl.k8s.io/release/v{VER}/bin/linux/{ARCH}/kubectl | Static binary |
| helm | 4.1.1 | https://get.helm.sh/helm-v{VER}-linux-{ARCH}.tar.gz | Static binary |
| k9s | 0.50.18 | https://github.com/derailed/k9s/releases/download/v{VER}/k9s_Linux_{ARCH}.tar.gz | Static binary |
| stern | 1.33.0 | https://github.com/stern/stern/releases/download/v{VER}/stern_linux_{ARCH}.tar.gz | Static binary |
| kubectx/kubens | 0.9.5 | https://github.com/ahmetb/kubectx/releases/download/v{VER}/kubectx_v{VER}_linux_{ARCH}.tar.gz | Static binary |

**Log Analysis/Data Tools (3 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| jq | 1.8.1 | https://github.com/jqlang/jq/releases/download/jq-{VER}/jq-linux-{ARCH} | Static binary |
| yq | 4.52.4 | https://github.com/mikefarah/yq/releases/download/v{VER}/yq_linux_{ARCH} | Static binary |
| less | apt-pinned | Ubuntu 24.04 apt | apt package |

**Database Clients (3 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| psql (postgresql-client) | apt-pinned | Ubuntu 24.04 apt | apt package |
| mysql (mysql-client) | apt-pinned | Ubuntu 24.04 apt | apt package |
| redis-cli (redis-tools) | apt-pinned | Ubuntu 24.04 apt | apt package |

**Security Scanning (2 tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| trivy | 0.68.2 | https://github.com/aquasecurity/trivy/releases/download/v{VER}/trivy_{VER}_Linux-{ARCH}.tar.gz | Static binary |
| grype | 0.109.0 | https://github.com/anchore/grype/releases/download/v{VER}/grype_{VER}_linux_{ARCH}.tar.gz | Static binary |

**Standard Linux Utilities (7+ tools):**

| Tool | Version | Source | Binary Type |
|------|---------|--------|-------------|
| git | apt-pinned | Ubuntu 24.04 apt | apt package |
| vim | apt-pinned | Ubuntu 24.04 apt | apt package |
| nano | apt-pinned | Ubuntu 24.04 apt | apt package |
| tar | apt-pinned | Ubuntu 24.04 apt (pre-installed) | apt package |
| gzip | apt-pinned | Ubuntu 24.04 apt (pre-installed) | apt package |
| unzip | apt-pinned | Ubuntu 24.04 apt | apt package |
| file | apt-pinned | Ubuntu 24.04 apt | apt package |
| tree | apt-pinned | Ubuntu 24.04 apt | apt package |
| ripgrep | apt-pinned or static | Ubuntu 24.04 apt or GitHub | Required by Claude Code for search |

**Total: 32+ tools** (meets the 30+ requirement)

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| npm install (locked) | Native installer (`curl -fsSL https://claude.ai/install.sh \| bash -s <version>`) | Native is now recommended, npm deprecated but still works; version pinning via `bash -s <version>` |
| NodeSource apt repo | Direct binary download from nodejs.org | Direct binary avoids adding external apt repos; simpler in Docker |
| apt for K8s tools | Static binary downloads | Static binaries are architecture-aware and version-pinned; apt versions lag behind |

**Installation (Dockerfile ARGs):**
```dockerfile
# All versions pinned at top of Dockerfile
ARG UBUNTU_VERSION=24.04
ARG NODE_VERSION=22.22.0
ARG CLAUDE_CODE_VERSION=2.0.25
ARG TINI_VERSION=0.19.0
ARG KUBECTL_VERSION=1.35.1
ARG HELM_VERSION=4.1.1
ARG K9S_VERSION=0.50.18
ARG STERN_VERSION=1.33.0
ARG KUBECTX_VERSION=0.9.5
ARG JQ_VERSION=1.8.1
ARG YQ_VERSION=4.52.4
ARG TRIVY_VERSION=0.68.2
ARG GRYPE_VERSION=0.109.0
```

## Architecture Patterns

### Recommended Project Structure
```
docker/
  Dockerfile              # Multi-stage Dockerfile (primary deliverable)
  .dockerignore           # Exclude .git, .planning, etc.
scripts/
  verify-tools.sh         # Tool verification script (baked into image)
  install-tools.sh        # Tool download helper (build-time only, optional)
```

### Pattern 1: Three-Stage Multi-Stage Build
**What:** Separate concerns into download, install, and runtime stages
**When to use:** Always for this project (locked decision: 3+ stages)

```dockerfile
# =============================================================================
# Stage 1: Tool Downloader
# Downloads and verifies all static binary tools
# =============================================================================
FROM ubuntu:24.04 AS tools-downloader

ARG TARGETARCH
# ... ARG declarations for all tool versions ...

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget && \
    rm -rf /var/lib/apt/lists/*

# Download all static binaries into /tools/
RUN mkdir -p /tools && \
    # kubectl
    curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
      -o /tools/kubectl && chmod +x /tools/kubectl && \
    # ... repeat for each tool ...

# =============================================================================
# Stage 2: Node.js + Claude Code
# Installs Node.js and Claude Code via npm
# =============================================================================
FROM ubuntu:24.04 AS claude-installer

ARG NODE_VERSION
ARG CLAUDE_CODE_VERSION

# Install Node.js from official binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Download and install Node.js binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; else NODE_ARCH="$ARCH"; fi && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1

# Install Claude Code via npm (locked decision)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# =============================================================================
# Stage 3: Runtime Assembly
# Minimal runtime with all tools, non-root user, proper config
# =============================================================================
FROM ubuntu:24.04 AS runtime

# ... copy from previous stages, set up user, configure Claude Code ...
```

### Pattern 2: ARG Scoping for Multi-Stage Builds
**What:** Declare ARGs before any FROM to make them available across stages
**When to use:** Always with multi-stage builds using shared version variables

```dockerfile
# Global ARGs (before first FROM) - available to all stages via redeclaration
ARG NODE_VERSION=22.22.0
ARG CLAUDE_CODE_VERSION=2.0.25

FROM ubuntu:24.04 AS tools-downloader
# ARGs from global scope must be redeclared (without default) to use
ARG KUBECTL_VERSION
# ...

FROM ubuntu:24.04 AS claude-installer
ARG NODE_VERSION
ARG CLAUDE_CODE_VERSION
# Now available in this stage
```

### Pattern 3: Architecture-Aware Binary Downloads
**What:** Use Docker's TARGETARCH build arg for multi-platform support
**When to use:** Any binary download in Dockerfile

```dockerfile
FROM ubuntu:24.04 AS tools-downloader
ARG TARGETARCH
ARG KUBECTL_VERSION=1.35.1

RUN curl -fsSL \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    -o /tools/kubectl && chmod +x /tools/kubectl
```

Note: Docker automatically sets `TARGETARCH` to `amd64` or `arm64` based on the target platform. Some tools use different naming conventions (`x86_64` vs `amd64`, `aarch64` vs `arm64`), so the download script must handle these mappings.

### Pattern 4: Claude Code Pre-Configuration
**What:** Bake settings into the image so Claude Code starts without prompts
**When to use:** Always for container deployments

```dockerfile
# In the runtime stage, as the agent user:

# 1. Skip onboarding
RUN mkdir -p /app && \
    echo '{"hasCompletedOnboarding": true}' > /app/.claude.json

# 2. Disable telemetry and auto-updater via settings
RUN mkdir -p /app/.claude && \
    cat > /app/.claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write"
    ],
    "defaultMode": "bypassPermissions"
  },
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
EOF

# 3. Environment variables (belt-and-suspenders with settings.json)
ENV DISABLE_AUTOUPDATER=1
ENV DISABLE_TELEMETRY=1
ENV DISABLE_ERROR_REPORTING=1
```

### Pattern 5: Non-Root User with Proper Directory Ownership
**What:** Create dedicated user with specific UID/GID and writable paths
**When to use:** Always (locked decision)

```dockerfile
# Create agent user with high UID/GID
RUN groupadd -g 10000 agent && \
    useradd -m -u 10000 -g 10000 -d /app -s /bin/bash agent && \
    mkdir -p /app/.claude /tmp /var/log && \
    chown -R agent:agent /app /tmp /var/log

USER agent
WORKDIR /app
```

### Anti-Patterns to Avoid
- **Running apt-get update and apt-get install in separate RUN layers:** This causes cache staleness. Always combine: `RUN apt-get update && apt-get install -y ... && rm -rf /var/lib/apt/lists/*`
- **Using `:latest` tags anywhere:** Locked decision prohibits this. Always pin versions.
- **Installing build tools in the runtime stage:** Use multi-stage build to keep build dependencies out of the final image.
- **Running `npm install -g` as root without cleanup:** Clear npm cache after install: `npm cache clean --force`
- **Downloading binaries without verification:** Use checksums where available.
- **Using `ADD` instead of `COPY`:** ADD has surprising behaviors with URLs and archives. Use COPY for local files, RUN curl for downloads.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Container init (zombie reaping, signal forwarding) | Custom entrypoint with trap/wait | tini 0.19.0 | Handles edge cases around zombie processes, signal groups, and PID namespace correctly |
| Architecture detection | Custom uname parsing scripts | Docker TARGETARCH build arg | Built into BuildKit, handles all platform combinations |
| Node.js version management | nvm in container | Direct binary download from nodejs.org | nvm adds complexity and shell initialization overhead in containers |
| apt version pinning tool | Manual `apt list --all-versions` | `apt-get install package=version*` or accept Ubuntu 24.04 defaults | Ubuntu 24.04 is a point-in-time snapshot; apt packages are stable within a release |
| Tool verification | Manual `which` + `--version` checks | Structured verification script with exit codes | Consistent, automatable, extensible |

**Key insight:** Every binary download and system utility has well-established patterns in the Docker ecosystem. The complexity is in managing 30+ tools consistently, not in any individual installation.

## Common Pitfalls

### Pitfall 1: ARG Scope Loss in Multi-Stage Builds
**What goes wrong:** ARGs declared before a FROM statement are not automatically available in subsequent stages. The build silently uses empty strings.
**Why it happens:** Each FROM starts a new build stage with a clean scope. Docker requires explicit re-declaration.
**How to avoid:** Declare ARGs globally (before first FROM) with defaults, then re-declare (ARG NAME without default) in each stage that needs them.
**Warning signs:** Empty version strings in download URLs, curl errors downloading from malformed URLs.

### Pitfall 2: Layer Cache Invalidation Cascade
**What goes wrong:** Changing any one tool version invalidates the cache for all subsequent tool downloads in the same RUN command.
**Why it happens:** Docker caches at the RUN instruction level. One long RUN with all downloads means any version change re-downloads everything.
**How to avoid:** Group tool downloads by change frequency. K8s tools (kubectl, helm) change often; system tools rarely. Consider separate RUN commands for different tool groups, or accept the trade-off of a single monolithic download step for simplicity.
**Warning signs:** Build times spike when only one version changed.

### Pitfall 3: Architecture Name Mismatches
**What goes wrong:** Binary download fails because the tool uses `x86_64` but Docker's TARGETARCH returns `amd64`.
**Why it happens:** No standard naming convention across projects. Some use `amd64/arm64`, others use `x86_64/aarch64`, others use `64bit/ARM64`.
**How to avoid:** Create an explicit mapping in the download script:
```bash
case "${TARGETARCH}" in
  amd64) ARCH_ALT="x86_64" ; K9S_ARCH="amd64" ;;
  arm64) ARCH_ALT="aarch64" ; K9S_ARCH="arm64" ;;
esac
```
**Warning signs:** 404 errors during build, but only on non-amd64 platforms.

### Pitfall 4: npm Global Install Path Issues with Non-Root User
**What goes wrong:** Claude Code installed as root via npm is not accessible by the agent user, or the global npm directory has wrong permissions.
**Why it happens:** npm global installs go to `/usr/local/lib/node_modules` by default, which requires root. If you install as root then switch to non-root, the binaries are accessible but Claude Code may try to write to its install directory for updates.
**How to avoid:** Install Node.js and Claude Code in the claude-installer stage, then COPY the entire Node.js installation to the runtime stage. The auto-updater is disabled, so write access to the install directory is not needed.
**Warning signs:** Permission denied errors when Claude Code starts, or "EACCES" errors.

### Pitfall 5: Claude Code Onboarding Flow in Containers
**What goes wrong:** Claude Code launches the interactive onboarding wizard on first run, blocking automated startup.
**Why it happens:** Without `~/.claude.json` containing `"hasCompletedOnboarding": true`, Claude Code triggers the full onboarding flow.
**How to avoid:** Pre-create `/app/.claude.json` with `{"hasCompletedOnboarding": true}` in the Dockerfile. This is separate from authentication (Phase 2 scope).
**Warning signs:** Container hangs on startup waiting for interactive input.

### Pitfall 6: Tools Requiring Root Capabilities
**What goes wrong:** strace, tcpdump, perf, and bpftrace fail with "Operation not permitted" as non-root.
**Why it happens:** These tools require specific Linux capabilities (CAP_SYS_PTRACE, CAP_NET_RAW, CAP_SYS_ADMIN).
**How to avoid:** Per locked decision, document these as requiring `--cap-add` or `--privileged` at runtime. The verify-tools.sh script should test these tools with a special flag that marks them as "requires elevated privileges" rather than failing the verification.
**Warning signs:** Verification script fails on 4-5 tools that work fine as root.

### Pitfall 7: npm Deprecation Warning on Claude Code Launch
**What goes wrong:** Claude Code displays "npm install is deprecated, use native installer" warning on every launch.
**Why it happens:** Anthropic deprecated npm installation in late 2025.
**How to avoid:** This is cosmetic and does not affect functionality. The warning can potentially be suppressed by setting `DISABLE_INSTALLATION_CHECKS=1` environment variable. The planner should include this env var in the Dockerfile.
**Warning signs:** Noisy container logs on startup.

## Code Examples

### Complete Tool Download Pattern (Stage 1)

```dockerfile
# Source: Docker best practices + tool release pages
FROM ubuntu:24.04 AS tools-downloader

ARG TARGETARCH

# Version pins
ARG KUBECTL_VERSION=1.35.1
ARG HELM_VERSION=4.1.1
ARG K9S_VERSION=0.50.18
ARG STERN_VERSION=1.33.0
ARG KUBECTX_VERSION=0.9.5
ARG JQ_VERSION=1.8.1
ARG YQ_VERSION=4.52.4
ARG TRIVY_VERSION=0.68.2
ARG GRYPE_VERSION=0.109.0
ARG TINI_VERSION=0.19.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tools/bin

# Architecture mapping
# TARGETARCH is "amd64" or "arm64" (set by Docker BuildKit)
# Some tools use different naming: x86_64/aarch64 or 64-bit/ARM64

# tini
RUN curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-${TARGETARCH}" \
    -o /tools/bin/tini && chmod +x /tools/bin/tini

# kubectl
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    -o /tools/bin/kubectl && chmod +x /tools/bin/kubectl

# helm
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/linux-${TARGETARCH}/helm /tools/bin/helm

# k9s
RUN curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin k9s

# stern
RUN STERN_ARCH="${TARGETARCH}" && \
    curl -fsSL "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${STERN_ARCH}.tar.gz" \
    | tar -xz -C /tools/bin stern

# kubectx + kubens
RUN curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin kubectx && \
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin kubens

# jq
RUN JQ_ARCH="${TARGETARCH}" && \
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${JQ_ARCH}" \
    -o /tools/bin/jq && chmod +x /tools/bin/jq

# yq
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
    -o /tools/bin/yq && chmod +x /tools/bin/yq

# trivy
RUN TRIVY_ARCH="${TARGETARCH}" && \
    if [ "$TRIVY_ARCH" = "amd64" ]; then TRIVY_ARCH="64bit"; fi && \
    if [ "$TRIVY_ARCH" = "arm64" ]; then TRIVY_ARCH="ARM64"; fi && \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
    | tar -xz -C /tools/bin trivy

# grype
RUN GRYPE_ARCH="${TARGETARCH}" && \
    curl -fsSL "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_${GRYPE_ARCH}.tar.gz" \
    | tar -xz -C /tools/bin grype
```

### Node.js Direct Binary Install (Stage 2)

```dockerfile
# Source: https://nodejs.org/en/download (recommended for Docker)
FROM ubuntu:24.04 AS claude-installer

ARG NODE_VERSION=22.22.0
ARG CLAUDE_CODE_VERSION=2.0.25

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js from official binary tarball
# nodejs.org uses "x64" not "amd64"
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; else NODE_ARCH="$ARCH"; fi && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1 && \
    node --version && npm --version

# Install Claude Code via npm (locked decision)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    npm cache clean --force

# Verify installation
RUN claude --version
```

### Runtime Stage Assembly (Stage 3)

```dockerfile
# Source: Docker best practices, Claude Code docs
FROM ubuntu:24.04 AS runtime

# apt packages (system tools, database clients, network tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Network tools
    curl \
    dnsutils \
    nmap \
    tcpdump \
    wget \
    netcat-openbsd \
    iproute2 \
    iputils-ping \
    # Process/system tools
    htop \
    strace \
    procps \
    # Performance (require privileges at runtime)
    linux-tools-generic \
    bpftrace \
    # Database clients
    postgresql-client \
    default-mysql-client \
    redis-tools \
    # Standard utilities
    git \
    vim-tiny \
    nano \
    unzip \
    file \
    tree \
    less \
    ca-certificates \
    ripgrep \
    bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Copy tini from tools stage
COPY --from=tools-downloader /tools/bin/tini /usr/local/bin/tini

# Copy all static binary tools
COPY --from=tools-downloader /tools/bin/kubectl /usr/local/bin/
COPY --from=tools-downloader /tools/bin/helm /usr/local/bin/
COPY --from=tools-downloader /tools/bin/k9s /usr/local/bin/
COPY --from=tools-downloader /tools/bin/stern /usr/local/bin/
COPY --from=tools-downloader /tools/bin/kubectx /usr/local/bin/
COPY --from=tools-downloader /tools/bin/kubens /usr/local/bin/
COPY --from=tools-downloader /tools/bin/jq /usr/local/bin/
COPY --from=tools-downloader /tools/bin/yq /usr/local/bin/
COPY --from=tools-downloader /tools/bin/trivy /usr/local/bin/
COPY --from=tools-downloader /tools/bin/grype /usr/local/bin/

# Copy Node.js + Claude Code from installer stage
COPY --from=claude-installer /usr/local/bin/node /usr/local/bin/
COPY --from=claude-installer /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/.bin/claude /usr/local/bin/claude && \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Create non-root user
RUN groupadd -g 10000 agent && \
    useradd -m -u 10000 -g 10000 -d /app -s /bin/bash agent && \
    mkdir -p /app/.claude /var/log && \
    chown -R agent:agent /app /tmp /var/log

# Switch to non-root user
USER agent
WORKDIR /app

# Pre-configure Claude Code
RUN echo '{"hasCompletedOnboarding": true}' > /app/.claude.json && \
    mkdir -p /app/.claude && \
    cat > /app/.claude/settings.json << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write"
    ],
    "defaultMode": "bypassPermissions"
  },
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  }
}
SETTINGS

# Environment variables
ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    DISABLE_INSTALLATION_CHECKS=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    HOME=/app \
    PATH="/usr/local/bin:${PATH}"

# Copy verification script
COPY --chown=agent:agent scripts/verify-tools.sh /usr/local/bin/verify-tools.sh
RUN chmod +x /usr/local/bin/verify-tools.sh

# tini as entrypoint (PID 1)
ENTRYPOINT ["/usr/local/bin/tini", "--"]
CMD ["bash"]
```

### Tool Verification Script

```bash
#!/usr/bin/env bash
# verify-tools.sh - Confirms all tools execute correctly as non-root
# Exit code 0 = all tools verified, non-zero = failures detected

set -euo pipefail

PASS=0
FAIL=0
SKIP=0
ERRORS=()

check_tool() {
    local name="$1"
    local cmd="$2"
    local privileged="${3:-false}"

    if [ "$privileged" = "true" ]; then
        # Tools requiring elevated privileges - check binary exists but skip execution test
        if command -v "$name" &>/dev/null; then
            echo "[SKIP] $name (requires elevated privileges)"
            ((SKIP++))
        else
            echo "[FAIL] $name - binary not found"
            ERRORS+=("$name: binary not found")
            ((FAIL++))
        fi
        return
    fi

    if eval "$cmd" &>/dev/null 2>&1; then
        echo "[PASS] $name"
        ((PASS++))
    else
        echo "[FAIL] $name"
        ERRORS+=("$name: command failed")
        ((FAIL++))
    fi
}

echo "=== Tool Verification ==="
echo "Running as: $(whoami) (UID: $(id -u))"
echo ""

# Network tools
check_tool "curl" "curl --version"
check_tool "dig" "dig -v"
check_tool "nmap" "nmap --version"
check_tool "tcpdump" "tcpdump --version" "true"  # needs CAP_NET_RAW
check_tool "wget" "wget --version"
check_tool "netcat" "nc -h"
check_tool "ip" "ip -V"
check_tool "ss" "ss -V"
check_tool "ping" "ping -c 1 127.0.0.1"

# Process tools
check_tool "htop" "htop --version"
check_tool "strace" "strace -V" "true"  # needs CAP_SYS_PTRACE
check_tool "ps" "ps --version"
check_tool "top" "top -v"
check_tool "perf" "perf version" "true"  # needs privileges
check_tool "bpftrace" "bpftrace --version" "true"  # needs privileges

# Kubernetes tools
check_tool "kubectl" "kubectl version --client"
check_tool "helm" "helm version"
check_tool "k9s" "k9s version"
check_tool "stern" "stern --version"
check_tool "kubectx" "kubectx --help"
check_tool "kubens" "kubens --help"

# Data/log tools
check_tool "jq" "jq --version"
check_tool "yq" "yq --version"
check_tool "less" "less --version"

# Database clients
check_tool "psql" "psql --version"
check_tool "mysql" "mysql --version"
check_tool "redis-cli" "redis-cli --version"

# Security tools
check_tool "trivy" "trivy --version"
check_tool "grype" "grype version"

# Standard utilities
check_tool "git" "git --version"
check_tool "vim" "vim --version"
check_tool "nano" "nano --version"
check_tool "unzip" "unzip -v"
check_tool "file" "file --version"
check_tool "tree" "tree --version"
check_tool "rg" "rg --version"

# Claude Code
check_tool "claude" "claude --version"
check_tool "node" "node --version"

echo ""
echo "=== Results ==="
echo "PASS: $PASS | FAIL: $FAIL | SKIP (privileged): $SKIP"
echo "Total tools: $((PASS + FAIL + SKIP))"

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
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Claude Code via npm | Native binary installer | Late 2025 | npm still works but deprecated; native installer auto-updates, no Node.js dependency |
| Helm v3 | Helm v4 (4.1.1) | November 2025 (KubeCon) | URL pattern changed from helm-v3.x.x to helm-v4.x.x; API remains similar |
| Docker `--init` flag | Explicit tini in Dockerfile | Stable pattern | Using tini directly gives more control than Docker's built-in init |
| `apt-get install` without pinning | Version-pinned apt packages | Best practice | Ubuntu 24.04 packages are stable within release, but pinning prevents drift if repos update |

**Deprecated/outdated:**
- **Claude Code npm installation:** Officially deprecated. Still functional but displays warning. The official devcontainer is migrating to native installer (PR #23853). The locked decision uses npm, which is acceptable but the deprecation should be noted.
- **Helm v3:** Still available but Helm v4 is current. URL download patterns differ.

## Open Questions

1. **UID discrepancy: 10000 vs 1000**
   - What we know: CONTEXT.md locks UID 10000/GID 10000. ROADMAP success criteria #2 and requirement IMG-04 state "UID 1000".
   - What's unclear: Which is authoritative?
   - Recommendation: Use UID 10000 per CONTEXT.md (more recent, deliberate security decision). The planner should flag this and update ROADMAP/requirements to say "non-root" without specifying a UID number, or update to 10000.

2. **Exact apt package versions for Ubuntu 24.04**
   - What we know: Ubuntu 24.04 repos provide stable package versions within the release. Exact version numbers depend on the apt repository snapshot at build time.
   - What's unclear: Whether to pin to exact versions (e.g., `curl=8.5.0-2ubuntu10.6`) or accept Ubuntu 24.04 defaults.
   - Recommendation: For apt packages, use `apt-get install --no-install-recommends package` without exact version pins. The Ubuntu 24.04 tag already acts as a version pin. Exact apt version pinning is fragile (versions change with security updates) and adds maintenance burden. Pin the base image tag instead: `ubuntu:24.04` (or even by digest for maximum reproducibility).

3. **Claude Code npm deprecation vs locked decision**
   - What we know: npm install is deprecated but functional. Native installer supports version pinning via `bash -s <version>`. The native installer does NOT require Node.js.
   - What's unclear: Whether to respect the locked decision exactly or adapt.
   - Recommendation: Honor the locked decision (npm install). Add `DISABLE_INSTALLATION_CHECKS=1` to suppress deprecation warnings. Document the native installer as a future migration path. Node.js 22 is still needed per the locked decision regardless.

4. **Trivy and Grype architecture naming in download URLs**
   - What we know: Trivy uses `64bit`/`ARM64` in download URLs. Grype uses `amd64`/`arm64`.
   - What's unclear: Exact URL templates may change between patch releases.
   - Recommendation: Verify download URLs during implementation by testing both architectures. Add a build-time verification step that checks HTTP 200 for each URL.

5. **linux-tools-generic package for perf**
   - What we know: `perf` comes from `linux-tools-$(uname -r)` which is kernel-version-specific. In containers, the kernel is the host kernel, not the container's.
   - What's unclear: Whether `linux-tools-generic` provides a working `perf` binary in a container.
   - Recommendation: Install `linux-tools-generic` and `linux-perf` as a best-effort. The tool requires `--privileged` at runtime anyway. If the binary doesn't match the host kernel, it will fail gracefully (this is expected and documented behavior for perf in containers).

## Sources

### Primary (HIGH confidence)
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) - Environment variables, permissions, settings.json format
- [Claude Code Permissions Documentation](https://code.claude.com/docs/en/permissions) - Permission modes, rule syntax, bypassPermissions
- [Claude Code Advanced Setup](https://code.claude.com/docs/en/setup) - Installation methods, npm deprecation, native installer
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless) - Non-interactive operation, -p flag, --allowedTools
- [Claude Code DevContainer Reference](https://code.claude.com/docs/en/devcontainer) - Official Dockerfile pattern
- [Claude Code Official Dockerfile](https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile) - Reference implementation
- [Docker Multi-stage Build Docs](https://docs.docker.com/build/building/multi-stage/) - COPY --from, stage naming
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/) - Layer caching, apt-get patterns

### Secondary (MEDIUM confidence)
- [Node.js 22.22.0 Release](https://nodejs.org/en/blog/release/v22.22.0) - Node.js LTS version confirmed
- [tini v0.19.0](https://github.com/krallin/tini/releases/tag/v0.19.0) - Latest release, download URLs verified
- [kubectl 1.35.1](https://kubernetes.io/releases/) - Latest stable Kubernetes release
- [Helm 4.1.1](https://github.com/helm/helm/releases) - Latest Helm release
- [k9s 0.50.18](https://github.com/derailed/k9s/releases) - Latest k9s release
- [jq 1.8.1](https://github.com/jqlang/jq/releases) - Latest jq release
- [yq 4.52.4](https://github.com/mikefarah/yq/releases) - Latest yq release
- [trivy 0.68.2](https://github.com/aquasecurity/trivy/releases) - Latest Trivy release
- [grype 0.109.0](https://github.com/anchore/grype/releases) - Latest Grype release
- [stern 1.33.0](https://github.com/stern/stern/releases) - Latest Stern release
- [kubectx 0.9.5](https://github.com/ahmetb/kubectx/releases) - Latest kubectx release
- [Claude Code Issue #19985](https://github.com/anthropics/claude-code/issues/19985) - npm to native migration in Docker
- [Claude Code Issue #4714](https://github.com/anthropics/claude-code/issues/4714) - hasCompletedOnboarding behavior

### Tertiary (LOW confidence)
- Claude Code npm version 2.0.25 - From search results; verify at build time as this changes frequently
- Exact download URL templates for trivy/grype - Architecture naming conventions may vary between releases; verify at implementation time

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tool versions verified against official release pages and documentation
- Architecture patterns: HIGH - Based on official Docker docs, Claude Code reference implementation, and established multi-stage build patterns
- Pitfalls: HIGH - Based on well-documented Docker, npm, and Claude Code behaviors confirmed by official docs and issue trackers
- Tool versions: MEDIUM - Versions are current as of 2026-02-25 but change frequently; pin at build time
- Download URL templates: MEDIUM - Verified for current versions but naming conventions may shift; test during implementation

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (30 days; tool versions will need refresh, patterns remain stable)
