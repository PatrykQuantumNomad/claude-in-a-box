---
phase: quick-004
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/readiness.sh
  - scripts/healthcheck.sh
  - scripts/setup-bats.sh
  - scripts/install-calico.sh
  - scripts/verify-tools.sh
  - scripts/entrypoint.sh
  - scripts/generate-claude-md.sh
  - scripts/helm-golden-test.sh
  - docker/Dockerfile
  - helm/claude-in-a-box/Chart.yaml
  - helm/claude-in-a-box/values.yaml
  - helm/claude-in-a-box/values-readonly.yaml
  - helm/claude-in-a-box/values-operator.yaml
  - helm/claude-in-a-box/values-airgapped.yaml
  - helm/claude-in-a-box/templates/_helpers.tpl
  - helm/claude-in-a-box/templates/statefulset.yaml
  - helm/claude-in-a-box/templates/service.yaml
  - helm/claude-in-a-box/templates/serviceaccount.yaml
  - helm/claude-in-a-box/templates/networkpolicy.yaml
  - helm/claude-in-a-box/templates/clusterrole-reader.yaml
  - helm/claude-in-a-box/templates/clusterrolebinding-reader.yaml
  - helm/claude-in-a-box/templates/clusterrole-operator.yaml
  - helm/claude-in-a-box/templates/clusterrolebinding-operator.yaml
  - helm/claude-in-a-box/templates/NOTES.txt
autonomous: true
requirements: []

must_haves:
  truths:
    - "Every shell script has a file-level header explaining its purpose, usage, and non-obvious behavior"
    - "Every Helm template has a comment block explaining what it creates and when it is conditionally rendered"
    - "The Dockerfile has per-stage documentation explaining the build strategy"
    - "values.yaml has section-level comments explaining the security model and architectural decisions behind each group"
  artifacts:
    - path: "scripts/*.sh"
      provides: "Shell scripts with inline documentation"
    - path: "helm/claude-in-a-box/templates/*.yaml"
      provides: "Helm templates with header comments"
    - path: "helm/claude-in-a-box/values.yaml"
      provides: "Values file with section-level docs"
    - path: "docker/Dockerfile"
      provides: "Dockerfile with enhanced stage docs"
  key_links: []
---

<objective>
Add comprehensive inline documentation (comments, headers, usage info) to all shell scripts, Helm chart files, and the Dockerfile.

Purpose: Make the infrastructure code self-documenting so new contributors (or Claude in a future session) can understand what each file does, why key decisions were made, and what non-obvious behavior exists -- without needing to read external docs or git history.

Output: All 24 files updated with inline documentation. No new files created.
</objective>

<execution_context>
@./.claude/get-shit-done/workflows/execute-plan.md
@./.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md

Key context from STATE.md Post-Milestone Activity section:
- CLAUDE_TEST_MODE was added for CI -- readiness.sh and healthcheck.sh return 0 immediately when set
- entrypoint.sh runs `sleep infinity` in test mode instead of starting Claude
- Pod must be force-deleted after `kubectl set env` because StatefulSet OrderedReady policy prevents automatic replacement
- BATS tests use CLAUDE_TEST_MODE=true to bypass auth in test environments
</context>

<tasks>

<task type="auto">
  <name>Task 1: Document shell scripts</name>
  <files>
    scripts/readiness.sh
    scripts/healthcheck.sh
    scripts/setup-bats.sh
    scripts/install-calico.sh
    scripts/verify-tools.sh
    scripts/entrypoint.sh
    scripts/generate-claude-md.sh
    scripts/helm-golden-test.sh
  </files>
  <action>
Add or enhance inline documentation to all 8 shell scripts. The goal is explaining WHY, not just WHAT. Many scripts already have good documentation -- enhance rather than rewrite.

**readiness.sh** (needs most work -- currently 7 lines):
- Add a full header block with: script name, one-line description, how it works (runs `claude auth status` which spawns Node.js), why the probe interval must be 30s+ (3-5s Node.js startup latency per call), CLAUDE_TEST_MODE bypass behavior and why it exists (CI pods have no auth credentials), exit code semantics.
- Add inline comment on the `claude auth status` line explaining it verifies the Claude OAuth/API key is valid.

**healthcheck.sh** (needs most work -- currently 6 lines):
- Add a full header block with: script name, one-line description, how it differs from readiness (liveness = process running, readiness = authenticated and ready), `pgrep -f "claude"` matches any process with "claude" in its command line, CLAUDE_TEST_MODE bypass and why.
- Add inline comment on the pgrep line.

