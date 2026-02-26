# Project Research Summary

**Project:** Claude In A Box — Astro Landing Page
**Domain:** Static marketing landing page for an open-source Kubernetes DevOps tool
**Researched:** 2026-02-25
**Confidence:** HIGH

## Executive Summary

Claude In A Box is an open-source DevOps tool that runs containerized Claude Code inside a Kubernetes cluster, providing phone-first remote cluster access via Anthropic's relay infrastructure. The landing page at `remotekube.patrykgolabek.dev` is a single-page marketing site whose job is to communicate this value proposition and drive visitors to the GitHub repo. Research across 100+ developer tool landing pages confirms the dominant 2026 pattern: dark-themed, centered hero with a bold headline, feature bento grid, copy-paste quickstart, and a clean footer. This page should follow that pattern while leaning into the product's unique visual hook — the phone-to-cluster data flow — as the signature hero visual.

The recommended stack is Astro 5.17.x (stable, zero JS by default) with Tailwind CSS v4 via `@tailwindcss/vite` (not the deprecated `@astrojs/tailwind` integration), deployed to GitHub Pages via the official `withastro/action@v5`. The Astro project lives in a `site/` subdirectory, completely isolated from the existing Docker/Helm/Kubernetes tooling. A separate `deploy-site.yaml` workflow with path filtering ensures the existing CI pipeline is never triggered by site-only changes and vice versa. This isolation is non-negotiable — mixing the two build systems creates maintenance debt and wasted CI minutes.

The most dangerous pitfalls are all concentrated in Phase 1 setup: custom domain configuration is uniquely fragile on GitHub Pages (the CNAME file in `site/public/` must be present in every deployment artifact or the domain resets), the Pages source must be manually switched to "GitHub Actions" before the first deploy, and the Astro `site` config must not include a `base` setting when using a custom domain. All eight critical pitfalls documented in research are preventable at setup time with correct configuration. None require architectural changes once the foundation is correct.

## Key Findings

### Recommended Stack

Astro 5.17.x is the right choice: it generates zero JavaScript by default (ideal for a content-only landing page), ships built-in image optimization via Sharp, and has the most mature GitHub Pages deployment story of any static site framework. Astro 6 is in beta as of Feb 2026 and should not be used — it dropped Node 18/20 support and has breaking changes that are not worth absorbing for a landing page. Tailwind CSS v4 changes the integration model entirely: configure it via `@tailwindcss/vite` directly in Astro's Vite config and use CSS-first `@theme` blocks instead of `tailwind.config.js`. The old `@astrojs/tailwind` integration is deprecated and does not support v4. For animations, `motion` (vanilla JS, v12.34.x) is the correct choice — it works in Astro `<script>` tags without React, stays under 5kb for the APIs needed (animate, inView, stagger), and is actively maintained.

**Core technologies:**
- Astro 5.17.x: static site generator — zero JS output, Vite-based, excellent GitHub Pages support
- Tailwind CSS 4.2.x + `@tailwindcss/vite`: utility CSS — v4 CSS-first config, no `tailwind.config.js` needed
- TypeScript (bundled): type safety — use `"extends": "astro/tsconfigs/strict"` preset
- Sharp (bundled): image optimization — auto-converts to WebP at build time, zero runtime cost
- motion 12.34.x: scroll animations — vanilla JS, no React dependency, lazy-loadable
- `@astrojs/sitemap` 3.7.x: SEO sitemap — required for public-facing page, needs `site` set in config
- `astro-icon` 1.1.5 + `@iconify-json/lucide`: icons — server-rendered to static HTML, zero JS runtime
- `withastro/action@v5`: CI/CD — official Astro GitHub Action, supports `path: ./site` for subdirectory projects

**What not to use:** `@astrojs/tailwind` (deprecated for v4), `@astrojs/react` for animations only (adds 45kb for no reason), Astro 6 beta, `tailwind.config.js` (v3 pattern), `@astrojs/image` (deprecated since Astro 3), Google Fonts via `<link>` tag (GDPR and render-blocking).

### Expected Features

Competitor analysis (Warp, Linear, Railway, Coolify, K9s, Lens, Charm) and the Evil Martians study of 100 dev tool pages establishes clear expectations for what this page needs.

