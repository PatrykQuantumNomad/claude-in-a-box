# Phase 10: Foundation & Infrastructure - Research

**Researched:** 2026-02-25
**Domain:** Astro static site generator, Tailwind CSS v4, GitHub Pages deployment, GitHub Actions CI/CD isolation, dark theme design systems
**Confidence:** HIGH

## Summary

Phase 10 establishes the Astro site scaffold in a `site/` subdirectory, deploys it to GitHub Pages at `remotekube.patrykgolabek.dev`, isolates CI/CD pipelines so site changes and infrastructure changes trigger separate workflows, and creates a dark theme design system with defined tokens ready for Phase 11 component development.

The stack is well-established: Astro 5.17.x is stable, Tailwind CSS v4 has native Vite plugin support via `@tailwindcss/vite`, and the `withastro/action@v5` provides turnkey GitHub Pages deployment with monorepo/subdirectory support via its `path` input. The primary complexity is in CI/CD isolation (path filters on two separate workflows) and the design system token architecture (getting the `@theme` directive right for a dark-first approach).

**Primary recommendation:** Scaffold with `npm create astro@latest` using the `minimal` template, add Tailwind CSS v4 via `@tailwindcss/vite`, self-host Inter + JetBrains Mono fonts via Fontsource packages, define the dark theme as CSS custom properties consumed by Tailwind's `@theme` directive, and deploy via `withastro/action@v5` with `path: ./site`.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| astro | 5.17.x | Static site generator | Official latest stable; pre-renders to static HTML, zero JS by default, islands architecture |
| tailwindcss | 4.x | Utility-first CSS framework | CSS-first config via `@theme`, no `tailwind.config.js` needed, native Vite plugin |
| @tailwindcss/vite | 4.x | Tailwind Vite integration | Official plugin for Astro's Vite pipeline; replaces deprecated `@astrojs/tailwind` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @fontsource-variable/inter | latest | Self-hosted Inter variable font | Body text, UI elements -- import in global CSS |
| @fontsource-variable/jetbrains-mono | latest | Self-hosted JetBrains Mono variable font | Code blocks, terminal UI, monospace elements |
| motion | 12.34.x | Scroll-triggered animations (vanilla JS) | Phase 12 scope -- install now or defer; no React dependency needed |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @fontsource-variable/* | Astro experimental fonts API (`experimental.fonts`) | Astro fonts API is experimental since v5.7.0, may change; Fontsource is stable and battle-tested. Recommend Fontsource for now. |
| @fontsource-variable/* | Google Fonts CDN | Sends user data to Google, extra DNS lookup, GDPR concern. Self-hosted is faster and more private. |
| @tailwindcss/vite | @astrojs/tailwind | @astrojs/tailwind is deprecated for Tailwind v4. Do NOT use it. |

**Installation:**

```bash
# In site/ directory
npm create astro@latest . -- --template minimal --no-install
npm install
npm install tailwindcss @tailwindcss/vite
npm install @fontsource-variable/inter @fontsource-variable/jetbrains-mono
```

## Architecture Patterns

### Recommended Project Structure

```
site/
├── public/
│   └── CNAME                    # Custom domain file: remotekube.patrykgolabek.dev
├── src/
│   ├── components/
│   │   ├── sections/            # Landing page sections (Phase 11)
│   │   └── ui/                  # Reusable UI components (Phase 11)
│   ├── layouts/
│   │   └── BaseLayout.astro     # HTML shell, <head>, font imports, global styles
│   ├── pages/
│   │   ├── index.astro          # Landing page (placeholder in Phase 10, content in Phase 11)
│   │   └── 404.astro            # Custom 404 page (Phase 11 scope, stub in Phase 10)
│   └── styles/
│       └── global.css           # Tailwind import, @theme tokens, font imports
├── astro.config.mjs             # Astro + Tailwind vite plugin config
├── package.json
├── package-lock.json            # MUST be committed for CI reproducibility
└── tsconfig.json                # Astro default TypeScript config
```

### Pattern 1: Tailwind CSS v4 Theme via @theme Directive

**What:** Define all design tokens (colors, fonts, spacing) in a single CSS file using Tailwind v4's `@theme` directive. This replaces `tailwind.config.js` entirely.

**When to use:** Always in Tailwind v4 projects. This is the standard approach.

**Example:**

```css
/* site/src/styles/global.css */
/* Source: https://tailwindcss.com/docs/theme */

