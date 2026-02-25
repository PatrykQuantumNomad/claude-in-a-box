# Stack Research

**Domain:** Containerized AI agent deployment with DevOps debugging toolkit
**Researched:** 2026-02-25
**Confidence:** HIGH

## Recommended Stack

### Base Image & Container Runtime

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Ubuntu | 24.04 LTS (Noble Numbat) | Base container image | 5 years of security updates through 2029. Widest package availability of any container base. Required because the tool set (30+ binaries) needs a full userland -- Alpine would require extensive musl workarounds for Go and C++ binaries. Use `ubuntu:24.04` not `ubuntu:latest` to pin deterministically. |
| Docker Engine | 29.x | Container runtime (host) | Current stable release (29.2.1 as of Feb 2026). Engine 28 reached EOL Nov 2025. BuildKit is the default builder since Engine 23.0, enabling cache mounts and secret mounts out of the box. |
| Docker Compose | v5.1.x | Local multi-container orchestration | Current stable (v5.1.0 released 2026-02-24). Docker skipped v3/v4 numbering to avoid confusion with legacy compose file versions. Uses Compose Specification, not legacy v2/v3 file formats. |
| BuildKit | Default (bundled with Engine 29) | Image build backend | Enables `--mount=type=cache` for apt and npm caches (10x faster rebuilds), `--mount=type=secret` for API keys during build, and parallel stage execution in multi-stage builds. No separate install needed. |
| tini | 0.19.0 | Init process (PID 1) | Proper SIGTERM forwarding and zombie process reaping. Without tini, Claude Code process at PID 1 will not receive SIGTERM from `docker stop`, leading to SIGKILL after grace period. Install via `apt-get install tini` in Ubuntu or use Docker's `--init` flag. |

### Claude Code Runtime

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Claude Code CLI | Latest (native installer) | AI agent runtime | Install via `curl -fsSL https://claude.ai/install.sh \| bash`. The npm installation (`@anthropic-ai/claude-code`) is officially deprecated -- the native installer is faster, has no Node.js dependency, and auto-updates. Pin a specific version with `bash -s <version>` for reproducible builds. Disable auto-updates in container via `DISABLE_AUTOUPDATER=1`. |
| Node.js | 24.x LTS (Krypton) | Claude Code dependency (if needed) | Node.js 24 entered Active LTS on Oct 28, 2025. However, the native Claude Code installer bundles its own runtime -- Node.js is only needed if using the deprecated npm install path or for custom scripting. If required, use `node:24-slim` in builder stage only. Node.js 22 (Jod) is in Maintenance LTS until Apr 2027 and remains a valid fallback. |

### Kubernetes Tooling (Embedded in Image)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| kubectl | 1.35.x | Kubernetes CLI | Must match within one minor version of target cluster. Pin to 1.35.x as the current stable. Download the static binary directly from `dl.k8s.io` -- do not install via apt (outdated). |
| Helm | 4.1.x | Kubernetes package manager | Helm 4.0.0 released Nov 2025, first major release in 6 years. Helm 3 bug fixes end Jul 2026, security fixes end Nov 2026. Start with Helm 4 for new projects. Download static binary from GitHub releases. |
| k9s | 0.50.18 | Kubernetes TUI dashboard | Latest maintenance release (Jan 2026). Single static binary, no dependencies. Invaluable for interactive cluster debugging sessions. |
| stern | 1.33.1 | Multi-pod log tailing | Latest release (Nov 2025). Color-coded output across multiple pods/containers. Regex-based pod filtering. Auto-follows new pods matching the query. |
| kubectx/kubens | 0.9.5 | Context and namespace switching | Latest release. Go binary version is 8-15x faster than the bash implementation. Download from GitHub releases. |
| kustomize | 5.8.1 | Kubernetes manifest customization | Released Feb 2026. Compatible with Helm 4. Built into kubectl but standalone version offers more features and faster updates. |
| crictl | 1.35.0 | Container runtime debugging | Matches Kubernetes 1.35.x release cycle. Essential for debugging containerd/CRI-O runtime issues on nodes. |

