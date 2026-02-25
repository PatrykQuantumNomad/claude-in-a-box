# =============================================================================
# Claude In A Box - Multi-Stage Dockerfile
# Produces a deployment-ready Ubuntu 24.04 image with Claude Code and 32+
# SRE/DevOps debugging tools, running as non-root with tini as PID 1.
# =============================================================================

# =============================================================================
# Global ARGs - Version pins for all tools
# Declared before first FROM so they can be redeclared in any stage.
# =============================================================================
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

# =============================================================================
# Stage 1: tools-downloader
# Downloads and verifies all static binary tools for linux/amd64 and linux/arm64
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS tools-downloader

# Redeclare ARGs needed in this stage (without defaults)
ARG TARGETARCH
ARG TINI_VERSION
ARG KUBECTL_VERSION
ARG HELM_VERSION
ARG K9S_VERSION
ARG STERN_VERSION
ARG KUBECTX_VERSION
ARG JQ_VERSION
ARG YQ_VERSION
ARG TRIVY_VERSION
ARG GRYPE_VERSION

# Install minimal download dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tools/bin

# -- tini (PID 1 init process) -----------------------------------------------
RUN curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-${TARGETARCH}" \
    -o /tools/bin/tini && chmod +x /tools/bin/tini

# -- kubectl ------------------------------------------------------------------
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    -o /tools/bin/kubectl && chmod +x /tools/bin/kubectl

# -- helm (extract from tarball) ----------------------------------------------
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/linux-${TARGETARCH}/helm /tools/bin/helm \
    && rm -rf /tmp/linux-${TARGETARCH}

# -- k9s (extract from tarball) -----------------------------------------------
RUN curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin k9s

# -- stern (extract from tarball) ---------------------------------------------
RUN curl -fsSL "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin stern

# -- kubectx + kubens (two separate downloads) --------------------------------
RUN curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin kubectx && \
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin kubens

# -- jq (direct binary download) ---------------------------------------------
RUN curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${TARGETARCH}" \
    -o /tools/bin/jq && chmod +x /tools/bin/jq

# -- yq (direct binary download) ---------------------------------------------
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
    -o /tools/bin/yq && chmod +x /tools/bin/yq

# -- trivy (architecture naming: amd64->"64bit", arm64->"ARM64") --------------
RUN TRIVY_ARCH="${TARGETARCH}" && \
    case "${TRIVY_ARCH}" in \
        amd64) TRIVY_ARCH="64bit" ;; \
        arm64) TRIVY_ARCH="ARM64" ;; \
    esac && \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
    | tar -xz -C /tools/bin trivy

# -- grype (uses standard amd64/arm64) ----------------------------------------
RUN curl -fsSL "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_${TARGETARCH}.tar.gz" \
    | tar -xz -C /tools/bin grype

