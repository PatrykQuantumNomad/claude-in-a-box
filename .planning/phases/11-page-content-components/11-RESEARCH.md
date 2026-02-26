# Phase 11: Page Content & Components - Research

**Researched:** 2026-02-26
**Domain:** Astro components, Tailwind CSS v4 responsive layout, SVG diagrams, clipboard API, landing page sections
**Confidence:** HIGH

## Summary

Phase 11 transforms the placeholder Astro site (established in Phase 10) into a complete, responsive landing page with six distinct content sections: hero, feature bento grid, architecture SVG diagram, quickstart terminal blocks with copy-to-clipboard, use cases, and footer. It also adds responsive layout support across three breakpoints (375px mobile, 768px tablet, 1280px+ desktop) and a custom 404 page.

The technical foundation is already solid: Astro 5.18.0 with Tailwind CSS v4.2.1, a dark theme design system with oklch color tokens, self-hosted Inter and JetBrains Mono fonts, and a BaseLayout component. All Phase 11 work is pure Astro components (.astro files) with zero client-side framework dependencies. The only client-side JavaScript needed is a small clipboard script for the copy buttons, implemented via Astro's native `<script>` tag processing. The architecture diagram is a hand-crafted inline SVG using the existing design tokens.

**Primary recommendation:** Build each landing page section as a standalone Astro component in `src/components/sections/`, compose them in `index.astro`, use CSS Grid with Tailwind responsive prefixes for the bento layout, implement copy-to-clipboard with `navigator.clipboard.writeText()` in a processed `<script>` tag, and create `src/pages/404.astro` using the existing BaseLayout.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PAGE-01 | Hero section with headline, tagline, and two CTAs (View on GitHub + Quickstart) | Astro component pattern with anchor link + smooth scroll CSS; GitHub repo URL from git remote |
| PAGE-02 | Feature showcase as bento grid with 4-6 cards highlighting key capabilities | CSS Grid with Tailwind `grid`, `grid-cols-*`, `col-span-*`, `row-span-*` responsive classes |
| PAGE-03 | Architecture diagram (SVG) showing phone -> Anthropic relay -> Kubernetes cluster data flow | Inline SVG with viewBox for responsiveness, styled with Tailwind's design tokens via CSS variables |
| PAGE-04 | Quickstart section with terminal-styled code blocks and copy-to-clipboard for all 3 deployment methods | `navigator.clipboard.writeText()` in Astro `<script>` tag, terminal UI with JetBrains Mono font |
| PAGE-05 | Use cases section showing 3-4 real-world scenarios | Static Astro component cards, no interactivity needed |
| PAGE-06 | Footer with GitHub link, license info, and Anthropic attribution | Static Astro component, MIT license, copyright Patryk Golabek |
| DESIGN-03 | Responsive layout working on mobile, tablet, and desktop breakpoints | Tailwind v4 default breakpoints: md (768px), lg (1024px), xl (1280px); mobile-first approach |
| DESIGN-05 | Custom 404 page matching site design | `src/pages/404.astro` using BaseLayout -- Astro auto-generates 404.html, GitHub Pages serves it |
</phase_requirements>

## Standard Stack

### Core (already installed from Phase 10)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| astro | 5.18.0 | Static site generator | Already installed; zero-JS components render to HTML at build time |
| tailwindcss | 4.2.1 | Utility-first CSS framework | Already installed; CSS-first config via @theme, responsive breakpoints built-in |
| @tailwindcss/vite | 4.2.1 | Tailwind Vite integration | Already installed; official plugin for Astro's Vite pipeline |

### Supporting (already installed from Phase 10)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @fontsource-variable/inter | 5.x | Body text font | Already imported in global.css |
| @fontsource-variable/jetbrains-mono | 5.x | Terminal/code block font | Already imported in global.css; use for quickstart code blocks |

### No New Dependencies

Phase 11 requires **zero new npm packages**. All functionality is achievable with:
- Astro's built-in component system (`.astro` files)
- Tailwind CSS v4 responsive utilities (already configured)
- Native browser `navigator.clipboard` API (no library needed)
- Inline SVG for the architecture diagram (no library needed)
- CSS `scroll-behavior: smooth` for anchor scroll (no library needed)

