---
phase: quick-006
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - site/src/pages/docs/kustomize.astro
  - site/src/components/ui/DocsNav.astro
  - site/src/pages/docs/index.astro
autonomous: true
requirements: [QUICK-006]

must_haves:
  truths:
    - "Kustomize docs page renders at /docs/kustomize/ with content about base resources, overlays, and deployment workflow"
    - "DocsNav sidebar includes Kustomize link and highlights it when active"
    - "Docs index page includes a Kustomize card linking to the new page"
    - "SVG diagrams show the Kustomize overlay structure and deployment workflow"
  artifacts:
    - path: "site/src/pages/docs/kustomize.astro"
      provides: "Kustomize documentation page"
      min_lines: 100
    - path: "site/src/components/ui/DocsNav.astro"
      provides: "Updated sidebar with Kustomize entry"
      contains: "kustomize"
    - path: "site/src/pages/docs/index.astro"
      provides: "Updated docs index with Kustomize card"
      contains: "kustomize"
  key_links:
    - from: "site/src/components/ui/DocsNav.astro"
      to: "/docs/kustomize/"
      via: "navItems array entry"
      pattern: "kustomize.*href.*docs/kustomize"
    - from: "site/src/pages/docs/index.astro"
      to: "/docs/kustomize/"
      via: "card link"
      pattern: "href.*docs/kustomize"
---

<objective>
Add a Kustomize documentation page to the site at /docs/kustomize/.

Purpose: Document how the k8s/ directory uses a Kustomize-style base/overlays convention for Kubernetes manifest management -- base resources (ServiceAccount, RBAC, NetworkPolicy, StatefulSet) and the optional operator overlay. Include SVG diagrams showing the directory/overlay structure and the deployment workflow.

Output: New kustomize.astro page, updated DocsNav sidebar, updated docs index card grid.
</objective>

<execution_context>
@./.claude/get-shit-done/workflows/execute-plan.md
@./.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

Key interfaces the executor needs:

From site/src/layouts/DocsLayout.astro:
```astro
interface Props {
  title: string;
  description?: string;
  activeSlug: string;
}
```
Usage: `<DocsLayout title="..." description="..." activeSlug="kustomize">`

From site/src/components/ui/DiagramBlock.astro:
```astro
interface Props {
  title: string;
  description?: string;
}
```
Usage: `<DiagramBlock title="..." description="..."><svg>...</svg></DiagramBlock>`

From site/src/components/ui/DocsNav.astro navItems array (line 8-14):
```typescript
const navItems = [
  { slug: "overview", label: "Overview", href: "/docs/" },
  { slug: "helm-chart", label: "Helm Chart", href: "/docs/helm-chart/" },
  { slug: "dockerfile", label: "Dockerfile", href: "/docs/dockerfile/" },
  { slug: "kind-deployment", label: "KIND Deployment", href: "/docs/kind-deployment/" },
  { slug: "scripts", label: "Scripts Reference", href: "/docs/scripts/" },
];
```

Kustomize directory structure (k8s/):
```
k8s/
  base/
    01-serviceaccount.yaml   -- ServiceAccount (claude-agent, automountServiceAccountToken)
    02-rbac-reader.yaml      -- ClusterRole + ClusterRoleBinding (get/list/watch on 14 resource types)
    03-networkpolicy.yaml    -- Egress-only NetworkPolicy (DNS, HTTPS, K8s API)
    04-statefulset.yaml      -- Headless Service + StatefulSet (non-root UID 10000, PVC, probes)
  overlays/
    rbac-operator.yaml       -- Operator-tier ClusterRole + ClusterRoleBinding (delete pods, create exec, update deployments)
```

NOTE: There are NO kustomization.yaml files. The project uses the base/overlays directory convention but deploys with plain `kubectl apply -f k8s/base/` (seen in CI at .github/workflows/ci.yaml:130). The overlay is applied separately with `kubectl apply -f k8s/overlays/rbac-operator.yaml`. The Helm chart is the primary deployment method; k8s/ provides a Helm-free alternative. Document this accurately -- do NOT claim Kustomize CLI (`kustomize build`) is used.

