---
phase: quick-005
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - site/src/layouts/DocsLayout.astro
  - site/src/components/ui/DocsNav.astro
  - site/src/components/ui/DiagramBlock.astro
  - site/src/pages/docs/index.astro
  - site/src/pages/docs/helm-chart.astro
  - site/src/pages/docs/dockerfile.astro
  - site/src/pages/docs/kind-deployment.astro
  - site/src/pages/docs/scripts.astro
  - site/src/styles/global.css
autonomous: true
requirements: [QUICK-005]

must_haves:
  truths:
    - "User can navigate to /docs/ and see a documentation index page"
    - "User can read comprehensive Helm chart docs at /docs/helm-chart/ with values table in helm-docs style"
    - "User can read Dockerfile docs at /docs/dockerfile/ with build stage diagram"
    - "User can read KIND deployment docs at /docs/kind-deployment/ with flow diagram"
    - "User can read scripts reference at /docs/scripts/ with purpose and usage for each script"
    - "All doc pages share a sidebar navigation and consistent layout"
    - "Architecture/flow diagrams render as inline SVGs matching the site design system"
  artifacts:
    - path: "site/src/layouts/DocsLayout.astro"
      provides: "Shared docs layout with sidebar navigation"
      min_lines: 40
    - path: "site/src/pages/docs/helm-chart.astro"
      provides: "Helm chart documentation page with values table and RBAC diagram"
      min_lines: 100
    - path: "site/src/pages/docs/dockerfile.astro"
      provides: "Dockerfile documentation with multi-stage build diagram"
      min_lines: 80
    - path: "site/src/pages/docs/kind-deployment.astro"
      provides: "KIND deployment docs with bootstrap flow diagram"
      min_lines: 80
    - path: "site/src/pages/docs/scripts.astro"
      provides: "Scripts reference page"
      min_lines: 60
  key_links:
    - from: "site/src/pages/docs/*.astro"
      to: "site/src/layouts/DocsLayout.astro"
      via: "import and use as layout wrapper"
      pattern: "import DocsLayout"
    - from: "site/src/layouts/DocsLayout.astro"
      to: "site/src/layouts/BaseLayout.astro"
      via: "wraps BaseLayout for SEO/meta inheritance"
      pattern: "import BaseLayout"
---

<objective>
Create comprehensive documentation pages for the Helm chart, Dockerfile, and KIND deployment on the Astro site. Each page includes detailed reference content plus inline SVG diagrams matching the site's deep navy + electric blue design system.

Purpose: Make infrastructure internals discoverable and visually clear for users evaluating or deploying claude-in-a-box.
Output: 9 new/modified files under site/src/ producing 5 new routes under /docs/.
</objective>

<execution_context>
@./.claude/get-shit-done/workflows/execute-plan.md
@./.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@site/src/layouts/BaseLayout.astro
@site/src/styles/global.css
@site/src/components/ui/TerminalBlock.astro
@site/src/components/sections/Architecture.astro
@site/astro.config.mjs
@helm/claude-in-a-box/values.yaml
@helm/claude-in-a-box/Chart.yaml
@helm/claude-in-a-box/templates/statefulset.yaml
@helm/claude-in-a-box/templates/networkpolicy.yaml
@helm/claude-in-a-box/templates/clusterrole-reader.yaml
@helm/claude-in-a-box/templates/clusterrole-operator.yaml
@helm/claude-in-a-box/templates/_helpers.tpl
@helm/claude-in-a-box/values-airgapped.yaml
@helm/claude-in-a-box/values-operator.yaml
@helm/claude-in-a-box/values-readonly.yaml
@docker/Dockerfile
@scripts/entrypoint.sh
@scripts/install-calico.sh
@scripts/healthcheck.sh
@scripts/readiness.sh
@scripts/generate-claude-md.sh
@scripts/verify-tools.sh
@scripts/helm-golden-test.sh
@scripts/setup-bats.sh

<interfaces>
<!-- Existing design system from global.css -->
oklch color tokens:
  bg-primary: oklch(0.13 0.03 260)
  bg-secondary: oklch(0.16 0.03 260)
  bg-tertiary: oklch(0.19 0.03 260)
  text-primary: oklch(0.97 0.005 260)
  text-secondary: oklch(0.75 0.02 260)
  text-muted: oklch(0.55 0.02 260)
  accent: oklch(0.62 0.22 260)
  border: oklch(0.24 0.04 260)
  glass surface: oklch(0.16 0.03 260 / 0.60)
  glass border: oklch(0.28 0.04 260 / 0.60)