**Installation:** None. Run `npm install` in `site/` only if `node_modules` is missing.

## Architecture Patterns

### Recommended Project Structure

```
site/src/
  components/
    sections/
      Hero.astro              # PAGE-01: headline, tagline, CTAs
      Features.astro           # PAGE-02: bento grid feature cards
      Architecture.astro       # PAGE-03: SVG architecture diagram
      Quickstart.astro         # PAGE-04: terminal code blocks with copy
      UseCases.astro           # PAGE-05: scenario cards
      Footer.astro             # PAGE-06: links, license, attribution
    ui/
      TerminalBlock.astro      # Reusable terminal-styled code block with copy button
      FeatureCard.astro        # Reusable bento grid card
      UseCaseCard.astro        # Reusable use case card
  layouts/
    BaseLayout.astro           # Already exists from Phase 10
  pages/
    index.astro                # Composes all sections
    404.astro                  # DESIGN-05: custom 404 page
  styles/
    global.css                 # Already exists from Phase 10, extend with smooth scroll
```

### Pattern 1: Section Component Composition

**What:** Each landing page section is an independent Astro component composed in `index.astro`.
**When to use:** Always for landing pages. Keeps sections isolated, testable, and reorderable.

```astro
---
// src/pages/index.astro
import BaseLayout from "../layouts/BaseLayout.astro";
import Hero from "../components/sections/Hero.astro";
import Features from "../components/sections/Features.astro";
import Architecture from "../components/sections/Architecture.astro";
import Quickstart from "../components/sections/Quickstart.astro";
import UseCases from "../components/sections/UseCases.astro";
import Footer from "../components/sections/Footer.astro";
---

<BaseLayout title="RemoteKube - Claude Code in Your Cluster">
  <main>
    <Hero />
    <Features />
    <Architecture />
    <Quickstart />
    <UseCases />
  </main>
  <Footer />
</BaseLayout>
```

### Pattern 2: Typed Props for Reusable UI Components

**What:** Use TypeScript interfaces in frontmatter for component props. Enables consistent data passing.
**When to use:** For reusable components like FeatureCard, UseCaseCard, TerminalBlock.

```astro
---
// src/components/ui/FeatureCard.astro
// Source: https://docs.astro.build/en/basics/astro-components/
interface Props {
  title: string;
  description: string;
  icon: string;
  colSpan?: number;
  rowSpan?: number;
}

const { title, description, icon, colSpan = 1, rowSpan = 1 } = Astro.props;
---

<div class={`
  bg-bg-secondary border border-border rounded-2xl p-6
  ${colSpan === 2 ? 'md:col-span-2' : ''}
  ${rowSpan === 2 ? 'md:row-span-2' : ''}
`}>
  <div class="text-3xl mb-4">{icon}</div>
  <h3 class="text-lg font-semibold text-text-primary mb-2">{title}</h3>
  <p class="text-text-secondary text-sm leading-relaxed">{description}</p>
</div>
```

### Pattern 3: CSS-Only Smooth Scroll for Anchor CTAs

**What:** Use `scroll-behavior: smooth` in CSS for the Quickstart CTA to scroll to the quickstart section.
**When to use:** For the hero's "Quickstart" CTA button that scrolls to `#quickstart`.

```css
/* Add to site/src/styles/global.css */
/* Source: https://rodneylab.com/astro-scroll-to-anchor/ */
html {
  scroll-behavior: smooth;
}

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }
}
```

The hero CTA uses a standard anchor link:

```astro
<a href="#quickstart" class="...">Quickstart</a>
```

And the quickstart section has the matching ID:

```astro
<section id="quickstart" class="...">
```

### Pattern 4: Client-Side Script for Clipboard (Astro Processed)

**What:** Astro processes `<script>` tags with bundling, TypeScript support, and deduplication. Use this for the copy-to-clipboard functionality.
**When to use:** In the TerminalBlock component for copy buttons.