SVG diagram style -- use oklch color tokens matching existing docs diagrams:
- Box fill: `oklch(0.16 0.03 260 / 0.70)`
- Box stroke: `oklch(0.28 0.04 260)`
- Primary text: `oklch(0.97 0.005 260)`
- Secondary text: `oklch(0.55 0.02 260)`
- Accent text: `oklch(0.62 0.22 260)`
- Arrow/connector: `oklch(0.70 0.15 250)`
- Label text: `oklch(0.75 0.02 260)`
- Note pill fill: `oklch(0.14 0.03 260 / 0.60)`
- Note pill stroke: `oklch(0.24 0.04 260)`

Docs index card pattern (from index.astro):
```html
<a href="/docs/kustomize/" class="glass-card rounded-xl p-6 block no-underline">
  <div class="text-3xl mb-3">EMOJI</div>
  <h2 class="text-lg font-semibold text-text-primary mb-2 !mt-0">Title</h2>
  <p class="text-text-secondary text-sm !mb-0">Description</p>
</a>
```
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Kustomize documentation page</name>
  <files>site/src/pages/docs/kustomize.astro</files>
  <action>
Create site/src/pages/docs/kustomize.astro following the exact pattern of helm-chart.astro and kind-deployment.astro.

Import DocsLayout, DiagramBlock, and TerminalBlock. Use activeSlug="kustomize".

Page title: "Kustomize Reference | RemoteKube"
Description: "Kubernetes manifest management with base/overlays directory convention: ServiceAccount, RBAC, NetworkPolicy, StatefulSet, and operator overlay."

Sections to include:

1. **H1 heading** with gradient-text span: "Kustomize Reference"

2. **Overview (h2 id="overview")** -- Explain that the k8s/ directory provides a Helm-free alternative for deploying claude-in-a-box using plain kubectl. It follows the Kustomize base/overlays directory convention for organizing manifests, though it uses direct `kubectl apply` rather than the `kustomize build` CLI. The base/ directory contains 4 numbered manifests applied in order, and overlays/ contains optional additive patches.

3. **Directory Structure (h2 id="directory-structure")** -- Include a DiagramBlock with an SVG diagram showing the k8s/ directory tree structure. Show k8s/ as a parent, with base/ containing the 4 numbered YAML files and overlays/ containing rbac-operator.yaml. Use boxes for directories, smaller boxes/rows for files. Use the standard oklch color tokens. viewBox should be approximately 800x320.

4. **Base Resources (h2 id="base-resources")** -- docs-table with columns: File, Kind, Description. Rows:
   - 01-serviceaccount.yaml | ServiceAccount | Dedicated identity for claude-agent pod, automounts API token
   - 02-rbac-reader.yaml | ClusterRole + ClusterRoleBinding | Read-only access (get/list/watch) to 14 resource types across 4 API groups
   - 03-networkpolicy.yaml | NetworkPolicy | Egress-only policy: DNS (53), HTTPS (443), K8s API (6443). All ingress blocked
   - 04-statefulset.yaml | Service + StatefulSet | Headless Service for DNS identity, StatefulSet with PVC, non-root (UID 10000), probes

5. **Overlay: Operator RBAC (h2 id="operator-overlay")** -- Explain that the overlay is additive (never removes reader permissions), lives in overlays/ so it is NOT applied by default, and is applied/revoked manually. Include a docs-table with columns: Resource, Verb, Purpose. Rows:
   - pods | delete | Force-restart pods via StatefulSet controller recreation
   - pods/exec | create | Interactive debugging inside running containers
   - deployments, statefulsets | update, patch | Rollout restarts and spec modifications

