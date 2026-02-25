# Pitfalls Research

**Domain:** Containerized AI Agent Deployment with DevOps Debugging Toolkit
**Researched:** 2026-02-25
**Confidence:** HIGH (verified across official docs, GitHub issues, and multiple community sources)

## Critical Pitfalls

### Pitfall 1: KIND Image Loading Silently Uses Stale Images

**What goes wrong:**
After rebuilding the Docker image, deploying to KIND still runs the old image. The pod starts successfully, shows no errors, but the new code or tools are not present. Developers waste hours debugging application logic when the problem is infrastructure. This is compounded by two interacting behaviors: (1) KIND's containerd has its own image store separate from Docker's, so `docker build` alone does not update what KIND sees, and (2) Kubernetes default pull policy for `:latest` is `Always`, which attempts a registry pull that fails silently or pulls nothing when no registry exists.

**Why it happens:**
KIND nodes run containerd internally, which maintains a completely separate image store from the Docker daemon. Building an image with `docker build` only updates Docker's store. Without an explicit `kind load docker-image <image> --name <cluster>`, the KIND nodes never see the new image. Additionally, if the cluster name is not specified in `kind load` and the cluster is not named "kind" (the default), the load silently targets the wrong cluster.

**How to avoid:**
- Never use `:latest` tags. Use content-addressable tags (git SHA, build number, or timestamp).
- Always run `kind load docker-image <image>:<tag> --name <cluster-name>` after every `docker build`.
- Set `imagePullPolicy: Never` or `imagePullPolicy: IfNotPresent` in all pod specs for locally-loaded images.
- Wrap the build-load-deploy cycle in a single Makefile target so steps cannot be skipped.
- Add a verification step: `docker exec <kind-node> crictl images | grep <image>` to confirm the image exists in containerd.

**Warning signs:**
- Pod is running but tool versions or behavior do not match latest code.
- `kubectl describe pod` shows image pull errors or "image not found" when using `Always` pull policy.
- Pod logs show old behavior after a rebuild.
- `kind load` command completes instantly (suspiciously fast for a large image) -- may indicate wrong cluster target.

**Phase to address:**
Phase 1 (Foundation) -- The Makefile and build scripts must enforce the build-load-deploy chain from day one. This is the single most common KIND frustration.

---

### Pitfall 2: OAuth Authentication Does Not Persist Across Container Restarts