### Observability & Monitoring Tools (Embedded in Image)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| promtool | 3.9.1 (from Prometheus) | Prometheus rule/config validation | Bundled with Prometheus releases. Download just the `promtool` binary from Prometheus GitHub releases. Validates alerting rules and recording rules without a running Prometheus instance. |
| logcli | 3.6.7 (from Grafana Loki) | Loki log querying | Released Feb 2026. Query Loki directly from the command line without Grafana UI. Match version to your Loki deployment. |
| grpcurl | 1.9.3 | gRPC service debugging | Released Mar 2025. Like curl but for gRPC. Essential for debugging gRPC-based services (Envoy, Istio, custom services). |

### Container & Image Tools (Embedded in Image)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Docker CLI | Matches host Engine | Docker operations from inside container | Install `docker-ce-cli` only (not the full engine). The container uses Docker socket mount to communicate with host Docker daemon. |
| skopeo | 1.22.0 | Container image inspection/copy | Released Feb 2025. Inspect remote images without pulling them. Copy images between registries. No daemon required -- stateless operation ideal for containers. |

### Network Debugging Tools (Embedded in Image -- from Ubuntu repos)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| curl | Ubuntu 24.04 repo | HTTP/HTTPS client | Standard HTTP debugging. Supports HTTP/2 and HTTP/3. |
| dig (bind9-dnsutils) | Ubuntu 24.04 repo | DNS debugging | Query DNS records. Essential for Kubernetes DNS debugging (CoreDNS issues). |
| nmap | Ubuntu 24.04 repo | Network scanning/port discovery | Service discovery, port scanning, network mapping. |
| tcpdump | Ubuntu 24.04 repo | Packet capture | Low-level network debugging. Requires `NET_RAW` capability in Kubernetes. |
| netcat (ncat) | Ubuntu 24.04 repo | TCP/UDP connectivity testing | Quick port reachability tests. Use `ncat` (from nmap) not `nc.openbsd`. |
| mtr | Ubuntu 24.04 repo | Network route tracing | Combines ping and traceroute. Identifies latency and packet loss along the path. |
| openssl | Ubuntu 24.04 repo | TLS/certificate debugging | Verify certificates, test TLS connections, inspect certificate chains. |

### System Debugging Tools (Embedded in Image -- from Ubuntu repos)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| htop | Ubuntu 24.04 repo | Process monitoring | Interactive process viewer with tree view. Better than `top` for debugging resource usage. |
| strace | Ubuntu 24.04 repo | System call tracing | Trace system calls. Requires `SYS_PTRACE` capability in Kubernetes. |
| lsof | Ubuntu 24.04 repo | Open file/socket listing | Find which processes hold files or sockets. Essential for debugging "address already in use" issues. |

### Modern CLI Tools (Embedded in Image)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| jq | 1.8.1 | JSON processing | Released Jul 2025 with security fixes (CVE-2025-49014). Install from GitHub releases, not apt (repo version may lag). |
| yq | 4.52.4 | YAML/JSON/XML processing | Released Feb 2026. jq-like syntax for YAML. Essential for Kubernetes manifest manipulation. Install from GitHub releases. |
| bat | 0.26.1 | Syntax-highlighted file viewing | Released Dec 2025. `cat` replacement with syntax highlighting, line numbers, git integration. |
| fd | 10.3.0 | Fast file finding | Released Aug 2025. `find` replacement that respects .gitignore and has intuitive syntax. |
| ripgrep | 15.1.0 | Fast text search | Released Oct 2025. 10x faster than grep. Respects .gitignore. Claude Code also depends on ripgrep internally. |