@import "tailwindcss";

/* Self-hosted fonts */
@import "@fontsource-variable/inter";
@import "@fontsource-variable/jetbrains-mono";

@theme {
  /* Override default fonts */
  --font-sans: "Inter Variable", "Inter", system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", "JetBrains Mono", ui-monospace, monospace;

  /* Dark theme color palette */
  --color-bg-primary: oklch(0.15 0.01 260);
  --color-bg-secondary: oklch(0.20 0.01 260);
  --color-bg-tertiary: oklch(0.25 0.02 260);
  --color-text-primary: oklch(0.95 0.01 260);
  --color-text-secondary: oklch(0.75 0.02 260);
  --color-text-muted: oklch(0.55 0.02 260);
  --color-accent: oklch(0.70 0.15 250);
  --color-accent-hover: oklch(0.75 0.17 250);
  --color-border: oklch(0.30 0.02 260);

  /* Spacing scale (Tailwind v4 multiplier-based) */
  --spacing: 0.25rem;
}
```

**Key insight:** In Tailwind v4, `@theme` variables automatically generate utility classes. Defining `--color-accent` creates `bg-accent`, `text-accent`, `border-accent`, etc. No separate config file needed.

### Pattern 2: Astro Config with Tailwind Vite Plugin + Custom Domain

**What:** Configure Astro with `@tailwindcss/vite` as a Vite plugin and set `site` for the custom domain.

**When to use:** Required for this project.

**Example:**

```javascript
// site/astro.config.mjs
// Source: https://tailwindcss.com/docs/installation/framework-guides/astro
// Source: https://docs.astro.build/en/guides/deploy/github/

import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  // No 'base' needed when using a custom domain
  vite: {
    plugins: [tailwindcss()],
  },
});
```

### Pattern 3: BaseLayout with Font Loading

**What:** Single layout component that wraps all pages with HTML shell, meta tags, and font preloading.

**When to use:** Every page.

**Example:**

```astro
---
// site/src/layouts/BaseLayout.astro
import "../styles/global.css";

interface Props {
  title: string;
  description?: string;
}

const { title, description = "Deploy Claude Code inside your Kubernetes cluster" } = Astro.props;
---

<!doctype html>
<html lang="en" class="dark">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content={description} />
    <title>{title}</title>
  </head>
  <body class="bg-bg-primary text-text-primary font-sans antialiased">
    <slot />
  </body>
</html>
```

### Pattern 4: GitHub Actions Deploy Workflow with Path Filter and Subdirectory

**What:** Dedicated workflow that only triggers on site/ changes, builds from the site/ subdirectory, and deploys to GitHub Pages.

**When to use:** For this project's CI/CD isolation requirement.

**Example:**

```yaml
# .github/workflows/deploy-site.yaml
# Source: https://docs.astro.build/en/guides/deploy/github/
# Source: https://github.com/withastro/action (v5, path input)

name: Deploy Site

on:
  push:
    branches: [main]
    paths:
      - "site/**"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Build Astro site
        uses: withastro/action@v5
        with:
          path: ./site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

### Pattern 5: Existing CI Workflow with paths-ignore

**What:** Add `paths-ignore` to existing CI workflow so it does not trigger on site/ changes.

**When to use:** Required for SITE-04 requirement.

**Example modification to existing `.github/workflows/ci.yaml`:**

```yaml
on:
  push:
    branches: ["*"]
    tags: ["v*"]
    paths-ignore:
      - "site/**"
  pull_request:
    branches: [main]
    paths-ignore:
      - "site/**"
```