**Must have (table stakes — page feels incomplete without these):**
- Hero section with bold centered headline, subheadline, and two CTAs (GitHub + Quickstart)
- Feature bento grid (5-6 cards, asymmetric layout) — Remote Control gets the large card
- Architecture diagram — the phone-to-cluster flow is the product's "aha moment" and must be visual
- Quickstart terminal code block — copy-paste Helm commands; this is the primary conversion point
- Use cases section — 3-4 concrete scenario cards (on-call, deploy failure, cluster exploration, incident)
- Footer with GitHub, docs, license links
- Dark theme with electric cyan/blue accent — DevOps audiences expect dark; light themes read as non-technical
- Responsive layout — ironic to have a broken mobile experience for a phone-first product
- GitHub stars badge — minimal real social proof; no testimonials at v1.0, no fake metrics

**Should have (differentiators that elevate the page):**
- Animated architecture diagram SVG — CSS `stroke-dashoffset` animation showing connection establishing
- Bento grid asymmetry — larger card for Remote Control vs equal-size cards for supporting features
- Eyebrow text above headline — version badge or "Open Source" pill; common in top dev tool pages
- Gradient glow hover effects on cards — CSS `box-shadow` with accent color at 20% opacity
- Typing animation on quickstart — CSS `@keyframes` typing effect with blinking cursor

**Defer to v1.x (add after page is live and stable):**
- Animated architecture diagram (static SVG is fine for launch)
- Phone + Cluster split hero visual (base hero first)
- Dynamic GitHub stats (live star count, Docker pulls)
- Asciinema/GIF demo embed

**Do not build at all:**
- Pricing section (free OSS tool — looks confused or suspicious)
- Blog/changelog (no posts = looks abandoned)
- Live interactive demo (requires always-on infrastructure)
- Testimonials at v1.0 (no real users yet; fake ones destroy credibility)
- Newsletter signup (DevOps engineers are allergic to email capture)
- Video hero (bandwidth cost, disabled on mobile)

**Design system:**
- Background: `#0a0a0a`, Surface: `#141414`, Border: `#1f1f1f`
- Text primary: `#ededed`, Text secondary: `#888888`
- Accent: `#00d4ff` (electric cyan — distinct from Railway's/Coolify's purple ownership)
- Code color: `#22c55e` (terminal green)
- Typography: Inter (display + body), JetBrains Mono (code)

### Architecture Approach

The architecture answer is complete isolation. The Astro project lives entirely in `site/` at the repo root — mirroring the existing convention of top-level directories per concern (`docker/`, `helm/`, `k8s/`). The `site/` directory has its own `package.json` and lockfile; nothing is shared with the repo root. Two separate workflow files handle the two separate concerns: `ci.yaml` (existing, add `paths-ignore: ['site/**']`) and `deploy-site.yaml` (new, `paths: ['site/**']`). This means a Dockerfile change never triggers an Astro build, and a landing page text change never triggers Docker builds, Trivy scans, Helm lint, or KIND integration tests. `.dockerignore` must add `site/` to prevent `node_modules/` (200+ MB) from entering Docker build context.

**Major components:**
1. `site/src/layouts/Base.astro` — HTML shell with `<head>`, meta tags, Open Graph tags; imports global.css
2. `site/src/pages/index.astro` — landing page entry point; imports layout and all section components
3. `site/src/components/Hero.astro` — headline, subheadline, two CTAs, hero visual
4. `site/src/components/Features.astro` — bento grid with 5-6 feature cards
5. `site/src/components/Architecture.astro` — SVG diagram: phone -> relay -> cluster
6. `site/src/components/QuickStart.astro` — terminal code block with copy button
7. `site/src/components/UseCases.astro` — 3-4 scenario cards (on-call, deploy, explore, incident)
8. `site/src/components/Footer.astro` — GitHub, docs, license, author attribution
9. `.github/workflows/deploy-site.yaml` — build + deploy to GitHub Pages (separate from CI)

**Build order:** Foundation (configs, CNAME, npm install) -> Layout + styles -> Components -> Page assembly -> CI/CD integration

### Critical Pitfalls