6. **Deployment Workflow (h2 id="deployment-workflow")** -- DiagramBlock SVG diagram showing the deployment flow. Two paths from a decision diamond "Deployment method?" -- left path: "Helm" going to "helm install" box, right path: "kubectl" going to "kubectl apply -f k8s/base/" box, then an optional dashed arrow to "kubectl apply -f k8s/overlays/rbac-operator.yaml". viewBox approximately 800x250. Use arrow markers like existing diagrams.

7. **Usage (h2 id="usage")** -- Three subsections with TerminalBlock components:
   - "Deploy with base resources": `kubectl apply -f k8s/base/`
   - "Add operator permissions": `kubectl apply -f k8s/overlays/rbac-operator.yaml`
   - "Revoke operator permissions": `kubectl delete -f k8s/overlays/rbac-operator.yaml`

8. **Helm vs kubectl (h2 id="helm-vs-kubectl")** -- docs-table comparing the two approaches. Columns: Feature, Helm Chart, kubectl (k8s/). Rows:
   - Templating | Values-driven (values.yaml) | Static manifests
   - Security profiles | 3 profiles via values overlays | Base + manual operator overlay
   - Lifecycle | helm install/upgrade/rollback | kubectl apply/delete
   - Best for | Production, multi-env | Quick local testing, CI

All text paragraphs should use class="text-text-secondary". All SVG elements must use the oklch color tokens listed in context. Every SVG must have role="img" and an aria-label.
  </action>
  <verify>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro check 2>&1 | tail -20; echo "---"; npx astro build 2>&1 | tail -10</verify>
  <done>Kustomize page renders at /docs/kustomize/ with all 8 sections, 2 SVG diagrams, 3 TerminalBlock commands, and 3 docs-tables. Page builds without errors.</done>
</task>

<task type="auto">
  <name>Task 2: Add Kustomize to DocsNav sidebar and docs index</name>
  <files>site/src/components/ui/DocsNav.astro, site/src/pages/docs/index.astro</files>
  <action>
In site/src/components/ui/DocsNav.astro, add a new entry to the navItems array after "KIND Deployment" and before "Scripts Reference":
```
{ slug: "kustomize", label: "Kustomize", href: "/docs/kustomize/" },
```

In site/src/pages/docs/index.astro, add a new card to the grid after the KIND Deployment card and before the Scripts Reference card:
```html
<a href="/docs/kustomize/" class="glass-card rounded-xl p-6 block no-underline">
  <div class="text-3xl mb-3">&#128193;</div>
  <h2 class="text-lg font-semibold text-text-primary mb-2 !mt-0">Kustomize</h2>
  <p class="text-text-secondary text-sm !mb-0">Base/overlays directory convention, kubectl deployment, and operator RBAC overlay.</p>
</a>
```

Use HTML entity &#128193; (open file folder) for the emoji icon, consistent with the emoji icon pattern used by existing cards.
  </action>
  <verify>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro build 2>&1 | tail -5</verify>
  <done>DocsNav shows 6 items (Overview, Helm Chart, Dockerfile, KIND Deployment, Kustomize, Scripts Reference). Docs index shows 5 cards including Kustomize. Site builds successfully.</done>
</task>

</tasks>

<verification>
- `cd site && npx astro build` completes without errors
- `/docs/kustomize/` page is generated in build output
- DocsNav includes Kustomize link between KIND Deployment and Scripts Reference
- Docs index includes Kustomize card in grid
- Both SVG diagrams render (directory structure and deployment workflow)
</verification>

<success_criteria>
- Kustomize documentation page exists at /docs/kustomize/ with accurate content about the k8s/ directory structure
- Page correctly describes that kubectl apply (not kustomize build) is used
- Two SVG diagrams: directory structure tree and deployment workflow
- Base resources table documents all 4 numbered YAML files
- Operator overlay section explains the additive RBAC pattern
- DocsNav sidebar includes Kustomize entry in correct position
- Docs index includes Kustomize card in the grid
- Site builds without errors
</success_criteria>

<output>
After completion, create `.planning/quick/006-add-kustomize-documentation-page-to-the-/006-SUMMARY.md`
</output>