**CRITICAL:** You cannot use both `paths` and `paths-ignore` on the same event trigger. The existing CI workflow uses branches, not paths, so adding `paths-ignore` is safe.

### Anti-Patterns to Avoid

- **Using `@astrojs/tailwind` with Tailwind v4:** This integration is deprecated. Use `@tailwindcss/vite` directly.
- **Setting `base` in astro.config with custom domain:** Do NOT set `base: '/claude-in-a-box'` when using a custom domain. The site will be served from root.
- **Google Fonts CDN for font loading:** Adds external dependency, GDPR concern, extra DNS lookup. Self-host via Fontsource.
- **Creating `tailwind.config.js` with Tailwind v4:** Not needed. All configuration goes in CSS via `@theme`.
- **Using `dark:` variant classes:** Since this is a dark-only theme (no light mode toggle), define dark colors as the defaults directly in `@theme`. No `dark:` prefix needed anywhere.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Font self-hosting | Manual @font-face declarations | @fontsource-variable/* packages | Handles subsetting, formats, font-display, variable font axes |
| Tailwind theme config | Custom CSS variables + manual utility mapping | `@theme` directive in Tailwind v4 | Automatically generates utility classes from CSS variables |
| GitHub Pages deployment | Custom build + rsync/push scripts | `withastro/action@v5` + `actions/deploy-pages@v4` | Handles caching, artifact upload, Pages API, environment URLs |
| Responsive spacing/sizing | Manual rem/px calculations | Tailwind spacing utilities with `--spacing` base | Consistent scale, responsive by default |

**Key insight:** Tailwind v4's CSS-first approach means the design system IS the CSS file. No separate token files, no build step for tokens, no JS config. The `@theme` block is the single source of truth.

## Common Pitfalls

### Pitfall 1: Forgetting package-lock.json in CI

**What goes wrong:** `withastro/action` auto-detects the package manager from lockfiles. Without `package-lock.json` committed, it may fall back to wrong defaults or fail.
**Why it happens:** `.gitignore` templates sometimes exclude lockfiles.
**How to avoid:** Ensure `package-lock.json` is committed in the `site/` directory. The action detects npm from this file.
**Warning signs:** CI build fails with "Could not detect package manager" or installs wrong versions.

### Pitfall 2: CNAME File Deleted on Deploy

**What goes wrong:** GitHub Pages custom domain stops working after each deploy because CNAME file is missing from build output.
**Why it happens:** CNAME file not placed in `public/` directory (Astro copies `public/` contents to build output root).
**How to avoid:** Create `site/public/CNAME` containing `remotekube.patrykgolabek.dev`. This file gets copied to `dist/` during build.
**Warning signs:** Site works at `<user>.github.io/<repo>` but not at custom domain after deploy.

### Pitfall 3: Both Workflows Triggering on Same Push

**What goes wrong:** A push that touches both `site/` and other files triggers both workflows, or path filters are misconfigured.
**Why it happens:** Incorrect glob patterns, or forgetting to add `paths-ignore` to the existing CI workflow.
**How to avoid:** Deploy workflow uses `paths: ["site/**"]`. CI workflow uses `paths-ignore: ["site/**"]`. Test with a commit that only touches site files and verify only deploy runs.
**Warning signs:** Both workflows appear in the Actions tab for the same commit.

### Pitfall 4: GitHub Pages Source Not Set to "GitHub Actions"

**What goes wrong:** Deploy workflow succeeds (builds and uploads artifact) but site is not published.
**Why it happens:** GitHub Pages defaults to "Deploy from a branch" source. Must be manually changed to "GitHub Actions" in repo Settings > Pages.
**How to avoid:** This is documented as a manual prerequisite. Must be done before first deploy.
**Warning signs:** Workflow shows green but site returns 404 at the custom domain.

### Pitfall 5: DNS CNAME Not Created Before Deploy

**What goes wrong:** Site deploys but custom domain returns DNS error.
**Why it happens:** DNS CNAME record for `remotekube.patrykgolabek.dev` not created at DNS provider.
**How to avoid:** Create CNAME record pointing `remotekube.patrykgolabek.dev` to `<username>.github.io` BEFORE the first deploy. DNS propagation can take up to 24 hours. The "Enforce HTTPS" option may not be available for up to 24 hours after DNS propagation.
**Warning signs:** `dig remotekube.patrykgolabek.dev` returns NXDOMAIN or wrong target.

### Pitfall 6: Docker Build Context Including site/ Directory

**What goes wrong:** Docker builds become slower as site/ grows with node_modules and build artifacts. Image may bloat.
**Why it happens:** `.dockerignore` not updated to exclude `site/`.
**How to avoid:** Add `site/` to `.dockerignore`. This is a one-line change.
**Warning signs:** Docker build is unexpectedly slow or image size increases.

### Pitfall 7: Tailwind v4 Font Variable Scoping

**What goes wrong:** Font utilities like `font-sans` and `font-mono` don't apply custom fonts, falling back to system defaults.
**Why it happens:** Using `var()` references in `@theme` without the `inline` keyword.
**How to avoid:** When referencing CSS variables inside `@theme`, use `@theme inline { ... }` to ensure the resolved value is used in utilities, not the variable reference.
**Warning signs:** Inspecting element in DevTools shows `font-family: var(--font-inter)` literally instead of the resolved font stack.

## Code Examples

Verified patterns from official sources:

### Astro Project Initialization

```bash
# Source: https://docs.astro.build/en/install-and-setup/
cd site/
npm create astro@latest . -- --template minimal --no-install
npm install
```

The `minimal` template provides the cleanest starting point: single page, no integrations, no sample content.

### Tailwind CSS v4 Setup in Astro

```javascript
// site/astro.config.mjs
// Source: https://tailwindcss.com/docs/installation/framework-guides/astro

import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  vite: {
    plugins: [tailwindcss()],
  },
});
```

```css
/* site/src/styles/global.css */
/* Source: https://tailwindcss.com/docs/installation/framework-guides/astro */

