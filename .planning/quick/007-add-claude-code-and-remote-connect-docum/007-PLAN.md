---
phase: quick-007
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - site/src/pages/docs/claude-code.astro
  - site/src/components/ui/DocsNav.astro
  - site/src/pages/docs/index.astro
autonomous: true
requirements: [QUICK-007]

must_haves:
  truths:
    - "Visitor can navigate to /docs/claude-code/ and read about what Claude Code is"
    - "Visitor sees how Remote Connect works, especially in the RemoteKube context"
    - "Visitor sees two SVG diagrams: Remote Connect architecture flow and RemoteKube + Remote Connect integration"
    - "Sidebar includes Claude Code entry and it highlights when active"
    - "Docs index page includes a Claude Code card linking to the new page"
  artifacts:
    - path: "site/src/pages/docs/claude-code.astro"
      provides: "Claude Code & Remote Connect documentation page"
      min_lines: 200
    - path: "site/src/components/ui/DocsNav.astro"
      provides: "Updated sidebar with Claude Code entry"
      contains: "claude-code"
    - path: "site/src/pages/docs/index.astro"
      provides: "Updated docs index with Claude Code card"
      contains: "claude-code"
  key_links:
    - from: "site/src/components/ui/DocsNav.astro"
      to: "/docs/claude-code/"
      via: "navItems array entry"
      pattern: "claude-code.*Claude Code"
    - from: "site/src/pages/docs/index.astro"
      to: "/docs/claude-code/"
      via: "card link in grid"
      pattern: "href.*docs/claude-code"
---

<objective>
Add a Claude Code documentation page to the site covering what Claude Code is, how Remote Connect works, and specifically how RemoteKube leverages Remote Connect to let users control a pod-hosted Claude Code session from their phone or browser.

Purpose: Complete the documentation suite with the core product concept -- the "control from anywhere" value proposition that makes RemoteKube useful.
Output: New /docs/claude-code/ page with two SVG diagrams, updated sidebar and index.
</objective>

<execution_context>
@./.claude/get-shit-done/workflows/execute-plan.md
@./.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@site/src/pages/docs/kustomize.astro (reference page pattern -- DocsLayout, DiagramBlock, sections, tables)
@site/src/components/ui/DocsNav.astro (sidebar nav -- add entry to navItems array)
@site/src/components/ui/DiagramBlock.astro (diagram wrapper component)
@site/src/components/ui/TerminalBlock.astro (terminal command block component)
@site/src/pages/docs/index.astro (index page -- add card to grid)
@site/src/layouts/DocsLayout.astro (layout wrapper)

<interfaces>
From site/src/components/ui/DocsNav.astro:
```typescript
interface Props {
  activeSlug: string;
}
// navItems array: { slug: string, label: string, href: string }[]
```

From site/src/layouts/DocsLayout.astro:
```typescript
interface Props {
  title: string;
  description?: string;
  activeSlug: string;
}
```

From site/src/components/ui/DiagramBlock.astro:
```typescript
interface Props {
  title: string;
  description?: string;
}
// Usage: <DiagramBlock title="..." description="..."><svg ...></svg></DiagramBlock>
```