```astro
---
// src/components/ui/TerminalBlock.astro
// Source: https://docs.astro.build/en/guides/client-side-scripts/
interface Props {
  title: string;
  code: string;
}

const { title, code } = Astro.props;
---

<div class="relative group bg-bg-secondary border border-border rounded-xl overflow-hidden">
  <div class="flex items-center justify-between px-4 py-2 bg-bg-tertiary border-b border-border">
    <span class="text-text-muted text-xs font-mono">{title}</span>
    <button
      class="copy-btn text-text-muted hover:text-text-primary transition-colors text-xs"
      data-code={code}
      aria-label="Copy to clipboard"
    >
      Copy
    </button>
  </div>
  <pre class="p-4 overflow-x-auto"><code class="text-sm font-mono text-text-secondary">{code}</code></pre>
</div>

<script>
  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const code = btn.getAttribute('data-code');
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code);
        const original = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => {
          btn.textContent = original;
        }, 2000);
      } catch {
        // Fallback: select text in the pre element
        const pre = btn.closest('.relative')?.querySelector('pre');
        if (pre) {
          const range = document.createRange();
          range.selectNodeContents(pre);
          const selection = window.getSelection();
          selection?.removeAllRanges();
          selection?.addRange(range);
        }
      }
    });
  });
</script>
```

**Key Astro script behaviors:**
- Scripts are bundled and deduplicated -- if TerminalBlock is used 3 times, the script is included only once
- Scripts are automatically `type="module"`
- TypeScript is supported natively
- Small scripts are inlined into the HTML

### Pattern 5: Responsive Bento Grid with Tailwind

**What:** CSS Grid layout that stacks on mobile, arranges into a bento pattern on tablet/desktop.
**When to use:** Feature showcase section (PAGE-02).

```astro
---
// src/components/sections/Features.astro
import FeatureCard from "../ui/FeatureCard.astro";
---

<section class="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
  <h2 class="text-3xl font-bold text-text-primary text-center mb-12">
    Key Capabilities
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <FeatureCard
      title="Remote Control"
      description="Manage your cluster from your phone or claude.ai"
      icon="phone-icon"
      colSpan={2}
    />
    <FeatureCard
      title="MCP Integration"
      description="14 Kubernetes resource types via kubernetes-mcp-server"
      icon="k8s-icon"
    />
    <!-- ... more cards ... -->
  </div>
</section>
```

**Responsive behavior:**
- Mobile (< 768px): `grid-cols-1` -- single column stack
- Tablet (768px+): `md:grid-cols-2` -- 2-column grid
- Desktop (1024px+): `lg:grid-cols-3` -- 3-column bento with spans

### Pattern 6: Inline SVG Architecture Diagram

**What:** Hand-crafted SVG with viewBox for responsive scaling, using CSS custom properties for theming.
**When to use:** Architecture diagram section (PAGE-03).

```astro
---
// src/components/sections/Architecture.astro
---

<section class="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
  <h2 class="text-3xl font-bold text-text-primary text-center mb-12">
    How It Works
  </h2>
  <div class="max-w-4xl mx-auto">
    <svg
      viewBox="0 0 800 400"
      class="w-full h-auto"
      role="img"
      aria-label="Architecture diagram showing phone connecting to Anthropic API relay, then to Claude Code CLI running inside a Kubernetes cluster"
    >
      <!-- SVG content using currentColor and theme-aware colors -->
      <!-- Remove fixed width/height to let viewBox control scaling -->
    </svg>
  </div>
</section>
```

**SVG best practices for this project:**
- Use `viewBox` without fixed `width`/`height` attributes for responsiveness
- Use `role="img"` and `aria-label` for accessibility
- Reference design token colors via CSS: `fill="currentColor"` or inline `style="fill: oklch(...)"`
- Keep path complexity under 5,000 commands to avoid FCP impact
- Optimize with SVGOMG if hand-crafted SVG is complex

### Pattern 7: Custom 404 Page

**What:** Astro automatically generates `404.html` from `src/pages/404.astro`. GitHub Pages serves this for all non-existent routes.
**When to use:** Required for DESIGN-05.