@import "tailwindcss";
@import "@fontsource-variable/inter";
@import "@fontsource-variable/jetbrains-mono";

@theme {
  --font-sans: "Inter Variable", "Inter", system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", "JetBrains Mono", ui-monospace, monospace;
}
```

### CNAME File for Custom Domain

```
remotekube.patrykgolabek.dev
```

File location: `site/public/CNAME` (no trailing newline, just the domain)

### .dockerignore Addition

```
# Existing .dockerignore content...
site/
```

### Placeholder Index Page with Dark Theme

```astro
---
// site/src/pages/index.astro
import BaseLayout from "../layouts/BaseLayout.astro";
---

<BaseLayout title="RemoteKube - Claude Code in Your Cluster">
  <main class="min-h-screen flex items-center justify-center">
    <div class="text-center space-y-4">
      <h1 class="text-4xl font-bold text-text-primary">
        RemoteKube
      </h1>
      <p class="text-lg text-text-secondary font-mono">
        Deploy once, control from anywhere
      </p>
    </div>
  </main>
</BaseLayout>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@astrojs/tailwind` integration | `@tailwindcss/vite` Vite plugin | Tailwind v4 / Astro 5.2 (Jan 2025) | Old integration is deprecated; do not use for new projects |
| `tailwind.config.js` for theme | `@theme` directive in CSS | Tailwind v4 (Jan 2025) | All config lives in CSS, no JS config file |
| Google Fonts `<link>` tags | Self-hosted via Fontsource or Astro fonts API | Ongoing trend, Astro fonts API in v5.7.0 | Better performance, privacy, no GDPR concern |
| `withastro/action@v3` | `withastro/action@v5` | v5 released 2025 | Improved caching, Node 22 default, better monorepo support |
| `actions/checkout@v4` | `actions/checkout@v4` (current) / `@v5` available | v5 exists but v4 is widely used | Either works; v4 is battle-tested |

**Deprecated/outdated:**
- `@astrojs/tailwind`: Deprecated for Tailwind v4. Use `@tailwindcss/vite` instead.
- `tailwind.config.js` / `tailwind.config.mjs`: Not needed with Tailwind v4 CSS-first config.
- `withastro/action@v3`: Superseded by v5. Use v5.

## Open Questions

1. **Color palette exact values**
   - What we know: Dark theme with blue/purple accent tones is standard for DevOps/developer tools
   - What's unclear: Exact oklch values for the color palette need to be finalized during implementation
   - Recommendation: Define a small, intentional palette (3 backgrounds, 3 text levels, 1-2 accents, 1 border) and iterate visually. The `@theme` approach makes this trivially changeable.

2. **Astro experimental fonts API vs Fontsource packages**
   - What we know: Astro's `experimental.fonts` API (v5.7.0+) provides built-in font optimization with preloading and fallback generation. Fontsource packages are stable and proven.
   - What's unclear: Whether the experimental API is stable enough for production use (it has been experimental for ~10 months now)
   - Recommendation: Use Fontsource packages for stability. The experimental API can be adopted later if it stabilizes. Both approaches produce self-hosted fonts.

3. **Motion.js installation timing**
   - What we know: Motion 12.34.x is needed for Phase 12 (scroll animations). It has no React dependency.
   - What's unclear: Whether to install it in Phase 10 (infrastructure) or Phase 12 (when actually used)
   - Recommendation: Defer to Phase 12. Keep Phase 10 minimal. Installing unused dependencies adds noise.

4. **Initial deploy workflow trigger**
   - What we know: The deploy workflow uses `paths: ["site/**"]` which means it only triggers when site files change. The first commit creating the entire site/ directory will trigger it.
   - What's unclear: Whether the workflow needs `workflow_dispatch` as a backup trigger
   - Recommendation: Include `workflow_dispatch` for manual triggering during setup/debugging. It costs nothing and provides a safety valve.

## Sources

### Primary (HIGH confidence)

- Astro official docs: Install and Setup - https://docs.astro.build/en/install-and-setup/
- Astro official docs: Deploy to GitHub Pages - https://docs.astro.build/en/guides/deploy/github/
- Tailwind CSS official docs: Install with Astro - https://tailwindcss.com/docs/installation/framework-guides/astro
- Tailwind CSS official docs: Theme Variables (@theme directive) - https://tailwindcss.com/docs/theme
- withastro/action GitHub repo (v5, `path` input for subdirectories) - https://github.com/withastro/action
- GitHub Actions docs: paths/paths-ignore filters - https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions
- GitHub Pages docs: Custom domains - https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site
- Motion GitHub repo (vanilla JS usage confirmed) - https://github.com/motiondivision/motion

### Secondary (MEDIUM confidence)

- Fontsource JetBrains Mono - https://fontsource.org/fonts/jetbrains-mono/install
- Astro experimental fonts API docs - https://docs.astro.build/en/reference/experimental-flags/fonts/
- Astro blog: Astro 5.2 (Tailwind v4 support) - https://astro.build/blog/astro-520/

### Tertiary (LOW confidence)

- None. All findings verified with primary or secondary sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified via official docs, versions confirmed via npm/search, Astro + Tailwind v4 integration documented on both official sites
- Architecture: HIGH - Project structure follows Astro conventions, deploy workflow matches official Astro + GitHub Pages guide, path filters documented in GitHub Actions docs
- Pitfalls: HIGH - Each pitfall is derived from official documentation caveats (CNAME placement, path filter limitations, Pages source setting, lockfile detection)
- Design system: MEDIUM - The `@theme` approach is well-documented, but exact color values and spacing scale are implementation choices that need visual iteration

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (30 days -- stable stack, no fast-moving dependencies)