**What goes wrong:**
User authenticates via `claude /login` inside the container. Credentials are saved to `~/.claude/.credentials.json`. Container restarts, and Claude Code prompts for authentication again as if no credentials exist -- despite the file being present on the mounted volume with valid tokens that have not expired. This is a known, recurring issue (anthropics/claude-code#22066, #1736, #10039).

**Why it happens:**
Multiple interacting causes: (1) Claude Code may look for credentials at a path that differs between container runs due to HOME directory, hostname, or UID changes. (2) The credentials file format or location changed across Claude Code versions, and old files are silently ignored. (3) On some platforms, Claude on Mac deletes the `.credentials.json` that Claude on Linux uses, creating cross-platform conflicts in shared volumes. (4) OAuth access tokens are short-lived, and the refresh token flow has known issues in headless/container environments where the refresh fails silently instead of re-authenticating.

**How to avoid:**
- Use `claude setup-token` on the host machine to generate a long-lived OAuth token (valid ~1 year), then pass it as `CLAUDE_CODE_OAUTH_TOKEN` environment variable. This bypasses the interactive flow entirely.
- If using interactive login, ensure: fixed `--hostname` on the container, consistent UID/GID mapping, and the volume mount targets the exact path Claude Code expects (`~/.claude/`).
- Build the entrypoint to check for the `CLAUDE_CODE_OAUTH_TOKEN` env var first, fall back to credential file, and log clearly which auth method is active.
- Pin the Claude Code version in the Dockerfile to avoid credential format changes across upgrades.

**Warning signs:**
- Container starts, but Claude Code immediately asks for login.
- Credential file exists on volume but has 0 bytes (incomplete auth flow).
- Auth works on first run but fails after `docker stop && docker start`.
- Different behavior between `docker run` (new container) and `docker exec` (existing container).

**Phase to address:**
Phase 1 (Foundation) -- Authentication is gating for every other feature. The entrypoint script must handle auth robustly before Remote Control or any other capability works.

---

### Pitfall 3: Entrypoint Shell Script Swallows SIGTERM (PID 1 Problem)

**What goes wrong:**
Kubernetes sends SIGTERM to gracefully shut down the pod (during rolling updates, scale-down, or node drain). The shell script entrypoint is PID 1. Shells running as PID 1 do not have default signal handlers and do not forward signals to child processes. Claude Code never receives SIGTERM, never performs cleanup, and after the grace period (default 30 seconds), Kubernetes sends SIGKILL. This causes: orphaned Remote Control sessions, unsaved session state, corrupted credential files if mid-write, and potential data loss in any in-progress operation.

**Why it happens:**
PID 1 in Linux has special behavior -- it does not receive default signal handlers. When a bash script is the entrypoint, bash becomes PID 1 and starts Claude Code as a child process with a different PID. Bash ignores SIGTERM by default. Even with `trap` handlers in the script, common patterns like `sleep infinity` or `wait` prevent the trap from executing.

**How to avoid:**
- Use `exec` in the entrypoint script to replace the shell with the Claude Code process: `exec claude code --remote-control`. This makes Claude Code PID 1 and lets it handle signals directly.
- If the entrypoint must do setup work before exec (env var processing, auth checks, mode selection), do all setup first, then `exec` as the final command.
- If exec is not possible (multiple processes, complex orchestration), use `tini` or `dumb-init` as the actual entrypoint. These lightweight init processes properly forward signals and reap zombie processes.
- Set `terminationGracePeriodSeconds` in the pod spec to a value longer than Claude Code needs for cleanup (recommend 60s for Remote Control session teardown).
- Test signal handling explicitly: `docker kill --signal SIGTERM <container>` and verify graceful shutdown in logs.

**Warning signs:**
- Container takes exactly 30 seconds to stop (hitting the default grace period, then SIGKILL).
- "Terminated" in pod events without corresponding cleanup in application logs.
- Remote Control sessions show as "disconnected" rather than "ended" after pod restarts.
- Zombie processes inside the container (visible with `ps aux` showing defunct processes).

**Phase to address:**
Phase 1 (Foundation) -- The entrypoint script structure must be correct from the start. Retrofitting signal handling into a complex entrypoint is error-prone.

---

### Pitfall 4: OAuth Token Expiration Kills Long-Running Autonomous Sessions

**What goes wrong:**
Claude Code is running autonomously via Remote Control, mid-way through a debugging session or multi-step operation. The OAuth access token expires. Instead of transparently refreshing, Claude Code throws a `401 authentication_error` and halts. The session is lost, any in-progress work is left in an incomplete state (partial commits, uncommitted changes, mid-process branches). There is no warning before expiration and no graceful degradation.

**Why it happens:**
OAuth access tokens are intentionally short-lived for security. The refresh token mechanism in Claude Code has known issues in headless/container environments (anthropics/claude-code#12447, #21765). When the refresh fails, the error is destructive rather than graceful -- it does not pause the session or save state, it simply crashes.

**How to avoid:**
- Use `claude setup-token` to generate long-lived tokens (reportedly valid ~1 year) instead of relying on the interactive OAuth flow with short-lived access tokens.
- Build a health check that monitors token expiration time. If Claude Code exposes expiry via `/status` or the credentials file, the health check can alert before expiration.
- Configure Kubernetes liveness and readiness probes to detect auth failure states and restart the pod (which triggers re-auth via the entrypoint).
- Document the token lifetime clearly so operators know when to rotate.
- Consider a sidecar or CronJob that periodically validates the token and alerts if expiry is approaching.

**Warning signs:**
- Sessions that have been running for hours suddenly disconnect.
- `401 authentication_error` in Claude Code logs.
- Remote Control shows "session ended" without operator action.
- Inconsistent session lifetimes (sometimes works for days, sometimes fails after hours).

**Phase to address:**
Phase 1 (Foundation) for token setup, Phase 2 (Hardening) for monitoring and health checks around token lifetime.

---

### Pitfall 5: RBAC Too Broad in Development, Too Narrow in Production

**What goes wrong:**
During development, the ClusterRole gets `*` wildcards on apiGroups, resources, and verbs to "get things working." This creates a massive security hole -- a compromised pod can read secrets, modify RBAC, escalate privileges, and take over the cluster. When the team later tries to tighten permissions, they cannot determine what permissions are actually needed because the application has only ever run with full access. Conversely, if RBAC is too restrictive, Claude Code cannot perform its debugging functions and fails with opaque "Forbidden" errors that are hard to diagnose.

**Why it happens:**
RBAC is painful to iterate on. Each missing permission produces a separate "Forbidden" error, requiring a cycle of: attempt operation, get error, find missing permission, update role, re-apply, retry. Developers short-circuit this by granting full access. The opposite problem (too narrow) happens when roles are copied from examples without understanding all the resources Claude Code needs (CRDs, custom resources, events, logs sub-resource).

**How to avoid:**
- Define two explicit ClusterRole tiers from the start:
  - **read-only** (default): get/list/watch on pods, deployments, services, configmaps, events, nodes, namespaces, ingresses, logs (pods/log sub-resource). No secrets.
  - **operator** (opt-in): adds patch/update on deployments (rollout restart), delete on pods (pod restart), create on pods/exec (exec into pods). Still no secrets, no RBAC modification.
- Never use `*` wildcards in any ClusterRole. Enumerate every resource and verb explicitly.
- Test RBAC with `kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource>` before deploying.
- Use a dedicated ServiceAccount (not the default namespace ServiceAccount) so RBAC is isolated to Claude's pod only.
- Include `pods/log` as an explicit resource -- it is a sub-resource of pods and `get pods` does not grant log access.

**Warning signs:**
- ClusterRole YAML contains `"*"` in any field.
- `kubectl auth can-i create secrets` returns "yes" for Claude's ServiceAccount.
- RBAC manifests reference the `default` ServiceAccount.
- Debugging Claude cannot view logs despite having "pods" access (missing `pods/log` sub-resource).

**Phase to address:**
Phase 1 (Foundation) -- Define both tiers correctly from the start. Phase 2 (Hardening) -- Audit with `kubectl auth can-i` across all required operations.

---

### Pitfall 6: NetworkPolicy Blocks DNS and Kills All Connectivity

**What goes wrong:**
A NetworkPolicy is applied to restrict Claude Code's egress (as a security measure to prevent arbitrary outbound connections). All pod connectivity immediately breaks -- not just the restricted destinations, but everything. Service discovery fails, Kubernetes API calls fail, even health checks fail. The pod enters CrashLoopBackOff. This is the single most common NetworkPolicy mistake.

**Why it happens:**
Developers think in terms of "allow HTTPS to Anthropic API" but forget that every connection starts with a DNS lookup. DNS uses UDP port 53 (and sometimes TCP 53) to the kube-dns service in the kube-system namespace. Without an explicit egress rule allowing DNS, the default-deny blocks it, and without DNS nothing can resolve -- including the Anthropic API hostname, the Kubernetes API server hostname, and internal service names.

**How to avoid:**
- Every NetworkPolicy with egress restrictions MUST include a DNS allow rule:
  ```yaml
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  ```
- Test NetworkPolicy in KIND before production. KIND supports NetworkPolicy with the default kindnet CNI.
- After applying any NetworkPolicy, immediately verify DNS: `kubectl exec <pod> -- nslookup kubernetes.default`.
- Allow egress to the Kubernetes API server explicitly (for kubectl/RBAC operations within the pod).
- Allow HTTPS (port 443) egress for Anthropic API, Remote Control relay, and OAuth endpoints.

**Warning signs:**
- All network operations fail simultaneously after applying NetworkPolicy.
- `nslookup` or `dig` commands timeout inside the pod.
- Pod enters CrashLoopBackOff shortly after NetworkPolicy is applied.
- `kubectl logs` shows connection timeouts to hostnames (not IPs).

**Phase to address:**
Phase 1 (Foundation) for the basic NetworkPolicy with DNS allowance. Phase 2 (Hardening) for fine-tuning egress rules to specific destinations.

---

### Pitfall 7: Docker Image Layer Bloat from apt-get Without Same-Layer Cleanup

**What goes wrong:**
The image reaches 3-4 GB instead of the target 2 GB. CI/CD pulls take 5+ minutes. KIND `kind load` takes over a minute per node. Development iteration slows to a crawl because every rebuild transfers a massive image.

**Why it happens:**
With 30+ tools to install, developers naturally write separate `RUN apt-get install` commands for organization. Each `RUN` creates a new layer. Cleanup commands (`apt-get clean`, `rm -rf /var/lib/apt/lists/*`) in a separate `RUN` do not reduce image size because the files still exist in previous layers. Package managers also install "recommended" packages by default, adding hundreds of MB of unnecessary dependencies. Additionally, build tools (compilers, headers, make) needed to build some tools from source are left in the final image.

**How to avoid:**
- Combine all `apt-get install` commands into a single `RUN` with cleanup in the same command:
  ```dockerfile
  RUN apt-get update && \
      apt-get install -y --no-install-recommends \
        tool1 tool2 tool3 && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*
  ```
- Always use `--no-install-recommends` to avoid pulling in unnecessary packages.
- Use multi-stage builds: compile tools from source in a builder stage, copy only binaries to the final stage.
- Group tool installations by change frequency: base OS packages (rarely change) in early layers, tool installations (sometimes change) in middle layers, configuration files (frequently change) in late layers.
- Use BuildKit cache mounts (`--mount=type=cache,target=/var/cache/apt`) to cache apt packages across builds without bloating layers.
- Measure image size after every Dockerfile change with `docker images` and investigate any increase over 100 MB.
- Use `dive` (wagoodman/dive) to inspect layer sizes and identify bloat.

**Warning signs:**
- Image size exceeds 2 GB compressed.
- Multiple `RUN apt-get` commands in the Dockerfile without cleanup in the same layer.
- `docker history <image>` shows layers over 500 MB.
- Build cache grows unboundedly.

**Phase to address:**
Phase 1 (Foundation) -- Dockerfile structure must be correct from the first build. Restructuring layers later requires rebuilding everything.

---

### Pitfall 8: Non-Root User Cannot Run Networking Debugging Tools

**What goes wrong:**
The container runs as a non-root user (UID 1000) for security. Tools like `tcpdump`, `ping`, `traceroute`, `ss`, and `nmap` fail with "Operation not permitted" because they require raw socket access (NET_RAW capability) or network admin privileges (NET_ADMIN capability). The debugging toolkit -- the core value proposition of the product -- is partially non-functional.

**Why it happens:**
By default, Kubernetes drops all Linux capabilities from containers. Tools that manipulate or capture raw network packets need `NET_RAW` (for packet capture) and/or `NET_ADMIN` (for network interface configuration). Running as non-root without adding these capabilities back makes network debugging tools useless. However, adding capabilities broadly undermines the security benefits of non-root execution.

**How to avoid:**
- Audit every tool in the toolkit for capability requirements before deciding the security posture:
  - **No capabilities needed:** kubectl, curl, wget, jq, yq, dig, nslookup, helm, k9s, stern, kubectx, kubens
  - **NET_RAW needed:** tcpdump, ping, traceroute, nmap, mtr
  - **NET_ADMIN needed:** iptables, ip route manipulation, tc (traffic control)
  - **SYS_PTRACE needed:** strace, gdb
- Implement a two-tier security model in Kubernetes manifests:
  - Default pod spec: no added capabilities, majority of tools work fine.
  - Operator/advanced pod spec: adds `NET_RAW` via `securityContext.capabilities.add: ["NET_RAW"]` for network debugging tools.
- Document clearly which tools require elevated capabilities and how to enable them.
- For tools like `tcpdump`, recommend using `kubectl debug` with an ephemeral container from `nicolaka/netshoot` as an alternative to adding capabilities to the main pod.
- Set file capabilities where possible: `setcap cap_net_raw+ep /usr/bin/tcpdump` in the Dockerfile so the binary gets the capability without the entire container needing it.

**Warning signs:**
- "Operation not permitted" errors when running network tools.
- Tool verification scripts pass for half the toolkit and fail for the other half.
- Security team rejects the deployment because it requests `NET_ADMIN` when only `NET_RAW` is needed.

**Phase to address:**
Phase 1 (Foundation) for the capability audit and two-tier model. Phase 2 (Hardening) for per-binary capabilities and ephemeral container alternatives.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `*` wildcards in RBAC | Fast unblocking during development | Security vulnerability, impossible to audit actual permissions needed | Never -- enumerate permissions from day one |
| Single `RUN` with all 30+ tools | Simple Dockerfile | Any single tool version change invalidates the entire cache, rebuilding everything | Only for final optimization pass. During development, group by change frequency |
| Hardcoding Claude Code version as `latest` | Always get newest features | Reproducibility breaks, credential format changes, API changes between versions | Never -- always pin exact version |
| Skipping `kind load` via local registry | Faster iteration loop | Registry management complexity, port conflicts, different behavior than CI/CD | Acceptable after Phase 1 when the basic flow is proven |
| Running as root for "simplicity" | All tools work immediately | Fails security review, violates pod security standards, creates habit of ignoring security | Never for the main image. Acceptable in a separate "privileged debug" variant |
| Storing OAuth token in Kubernetes Secret without encryption | Easy credential access | Token visible in etcd, to anyone with Secret read access, in kubectl describe output | Only in development KIND clusters. Production requires sealed secrets or external secret store |

## Integration Gotchas

Common mistakes when connecting to external services and cluster components.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Anthropic API (Remote Control) | Assuming outbound HTTPS on port 443 is sufficient without DNS resolution | Allow both DNS egress (UDP/TCP 53 to kube-dns) AND HTTPS egress (TCP 443) in NetworkPolicy |
| Kubernetes API Server | Using the cluster DNS name `kubernetes.default.svc` without allowing DNS | Either allow DNS + use DNS name, or use the `KUBERNETES_SERVICE_HOST` env var which provides the IP directly |
| KIND image loading | Running `kind load docker-image myimage` without `--name` flag | Always specify `--name <cluster-name>` matching your kind cluster config |
| OAuth flow | Attempting browser-based OAuth inside a headless container | Use `claude setup-token` on host, pass token as `CLAUDE_CODE_OAUTH_TOKEN` env var |
| PVC for token persistence | Mounting volume at `/root/.claude` when container runs as non-root user (UID 1000) | Mount at the actual home directory of the non-root user, e.g., `/home/claude/.claude` |
| Docker socket mount (Compose) | Mounting `/var/run/docker.sock` without considering group permissions | Ensure the container user is in the `docker` group, or use rootless Docker socket |
| containerd 2.x (KIND nodes) | Using KIND v0.26.x or older with newer Docker/containerd versions | Update to KIND v0.27.0+ which supports containerd 2.x transfer API |

## Performance Traps

Patterns that work at small scale but fail as usage grows or as the development workflow iterates.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Rebuilding entire image on every code change | 5-10 minute rebuild cycles | Layer ordering: OS packages first, tool installs second, config files last. Use BuildKit cache mounts | Immediately -- first development iteration |
| Loading image to all KIND nodes every rebuild | `kind load` takes 60-90s for a 2GB image across 3 nodes | Use `kind load --nodes <specific-node>` when only one node runs the StatefulSet, or use a local registry | At 3+ nodes with images over 1 GB |
| Not using BuildKit | Sequential layer builds, no parallel execution | Set `DOCKER_BUILDKIT=1` or use `docker buildx build`. BuildKit parallelizes independent stages | Immediately on complex multi-stage builds |
| PVC on slow storage class in KIND | Token persistence, session state writes are sluggish | KIND defaults to hostpath provisioner which is fast. In production, specify storage class explicitly | Only in production, not KIND |
| Running `apt-get update` in every layer group | Network calls on every build, flaky builds when mirrors are slow | Use BuildKit cache mount for `/var/lib/apt/lists`, or run update once at the top of a combined RUN | When building frequently or on slow networks |

## Security Mistakes

Domain-specific security issues beyond general container security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Baking OAuth tokens into the Docker image | Token visible to anyone with image pull access, in `docker history`, in layer inspection | Use environment variables or mounted secrets. Never `COPY` or `ENV` credentials in Dockerfile |
| Granting `secrets` read access in RBAC | Claude Code agent can read all secrets in the cluster, including TLS certs, database passwords, API keys | Explicitly exclude `secrets` from the ClusterRole. If secret access is needed, scope to specific namespaces with a Role (not ClusterRole) |
| Using `default` ServiceAccount | All pods in the namespace share the same identity and RBAC permissions | Create a dedicated `claude-agent` ServiceAccount and bind roles only to it |
| Adding `SYS_ADMIN` capability for strace | SYS_ADMIN is almost equivalent to root -- allows mount, unmount, namespace manipulation | Use `SYS_PTRACE` specifically for strace/gdb. Use `NET_RAW` specifically for tcpdump. Never use SYS_ADMIN |
| Not restricting egress in NetworkPolicy | Compromised agent can exfiltrate data to any external endpoint | Allowlist specific egress: Anthropic API domains, Kubernetes API, DNS. Deny everything else |
| OAuth token in plain Kubernetes Secret | Readable in etcd, in `kubectl describe secret`, by anyone with Secret RBAC | In production: use sealed-secrets, external-secrets-operator, or vault-injector. In KIND dev: acceptable risk |

## UX Pitfalls

Common user experience mistakes specific to containerized CLI tool deployments.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Auth failure shows raw 401 JSON error | User has no idea what to do. Searches GitHub issues | Entrypoint detects auth failure, prints clear message: "Authentication expired. Re-run with CLAUDE_CODE_OAUTH_TOKEN or exec into container and run claude /login" |
| `kind load` step not in Makefile | Developer rebuilds image, deploys, and wonders why old version is running | Single `make deploy` target that chains: build, tag, load, apply, wait-for-ready |
| No startup readiness indicator | User deploys, waits, has no idea if Claude Code is connected to Remote Control | Log a clear "Remote Control session active -- connect at claude.ai/code" message on successful connection |
| Tool verification runs at build time only | Image ships with tools that fail at runtime (missing shared libs, wrong permissions) | Include a `make verify-tools` target that runs inside the deployed container and checks every tool works |
| Opaque RBAC failures | Claude Code says "Permission denied" with no indication of which permission is missing | Wrap kubectl operations with error handling that parses the Forbidden response and suggests the specific RBAC verb/resource needed |
| Container logs flood with debug output | Difficult to find actual errors in pages of debug logs | Default to structured JSON logging with adjustable log level via environment variable |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Dockerfile builds successfully:** Often missing -- cleanup in same layer, version pins, non-root user actually set, `ENTRYPOINT` uses exec form not shell form
- [ ] **KIND cluster creates:** Often missing -- image loaded after build, imagePullPolicy set to Never/IfNotPresent, cluster name matches in all scripts
- [ ] **RBAC applied:** Often missing -- `pods/log` sub-resource (needed for `kubectl logs`), `events` resource (needed for `kubectl describe`), ServiceAccount actually referenced in pod spec
- [ ] **Claude Code starts:** Often missing -- auth token actually valid (not expired), HOME directory writable, .claude directory mounted with correct ownership
- [ ] **Remote Control connects:** Often missing -- egress NetworkPolicy allows both DNS and HTTPS, no proxy/firewall blocking outbound 443, session ID visible in logs
- [ ] **Tools work:** Often missing -- non-root user lacks capabilities for network tools, binaries exist but depend on shared libraries not in the image, PATH not set correctly for installed binaries
- [ ] **Graceful shutdown works:** Often missing -- `exec` in entrypoint, `terminationGracePeriodSeconds` long enough, trap handlers tested with actual SIGTERM
- [ ] **Persistence works across restarts:** Often missing -- PVC actually bound (not Pending), volume mount path matches app expectations, file ownership matches container UID

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Stale KIND image | LOW | `kind load docker-image <image>:<tag> --name <cluster>`, then `kubectl rollout restart statefulset/<name>` |
| OAuth token expired mid-session | LOW | `kubectl exec -it <pod> -- claude /login` or restart pod with fresh `CLAUDE_CODE_OAUTH_TOKEN` |
| SIGTERM not handled | MEDIUM | Add `tini` as entrypoint in Dockerfile (`ENTRYPOINT ["/usr/bin/tini", "--"]`), rebuild and redeploy |
| RBAC too broad (security audit) | MEDIUM | Audit actual API calls with `kubectl auth can-i --list --as=system:serviceaccount:...`, create minimal role from observed usage |
| NetworkPolicy breaks DNS | LOW | Apply DNS egress rule immediately, rollback NetworkPolicy if DNS rule is unclear |
| Image bloat over 2GB | HIGH | Requires Dockerfile restructuring -- combine layers, add cleanup, use multi-stage. Full rebuild and re-test needed |
| Non-root tools failing | MEDIUM | Add specific capabilities in securityContext, or use setcap on specific binaries, rebuild image |
| PVC data loss | HIGH | If no backup, data is gone. Prevent by: using `Retain` reclaim policy, never deleting PVCs manually, document volume lifecycle |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| KIND stale image loading | Phase 1: Foundation | `make deploy` succeeds with fresh image; `crictl images` on KIND node shows correct tag |
| OAuth persistence failure | Phase 1: Foundation | Container restart retains auth; `CLAUDE_CODE_OAUTH_TOKEN` flow works end-to-end |
| PID 1 signal swallowing | Phase 1: Foundation | `docker kill --signal SIGTERM` triggers graceful shutdown within 5 seconds, visible in logs |
| Token expiration in sessions | Phase 2: Hardening | Health check detects approaching expiry; monitoring alerts before expiration |
| RBAC over-permissioning | Phase 1: Foundation (define), Phase 2: Hardening (audit) | `kubectl auth can-i` returns "no" for secrets, RBAC modification, and destructive operations |
| NetworkPolicy DNS blocking | Phase 1: Foundation | `nslookup kubernetes.default` succeeds from inside the pod after NetworkPolicy is applied |
| Image layer bloat | Phase 1: Foundation | `docker images` shows image under 2 GB compressed; `dive` report shows no wasted space |
| Non-root capability gaps | Phase 1: Foundation (audit), Phase 2: Hardening (per-binary caps) | Tool verification script passes for all tools in the manifest; network tools work with NET_RAW |
| Docker socket security (Compose) | Phase 1: Foundation | Docker Compose deployment works without root; socket permissions documented |
| containerd 2.x compatibility | Phase 1: Foundation | `kind load` succeeds with current Docker and KIND versions; version requirements documented |

## Sources

- [KiND -- How I Wasted a Day Loading Local Docker Images (iximiuz)](https://iximiuz.com/en/posts/kubernetes-kind-load-docker-image/) -- HIGH confidence (direct experience post)
- [KIND Known Issues (official docs)](https://kind.sigs.k8s.io/docs/user/known-issues/) -- HIGH confidence
- [KIND Issue #3795: containerd managed image loading](https://github.com/kubernetes-sigs/kind/issues/3795) -- HIGH confidence
- [KIND Issue #3853: Image loading failure with v0.26.0](https://github.com/kubernetes-sigs/kind/issues/3853) -- HIGH confidence
- [Claude Code Issue #22066: OAuth authentication not persisting in Docker](https://github.com/anthropics/claude-code/issues/22066) -- HIGH confidence
- [Claude Code Issue #12447: OAuth token expiration in autonomous workflows](https://github.com/anthropics/claude-code/issues/12447) -- HIGH confidence
- [Claude Code Issue #21765: OAuth refresh token not used on headless machines](https://github.com/anthropics/claude-code/issues/21765) -- HIGH confidence
- [cabinlab/claude-code-sdk-docker AUTHENTICATION.md](https://github.com/cabinlab/claude-code-sdk-docker/blob/main/docs/AUTHENTICATION.md) -- MEDIUM confidence
- [PID 1 Signal Handling in Docker (Peter Malmgren)](https://petermalmgren.com/signal-handling-docker/) -- HIGH confidence
- [Shutdown Signals with Docker Entry Point Scripts (Ben Cane)](https://bencane.com/shutdown-signals-with-docker-entry-point-scripts-5e560f4e2d45) -- HIGH confidence
- [5 Kubernetes RBAC Mistakes You Must Avoid (Red Hat)](https://www.redhat.com/en/blog/5-kubernetes-rbac-mistakes-you-must-avoid) -- HIGH confidence
- [Privilege Escalation with RBAC Misconfigurations](https://medium.com/@esrakyhn/privilege-escalation-with-kubernetes-rbac-misconfigurations-8add491d99f7) -- MEDIUM confidence
- [DNS Resolution Failure in Kubernetes with Network Policies (Otterize)](https://otterize.com/blog/dns-resolution-failure-in-kubernetes) -- HIGH confidence
- [Kubernetes Network Policy Recipes -- Deny Egress (ahmetb)](https://github.com/ahmetb/kubernetes-network-policy-recipes/blob/master/11-deny-egress-traffic-from-an-application.md) -- HIGH confidence
- [Docker Image Optimization Deep Dive with dive (InfoQ)](https://www.infoq.com/articles/docker-size-dive/) -- MEDIUM confidence
- [nicolaka/netshoot -- Network Troubleshooting Container](https://github.com/nicolaka/netshoot) -- HIGH confidence
- [Kubernetes Issue #118962: NET_RAW not added to ephemeral containers](https://github.com/kubernetes/kubernetes/issues/118962) -- HIGH confidence
- [Claude Code Remote Control Official Docs](https://code.claude.com/docs/en/remote-control) -- HIGH confidence
- [Kubernetes SecurityContext Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) -- HIGH confidence
- [Run Kubernetes Pod as Non-Root User (DevOpsCube)](https://devopscube.com/run-kubernetes-pod-as-non-root-user/) -- MEDIUM confidence

---
*Pitfalls research for: Containerized AI Agent Deployment with DevOps Debugging Toolkit (Claude In A Box)*
*Researched: 2026-02-25*
