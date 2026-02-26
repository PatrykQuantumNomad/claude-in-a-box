# Stack Research

**Domain:** Astro landing page for existing Kubernetes DevOps tool (Claude In A Box)
**Researched:** 2026-02-25
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Astro | 5.17.x (latest 5.17.3) | Static site generator / framework | Production-stable. Astro 6 is in beta (announced Jan 2026) but not ready for production. Astro 5 ships zero JavaScript by default -- perfect for a landing page that is pure content + styling. Static HTML output means instant page loads and excellent SEO. Built on Vite for fast dev experience. Requires Node.js >=20.3.0 or >=22.0.0. |
| Tailwind CSS | 4.2.x (latest 4.2.1) | Utility-first CSS framework | v4 is a ground-up rewrite with CSS-first configuration (no more `tailwind.config.js`). Uses `@tailwindcss/vite` plugin directly in Astro's Vite config -- the old `@astrojs/tailwind` integration is deprecated for v4. New color palettes (mauve, olive, mist, taupe) added in 4.2.0 (Feb 19, 2026). Rapid styling without writing custom CSS. |
| TypeScript | Bundled with Astro | Type safety | Astro includes TypeScript support out of the box. Use `"extends": "astro/tsconfigs/strict"` in tsconfig.json. No separate install needed. |
| Sharp | Bundled with Astro | Image optimization at build time | Astro's default image service. Automatically converts images to WebP, generates `srcset` for responsive images, and optimizes quality. Runs at build time for static sites -- zero runtime cost. No separate install needed; Astro auto-installs it. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| motion | 12.34.x | Scroll-triggered animations | Use for hero entrance animations, feature card reveals, scroll-based transitions. Works as vanilla JavaScript in Astro `<script>` tags -- no React needed. Import `animate`, `inView`, `stagger` from `motion`. Lazy-loadable features keep bundle under 5kb. |
| @astrojs/sitemap | 3.7.x | SEO sitemap generation | Always include for a public landing page. Auto-generates `sitemap-index.xml` at build time. Requires `site` to be set in `astro.config.mjs`. |
| astro-icon | 1.1.5 | SVG icon management | Use for DevOps tool icons, feature icons, social links. Server-rendered to static HTML (zero runtime JS). Supports Iconify icon sets and custom local SVGs. Auto-optimizes with svgo. |
| @iconify-json/lucide | Latest | Icon set for astro-icon | Lucide provides clean, consistent icons well-suited for developer tools. Covers terminal, cloud, shield, settings, and other DevOps-relevant glyphs. Only the icons you use are included in the build. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Astro VS Code Extension | Syntax highlighting, type checking for `.astro` files | Official extension: `astro-build.astro-vscode`. Provides IntelliSense, formatting, and error detection in `.astro` components. |
| Prettier + prettier-plugin-astro | Code formatting | `npm install -D prettier prettier-plugin-astro`. Add `"plugins": ["prettier-plugin-astro"]` to `.prettierrc`. |

## GitHub Pages Deployment

### Workflow Configuration

The landing page deploys via a **separate** GitHub Actions workflow from the existing CI pipeline (`ci.yaml`). This is correct because the triggers, permissions, and purposes are entirely different.

**File:** `.github/workflows/deploy-pages.yaml`

```yaml
name: Deploy Landing Page

on:
  push:
    branches: [main]
    paths:
      - 'site/**'           # Only trigger when landing page files change
      - '.github/workflows/deploy-pages.yaml'
  workflow_dispatch:         # Allow manual deploys

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false  # Never cancel an in-progress deploy

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Build and upload
        uses: withastro/action@v5
        with:
          path: ./site        # Astro project lives in site/ subdirectory
          node-version: 22    # Matches Astro 5.x requirement

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

### Astro Configuration for Custom Domain

**File:** `site/astro.config.mjs`

```javascript
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";
import icon from "astro-icon";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  // No `base` needed -- custom domain serves from root
  integrations: [sitemap(), icon()],
  vite: {
    plugins: [tailwindcss()],
  },
});
```

### Custom Domain Setup

1. Create `site/public/CNAME` with content: `remotekube.patrykgolabek.dev`
2. Configure DNS: CNAME record `remotekube` pointing to `<username>.github.io`
3. In GitHub repo Settings > Pages > Custom domain: enter `remotekube.patrykgolabek.dev`
4. Enable "Enforce HTTPS" in GitHub Pages settings

### withastro/action@v5 Features

| Parameter | Value | Why |
|-----------|-------|-----|
| `path` | `./site` | Astro project in subdirectory, not repo root |
| `node-version` | `22` | Matches Astro 5.x LTS requirement (Node 22 Active LTS) |
| `cache` | `true` (default) | Caches `node_modules/.astro` for faster image re-processing |
| `package-manager` | auto-detected | Action reads lockfile. Use npm for simplicity. |

## Project Structure

```
claude-in-a-box/
  .github/workflows/
    ci.yaml                  # Existing -- Docker/Helm/K8s CI (UNCHANGED)
    deploy-pages.yaml        # NEW -- landing page deployment
  site/                      # NEW -- Astro landing page project
    astro.config.mjs
    package.json
    tsconfig.json
    src/
      layouts/
        BaseLayout.astro
      pages/
        index.astro
      components/
        Hero.astro
        Features.astro
        QuickStart.astro
        Footer.astro
      styles/
        global.css           # @import "tailwindcss";
      assets/                # Optimized images (processed by Sharp at build)
    public/
      CNAME                  # remotekube.patrykgolabek.dev
      favicon.svg