All critical pitfalls are Phase 1 setup issues. Get Phase 1 right and the rest of the project is straightforward.

1. **CNAME file deleted on every deployment** — Create `site/public/CNAME` containing exactly `remotekube.patrykgolabek.dev` (no trailing newline, no protocol). Astro copies `public/` to `dist/` automatically. Without this file in the artifact, GitHub Pages resets the custom domain on every deployment. This is the single most-reported GitHub Pages issue.

2. **GitHub Pages source not set to "GitHub Actions"** — Before the first deploy, manually set Settings > Pages > Source to "GitHub Actions." The `actions/deploy-pages` action requires this; without it the deploy silently produces no result or fails with a permissions error. Document this as a one-time setup prerequisite.

3. **`base` config set when using custom domain** — Set only `site: 'https://remotekube.patrykgolabek.dev'` in `astro.config.mjs`. Never set `base` for a custom domain deployment. `base` is for subpath deployments like `username.github.io/repo-name`. Setting it breaks every asset path and internal link.

4. **Deploy workflow triggers on all pushes** — Add `paths: ['site/**']` to `deploy-site.yaml` and `paths-ignore: ['site/**']` to `ci.yaml`. Without path filtering, every Helm or Dockerfile commit triggers a full Astro build and Pages deployment.

5. **Wrong DNS record type for subdomain** — `remotekube.patrykgolabek.dev` requires a CNAME record pointing to `<username>.github.io.` — not an A record, not a path-suffixed value. Enable "Enforce HTTPS" only after the DNS check shows green (certificate provisioning takes up to 1 hour).

6. **`withastro/action` `path` parameter missing** — Set `path: ./site` in the workflow. Without it, the action looks for `package.json` at the repo root (finding none), and the build fails with a confusing lockfile detection error.

7. **`id-token: write` permission missing from deploy workflow** — The deploy workflow needs `contents: read`, `pages: write`, and `id-token: write`. The last one is unusual and often missed. Without it, `actions/deploy-pages` fails with a cryptic permissions error. Do not add this to the existing CI workflow.

8. **No 404.astro page** — Create `site/src/pages/404.astro`. GitHub Pages serves a custom `404.html` if present in the deployment artifact. Without it, users who follow a broken link see the default GitHub 404 page with no project branding.

## Implications for Roadmap

Based on the dependency structure and pitfall distribution, a 3-phase approach is optimal. Phase 1 is a pure setup phase — it has zero deliverable content but gates everything else. Phase 2 builds all P1 content. Phase 3 adds P2 polish.

### Phase 1: Foundation and Infrastructure

**Rationale:** Seven of the eight critical pitfalls are Phase 1 configuration errors. If setup is correct, the rest is mechanical component building. If setup is wrong, every subsequent push breaks something (wrong domain, broken assets, wasted CI runs). Resolve all ambiguity before writing a single line of Astro component code.

**Delivers:** A deployable Astro scaffold that produces a working page at `remotekube.patrykgolabek.dev`, with correct custom domain, correct CI/CD isolation, and correct config — even if the page content is a placeholder.

**Addresses:**
- Astro project scaffold in `site/` subdirectory with own `package.json`
- `astro.config.mjs` with `site` set, no `base`, Tailwind via `@tailwindcss/vite`, sitemap and icon integrations
- `site/public/CNAME` with correct domain (prevents custom domain reset)
- `.github/workflows/deploy-site.yaml` with `path: ./site`, `paths: ['site/**']`, correct permissions including `id-token: write`, concurrency group
- `.github/workflows/ci.yaml` patched with `paths-ignore: ['site/**']`
- `.dockerignore` updated to exclude `site/`
- GitHub repo Settings > Pages source set to "GitHub Actions" (manual step, documented)
- DNS CNAME record created and verified (manual step, documented)
- HTTPS enforcement enabled after certificate provisioning
- Domain verification in GitHub account settings
- `tsconfig.json` extending Astro strict preset

**Avoids:** CNAME deletion (Pitfall 1), Pages source misconfiguration (Pitfall 2), site/base misconfiguration (Pitfall 3), deploy triggers on all pushes (Pitfall 4), DNS misconfiguration (Pitfall 6), withastro/action path error (Pitfall 7), permissions conflict (Pitfall 5)