**setup-bats.sh** (minor enhancement):
- Already has a good header. Add a brief note explaining this is for LOCAL development only -- CI installs BATS via the ci.yaml workflow. Add a comment above the .gitignore block explaining why tests/bats/ is gitignored (it's a cloned repo, not project code).

**install-calico.sh** (moderate enhancement):
- Already has usage line. Add explanation of WHY Calico is needed (KIND ships without a CNI that enforces NetworkPolicy -- Calico provides enforcement so our NetworkPolicy templates actually work in integration tests).
- Add inline comments explaining: (1) why we wait for CRDs before applying custom resources, (2) why FELIX_IGNORELOOSERPF=true is needed (KIND nodes use loose reverse path filtering which Calico's Felix dataplane rejects by default), (3) why CoreDNS needs a restart (pods scheduled before CNI was ready may have stale network config).

**verify-tools.sh** (already well-documented -- minimal touch):
- Add a one-line note in the header about when this runs: "Called by Dockerfile build verification and available at runtime via `verify-tools.sh`."

**entrypoint.sh** (already well-documented -- minimal touch):
- Add a brief note in the file header about the 3 supported modes and their use cases (interactive = local dev/attach, remote-control = phone/web access, headless = one-shot scripted tasks).
- Add a comment above the `exec` in each case branch explaining why exec is used (replaces shell so signals from tini reach Claude directly).

**generate-claude-md.sh** (already well-documented -- minimal touch):
- Add a note in the header about idempotent behavior: runs on every container start, overwrites previous CLAUDE.md.

**helm-golden-test.sh** (already well-documented -- minimal touch):
- Add a note explaining what golden file testing IS for readers unfamiliar with the pattern (renders Helm templates and compares against stored "known-good" output to catch unintended changes).

IMPORTANT: Do NOT add a "Last modified" or "Author" line to any script -- git handles that. Do NOT remove existing documentation. Preserve the existing `# ====` section separator style used throughout the codebase.
  </action>
  <verify>
All 8 scripts still pass shellcheck (if installed) or at minimum: `bash -n scripts/entrypoint.sh && bash -n scripts/readiness.sh && bash -n scripts/healthcheck.sh && bash -n scripts/verify-tools.sh && bash -n scripts/setup-bats.sh && bash -n scripts/generate-claude-md.sh && bash -n scripts/helm-golden-test.sh && bash -n scripts/install-calico.sh` -- all exit 0 (valid bash syntax).
  </verify>
  <done>
Every shell script has a descriptive header block explaining purpose, usage, and non-obvious behavior. readiness.sh and healthcheck.sh headers explain probe semantics and CLAUDE_TEST_MODE. install-calico.sh explains WHY each step exists. No script has its behavior altered -- only comments added.
  </done>
</task>

<task type="auto">
  <name>Task 2: Document Helm chart and Dockerfile</name>
  <files>
    docker/Dockerfile
    helm/claude-in-a-box/Chart.yaml
    helm/claude-in-a-box/values.yaml
    helm/claude-in-a-box/values-readonly.yaml
    helm/claude-in-a-box/values-operator.yaml
    helm/claude-in-a-box/values-airgapped.yaml
    helm/claude-in-a-box/templates/_helpers.tpl
    helm/claude-in-a-box/templates/statefulset.yaml
    helm/claude-in-a-box/templates/service.yaml
    helm/claude-in-a-box/templates/serviceaccount.yaml
    helm/claude-in-a-box/templates/networkpolicy.yaml
    helm/claude-in-a-box/templates/clusterrole-reader.yaml
    helm/claude-in-a-box/templates/clusterrolebinding-reader.yaml
    helm/claude-in-a-box/templates/clusterrole-operator.yaml
    helm/claude-in-a-box/templates/clusterrolebinding-operator.yaml
    helm/claude-in-a-box/templates/NOTES.txt
  </files>
  <action>
Add inline documentation to all Helm chart files and enhance Dockerfile comments. Focus on explaining the architectural decisions -- the security model, why StatefulSet instead of Deployment, etc.

**Dockerfile** (moderate enhancement -- already has good stage headers):
- Stage 1 (tools-downloader): Add a comment explaining the multi-arch strategy (TARGETARCH is set by Docker BuildKit, scripts handle amd64/arm64 naming differences per tool vendor).
- Stage 2 (claude-installer): Add a comment explaining why Node.js is installed from binary tarball rather than apt (version pinning, consistent across architectures, apt nodejs is often outdated).
- Stage 3 (runtime): Add comments explaining:
  - Why UID/GID 10000 (above typical system range, matches Kubernetes security best practices for non-root).
  - Why tini is PID 1 (Docker does not init zombie reaping or signal forwarding -- tini handles both).
  - Why skills are staged to /opt/ instead of directly to /app/.claude/ (PVC mount overlays container filesystem at /app/.claude/).
  - The HEALTHCHECK instruction is for standalone Docker usage; Kubernetes uses its own probe definitions from the Helm chart.

**Chart.yaml** (needs documentation):
- Add comments explaining: apiVersion v2 (Helm 3 only), type: application (vs library), version (chart version, not app version), appVersion (tracks the container image tag -- "dev" during development).

**values.yaml** (enhance section-level docs):
- Add a file-level header explaining the 3 security profiles (readonly = default, operator = elevated, airgapped = restricted) and how values overlay files work.
- Before `podSecurityContext:` section: explain this enforces non-root at the pod level (belt-and-suspenders with Dockerfile USER).
- Before `resources:` section: explain these are conservative defaults suitable for a single Claude Code session.
- Before `persistence:` section: explain the PVC stores Claude's credentials, conversation history, and staged skills across pod restarts.
- Before `livenessProbe:` / `readinessProbe:`: explain the difference (liveness = is the process alive, readiness = is auth valid) and why periodSeconds is 30 (Node.js startup latency in the readiness check).
- Before `terminationGracePeriodSeconds:`: explain 60s allows Claude to gracefully save state.

**values-readonly.yaml, values-operator.yaml, values-airgapped.yaml** (minimal -- already have good headers):
- values-airgapped.yaml: Add a comment explaining why k8sApi CIDR is 10.96.0.1/32 (default Kubernetes ClusterIP service CIDR for the API server).

**Helm templates** -- add a YAML comment header to each template file:

- **statefulset.yaml**: Explain why StatefulSet instead of Deployment (stable pod identity for `kubectl attach`, stable PVC binding so credentials persist). Note stdin/tty=true enables interactive terminal attachment. Note the single volumeMount at /app/.claude stores credentials + skills.
- **service.yaml**: Explain this is a headless service (clusterIP: None) required by StatefulSet for stable DNS, the placeholder port exists because Kubernetes requires at least one port definition even for headless services.
- **serviceaccount.yaml**: Explain automountServiceAccountToken must be true so the pod can query the Kubernetes API (used by generate-claude-md.sh and MCP kubernetes server).
- **networkpolicy.yaml**: Explain the default-deny-all approach (ingress: [] blocks all inbound), then selective egress allowlist. Explain each egress rule: DNS for name resolution, HTTPS for Anthropic API calls, K8s API for cluster introspection. Note this requires a CNI that supports NetworkPolicy (e.g., Calico).
- **clusterrole-reader.yaml**: Explain this is the default (reader-tier) RBAC -- read-only access to common Kubernetes resources. Note it's cluster-scoped so Claude can inspect resources across all namespaces.
- **clusterrolebinding-reader.yaml**: Explain this binds the reader ClusterRole to the chart's ServiceAccount. Always created (not conditional).
- **clusterrole-operator.yaml**: Explain this is the elevated (operator-tier) RBAC for debugging -- adds pod delete (for stuck pods), exec (for container inspection), and deployment/statefulset update/patch (for rollout restarts). Only created when operator.enabled=true.
- **clusterrolebinding-operator.yaml**: Same conditional note.
- **_helpers.tpl**: Add a file-level comment explaining this contains reusable template functions. Add a brief note above each `define` explaining its purpose (most already have this -- verify and fill gaps).
- **NOTES.txt**: This is already user-facing text, no changes needed.

IMPORTANT: Use `{{/*  */}}` for Helm template comments (not `#` which would appear in rendered output). For YAML-only files (values.yaml, Chart.yaml), use `#` comments. Preserve existing comment style. Do NOT change any template logic or values -- only add comments.
  </action>
  <verify>
Run `helm template test-release helm/claude-in-a-box` and verify it renders without errors. Run `helm lint helm/claude-in-a-box` and verify no errors (warnings about missing icon are acceptable). Run `docker build --check docker/` or `docker build --no-cache -f docker/Dockerfile . 2>&1 | head -5` to verify Dockerfile syntax is still valid (just syntax check, not full build).
  </verify>
  <done>
Every Helm template has a comment header explaining what it creates, when it is conditionally rendered, and why it exists. values.yaml has section-level documentation explaining the security model. Chart.yaml fields are documented. Dockerfile stages explain multi-arch and security decisions. All templates render identically to before (only comments added, no logic changes).
  </done>
</task>

</tasks>

<verification>
1. `bash -n scripts/*.sh` -- all scripts have valid syntax
2. `helm template test-release helm/claude-in-a-box` -- renders without errors
3. `helm lint helm/claude-in-a-box` -- no errors
4. `git diff --stat` -- only the listed files modified, no new files created
5. Spot-check: readiness.sh and healthcheck.sh have 10+ lines of comments (up from 4-5)
</verification>

<success_criteria>
- All 8 shell scripts have descriptive headers explaining purpose, usage, and non-obvious behavior
- All 10 Helm template files have comment headers explaining their role
- values.yaml has section-level documentation explaining security model and architectural decisions
- Chart.yaml fields are documented
- Dockerfile stages explain multi-arch strategy and security decisions
- Zero behavioral changes -- only comments added
- helm template and helm lint pass without errors
</success_criteria>

<output>
After completion, create `.planning/quick/004-add-documentation-to-shell-scripts-helm-/004-SUMMARY.md`
</output>