From site/src/components/ui/TerminalBlock.astro:
```typescript
interface Props {
  title: string;
  commands: string[];
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Claude Code & Remote Connect documentation page</name>
  <files>site/src/pages/docs/claude-code.astro</files>
  <action>
Create the documentation page at `site/src/pages/docs/claude-code.astro` following the exact pattern of existing docs pages (kustomize.astro is the best reference). Import DocsLayout, DiagramBlock, and TerminalBlock. Use `activeSlug="claude-code"`.

Page title: `<h1>` with `gradient-text` span: "Claude Code & Remote Connect"
Meta: title="Claude Code & Remote Connect | RemoteKube", description="What Claude Code is, how Remote Connect works, and how RemoteKube deploys Claude Code inside Kubernetes for phone/browser access."

**Sections to include (use h2 with id attributes, same pattern as other docs pages):**

1. **Overview** (`id="overview"`): Explain what Claude Code is -- Anthropic's official CLI for Claude that runs in a terminal, has full tool access (file read/write, bash, web fetch, etc.), and can work autonomously on coding tasks. It runs as a persistent process, maintaining session state and project context.

2. **Remote Connect** (`id="remote-connect"`): Explain Remote Connect (officially "Remote Control") -- a feature that connects claude.ai/code or the Claude mobile app (iOS/Android) to a running Claude Code session. Key points to cover in prose paragraphs (not just bullet lists):
   - Start with `claude remote-control` or `/remote-control` (or `/rc`) from within a session
   - Session stays running locally; web/mobile are just a window into it
   - Outbound HTTPS only, no inbound ports needed. Polls Anthropic API for work
   - Connect via session URL, QR code, or session list in claude.ai/code
   - Auto-reconnects after sleep/network drops; times out after ~10min offline
   - Currently requires Max plan (Pro plan support coming soon)
   - Key distinction: Remote Connect runs on YOUR machine (local MCP, tools, project config), unlike Claude Code on the web which runs on Anthropic cloud

3. **SVG Diagram 1: Remote Connect Architecture** -- Use DiagramBlock with title="Remote Connect Architecture" and description="How Remote Connect bridges a local Claude Code session to web and mobile clients."

   The SVG diagram (viewBox="0 0 800 300") should show a left-to-right flow:
   - LEFT: Two boxes stacked vertically -- "Phone / Claude App" (top) and "Browser / claude.ai/code" (bottom), both inside a dashed container labeled "Client Devices"
   - CENTER: A box labeled "Anthropic API" with subtitle "Polls for work" -- arrows from both client boxes point to this center box
   - RIGHT: A box labeled "Claude Code Process" with subtitle "Running locally" -- bidirectional arrows between center and right

   Use the same oklch color tokens as other diagram SVGs:
   - Box fill: `oklch(0.16 0.03 260 / 0.70)`
   - Box stroke: `oklch(0.28 0.04 260)`
   - Text primary: `oklch(0.97 0.005 260)`
   - Text secondary: `oklch(0.55 0.02 260)`
   - Accent/arrows: `oklch(0.70 0.15 250)` (use same arrow marker pattern as other diagrams)
   - Monospace text: `oklch(0.62 0.22 260)`
   - Note pill: fill `oklch(0.14 0.03 260 / 0.60)` with stroke `oklch(0.24 0.04 260)`

   Add a bottom note pill: "Outbound HTTPS only -- no inbound ports required"

4. **How RemoteKube Uses Remote Connect** (`id="remotekube-integration"`): Explain the specific integration -- RemoteKube deploys Claude Code inside a Kubernetes pod as a persistent process. The pod runs Claude Code with full access to cluster tools (kubectl, helm, etc.) and project files via a PersistentVolumeClaim. Remote Connect lets users access that pod-hosted session from their phone or any browser -- this is the "deploy once, control from anywhere" value proposition. Cover:
   - Pod runs Claude Code as a long-lived process (entrypoint.sh starts it)
   - PVC provides persistent workspace across pod restarts
   - NetworkPolicy allows outbound HTTPS (port 443) which is exactly what Remote Connect needs
   - User connects from anywhere -- phone on the go, browser at desk -- to the same session with full cluster context

5. **SVG Diagram 2: RemoteKube + Remote Connect** -- Use DiagramBlock with title="RemoteKube + Remote Connect" and description="End-to-end flow from mobile/browser through Anthropic API to the Claude Code pod in Kubernetes."

   The SVG diagram (viewBox="0 0 800 380") should show a three-tier architecture:
   - TOP ROW: Two client boxes -- "Phone" and "Browser" with small icons/labels
   - MIDDLE: "Anthropic API" box (the relay/bridge)
   - BOTTOM: A large dashed-border container labeled "Kubernetes Cluster" containing:
     - A box "claude-agent-0 Pod" containing two sub-elements: "Claude Code Process" and "PVC: /home/claude/workspace"
     - A small box to the side: "NetworkPolicy" with subtitle "Egress: 443 (HTTPS)"
   - Arrows: clients -> API (downward), API <-> Pod (bidirectional, through cluster boundary)

   Same oklch color tokens as diagram 1. Use dashed stroke for the Kubernetes cluster container boundary. Add a bottom note pill: "Deploy once, control from anywhere"

6. **Key Differences** (`id="key-differences"`): A docs-table comparing Remote Connect vs Claude Code on the Web:

   | Feature | Remote Connect (RemoteKube) | Claude Code on Web |
   |---------|---------------------------|-------------------|
   | Runs on | Your Kubernetes cluster | Anthropic cloud |
   | Tools access | Full cluster tools (kubectl, helm, etc.) | Sandboxed environment |
   | Project files | PVC-backed persistent workspace | Cloud workspace |
   | MCP servers | Custom MCP configurations | Standard only |
   | Session persistence | Survives pod restarts (PVC) | Cloud-managed |
   | Network | Your cluster network + policies | Anthropic network |

7. **Getting Started** (`id="getting-started"`): Brief section with TerminalBlock commands showing:
   - `claude remote-control` (start Remote Connect inside the pod)
   - Or use `/remote-control` (shortcut from within a Claude Code session)
   - Then: "Scan the QR code or visit the session URL from your phone or browser"

   Add a final paragraph noting the Max plan requirement and that Pro plan support is coming soon.

All text paragraphs use `class="text-text-secondary"`. All tables use the `docs-table` wrapper div. Follow the exact HTML structure from kustomize.astro for section headings, paragraphs, tables, and diagram blocks.
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro check 2>&1 | tail -20</automated>
  </verify>
  <done>Page exists at site/src/pages/docs/claude-code.astro with all 7 sections, 2 SVG diagrams using project oklch tokens, proper DocsLayout wrapper with activeSlug="claude-code", and consistent styling with other docs pages.</done>
</task>

<task type="auto">
  <name>Task 2: Add Claude Code to sidebar nav and docs index</name>
  <files>site/src/components/ui/DocsNav.astro, site/src/pages/docs/index.astro</files>
  <action>
**DocsNav.astro** -- Add a new entry to the `navItems` array. Insert it as the FIRST entry after "Overview" (before "Helm Chart") since Claude Code is the core concept that the infrastructure docs support:

```javascript
{ slug: "claude-code", label: "Claude Code", href: "/docs/claude-code/" },
```

The full navItems array should be:
1. Overview
2. Claude Code  <-- NEW
3. Helm Chart
4. Dockerfile
5. KIND Deployment
6. Kustomize
7. Scripts Reference

No other changes to DocsNav.astro.

**index.astro** -- Add a Claude Code card as the FIRST card in the grid (before Helm Chart), following the exact same pattern as existing cards. Use a robot/terminal emoji entity for the icon (&#129302; which is the robot face emoji). Card content:

```html
<a href="/docs/claude-code/" class="glass-card rounded-xl p-6 block no-underline">
  <div class="text-3xl mb-3">&#129302;</div>
  <h2 class="text-lg font-semibold text-text-primary mb-2 !mt-0">Claude Code</h2>
  <p class="text-text-secondary text-sm !mb-0">What Claude Code is, how Remote Connect works, and how RemoteKube enables control from anywhere.</p>