```astro
---
// src/pages/404.astro
// Source: https://docs.astro.build/en/basics/astro-pages/
import BaseLayout from "../layouts/BaseLayout.astro";
---

<BaseLayout title="404 - Page Not Found | RemoteKube">
  <main class="min-h-screen flex items-center justify-center">
    <div class="text-center space-y-6 p-8">
      <p class="text-6xl font-mono text-accent">404</p>
      <h1 class="text-2xl font-bold text-text-primary">Page Not Found</h1>
      <p class="text-text-secondary max-w-md">
        The page you're looking for doesn't exist.
      </p>
      <a
        href="/"
        class="inline-block px-6 py-3 bg-accent text-bg-primary font-semibold rounded-lg hover:bg-accent-hover transition-colors"
      >
        Back to Home
      </a>
    </div>
  </main>
</BaseLayout>
```

### Anti-Patterns to Avoid

- **Adding React/Preact for interactivity:** The copy-to-clipboard button does NOT need a framework. Use Astro's native `<script>` tag. Adding a framework for one button is massive overhead for zero benefit.
- **Using `is:inline` for the clipboard script:** Let Astro process the script so it gets bundled, deduplicated, and potentially inlined. Only use `is:inline` for external CDN scripts.
- **External SVG file for the architecture diagram:** Use inline SVG so it can be styled with CSS and benefits from immediate rendering without an extra HTTP request.
- **Installing a clipboard library (clipboard.js):** The native `navigator.clipboard.writeText()` API is supported in all modern browsers. No library needed.
- **Using `dark:` prefix classes:** This is a dark-only site. Colors are defined as defaults in `@theme`. Never use `dark:` prefixes.
- **Adding motion/animation in Phase 11:** Phase 12 handles all animations. Keep Phase 11 static -- no scroll-triggered reveals, no motion library import, no opacity transitions on scroll.
- **Hardcoding responsive pixel values:** Use Tailwind's responsive prefixes (`md:`, `lg:`, `xl:`) instead of custom media queries.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Clipboard functionality | Custom clipboard polyfill | `navigator.clipboard.writeText()` | Native API, 97%+ browser support, async/promise-based |
| Responsive grid layout | Custom CSS Grid with media queries | Tailwind responsive prefixes (`md:grid-cols-2 lg:grid-cols-3`) | Mobile-first, consistent breakpoints, no custom CSS needed |
| Smooth scrolling | JavaScript scroll library (scrollIntoView with custom easing) | CSS `scroll-behavior: smooth` with `prefers-reduced-motion` | Zero JS, native browser support, accessibility-respecting |
| SVG optimization | Manual path cleanup | SVGOMG (svgomg.net) | 20-80% file size reduction, handles precision, removes cruft |
| Icon system | Custom SVG sprite system | Inline SVG directly in components | Only ~10 icons needed total; sprite system is overengineered |
| Font loading | @font-face declarations | Fontsource packages (already installed) | Already handles subsetting, formats, font-display |

**Key insight:** Phase 11 is a content-heavy phase, not an infrastructure phase. Every component is a static Astro template with Tailwind classes. The only client-side JS is the ~20-line clipboard script. Resist the urge to add complexity.

## Common Pitfalls

### Pitfall 1: Forgetting Mobile-First Design

**What goes wrong:** Building the desktop layout first, then trying to make it responsive. Results in broken mobile layouts or excessive overrides.
**Why it happens:** Developers design in desktop browsers and forget Tailwind is mobile-first.
**How to avoid:** Write base styles for mobile (375px). Add `md:` prefixes for tablet. Add `lg:`/`xl:` prefixes for desktop. Test mobile viewport FIRST.
**Warning signs:** Lots of `max-md:` or `max-lg:` overrides. Base styles that only make sense on large screens.

### Pitfall 2: Clipboard API Fails on HTTP

**What goes wrong:** `navigator.clipboard.writeText()` throws a `NotAllowedError` or is undefined.
**Why it happens:** Clipboard API requires secure context (HTTPS). Development on `localhost` works (treated as secure), but HTTP does not.
**How to avoid:** The production site uses HTTPS via GitHub Pages. Dev server (`astro dev`) runs on localhost. Both are fine. Add a fallback `try/catch` that selects the text for manual copy.
**Warning signs:** Copy button works in dev but fails in some environments.