# Verify all binaries are present and executable
RUN ls -la /tools/bin/ && \
    echo "=== Tools downloaded ===" && \
    for f in /tools/bin/*; do echo "  $(basename $f): $(file $f)"; done

# =============================================================================
# Stage 2: claude-installer
# Installs Node.js and Claude Code via npm
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS claude-installer

# Redeclare ARGs needed in this stage
ARG TARGETARCH
ARG NODE_VERSION
ARG CLAUDE_CODE_VERSION

# Install dependencies for Node.js download and extraction
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install Node.js binary from nodejs.org
# nodejs.org uses "x64" not "amd64" for the download URL
RUN NODE_ARCH="${TARGETARCH}" && \
    case "${NODE_ARCH}" in \
        amd64) NODE_ARCH="x64" ;; \
    esac && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1 && \
    node --version && npm --version

# Install Claude Code via npm (locked decision)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    npm cache clean --force

# Verify Claude Code installation
RUN claude --version

# =============================================================================
# Stage 3: runtime
# Minimal runtime with all tools, non-root user, and Claude Code pre-configured
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS runtime

# Image metadata
LABEL maintainer="claude-in-a-box" \
      description="Containerized Claude Code with 32+ SRE/DevOps debugging tools" \
      org.opencontainers.image.title="Claude In A Box" \
      org.opencontainers.image.description="AI-powered DevOps agent with full debugging toolkit" \
      org.opencontainers.image.source="https://github.com/claude-in-a-box/claude-in-a-box"

# Install ALL apt packages in a single layer
# Ubuntu 24.04 tag acts as the version pin -- no exact apt version pinning
RUN apt-get update && apt-get install -y --no-install-recommends \
    # -- Network tools --
    curl \
    dnsutils \
    nmap \
    tcpdump \
    wget \
    netcat-openbsd \
    iproute2 \
    iputils-ping \
    # -- Process/system tools --
    htop \
    strace \
    procps \
    linux-tools-generic \
    bpftrace \
    # -- Database clients --
    postgresql-client \
    default-mysql-client \
    redis-tools \
    # -- Standard utilities --
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

# -- Copy tini from tools-downloader -----------------------------------------
COPY --from=tools-downloader /tools/bin/tini /usr/local/bin/tini

# -- Copy all static binary tools from tools-downloader ----------------------
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

# -- Copy Node.js + Claude Code from claude-installer -------------------------
COPY --from=claude-installer /usr/local/bin/node /usr/local/bin/
COPY --from=claude-installer /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create symlinks for claude and nodejs
# npm global installs put bin entries in /usr/local/bin/ in the installer stage,
# but we only copy /usr/local/lib/node_modules, so we recreate the symlinks manually.
RUN ln -s /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js /usr/local/bin/claude && \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs

# -- Create non-root user (UID 10000 / GID 10000 per CONTEXT.md) -------------
RUN groupadd -g 10000 agent && \
    useradd -m -u 10000 -g 10000 -d /app -s /bin/bash agent && \
    mkdir -p /app/.claude /var/log && \
    chown -R agent:agent /app /tmp /var/log

# Switch to non-root user
USER agent
WORKDIR /app

# -- Pre-configure Claude Code (as agent user) --------------------------------
# Skip onboarding wizard
RUN echo '{"hasCompletedOnboarding": true}' > /app/.claude.json

# Configure permissions, bypass mode, and disable telemetry/autoupdater
RUN cat > /app/.claude/settings.json << 'SETTINGS'
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
SETTINGS

# -- Environment variables (belt-and-suspenders with settings.json) -----------
ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    DISABLE_INSTALLATION_CHECKS=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    HOME=/app \
    PATH="/usr/local/bin:${PATH}"

# -- Copy tool verification script from build context ------------------------
# Build context is the project root, so path is scripts/verify-tools.sh
COPY --chown=agent:agent scripts/verify-tools.sh /usr/local/bin/verify-tools.sh
RUN chmod +x /usr/local/bin/verify-tools.sh

# -- Copy entrypoint and health check scripts from build context ----------------
COPY --chown=agent:agent scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=agent:agent scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=agent:agent scripts/readiness.sh /usr/local/bin/readiness.sh
COPY --chown=agent:agent scripts/generate-claude-md.sh /usr/local/bin/generate-claude-md.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/readiness.sh /usr/local/bin/generate-claude-md.sh

# -- Copy MCP server configuration (project scope) ----------------------------
COPY --chown=agent:agent .mcp.json /app/.mcp.json

# -- Copy DevOps skills to staging location -----------------------------------
# Skills are staged in /opt/claude-skills/ because the PVC mounts at /app/.claude/
# and would overlay any files COPY'd into /app/.claude/skills/ at build time.
# The entrypoint copies them from staging into the PVC on first start.
COPY --chown=agent:agent .claude/skills/ /opt/claude-skills/

# -- Docker HEALTHCHECK using liveness probe script ----------------------------
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

# -- Entrypoint: tini as PID 1 for proper signal handling --------------------
ENTRYPOINT ["/usr/local/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