SVG diagram styling convention (from Architecture.astro):
  Node fill: oklch(0.16 0.03 260 / 0.70)
  Node stroke: oklch(0.28 0.04 260), 1.5px
  Arrow stroke: oklch(0.70 0.15 250), 2px
  Label (primary): oklch(0.97 0.005 260), 14px, weight 600
  Label (secondary): oklch(0.55 0.02 260), 11px
  Pill fill: oklch(0.14 0.03 260 / 0.60)
  Pill stroke: oklch(0.24 0.04 260), 1px

Arrowhead marker definition:
  <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" style="fill: oklch(0.70 0.15 250)" />
  </marker>

BaseLayout Props interface:
  title: string (required)
  description?: string
  image?: string
  noindex?: boolean

Fonts: Space Grotesk Variable (sans), JetBrains Mono Variable (mono)
CSS classes: glass-card, glass-terminal, gradient-text, section-divider, reveal-section, reveal-card
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create DocsLayout, DocsNav sidebar, and DiagramBlock component</name>
  <files>
    site/src/layouts/DocsLayout.astro
    site/src/components/ui/DocsNav.astro
    site/src/components/ui/DiagramBlock.astro
    site/src/styles/global.css
  </files>
  <action>
Create a DocsLayout.astro that wraps BaseLayout.astro. It should:
- Accept props: title (string), description (string, optional), activeSlug (string -- current page slug for nav highlighting)
- Render a responsive two-column layout: left sidebar (DocsNav) + right content area
- On mobile (< lg), the sidebar collapses into a hamburger/expandable menu at the top
- Content area has max-w-4xl, comfortable reading width with prose-like spacing
- Background matches bg-primary, text matches text-primary/text-secondary

Create DocsNav.astro sidebar component:
- Props: activeSlug (string)
- Lists all doc pages with links:
  - Overview (/docs/)
  - Helm Chart (/docs/helm-chart/)
  - Dockerfile (/docs/dockerfile/)
  - KIND Deployment (/docs/kind-deployment/)
  - Scripts Reference (/docs/scripts/)
- Active page link highlighted with accent color and left border
- Uses glass-card styling for the sidebar container on desktop, simpler style on mobile
- Include a "Back to Home" link at the top that goes to /

Create DiagramBlock.astro component for wrapping SVG diagrams:
- Props: title (string), description (string, optional)
- Renders a glass-card container with the title above and a slot for the SVG content
- Adds overflow-x-auto for mobile horizontal scroll on wide diagrams
- Consistent padding and rounded corners

Add docs-specific CSS utilities to global.css (append, do not modify existing):
- .docs-prose class: sets line-height 1.75, paragraph margin 1.25em, heading margins, code inline styling (bg-bg-tertiary px-1.5 py-0.5 rounded font-mono text-sm), table styling for values tables (glass-terminal background, border-collapse, cell padding), h2/h3 anchor styling
- .docs-table class: full-width table with glass-terminal styling, thead with bg-bg-tertiary, tbody rows with border-bottom border-border, cells with padding and font-mono for value column, responsive horizontal scroll wrapper
- Keep additions clearly separated with a comment block "/* ===== Documentation page styles ===== */"
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro check 2>&1 | tail -20</automated>
  </verify>
  <done>DocsLayout wraps BaseLayout with sidebar + content area. DocsNav renders 5 links with active state. DiagramBlock provides glass-card SVG wrapper. Docs CSS utilities appended to global.css. No type errors.</done>
</task>

<task type="auto">
  <name>Task 2: Create docs index page and Helm chart documentation page</name>
  <files>
    site/src/pages/docs/index.astro
    site/src/pages/docs/helm-chart.astro
  </files>
  <action>
Create site/src/pages/docs/index.astro:
- Uses DocsLayout with title "Documentation | RemoteKube", activeSlug="overview"
- Hero section: "Documentation" heading with gradient-text, subtitle "Infrastructure reference for claude-in-a-box"
- Grid of 4 glass-cards linking to each doc page (Helm Chart, Dockerfile, KIND Deployment, Scripts Reference), each with an emoji icon, title, and 1-sentence description
- Brief intro paragraph explaining the project's infrastructure architecture

Create site/src/pages/docs/helm-chart.astro (the most comprehensive page):
- Uses DocsLayout with title "Helm Chart Reference | RemoteKube", activeSlug="helm-chart"
- Sections (use h2 for each, h3 for subsections):