### Local Development & Testing

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| KIND | 0.31.0 | Local Kubernetes clusters | Latest release. Default node image is Kubernetes 1.35.0. Supports amd64 and arm64. Use `@sha256` digest for node images to guarantee reproducibility. Note: K8s 1.35+ dropped cgroup v1 support. |
| Docker Desktop | Latest | Local Docker runtime | Includes KIND as a built-in cluster provisioner since 2025. Provides Docker Engine, Docker Compose, and BuildKit. |

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Ubuntu 24.04 base | Alpine 3.19 | Only if image size is the sole priority and you can tolerate musl incompatibilities with Go/C++ binaries. Alpine saves ~60MB on base but the debugging toolkit needs glibc. Not worth the risk. |
| Ubuntu 24.04 base | Debian 12 (Bookworm) slim | If you want smaller base (~80MB vs ~78MB) with glibc. Reasonable choice but Ubuntu has better documentation for enterprise environments and identical package availability. Marginal difference. |
| Ubuntu 24.04 base | Wolfi/Chainguard | If supply chain security is paramount. Distroless approach with SBOM. But requires significant effort to add 30+ tools and loses interactive shell capability, which defeats the purpose. |
| Helm 4 | Helm 3.20.x | If targeting clusters that have Helm 3 Tiller remnants or need backward compatibility. Helm 3 gets security fixes until Nov 2026. For greenfield, go Helm 4. |
| KIND | Minikube | If you need hypervisor-based isolation (VirtualBox/HyperKit) or addons ecosystem. KIND is faster to start (30s vs 2-3min), uses less resources, and is the official K8s testing tool. |
| KIND | k3d (k3s in Docker) | If you want Rancher/k3s compatibility testing. k3d is lighter but KIND mirrors upstream Kubernetes behavior exactly, which matters for a tool that debugs production K8s clusters. |
| Docker Compose v5 | Podman Compose | If Docker licensing is a concern. Podman Compose is less mature and has compatibility gaps with Docker Compose Specification. Stick with Docker Compose. |
| Native Claude Code installer | npm `@anthropic-ai/claude-code` | Only if you need to pin a very specific older version that the native installer does not serve. The npm package has known issues (missing entry points in some versions). Avoid. |
| StatefulSet | Agent Sandbox CRD | If you want Kubernetes-native AI agent lifecycle management with hibernation support. Agent Sandbox (kubernetes-sigs/agent-sandbox) launched Nov 2025 at KubeCon. It is promising but early-stage (alpha). Monitor for maturity; StatefulSet is proven. |
| Node.js 24 LTS | Node.js 22 LTS | If the native Claude Code installer is used (no Node.js needed). If npm path is required, Node.js 22 is in Maintenance LTS until Apr 2027 and still valid. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `ubuntu:latest` tag | Non-deterministic. Points to different versions over time. Breaks reproducible builds. | `ubuntu:24.04` with explicit tag. |
| Alpine base image | musl libc causes subtle incompatibilities with Go static binaries, glibc-linked tools (tcpdump, strace), and some npm native modules. Debugging these issues wastes more time than the ~60MB size savings. | `ubuntu:24.04` |
| npm install for Claude Code | Officially deprecated by Anthropic. Known bugs with missing entry points. Requires Node.js as an additional dependency. | Native installer: `curl -fsSL https://claude.ai/install.sh \| bash` |
| Kubernetes Deployment (for the agent) | Deployments lack stable pod identity and persistent storage semantics. If the Claude Code agent needs to maintain state (session history, tool configs), a Deployment will lose that on reschedule. | StatefulSet with volumeClaimTemplate for persistent agent state. |
| Docker Compose v1 (`docker-compose`) | Deprecated since Jul 2023. No longer receives updates. Python-based and slower. | Docker Compose v5 (`docker compose` CLI plugin). |
| Promtail (log shipping) | Deprecated by Grafana. LTS ends Feb 28, 2026 (this week). No further updates after EOL. | Grafana Alloy (successor built on OpenTelemetry Collector). Only relevant if the project adds log shipping; `logcli` for querying is unaffected. |
| Installing tools via `apt-get` when static binaries exist | Ubuntu repos carry older versions, sometimes 1-2 major versions behind. Each `apt-get install` pulls transitive dependencies that bloat the image. | Download specific version static binaries from GitHub releases for: kubectl, helm, k9s, stern, kubectx, kustomize, crictl, jq, yq, bat, fd, ripgrep, promtool, logcli, grpcurl, skopeo. |
| Running as root in container | Security risk. Kubernetes PSPs/PSAs may block it. Not needed for any of the debugging tools. | Create a non-root user (`useradd -m claude`). Grant capabilities selectively via K8s SecurityContext (`NET_RAW` for tcpdump, `SYS_PTRACE` for strace). |
| `dumb-init` | Unmaintained (last release 2018). tini is actively maintained and more widely adopted. | `tini` (0.19.0) or Docker's built-in `--init` flag. |
| `cgroup v1` with K8s 1.35+ | Kubernetes 1.35 dropped cgroup v1 support. KIND node images at 1.35+ also lack cgroup v1. | Ensure host runs cgroup v2 (default on Ubuntu 24.04 and modern kernels). |