**Research flag:** Standard patterns, well-documented — skip `/gsd:research-phase`

---

### Phase 2: Content and Components

**Rationale:** With infrastructure correct, all content work is independent of deployment concerns. Components can be built in dependency order (layout -> sections -> page) and verified locally with `astro dev`. All P1 features from FEATURES.md belong here. Content gates visuals — write copy first, then build components around it.

**Delivers:** The complete landing page with all table-stakes sections: hero, feature bento grid, architecture diagram, quickstart, use cases, footer. Full responsive layout. Dark theme with electric cyan design system.

**Addresses:**
- `Base.astro` layout with Open Graph meta tags (og:title, og:description, og:image)
- `Hero.astro` — eyebrow badge, bold headline, subheadline, two CTAs, hero visual
- `Features.astro` — asymmetric bento grid (1 large + 1 medium + 3 small cards), Lucide icons
- `Architecture.astro` — static SVG diagram: phone icon -> relay cloud -> Kubernetes cluster
- `QuickStart.astro` — terminal-styled dark code block, JetBrains Mono, copy-to-clipboard button
- `UseCases.astro` — 3-4 scenario cards (weekend on-call, deploy gone wrong, cluster exploration, incident response)
- `Footer.astro` — GitHub, docs, license, author attribution
- `404.astro` — custom 404 page matching site design
- `global.css` — Tailwind directives, design tokens (`@theme` block), color palette
- GitHub stars badge via shields.io

**Uses:** Astro components, Tailwind v4, `astro-icon` + `@iconify-json/lucide`, `astro:assets` for image optimization

**Avoids:** Missing 404 page (Pitfall 8), missing OG tags (UX pitfall), missing mobile responsiveness

**Research flag:** Standard patterns for all sections except the architecture diagram SVG — the SVG component is custom and may need a brief design iteration. No research phase needed; patterns are well-established.

---

### Phase 3: Animation and Polish

**Rationale:** P2 features add delight without blocking launch. Build after the page is live and confirmed working at the custom domain. Scroll-triggered animations require testing across browsers and devices; doing this before the base page is verified adds risk.

**Delivers:** Scroll-triggered entrance animations, animated architecture diagram, gradient glow hover effects, typing animation on quickstart terminal. Elevates the page from "functional" to "memorable."

**Addresses:**
- `motion` integration for scroll-triggered card reveals (`inView`, `stagger`)
- Hero section entrance animation
- Architecture diagram animated SVG — CSS `stroke-dashoffset` animation on connection lines, pod pulse
- Gradient glow hover effects on feature cards — `box-shadow` with accent color
- Typing animation on quickstart code block — CSS `@keyframes` with blinking cursor
- Performance verification — Lighthouse score, total JS bundle under 50kb

**Uses:** motion 12.34.x (vanilla JS in Astro `<script>` tags), CSS animations for diagram, CSS transitions for hover effects

**Research flag:** Standard patterns — skip `/gsd:research-phase`. Motion's `inView` and `stagger` APIs are well-documented. CSS `stroke-dashoffset` animation for SVG paths is a common technique.

---

### Phase Ordering Rationale

- Foundation must precede content: `npm install` and `astro build` must succeed before components can be developed. CNAME and DNS must be in place before the first deployment. CI path filtering must be correct from commit one.
- Content must precede animation: you cannot animate components that do not exist. The architecture diagram must be built as static SVG before adding animated strokes.
- Responsive layout is a constraint on Phase 2, not a phase: use Tailwind responsive utilities from the first component. Building desktop-only then "adding mobile later" doubles CSS work.
- Separate content from infrastructure: Phase 1 is pure infrastructure. Phase 2 is pure content. Phase 3 is pure polish. Clear phase boundaries prevent mixed concerns.

### Research Flags

Phases with standard patterns (skip `/gsd:research-phase`):
- **Phase 1:** GitHub Pages + Astro deployment is extremely well-documented. All configuration values are verified. Follow the exact workflow YAML and config from STACK.md and PITFALLS.md.
- **Phase 2:** Landing page section patterns are established. Component structure, Tailwind design system setup, and Astro component authoring all have official documentation. The architecture SVG is custom but not complex.
- **Phase 3:** motion v12 API is stable. CSS `stroke-dashoffset` animation is a standard technique. No research needed.