```

The `site/` subdirectory keeps the landing page cleanly separated from the core DevOps tooling (Docker, Helm, K8s manifests, shell scripts). The existing CI pipeline is unaffected.

## Installation

```bash
# Create the Astro project in site/ subdirectory
npm create astro@latest site -- --template minimal --typescript strict

# Navigate to the site directory
cd site

# Core dependencies
npm install astro tailwindcss @tailwindcss/vite

# Integrations
npm install @astrojs/sitemap astro-icon @iconify-json/lucide

# Animation (lightweight, vanilla JS)
npm install motion

# Dev dependencies
npm install -D prettier prettier-plugin-astro
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Astro 5.17.x (stable) | Astro 6 beta | Only after v6.0 stable release. Beta dropped Node 18/20 support and upgraded to Zod 4. No reason to risk beta instability on a landing page that needs to "just work." |
| Tailwind CSS v4 via `@tailwindcss/vite` | `@astrojs/tailwind` integration | Never for new projects. `@astrojs/tailwind` is deprecated for Tailwind v4. It only supports Tailwind v3. |
| Tailwind CSS v4 | Vanilla CSS / CSS Modules | If the team has no Tailwind experience and the page has fewer than 3 sections. For a full landing page, Tailwind's utility classes are significantly faster to build with. |
| motion (vanilla JS) | Framer Motion (React) | Only if you are already using React islands extensively. motion works without React in Astro's `<script>` tags. Adding React as a dependency for animations alone is wasteful. |
| motion (vanilla JS) | GSAP | Only if you need timeline-based cinematic animations (parallax scenes, SVG morphing). GSAP is heavier and has a commercial license for premium plugins. A landing page does not need this. |
| motion (vanilla JS) | CSS-only animations (`animation-timeline`, `scroll-timeline`) | If you want zero JS dependencies for animation. CSS scroll-driven animations are available in Chromium browsers but lack Firefox/Safari support as of Feb 2026. Progressive enhancement only. |
| motion (vanilla JS) | AOS (Animate On Scroll) | Never for new projects. AOS is unmaintained (last update 2021) and bundles jQuery-era patterns. motion is smaller and more capable. |
| npm | pnpm / bun | If you prefer faster installs or disk efficiency. Both work with `withastro/action@v5` (auto-detected from lockfile). npm is chosen here for simplicity -- this is a single landing page, not a monorepo. |
| `site/` subdirectory | Separate repository | If the landing page team is different from the core product team. For a solo/small team, keeping it in the same repo simplifies CI and deployment. Separate repo means separate GitHub Pages config. |
| GitHub Pages | Cloudflare Pages | If you want edge-side rendering, analytics, or Web Analytics. GitHub Pages is free, already integrated with the repo, and sufficient for a static landing page. Astro recently joined Cloudflare, so Cloudflare Pages may become the preferred Astro host long-term -- but that does not change anything for a static site today. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `@astrojs/tailwind` | Deprecated for Tailwind v4. Only works with Tailwind v3. Will not receive updates. | `@tailwindcss/vite` plugin added directly to Astro's Vite config. |
| `@astrojs/react` (for animations only) | Adds React as a dependency (~45kb min+gzip). Requires `client:*` directives for hydration. Unnecessary complexity for scroll animations. | `motion` package with vanilla JS in `<script>` tags. |
| `tailwind.config.js` / `tailwind.config.mjs` | Tailwind v4 uses CSS-first configuration. Config files are v3 patterns. | Configure in `global.css` using `@theme` blocks. |
| Astro 6 beta | Beta software. Breaking changes (Node 22+ only, Zod 4). Not production-ready. | Astro 5.17.x (stable). Upgrade when v6.0 stable ships. |
| `@astrojs/image` (old package) | Deprecated since Astro 3.0. Replaced by built-in `astro:assets`. | Use `<Image />` and `<Picture />` from `astro:assets`. Ships with Astro -- nothing to install. |
| Heavy animation frameworks (GSAP, Three.js, Lottie) | Overkill for a landing page. Adds significant bundle weight and complexity. A DevOps tool landing page is not a creative agency portfolio. | `motion` for tasteful scroll reveals. CSS transitions for hover effects. |
| React/Vue/Svelte UI component libraries | A landing page does not need component framework hydration. Every island adds JS weight. Astro components render to static HTML with zero JS. | Pure `.astro` components with Tailwind classes. |
| Google Fonts via `<link>` tag | Render-blocking, GDPR concerns (sends visitor IP to Google). | Self-host fonts in `public/fonts/`. Use `@font-face` in CSS. Or use system font stack (`font-sans` in Tailwind). |