### Pitfall 3: SVG Not Scaling on Mobile

**What goes wrong:** Architecture diagram overflows horizontally on small screens or is too tiny to read.
**Why it happens:** Fixed width/height attributes on the SVG element, or viewBox not set.
**How to avoid:** Remove `width` and `height` attributes from the SVG element. Set `viewBox="0 0 [width] [height]"`. Use `class="w-full h-auto"` in Tailwind. Consider a simplified mobile view or horizontal scroll for very complex diagrams.
**Warning signs:** Horizontal scrollbar on mobile, or diagram content is illegible at small sizes.

### Pitfall 4: Code Blocks Overflowing on Mobile

**What goes wrong:** Terminal code blocks with long commands break the layout on narrow screens.
**Why it happens:** `<pre>` elements preserve whitespace and do not wrap by default.
**How to avoid:** Add `overflow-x-auto` to the `<pre>` element. This enables horizontal scrolling within the code block without breaking the page layout. Consider using `whitespace-pre-wrap` only if the code is readable when wrapped (usually not for terminal commands).
**Warning signs:** Page-level horizontal scroll on mobile when viewing quickstart section.

### Pitfall 5: Bento Grid Gaps on Different Column Counts

**What goes wrong:** Grid items with `col-span-2` break the layout when the grid has fewer columns at smaller breakpoints.
**Why it happens:** A `col-span-2` item in a `grid-cols-1` layout overflows because it tries to span 2 columns in a 1-column grid.
**How to avoid:** Only apply span classes at the breakpoint where they make sense. Use `md:col-span-2` instead of `col-span-2`. Base layout should always be `grid-cols-1` with no spans.
**Warning signs:** Items disappearing or overflowing on mobile view.

### Pitfall 6: Anchor Scroll Offset by Fixed Header

**What goes wrong:** Clicking the Quickstart CTA scrolls to the section, but the section heading is hidden behind a fixed/sticky header.
**Why it happens:** Smooth scroll goes to the exact top of the target element, but a fixed header covers it.
**How to avoid:** If using a sticky/fixed header, add `scroll-margin-top` to the target section (e.g., `scroll-mt-20`). Alternatively, if there is no fixed header (current design has no header nav), this is not an issue.
**Warning signs:** Section heading not visible after scroll completes.

### Pitfall 7: GitHub Repo URL Inconsistency

**What goes wrong:** Landing page links to wrong GitHub URL.
**Why it happens:** The additional context specifies `patrykattc/claude-in-a-box` but the actual git remote is `PatrykQuantumNomad/claude-in-a-box`.
**How to avoid:** Use the actual git remote URL: `https://github.com/PatrykQuantumNomad/claude-in-a-box`. Verify with `git remote -v`.
**Warning signs:** "View on GitHub" CTA returns 404.

## Code Examples

Verified patterns from official sources:

### Section with Responsive Padding and Max Width

```astro
<!-- Standard section container pattern -->
<!-- Source: Tailwind CSS responsive design docs -->
<section class="py-16 md:py-20 lg:py-24 px-4 sm:px-6 lg:px-8">
  <div class="max-w-7xl mx-auto">
    <!-- Section content -->
  </div>
</section>
```

### Hero Section with Two CTAs

```astro
---
// src/components/sections/Hero.astro
---

<section class="min-h-[80vh] flex items-center justify-center px-4 sm:px-6 lg:px-8">
  <div class="max-w-4xl mx-auto text-center space-y-8">
    <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold text-text-primary tracking-tight">
      Deploy once, control from anywhere
    </h1>
    <p class="text-lg md:text-xl text-text-secondary max-w-2xl mx-auto">
      An AI-powered DevOps agent running inside your Kubernetes cluster,
      accessible from your phone via Remote Control
    </p>
    <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
      <a
        href="https://github.com/PatrykQuantumNomad/claude-in-a-box"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-2 px-6 py-3 bg-accent text-bg-primary font-semibold rounded-lg hover:bg-accent-hover transition-colors"
      >
        View on GitHub
      </a>
      <a
        href="#quickstart"
        class="inline-flex items-center gap-2 px-6 py-3 border border-border text-text-primary font-semibold rounded-lg hover:bg-bg-secondary transition-colors"
      >
        Quickstart
      </a>
    </div>
  </div>
</section>
```