1. **Overview** -- Chart name, version, appVersion, type. Brief description of what the chart deploys (StatefulSet with Claude Code + SRE tools).

2. **Security Profiles** -- Explain the 3 profiles (readonly default, operator, airgapped) with a comparison table:
   | Feature | Readonly (default) | Operator | Airgapped |
   Columns: RBAC level, NetworkPolicy egress, Registry source, Use case

3. **Values Reference** (helm-docs style) -- Render ALL values from values.yaml as a table:
   | Key | Type | Default | Description |
   Extract every value: replicaCount, image.repository, image.pullPolicy, image.tag, imagePullSecrets, nameOverride, fullnameOverride, serviceAccount.create, serviceAccount.name, serviceAccount.automountServiceAccountToken, claudeMode, operator.enabled, networkPolicy.enabled, networkPolicy.egress.dns.enabled, networkPolicy.egress.https.enabled, networkPolicy.egress.https.cidr, networkPolicy.egress.k8sApi.enabled, networkPolicy.egress.k8sApi.cidr, podSecurityContext.runAsUser, podSecurityContext.runAsGroup, podSecurityContext.fsGroup, podSecurityContext.fsGroupChangePolicy, podSecurityContext.runAsNonRoot, resources.requests.memory, resources.requests.cpu, resources.limits.memory, resources.limits.cpu, persistence.size, persistence.storageClassName, persistence.accessMode, livenessProbe (exec command, initialDelaySeconds, periodSeconds, timeoutSeconds), readinessProbe (exec command, initialDelaySeconds, periodSeconds, timeoutSeconds), terminationGracePeriodSeconds
   Use the `-- comment` annotations from values.yaml as descriptions.

4. **RBAC Architecture** -- Inline SVG diagram showing:
   - ServiceAccount node at center
   - ClusterRoleBinding-reader connecting to ClusterRole-reader (always created)
   - ClusterRoleBinding-operator connecting to ClusterRole-operator (conditional, dashed border when disabled)
   - Reader ClusterRole lists: get, list, watch on pods/services/events/nodes/namespaces/configmaps/pvcs + apps resources + batch resources + ingresses
   - Operator ClusterRole lists: delete pods, create pods/exec, update/patch deployments/statefulsets
   - Use the site's SVG styling convention (oklch colors, 1.5px strokes, arrowhead markers)
   - viewBox 800x350, responsive width

5. **Network Policy** -- Explain default-deny-all + selective egress. Inline SVG diagram showing:
   - Pod node on left
   - 3 egress paths: DNS (UDP/TCP 53), HTTPS (TCP 443, 0.0.0.0/0), K8s API (TCP 6443, 0.0.0.0/0)
   - Ingress blocked (red X or crossed-out indicator)
   - Note about CNI requirement (Calico)

6. **Template Files** -- Brief table listing each template file, its Kubernetes resource kind, and a 1-line description:
   statefulset.yaml, service.yaml, serviceaccount.yaml, networkpolicy.yaml, clusterrole-reader.yaml, clusterrole-operator.yaml, clusterrolebinding-reader.yaml, clusterrolebinding-operator.yaml, _helpers.tpl, NOTES.txt

7. **Installation Examples** -- Use TerminalBlock component for 3 examples:
   - Default (readonly): `helm install claude-agent ./helm/claude-in-a-box`
   - Operator profile: `helm install claude-agent ./helm/claude-in-a-box -f helm/claude-in-a-box/values-operator.yaml`
   - Airgapped profile: `helm install claude-agent ./helm/claude-in-a-box -f helm/claude-in-a-box/values-airgapped.yaml`

Use the docs-prose and docs-table CSS classes for content styling. Wrap SVGs in DiagramBlock component.
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro check 2>&1 | tail -20 && npx astro build 2>&1 | grep -E "(error|Error|pages)" | tail -10</automated>
  </verify>
  <done>Docs index page renders at /docs/ with 4 linked cards. Helm chart page renders at /docs/helm-chart/ with complete values table (30+ values), 2 SVG diagrams (RBAC architecture and NetworkPolicy), security profiles comparison, template files reference, and installation examples. All tables use docs-table styling. Both pages use DocsLayout with working sidebar navigation.</done>
</task>

<task type="auto">
  <name>Task 3: Create Dockerfile documentation page with multi-stage build diagram</name>
  <files>site/src/pages/docs/dockerfile.astro</files>
  <action>