## Stack Patterns by Variant

**If deploying to Kubernetes (production):**
- Use StatefulSet with 1 replica per agent instance
- Mount ServiceAccount token for in-cluster kubectl access
- Apply RBAC with least-privilege (read-only on namespaced resources by default)
- Define NetworkPolicy to restrict egress to Kubernetes API server + Anthropic API endpoints only
- Use PersistentVolumeClaim for Claude Code session state and tool configs
- Set `DISABLE_AUTOUPDATER=1` -- pin version in image, update via image rebuild

**If deploying via Docker Compose (local/dev):**
- Mount Docker socket (`/var/run/docker.sock`) for Docker CLI access from inside container
- Use named volumes for persistent state
- Define shared network for multi-container debugging scenarios
- Set resource limits (`mem_limit`, `cpus`) to prevent runaway usage
- Use HEALTHCHECK with `claude --version` or a custom liveness probe

**If using KIND for local testing:**
- Create cluster with 1 control-plane + 2 worker nodes for realistic testing
- Use `@sha256` digests for node images (required by KIND docs for reproducibility)
- Load the built Docker image into KIND with `kind load docker-image`
- Apply the same StatefulSet/RBAC manifests used in production
- Use `extraMounts` in KIND config to persist data across cluster recreations

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| kubectl 1.35.x | K8s clusters 1.34-1.36 | kubectl supports +/- 1 minor version skew with cluster |
| Helm 4.1.x | K8s 1.30+ | Helm 4 dropped support for older K8s versions. Verify minimum with `helm version` |
| kustomize 5.8.1 | Helm 4.x | v5.8.1 specifically adds Helm 4 compatibility fixes |
| KIND 0.31.0 | K8s 1.31-1.35 node images | Pre-built images available for these versions. K8s 1.35 is the default. |
| crictl 1.35.0 | K8s 1.35.x | Follows Kubernetes release cycle. Match to cluster version. |
| Claude Code CLI | Anthropic API (current) | Requires active Pro/Max/Teams/Enterprise subscription. API keys alone are not sufficient for Remote Control feature. |
| Docker Compose v5 | Docker Engine 29.x | Compose v5 is a CLI plugin bundled with Docker Desktop and Engine 29. |

## Installation

The Dockerfile should use multi-stage builds. Here is the high-level structure:

```bash
# Stage 1: Download and verify all static binaries
FROM ubuntu:24.04 AS downloader
RUN apt-get update && apt-get install -y curl ca-certificates

# Download each tool as a separate layer for cache efficiency
# kubectl
RUN curl -fsSL "https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL "https://get.helm.sh/helm-v4.1.1-linux-amd64.tar.gz" | tar xz \
    && mv linux-amd64/helm /usr/local/bin/helm

# ... (repeat for each tool)

# Stage 2: Runtime image
FROM ubuntu:24.04 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    curl \
    dnsutils \
    nmap \
    tcpdump \
    netcat-openbsd \
    mtr-tiny \
    openssl \
    htop \
    strace \
    lsof \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy static binaries from downloader
COPY --from=downloader /usr/local/bin/ /usr/local/bin/

# Install Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash -s <PINNED_VERSION>

# Create non-root user
RUN useradd -m -s /bin/bash claude
USER claude

ENTRYPOINT ["tini", "--"]
CMD ["claude"]
```

## Image Size Budget (Target: Under 2GB Compressed)

| Component | Estimated Size | Notes |
|-----------|---------------|-------|
| Ubuntu 24.04 base | ~78 MB | Minimal userland |
| apt packages (networking + debug) | ~120 MB | curl, dnsutils, nmap, tcpdump, mtr, openssl, htop, strace, lsof, git |
| Claude Code CLI (native) | ~200-400 MB | Includes bundled runtime (estimate -- verify after build) |
| kubectl + helm + kustomize | ~180 MB | Static Go binaries |
| k9s + stern + kubectx + crictl | ~120 MB | Static Go binaries |
| jq + yq + bat + fd + ripgrep | ~40 MB | Rust/Go static binaries |
| promtool + logcli + grpcurl | ~100 MB | Static Go binaries |
| skopeo + Docker CLI | ~100 MB | |
| **Total estimated** | **~940-1140 MB uncompressed** | Docker compression typically achieves 40-60% ratio |
| **Compressed estimate** | **~560-680 MB** | Well under 2GB target |