No phases require `/gsd:research-phase` — all findings come from official documentation with HIGH confidence.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified via official docs, npm releases, and GitHub releases. Versions confirmed current as of 2026-02-25. Version compatibility matrix fully cross-checked. |
| Features | HIGH | Based on direct analysis of 8 competitor landing pages plus Evil Martians research of 100 dev tool pages. Table stakes are unambiguous. P2 features reflect clear industry patterns. |
| Architecture | HIGH | Official Astro and GitHub Pages documentation. Monorepo subdirectory pattern (`path: ./site`) is the officially supported approach per `withastro/action` docs. No community inference needed. |
| Pitfalls | HIGH | All 8 critical pitfalls verified via official GitHub Pages docs, official Astro docs, and GitHub Community discussions with hundreds of confirmed reports. Recovery strategies are tested. |

**Overall confidence:** HIGH

### Gaps to Address

- **Exact Helm install commands:** The quickstart section requires the actual Helm repo URL and install command from the repository. FEATURES.md shows a placeholder URL (`https://...`). Resolve from the actual `helm/` directory or README during Phase 2 content authoring.

- **Product copy and headlines:** Copywriting for the hero headline, subheadline, feature card descriptions, and use case scenarios is not finalized. The research establishes patterns and examples but the final copy needs a deliberate writing pass during Phase 2. The hero headline in particular should be tested for clarity — "Your AI DevOps Agent, Running Inside Your Cluster" is a candidate but not final.

- **OG image creation:** The `og-image.png` for social sharing meta tags needs to be created. It is referenced in the architecture but not produced by any research. This is a design task for Phase 2.

- **Favicon design:** `site/public/favicon.svg` needs to be created. Not covered in research. Low complexity but easy to forget.

## Sources

### Primary (HIGH confidence)

- [Astro GitHub Pages Deploy Guide](https://docs.astro.build/en/guides/deploy/github/) — deployment workflow, CNAME setup, custom domain configuration
- [Astro Project Structure Docs](https://docs.astro.build/en/basics/project-structure/) — component, layout, pages conventions
- [withastro/action v5 GitHub Repo](https://github.com/withastro/action) — `path`, `node-version`, `cache` inputs; v5.2.0 verified
- [Tailwind CSS v4 Astro Install Guide](https://tailwindcss.com/docs/installation/framework-guides/astro) — `@tailwindcss/vite` integration, CSS-first config
- [GitHub Pages Custom Domain Docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) — CNAME DNS setup, HTTPS enforcement
- [GitHub Pages Troubleshooting Docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages) — DNS verification, certificate provisioning
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) — path filters, permissions
- [Motion.dev](https://motion.dev) — vanilla JS API, `inView`, `stagger`, `animate`
- [Astro Images Documentation](https://docs.astro.build/en/guides/images/) — built-in Sharp, `<Image />`, `<Picture />`
- Warp, Linear, Railway, Coolify, K9s, Lens, Charm landing pages — direct competitor analysis

### Secondary (MEDIUM confidence)

- [Evil Martians: "We studied 100 dev tool landing pages"](https://evilmartians.com/chronicles/we-studied-100-devtool-landing-pages-here-is-what-actually-works-in-2025) — hero patterns, CTA language, eyebrow text
- [GitHub Community #159544, #22366](https://github.com/orgs/community/discussions/159544) — CNAME deletion confirmation across hundreds of reports
- [Tailwind CSS Bento Grids (Tailwind UI)](https://tailwindcss.com/plus/ui-blocks/marketing/sections/bento-grids) — 5 bento grid variants for reference
- [actions/deploy-pages Issue #329](https://github.com/actions/deploy-pages/issues/329) — `id-token: write` permission requirement clarification

### Tertiary (LOW confidence)

- [Markepear: Dev tool landing page examples](https://www.markepear.dev/examples/landing-page) — 50+ dev tool page patterns
- [LaunchKit (Evil Martians)](https://launchkit.evilmartians.io/) — free devtool landing page template reference

---
*Research completed: 2026-02-25*
*Ready for roadmap: yes*