Create site/src/pages/docs/dockerfile.astro:
- Uses DocsLayout with title "Dockerfile Reference | RemoteKube", activeSlug="dockerfile"
- Sections (h2 for each):

1. **Overview** -- Multi-stage Dockerfile producing deployment-ready Ubuntu 24.04 image with Claude Code + 32+ SRE/DevOps tools, running non-root with tini as PID 1.

2. **Build Stages** -- Inline SVG diagram (viewBox 800x400, responsive) showing 3 build stages flowing left-to-right:
   - Stage 1 "tools-downloader": Ubuntu base, downloads 10 static binaries (tini, kubectl, helm, k9s, stern, kubectx, kubens, jq, yq, trivy, grype). Show as a node with mini list of tool names.
   - Stage 2 "claude-installer": Ubuntu base, installs Node.js + Claude Code via npm. Show as node.
   - Stage 3 "runtime": Ubuntu base, COPY --from arrows from Stage 1 and Stage 2 converging into the runtime. Show COPY arrows.
   - Below runtime node, show key attributes: non-root user (UID 10000), tini PID 1, 32+ tools
   Use site SVG conventions. Arrows from Stage 1 and Stage 2 converge to Stage 3.

3. **Version Pins** -- Table of all ARG version pins from the Dockerfile:
   | ARG | Version | Purpose |
   UBUNTU_VERSION (24.04), NODE_VERSION (22.22.0), CLAUDE_CODE_VERSION (2.0.25), TINI_VERSION (0.19.0), KUBECTL_VERSION (1.35.1), HELM_VERSION (4.1.1), K9S_VERSION (0.50.18), STERN_VERSION (1.33.0), KUBECTX_VERSION (0.9.5), JQ_VERSION (1.8.1), YQ_VERSION (4.52.4), TRIVY_VERSION (0.68.2), GRYPE_VERSION (0.109.0)

4. **Installed Tools** -- Organized table by category matching verify-tools.sh structure:
   | Category | Tools |
   Network (9): curl, dig, nmap, tcpdump, wget, netcat, ip/ss, ping
   Process/System (6): htop, strace, ps/top, perf, bpftrace
   Kubernetes (6): kubectl, helm, k9s, stern, kubectx, kubens
   Data/Log (3): jq, yq, less
   Database Clients (3): psql, mysql, redis-cli
   Security (2): trivy, grype
   Standard (8): git, vim, nano, unzip, file, tree, ripgrep, bash
   Claude Code (2): claude, node

5. **Security** -- Non-root execution (UID/GID 10000, why above typical ranges), podSecurityContext alignment, pre-configured Claude settings (bypass permissions, disabled telemetry), tini as PID 1 for signal handling + zombie reaping.

6. **Multi-Architecture Support** -- Explain TARGETARCH handling for amd64/arm64, how each tool download maps TARGETARCH to vendor naming (kubectx uses x86_64, trivy uses 64bit/ARM64, nodejs uses x64).

7. **Build Command** -- TerminalBlock with:
   ```
   docker build -f docker/Dockerfile -t claude-in-a-box:dev .
   ```
   And multi-platform build:
   ```
   docker buildx build --platform linux/amd64,linux/arm64 -f docker/Dockerfile -t claude-in-a-box:dev .
   ```
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro build 2>&1 | grep -E "(error|Error|Generated)" | tail -5</automated>
  </verify>
  <done>Dockerfile page renders at /docs/dockerfile/ with multi-stage build diagram (3-stage SVG with COPY arrows), version pins table (13 ARGs), categorized tools table (39 tools in 8 categories), security section, multi-arch explanation, and build commands.</done>
</task>

<task type="auto">
  <name>Task 4: Create KIND deployment documentation page with bootstrap flow diagram</name>
  <files>site/src/pages/docs/kind-deployment.astro</files>
  <action>
Create site/src/pages/docs/kind-deployment.astro:
- Uses DocsLayout with title "KIND Deployment Guide | RemoteKube", activeSlug="kind-deployment"
- Sections (h2 for each):

1. **Overview** -- KIND (Kubernetes IN Docker) is used for local development and CI integration testing. The project provides a full bootstrap flow: create cluster, install Calico CNI, build image, load into KIND, deploy via Helm.

2. **Bootstrap Flow** -- Inline SVG diagram (viewBox 800x250, responsive) showing the sequential flow:
   - Step 1: "kind create cluster" (create KIND cluster)
   - Step 2: "install-calico.sh" (install Calico CNI for NetworkPolicy enforcement)
   - Step 3: "docker build" (build container image)
   - Step 4: "kind load" (load image into KIND nodes)
   - Step 5: "helm install" (deploy chart)
   Horizontal flow with arrows between steps, each as a rounded rect node.