## Sources

- [Claude Code Setup Docs](https://code.claude.com/docs/en/setup) -- verified installation methods, npm deprecation, native installer (HIGH confidence)
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless) -- verified `-p` flag and JSON output formats (HIGH confidence)
- [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control) -- verified requirements and session architecture (HIGH confidence)
- [KIND GitHub Releases](https://github.com/kubernetes-sigs/kind/releases) -- verified v0.31.0 with K8s 1.35.0 default (HIGH confidence)
- [Helm 4 Release](https://helm.sh/blog/helm-4-released/) -- verified v4.0.0 released Nov 2025 (HIGH confidence)
- [Kubernetes Releases](https://kubernetes.io/releases/) -- verified K8s 1.35 as current stable (HIGH confidence)
- [Docker Engine Release Notes](https://docs.docker.com/engine/release-notes/29/) -- verified Engine 29 as current (HIGH confidence)
- [Node.js Releases](https://nodejs.org/en/about/previous-releases) -- verified Node.js 24 LTS, 22 Maintenance (HIGH confidence)
- [kustomize Releases](https://github.com/kubernetes-sigs/kustomize/releases) -- verified v5.8.1 (HIGH confidence)
- [k9s Releases](https://github.com/derailed/k9s/releases) -- verified v0.50.18 (HIGH confidence)
- [stern Releases](https://github.com/stern/stern/releases) -- verified v1.33.1 (HIGH confidence)
- [kubectx Releases](https://github.com/ahmetb/kubectx/releases) -- verified v0.9.5 (HIGH confidence)
- [grpcurl Releases](https://github.com/fullstorydev/grpcurl/releases) -- verified v1.9.3 (HIGH confidence)
- [bat Releases](https://github.com/sharkdp/bat/releases) -- verified v0.26.1 (HIGH confidence)
- [fd Releases](https://github.com/sharkdp/fd/releases) -- verified v10.3.0 (HIGH confidence)
- [ripgrep Releases](https://github.com/BurntSushi/ripgrep/releases) -- verified v15.1.0 (HIGH confidence)
- [jq Releases](https://github.com/jqlang/jq/releases) -- verified v1.8.1 (HIGH confidence)
- [yq Releases](https://github.com/mikefarah/yq/releases) -- verified v4.52.4 (HIGH confidence)
- [skopeo Releases](https://github.com/containers/skopeo/releases) -- verified v1.22.0 (MEDIUM confidence -- Feb 2025 release, may have newer)
- [Prometheus Downloads](https://prometheus.io/download/) -- verified promtool via Prometheus 3.9.1 (HIGH confidence)
- [Grafana Loki Releases](https://github.com/grafana/loki/releases) -- verified logcli 3.6.7 (HIGH confidence)
- [cri-tools Releases](https://github.com/kubernetes-sigs/cri-tools/releases) -- verified crictl v1.35.0 (HIGH confidence)
- [Docker Compose Releases](https://github.com/docker/compose/releases) -- verified v5.1.0 (HIGH confidence)
- [Docker BuildKit Docs](https://docs.docker.com/build/buildkit/) -- verified cache mount support (HIGH confidence)
- [tini GitHub](https://github.com/krallin/tini) -- verified v0.19.0, PID 1 signal handling (HIGH confidence)
- [Agent Sandbox](https://github.com/kubernetes-sigs/agent-sandbox) -- verified existence, alpha status (MEDIUM confidence)
- [Promtail Deprecation](https://docs-bigbang.dso.mil/latest/docs/adrs/0004-alloy-replacing-promtail/) -- Grafana Alloy replacement (HIGH confidence)

---
*Stack research for: Claude In A Box -- Containerized AI Agent Deployment*
*Researched: 2026-02-25*