### Terminal Block with Copy

```astro
---
// src/components/ui/TerminalBlock.astro
// Source: Astro client-side scripts docs + Clipboard API MDN
interface Props {
  title: string;
  commands: string[];
}

const { title, commands } = Astro.props;
const codeText = commands.join('\n');
---

<div class="relative group bg-bg-secondary border border-border rounded-xl overflow-hidden">
  <div class="flex items-center justify-between px-4 py-2 bg-bg-tertiary border-b border-border">
    <span class="text-text-muted text-xs font-mono">{title}</span>
    <button
      class="copy-btn text-text-muted hover:text-text-primary transition-colors text-xs font-mono"
      data-code={codeText}
      aria-label={`Copy ${title} commands to clipboard`}
    >
      Copy
    </button>
  </div>
  <div class="p-4 overflow-x-auto">
    {commands.map((cmd) => (
      <div class="flex gap-2 font-mono text-sm">
        <span class="text-text-muted select-none shrink-0">$</span>
        <span class="text-text-secondary">{cmd}</span>
      </div>
    ))}
  </div>
</div>

<script>
  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const code = btn.getAttribute('data-code');
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code);
        const original = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = original; }, 2000);
      } catch {
        const pre = btn.closest('.relative')?.querySelector('.overflow-x-auto');
        if (pre) {
          const range = document.createRange();
          range.selectNodeContents(pre);
          window.getSelection()?.removeAllRanges();
          window.getSelection()?.addRange(range);
        }
      }
    });
  });
</script>
```

### Quickstart Section with 3 Deployment Methods

```astro
---
// src/components/sections/Quickstart.astro
import TerminalBlock from "../ui/TerminalBlock.astro";
---

<section id="quickstart" class="py-16 md:py-20 lg:py-24 px-4 sm:px-6 lg:px-8">
  <div class="max-w-4xl mx-auto space-y-12">
    <div class="text-center">
      <h2 class="text-3xl font-bold text-text-primary mb-4">Get Started</h2>
      <p class="text-text-secondary">Three deployment methods to match your workflow</p>
    </div>

    <div class="space-y-8">
      <div>
        <h3 class="text-lg font-semibold text-text-primary mb-3">KIND (Local Development)</h3>
        <TerminalBlock
          title="terminal"
          commands={[
            "git clone https://github.com/PatrykQuantumNomad/claude-in-a-box.git",
            "cd claude-in-a-box",
            "make bootstrap"
          ]}
        />
      </div>

      <div>
        <h3 class="text-lg font-semibold text-text-primary mb-3">Docker Compose (Standalone)</h3>
        <TerminalBlock
          title="terminal"
          commands={[
            "export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...",
            "docker compose up -d",
            "docker attach claude-agent"
          ]}
        />
      </div>

      <div>
        <h3 class="text-lg font-semibold text-text-primary mb-3">Helm (Production)</h3>
        <TerminalBlock
          title="terminal"
          commands={[
            "helm install claude-agent ./helm/claude-in-a-box \\",
            "  --set image.repository=ghcr.io/PatrykQuantumNomad/claude-in-a-box \\",
            "  --set image.tag=latest"
          ]}
        />
      </div>
    </div>
  </div>
</section>
```

### Footer Component

```astro
---
// src/components/sections/Footer.astro
---

<footer class="border-t border-border py-8 px-4 sm:px-6 lg:px-8">
  <div class="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-text-muted">
    <div class="flex items-center gap-4">
      <a
        href="https://github.com/PatrykQuantumNomad/claude-in-a-box"
        target="_blank"
        rel="noopener noreferrer"
        class="hover:text-text-secondary transition-colors"
      >
        GitHub
      </a>
      <span>MIT License</span>
    </div>
    <p>
      Built with Claude Code by
      <a
        href="https://github.com/PatrykQuantumNomad"
        target="_blank"
        rel="noopener noreferrer"
        class="hover:text-text-secondary transition-colors"
      >
        Patryk Golabek
      </a>
    </p>
  </div>
</footer>
```