3. **Calico CNI** -- Why Calico is required (kindnet ignores NetworkPolicy). Explain install-calico.sh:
   - Installs tigera-operator (configurable version via CALICO_VERSION env)
   - Waits for CRDs, applies custom resources
   - Fixes Reverse Path Filtering for KIND nodes (FELIX_IGNORELOOSERPF=true)
   - Restarts CoreDNS to recover from pre-CNI scheduling

4. **Container Startup Flow** -- Inline SVG diagram (viewBox 800x350, responsive) showing the entrypoint.sh logic:
   - Start: "tini (PID 1)" at top
   - Calls "entrypoint.sh"
   - Decision diamond: "CLAUDE_TEST_MODE?" -- Yes: "sleep infinity" (for CI). No: continue.
   - "validate_auth" -- checks OAuth token / API key / credentials file / interactive fallback
   - "Stage skills from /opt/ to PVC"
   - "Generate CLAUDE.md"
   - Decision diamond: "CLAUDE_MODE?" -- 3 branches:
     - interactive: "claude --dangerously-skip-permissions"
     - remote-control: "claude remote-control --verbose"
     - headless: "claude -p $CLAUDE_PROMPT --output-format json"
   Use vertical flow for this diagram. Rounded rects for steps, diamonds for decisions.

5. **Health Probes** -- Explain the two probes:
   - Liveness (healthcheck.sh): `pgrep -f "claude"`. Lightweight. If fails, container restarted.
   - Readiness (readiness.sh): `claude auth status`. Heavier (Node.js startup). If fails, pod removed from endpoints.
   - CLAUDE_TEST_MODE bypass for both.
   - Why periodSeconds=30 (avoid overlapping Node.js processes).

6. **Integration Testing** -- Briefly reference the CI pipeline:
   - BATS test framework (setup-bats.sh for local, apt-get in CI)
   - Test suites: RBAC, networking, tools verification, remote-control
   - CLAUDE_TEST_MODE=true for auth-less testing

7. **Quick Start** -- TerminalBlock with bootstrap commands:
   ```
   git clone https://github.com/PatrykQuantumNomad/claude-in-a-box.git
   cd claude-in-a-box
   make bootstrap
   ```
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro build 2>&1 | grep -E "(error|Error|Generated)" | tail -5</automated>
  </verify>
  <done>KIND deployment page renders at /docs/kind-deployment/ with bootstrap flow diagram (5-step horizontal SVG), container startup flow diagram (vertical decision-tree SVG with 3 mode branches), Calico CNI explanation, health probe details, integration testing reference, and quick start commands.</done>
</task>

<task type="auto">
  <name>Task 5: Create scripts reference page and add docs link to site navigation</name>
  <files>
    site/src/pages/docs/scripts.astro
    site/src/components/sections/Footer.astro
  </files>
  <action>
Create site/src/pages/docs/scripts.astro:
- Uses DocsLayout with title "Scripts Reference | RemoteKube", activeSlug="scripts"
- Sections (h2 for each):

1. **Overview** -- The scripts/ directory contains 8 shell scripts for container lifecycle, cluster setup, and testing. All scripts use `set -euo pipefail` and are documented with inline headers.

2. **Container Lifecycle Scripts** -- For each script, create a glass-card with:
   - Script name as h3
   - Purpose (1-2 sentences)
   - Usage example (inline code or TerminalBlock)
   - Key behaviors / exit codes

   Scripts in this section:
   a. **entrypoint.sh** -- Container entrypoint dispatched by tini. Validates mode, checks auth, stages skills, generates CLAUDE.md, then exec's into Claude Code. 3 modes: interactive, remote-control, headless. CLAUDE_TEST_MODE bypass for CI.
   b. **healthcheck.sh** -- Liveness probe. Uses `pgrep -f "claude"`. Exit 0 = alive, 1 = restart. Test mode bypass.
   c. **readiness.sh** -- Readiness probe. Runs `claude auth status` (spawns Node.js, ~3-5s). Exit 0 = ready, 1 = not ready. Test mode bypass.
   d. **generate-claude-md.sh** -- Generates /app/CLAUDE.md at startup by querying K8s API for cluster metadata. Standalone mode fallback if no ServiceAccount token.