</a>
```

Also update the intro paragraph in index.astro to mention Claude Code alongside infrastructure: change "Infrastructure reference for claude-in-a-box" to "Product and infrastructure reference for claude-in-a-box" in the `<p>` tag (line 13). Update the description meta similarly in the DocsLayout opening tag (line 5).
  </action>
  <verify>
    <automated>cd /Users/patrykattc/work/git/claude-in-a-box/site && npx astro check 2>&1 | tail -20</automated>
  </verify>
  <done>DocsNav shows "Claude Code" as second item (after Overview). Docs index has Claude Code card first in grid. Intro text updated to reflect product + infrastructure scope.</done>
</task>

</tasks>

<verification>
1. `cd site && npx astro build` completes without errors
2. `cd site && npx astro check` passes type checking
3. All three modified files contain correct cross-references (grep for "claude-code" in DocsNav, index, and the new page)
4. SVG diagrams use oklch color tokens matching the existing diagram convention
</verification>

<success_criteria>
- /docs/claude-code/ page renders with all 7 sections and 2 SVG diagrams
- Sidebar highlights "Claude Code" when on that page
- Docs index shows Claude Code card as first entry in grid
- Page follows exact same patterns as existing docs (DocsLayout, DiagramBlock, TerminalBlock, docs-table, text-text-secondary)
- Site builds successfully with `npx astro build`
</success_criteria>

<output>
After completion, create `.planning/quick/007-add-claude-code-and-remote-connect-docum/007-SUMMARY.md`
</output>