## Stack Patterns by Variant

**If building a simple landing page (1-5 sections, no blog):**
- Use the minimal Astro template (`--template minimal`)
- Single `index.astro` page with section components
- No content collections, no MDX, no dynamic routes
- This is the recommended approach for Claude In A Box

**If adding a blog or docs later:**
- Add `@astrojs/mdx` integration for MDX content
- Use Astro Content Collections for type-safe markdown
- Consider Astro Starlight for documentation specifically
- This can be added incrementally -- it does not affect the initial landing page

**If the page needs interactivity beyond animations:**
- Add `@astrojs/react` only for specific interactive islands
- Use `client:visible` directive so components load only when scrolled into view
- Keep the number of islands minimal (1-2 max for a landing page)

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Astro 5.17.x | Node.js >=20.3.0 or >=22.0.0 | Node 22 is Active LTS (recommended). Node 19, 21 are NOT supported. |
| Tailwind CSS 4.2.x | `@tailwindcss/vite` 4.2.x | Must use matching versions. Install both: `npm install tailwindcss @tailwindcss/vite`. |
| `@astrojs/sitemap` 3.7.x | Astro 5.x | Peer dependency on Astro. Version is auto-managed by `npx astro add sitemap`. |
| `astro-icon` 1.1.5 | Astro 3+ | Works with Astro 5.x. Requires `@iconify-json/*` packages for icon sets. |
| `withastro/action` v5.2.0 | Node.js 22 (default) | Supports npm, yarn, pnpm, bun, deno. Auto-detects from lockfile. |
| `actions/deploy-pages` v4 | GitHub Pages (Actions source) | Requires GitHub Pages to be configured with "GitHub Actions" as the source. |
| motion 12.34.x | Any (vanilla JS) | No framework dependency for vanilla JS usage. Only needs React for React-specific APIs. |
| Existing CI (`ci.yaml`) | Unaffected | Landing page workflow triggers only on `site/**` path changes. No conflict. |

## Sources

- [Astro 6 Beta Announcement](https://astro.build/blog/astro-6-beta/) -- confirmed v6 is beta, v5 is stable (HIGH confidence)
- [Astro GitHub Releases](https://github.com/withastro/astro/releases) -- verified v5.17.3 as latest stable (HIGH confidence)
- [Astro npm Package](https://www.npmjs.com/package/astro) -- verified v5.17.3, published Feb 2026 (HIGH confidence)
- [Astro GitHub Pages Deploy Guide](https://docs.astro.build/en/guides/deploy/github/) -- verified workflow YAML, `withastro/action@v5`, CNAME setup (HIGH confidence)
- [withastro/action GitHub Repo](https://github.com/withastro/action) -- verified v5.2.0, all parameters (path, node-version, cache, out-dir) (HIGH confidence)
- [withastro/action Releases](https://github.com/withastro/action/releases) -- verified v5.2.0 released Feb 11, 2025 (HIGH confidence)
- [Tailwind CSS v4 Astro Installation Guide](https://tailwindcss.com/docs/installation/framework-guides/astro) -- verified `@tailwindcss/vite` setup, CSS-first config (HIGH confidence)
- [Tailwind CSS GitHub Releases](https://github.com/tailwindlabs/tailwindcss/releases) -- verified v4.2.1 (Feb 2026), v4.2.0 new features (HIGH confidence)
- [Astro Tailwind Integration Docs](https://docs.astro.build/en/guides/integrations-guide/tailwind/) -- confirmed `@astrojs/tailwind` deprecated for v4 (HIGH confidence)
- [Motion.dev](https://motion.dev) -- verified vanilla JS API, npm package `motion` v12.34.3 (HIGH confidence)
- [Motion with Astro Guide (Netlify)](https://developers.netlify.com/guides/motion-animation-library-with-astro/) -- verified `animate`, `inView`, `stagger` usage in Astro `<script>` tags without React (HIGH confidence)
- [Astro Images Documentation](https://docs.astro.build/en/guides/images/) -- verified built-in `<Image />`, Sharp default service, WebP output (HIGH confidence)
- [@astrojs/sitemap Documentation](https://docs.astro.build/en/guides/integrations-guide/sitemap/) -- verified v3.7.0, `site` requirement (HIGH confidence)
- [astro-icon Documentation](https://www.astroicon.dev/) -- verified v1.1.5, Iconify support, zero runtime JS (HIGH confidence)
- [Astro TypeScript Docs](https://docs.astro.build/en/guides/typescript/) -- verified strict/strictest templates (HIGH confidence)
- [GitHub Pages Custom Domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) -- verified CNAME DNS setup (HIGH confidence)

---
*Stack research for: Claude In A Box -- Astro Landing Page*
*Researched: 2026-02-25*