3. **Build & Verification Scripts** --
   e. **verify-tools.sh** -- Validates all 32+ installed tools. Run during Docker build and available at runtime. Categorized checks: network, process, k8s, data, database, security, standard, claude. Privileged tools checked for binary existence only (SKIP, not FAIL).
   f. **helm-golden-test.sh** -- Golden file testing for Helm chart. Renders helm template output and compares against stored golden files. Usage: `bash scripts/helm-golden-test.sh` (compare) or `bash scripts/helm-golden-test.sh --update` (regenerate).

4. **Cluster Setup Scripts** --
   g. **install-calico.sh** -- Installs Calico CNI into KIND cluster for NetworkPolicy enforcement. Configurable version via CALICO_VERSION env. Handles CRD wait, Felix RPF fix, CoreDNS restart.
   h. **setup-bats.sh** -- Installs BATS test framework for local development. Clones bats-core into tests/bats/. Not used in CI (CI uses apt-get install bats).

5. **Script Summary Table** -- Render a docs-table summarizing all 8 scripts:
   | Script | Category | Used In | Purpose |
   Categories: Lifecycle, Build, Cluster Setup
   Used In: Container, CI, Local Dev

Also update site/src/components/sections/Footer.astro:
- Add a "Docs" link pointing to /docs/ in the footer. Look at the existing footer markup and add the link alongside any existing navigation links. If the footer only has copyright/attribution, add a small nav section above it with: "Home" (/) and "Docs" (/docs/) links, styled with text-text-muted hover:text-text-primary transition-colors.
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro build 2>&1 | grep -E "(error|Error|Generated|pages)" | tail -10</automated>
  </verify>
  <done>Scripts reference page renders at /docs/scripts/ with 8 script descriptions organized by category (lifecycle, build, cluster setup) plus summary table. Footer includes Docs link. Full Astro build succeeds with all 5 new doc pages generated (docs/index, docs/helm-chart, docs/dockerfile, docs/kind-deployment, docs/scripts).</done>
</task>

<task type="auto">
  <name>Task 6: Final verification -- build site, test all doc routes, validate links</name>
  <files></files>
  <action>
Run a complete build of the Astro site and verify:
1. `cd site && npm run build` completes without errors
2. All 5 doc routes exist in the dist output: docs/index.html, docs/helm-chart/index.html, docs/dockerfile/index.html, docs/kind-deployment/index.html, docs/scripts/index.html
3. Check that the sitemap includes the new doc pages (grep the generated sitemap)
4. Verify no broken internal links by grepping the built HTML for /docs/ hrefs and ensuring they all point to valid routes
5. Quick visual sanity: grep the built HTML to confirm SVG diagrams are present in helm-chart, dockerfile, and kind-deployment pages (search for "<svg" in those output files)

If any issues found, fix them. If all passes, this task is complete.
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npm run build 2>&1 | tail -20 && echo "---ROUTES---" && find dist -name "index.html" -path "*/docs/*" | sort && echo "---SVGS---" && grep -l "<svg" dist/docs/helm-chart/index.html dist/docs/dockerfile/index.html dist/docs/kind-deployment/index.html 2>/dev/null | wc -l</automated>
  </verify>
  <done>Astro build succeeds. 5 doc routes confirmed in dist/. Sitemap includes doc pages. SVG diagrams confirmed in 3 pages (helm-chart, dockerfile, kind-deployment). No broken internal links.</done>
</task>

</tasks>

<verification>
1. `cd site && npm run build` -- full build with zero errors
2. `find site/dist -name "index.html" -path "*/docs/*" | wc -l` -- outputs 5
3. All doc pages use DocsLayout with working sidebar navigation
4. SVG diagrams render in helm-chart (2 diagrams), dockerfile (1 diagram), kind-deployment (2 diagrams)
5. Values table on helm-chart page contains 30+ configuration values
6. Scripts page documents all 8 scripts from scripts/ directory
7. Footer contains link to /docs/
</verification>

<success_criteria>
- 5 new routes under /docs/ all build and render correctly
- Helm chart page has comprehensive values table in helm-docs style with all values from values.yaml
- 5 inline SVG architecture/flow diagrams using the site's oklch color system
- All pages share DocsLayout with functional sidebar navigation
- Site builds with zero errors and new pages appear in sitemap
</success_criteria>

<output>
After completion, create `.planning/quick/005-document-helm-chart-dockerfile-kind-depl/005-SUMMARY.md`
</output>