### Smooth Scroll CSS Addition

```css
/* Add to site/src/styles/global.css after existing @theme block */
/* Source: https://rodneylab.com/astro-scroll-to-anchor/ */

html {
  scroll-behavior: smooth;
}

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }
}
```

## Content Reference

The landing page content should be derived from the README.md. Key facts to use:

### Feature Cards Content (PAGE-02, 4-6 cards)

| Feature | Description | Source |
|---------|-------------|--------|
| Remote Control | Manage your cluster from your phone or claude.ai/code | README Features section |
| MCP Kubernetes | In-cluster read-only access to 14 resource types | README Features section |
| Three Startup Modes | Interactive, remote-control, or headless execution | README Features section |
| Tiered RBAC | Readonly, operator, or airgapped security profiles | README Features section |
| NetworkPolicy Isolation | Egress-only with DNS, HTTPS, and K8s API restriction | README Features section |
| 32+ DevOps Tools | kubectl, helm, k9s, stern, trivy, grype, and more | README Features section |

### Architecture Diagram Nodes (PAGE-03)

The SVG should depict this data flow (from README mermaid diagram):
1. **Phone / claude.ai** (user access) -- user initiates request
2. **Anthropic API + Remote Control** (cloud layer) -- relays to agent
3. **Claude Code** (inside pod) -- processes request
4. **MCP Server (kubernetes-mcp-server)** -- queries cluster
5. **Kubernetes Cluster** (resources) -- returns data

Supporting infrastructure shown: ServiceAccount, NetworkPolicy, PersistentVolumeClaim.

### Use Cases Content (PAGE-05, 3-4 scenarios)

| Scenario | Description |
|----------|-------------|
| Incident Response | Check pod status, read logs, and diagnose issues from your phone during on-call |
| Remote Debugging | Exec into pods, inspect configs, trace network issues from anywhere |
| Cluster Monitoring | Watch deployments, check resource health, review events without VPN |
| Automated Operations | Use headless mode for scripted checks, reporting, and routine maintenance |

### Deployment Commands (PAGE-04)

Exact commands from README:
- **KIND:** `git clone ... && cd claude-in-a-box && make bootstrap`
- **Docker Compose:** `export CLAUDE_CODE_OAUTH_TOKEN=... && docker compose up -d && docker attach claude-agent`
- **Helm:** `helm install claude-agent ./helm/claude-in-a-box --set image.repository=... --set image.tag=latest`

### Footer Content (PAGE-06)

- GitHub URL: `https://github.com/PatrykQuantumNomad/claude-in-a-box`
- License: MIT -- Copyright (c) 2026 Patryk Golabek
- Attribution: Built with Claude Code (Anthropic)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `document.execCommand('copy')` | `navigator.clipboard.writeText()` | Deprecated 2022+ | execCommand is deprecated, clipboard API is the standard |
| JavaScript smooth scroll libraries | CSS `scroll-behavior: smooth` | Widely supported 2020+ | Zero JS needed, 97%+ browser support |
| CSS Grid with `@media` queries | Tailwind responsive prefixes (`md:`, `lg:`) | Tailwind v3+ | No custom media queries needed; breakpoints are standardized |
| External SVG files (`<img src="diagram.svg">`) | Inline SVG for themed/interactive diagrams | Ongoing best practice | Stylable with CSS, no extra HTTP request, immediate render |
| `@astrojs/tailwind` | `@tailwindcss/vite` | Tailwind v4 / Jan 2025 | Already configured in Phase 10; old integration deprecated |

**Deprecated/outdated:**
- `document.execCommand('copy')`: Deprecated, no longer guaranteed to work. Use `navigator.clipboard.writeText()`.
- `clipboard.js` library: Unnecessary for modern browsers. Native API is sufficient.

## Open Questions

1. **Architecture SVG visual fidelity**
   - What we know: The README has a Mermaid diagram with the exact node/edge structure. The SVG needs to show phone -> Anthropic -> Claude Code -> MCP -> Kubernetes cluster.
   - What's unclear: Exact visual design -- box sizes, arrow styles, colors, positioning. This is a creative decision best resolved during implementation.
   - Recommendation: Start with a simple box-and-arrow layout. Use oklch accent color for connecting arrows, bg-secondary for boxes, text-primary for labels. Keep it clean and technical -- this is a DevOps audience.

2. **Bento grid exact card count and span configuration**
   - What we know: Requirement says 4-6 feature cards. Content for 6 features exists (from README).
   - What's unclear: Which cards should span 2 columns, whether to use 2 or 3 columns on desktop.
   - Recommendation: Use 6 cards in a 3-column desktop grid. First card (Remote Control) spans 2 columns as the "hero" feature. Remaining 5 cards are 1-column each. On tablet: 2 columns. On mobile: 1 column, all cards equal.

3. **Handling multiline Helm commands in terminal blocks**
   - What we know: The Helm install command with `--set` flags is long and uses backslash continuations.
   - What's unclear: Whether to show it as one long command with horizontal scroll or as multiple lines with continuation characters.
   - Recommendation: Show as multiple lines with `\` continuation characters (matching the README format). The `overflow-x-auto` on the code block handles any overflow. The copy button should copy the full command.

## Sources

### Primary (HIGH confidence)

- Astro official docs: Components - https://docs.astro.build/en/basics/astro-components/ (component structure, props, slots, scripts)
- Astro official docs: Pages (404 page) - https://docs.astro.build/en/basics/astro-pages/ (custom 404.astro auto-generates 404.html)
- Astro official docs: Client-side scripts - https://docs.astro.build/en/guides/client-side-scripts/ (script processing, deduplication, bundling)
- Tailwind CSS docs: Responsive design - https://tailwindcss.com/docs/responsive-design (default breakpoints, mobile-first, `--breakpoint-*` customization)
- MDN: Clipboard API - https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API (navigator.clipboard.writeText, security requirements)
- MDN: Navigator.clipboard - https://developer.mozilla.org/en-US/docs/Web/API/Navigator/clipboard (secure context requirement)

### Secondary (MEDIUM confidence)

- Rodney Lab: Astro Scroll to Anchor - https://rodneylab.com/astro-scroll-to-anchor/ (CSS-only smooth scroll with prefers-reduced-motion)
- DEV.to: Bento Grid with Tailwind CSS - https://dev.to/ibelick/creating-bento-grid-layouts-with-css-tailwind-css-26mo (grid-cols, col-span, row-span patterns)
- DEV.to: Responsive Bento Grid - https://dev.to/velox-web/how-to-build-a-responsive-bento-grid-with-tailwind-css-no-masonryjs-3f2c (grid-auto-flow dense, auto-rows)
- SVG on the Web: Best practices - https://svgontheweb.com/ (viewBox, responsive SVG, inline vs external)
- Creative Bloq: 10 Rules for Responsive SVGs - https://www.creativebloq.com/how-to/10-golden-rules-for-responsive-svgs (remove width/height, set viewBox)

### Tertiary (LOW confidence)

- None. All findings verified with primary or secondary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies; everything uses libraries already installed and configured in Phase 10
- Architecture: HIGH - Astro component patterns verified via official docs; section composition is a standard landing page pattern
- Responsive layout: HIGH - Tailwind v4 breakpoints and responsive prefixes verified via official Tailwind docs
- Clipboard API: HIGH - MDN documentation confirms navigator.clipboard.writeText() with secure context requirement
- Bento grid: HIGH - CSS Grid with Tailwind responsive classes is well-documented across multiple sources
- SVG diagram: MEDIUM - Inline SVG best practices are well-known, but the specific diagram design is a creative implementation decision
- Content: HIGH - All landing page content is derived directly from the project's README.md
- 404 page: HIGH - Astro official docs confirm src/pages/404.astro generates 404.html automatically

**Research date:** 2026-02-26
**Valid until:** 2026-03-26 (30 days -- stable stack, no fast-moving dependencies)
