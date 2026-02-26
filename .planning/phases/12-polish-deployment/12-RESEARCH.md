# Phase 12: Polish & Deployment - Research

**Researched:** 2026-02-26
**Domain:** Scroll-triggered animations (motion.js vanilla JS), SEO/Open Graph meta tags, CLS prevention, Astro client-side scripts
**Confidence:** HIGH

## Summary

Phase 12 adds two layers of polish to the completed Astro landing page: scroll-triggered reveal animations on feature cards and sections using Motion's vanilla JS API (`animate`, `inView`, `stagger`), and complete SEO/Open Graph metadata for rich social previews on Twitter/Slack/Discord. The site currently ships zero JavaScript (all static HTML + 18kb CSS + fonts). Adding Motion's vanilla JS functions will introduce approximately 4-5kb of JS (tree-shaken: `animate` ~3.8kb + `inView` ~0.5kb + `stagger` negligible), well within the 50kb budget.

The critical technical constraints are: (1) animations must only use `opacity` and `transform` properties to avoid layout shift (CLS = 0), (2) elements must be visually hidden before scroll-trigger fires but must not cause layout reflow when they appear, (3) `prefers-reduced-motion` must be respected -- Motion's vanilla `animate()` function automatically disables transform animations when the OS preference is set, which is the correct accessible behavior, (4) the OG image must be a static 1200x630px PNG placed in `public/` since this is a single-page site with no dynamic routes.

The Astro configuration already has `site: "https://remotekube.patrykgolabek.dev"` set, which is required for canonical URLs and OG tags. The BaseLayout.astro already has basic `<title>` and `<meta name="description">` but lacks Open Graph, Twitter Card, canonical URL, and favicon link tags. The deployment workflow (`deploy-site.yaml`) is already functional via `withastro/action@v5` -- no deployment changes needed.

**Primary recommendation:** Install `motion` 12.34.x, add a single `<script>` tag in BaseLayout.astro (or a dedicated animation script component) that imports `{ animate, inView, stagger }` from `"motion"` and targets sections/cards via CSS class selectors. Add comprehensive OG/Twitter meta tags to BaseLayout.astro's `<head>`. Create a static OG image at `public/og-image.png` (1200x630px). Optionally add `@astrojs/sitemap` for SEO completeness.

## Standard Stack

### Core (new dependency)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| motion | 12.34.x | Scroll-triggered reveal animations (vanilla JS) | Prior decision from Phase 10; tree-shakeable to ~4.3kb for `animate`+`inView`+`stagger`; built on Web Animations API + IntersectionObserver; no React dependency |

### Core (already installed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| astro | 5.18.0 | Static site generator | Already installed; script tags processed and bundled by Vite |
| tailwindcss | 4.2.1 | CSS utility framework | Already installed; used for initial hidden state classes |
| @tailwindcss/vite | 4.2.1 | Tailwind Vite plugin | Already installed |

### Supporting (optional, recommended)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @astrojs/sitemap | latest | Auto-generate sitemap.xml | SEO completeness; auto-discovers routes at build time; requires `site` in astro.config (already set) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| motion (vanilla JS) | CSS-only `@keyframes` + IntersectionObserver | More boilerplate, no stagger support, reinventing what motion provides in 4kb |
| motion (vanilla JS) | Native CSS scroll-driven animations (`animation-timeline: view()`) | Not yet supported in Firefox/Safari (2026); motion is cross-browser today |
| @astrojs/sitemap | Manual sitemap.xml in `public/` | Works but doesn't auto-update; integration is zero-config for a site this simple |
| Static OG image | Satori-based dynamic generation | Overkill for a single-page site; static image is simpler, faster build, zero dependencies |

**Installation:**
```bash
cd site
npm install motion
# Optional:
npx astro add sitemap
```

## Architecture Patterns

### Recommended Approach: Single Animation Script

**What:** One `<script>` block (in BaseLayout.astro or a dedicated `AnimationInit.astro` component) that handles all scroll-triggered animations via CSS class selectors. Astro processes `<script>` tags as modules, bundles imports, and deduplicates automatically.

**When to use:** Always for this project. The site has one page with multiple sections that all need the same reveal treatment.

**Structure:**
```
site/src/
  components/
    sections/
      Hero.astro              # No scroll animation (above fold, always visible)
      Features.astro           # Add .reveal-section class to section, .reveal-card to cards
      Architecture.astro       # Add .reveal-section class
      Quickstart.astro         # Add .reveal-section class
      UseCases.astro           # Add .reveal-section class, .reveal-card to cards
      Footer.astro             # No scroll animation (simple, always at bottom)
    ui/
      FeatureCard.astro        # Gets .reveal-card class
      UseCaseCard.astro        # Gets .reveal-card class
  layouts/
    BaseLayout.astro           # Add OG/Twitter meta tags to <head>, animation script
  pages/
    index.astro                # No changes needed
  styles/
    global.css                 # Add initial hidden state for .reveal-* classes
  public/
    og-image.png               # NEW: 1200x630px static OG preview image
    favicon.svg                # Already exists
    favicon.ico                # Already exists
```

### Pattern 1: Scroll-Triggered Reveal with inView + animate

**What:** Use `inView()` to detect when a section enters the viewport, then `animate()` to reveal it with opacity + translateY.
**When to use:** For each content section below the fold (Features, Architecture, Quickstart, UseCases).

**Example:**
```javascript
// Source: https://developers.netlify.com/guides/motion-animation-library-with-astro/
// Source: https://examples.motion.dev/js/scroll-triggered
import { animate, inView, stagger } from "motion";

// Reveal sections with fade-up
inView(".reveal-section", (element) => {
  animate(
    element,
    { opacity: [0, 1], y: [30, 0] },
    { duration: 0.6, ease: [0.17, 0.55, 0.55, 1] }
  );
}, { amount: 0.15 });

// Reveal cards with staggered fade-up (from parent section)
inView(".reveal-stagger", ({ target }) => {
  const cards = target.querySelectorAll(".reveal-card");
  if (cards.length > 0) {
    animate(
      cards,
      { opacity: [0, 1], y: [25, 0] },
      { duration: 0.5, ease: [0.17, 0.55, 0.55, 1], delay: stagger(0.1) }
    );
  }
}, { amount: 0.15 });
```

### Pattern 2: CSS Initial Hidden State (CLS Prevention)

**What:** Set elements to invisible via CSS BEFORE JavaScript loads, using `opacity: 0` and `transform: translateY()`. Use only compositor-friendly properties.
**When to use:** Always pair with scroll-triggered animations to prevent FOUC and CLS.

**Example:**
```css
/* In global.css */
.reveal-section,
.reveal-card {
  opacity: 0;
  transform: translateY(30px);
}

/* Fallback: if JS fails or is disabled, make content visible */
@media (prefers-reduced-motion: reduce) {
  .reveal-section,
  .reveal-card {
    opacity: 1;
    transform: none;
  }
}
```

**Critical detail:** `opacity` and `transform` do NOT cause layout shift. They run on the compositor thread. Never use `height`, `margin`, `padding`, or `display: none` for reveal animations -- these trigger layout recalculation and cause CLS.

### Pattern 3: Open Graph + Twitter Card Meta Tags in BaseLayout

**What:** Comprehensive meta tags in `<head>` for rich social previews.
**When to use:** In BaseLayout.astro, passed as props.

**Example:**
```astro
---
interface Props {
  title: string;
  description?: string;
  image?: string;
}

const {
  title,
  description = "Deploy Claude Code inside your Kubernetes cluster",
  image = "/og-image.png"
} = Astro.props;

const canonicalURL = new URL(Astro.url.pathname, Astro.site);
const imageURL = new URL(image, Astro.site);
---
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="canonical" href={canonicalURL} />
  <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
  <link rel="icon" href="/favicon.ico" sizes="32x32" />

  <!-- Primary Meta Tags -->
  <title>{title}</title>
  <meta name="description" content={description} />

  <!-- Open Graph / Facebook / Slack / Discord -->
  <meta property="og:type" content="website" />
  <meta property="og:url" content={canonicalURL} />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:image" content={imageURL} />
  <meta property="og:site_name" content="RemoteKube" />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:url" content={canonicalURL} />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={imageURL} />
</head>
```

### Anti-Patterns to Avoid

- **Animating `height`, `width`, `margin`, `top/left`:** These trigger layout recalculation and cause CLS. Only animate `opacity` and `transform`.
- **Using `display: none` for initial hidden state:** Causes layout shift when changed to `display: block`. Use `opacity: 0` instead.
- **Loading motion as `is:inline`:** Loses Vite tree-shaking and bundling. Use default `<script>` tag so Astro processes imports.
- **Animating Hero section:** Hero is above the fold and visible on initial render. Scroll-triggered animation on it would show a blank screen then flash content. Only animate below-fold sections.
- **Using `will-change` permanently:** Only add `will-change` on elements about to animate, not as a permanent CSS property. It forces GPU layer creation and wastes memory.
- **Relying on `og:title` alone without `twitter:card`:** Twitter/X requires `twitter:card` meta tag; it does not fall back to OG tags for the card type.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll viewport detection | Custom IntersectionObserver wrapper | `inView()` from motion | 0.5kb, handles cleanup, selector-based targeting, threshold options |
| Staggered animation delays | Manual `setTimeout` chains | `stagger()` from motion | Handles timing math, works with animate's delay option |
| Element animation | Raw Web Animations API calls | `animate()` from motion | Cross-browser normalization, hardware acceleration, easing functions |
| SEO meta tag management | Custom head component from scratch | Astro's built-in `Astro.site` + `Astro.url` | Already available, canonical URL generation built-in |
| Sitemap generation | Manual XML file | `@astrojs/sitemap` | Auto-discovers routes, updates on build, zero-config |
| OG image generation | Satori/Puppeteer pipeline | Static PNG in public/ | Single-page site; one image is all that's needed |

**Key insight:** Motion's vanilla JS API (`animate`, `inView`, `stagger`) provides exactly the primitives needed for scroll-triggered reveals at ~4.3kb total. Building equivalent functionality from scratch would mean writing an IntersectionObserver wrapper, animation scheduling, stagger timing, easing curves, and cleanup logic -- all of which motion handles.

## Common Pitfalls

### Pitfall 1: Layout Shift from Animation Initial State

**What goes wrong:** Elements start visible, then "jump" into animated position when JS loads, causing visible CLS.
**Why it happens:** No CSS initial state defined; elements render at final position, then JS resets them to start position before animating.
**How to avoid:** Define `.reveal-section` and `.reveal-card` in CSS with `opacity: 0; transform: translateY(30px)` so elements start hidden without JS. The animation then reveals them.
**Warning signs:** Lighthouse CLS score > 0; visible "flash" of content then reset on page load.

### Pitfall 2: Content Invisible Without JavaScript

**What goes wrong:** Users with JS disabled or when JS fails to load see a blank page because elements are permanently `opacity: 0`.
**Why it happens:** CSS initial state hides elements, but no fallback exists.
**How to avoid:** Add `<noscript>` style override OR use `prefers-reduced-motion: reduce` media query to show elements without animation. Since Motion automatically disables transform animations for reduced-motion users, adding a CSS `@media (prefers-reduced-motion: reduce) { .reveal-section, .reveal-card { opacity: 1; transform: none; } }` handles both reduced-motion users AND provides a reasonable noscript fallback.
**Warning signs:** Testing with DevTools "Disable JavaScript" shows blank content areas.

### Pitfall 3: Motion Auto-Disabling Transform Animations

**What goes wrong:** Developer tests animations, enables "Reduce Motion" in OS settings, and animations silently stop working. Confusion ensues.
**Why it happens:** Motion's `animate()` function automatically detects `prefers-reduced-motion: reduce` and disables transform/layout animations, preserving only opacity. This is a feature, not a bug (confirmed in GitHub issue #2771).
**How to avoid:** This is DESIRED behavior for accessibility. Do not override it with `reduceMotion: "never"`. The CSS fallback in Pitfall 2 ensures content is visible. Opacity animations still work, providing a subtle fade-in.
**Warning signs:** None -- this is correct behavior. Document it so developers don't think animations are "broken."

### Pitfall 4: OG Image Not Showing in Social Previews

**What goes wrong:** Sharing the URL shows a plain text link without preview image.
**Why it happens:** (a) Image URL is relative instead of absolute, (b) image file missing from build output, (c) image dimensions wrong (< 600x315px gets rejected), (d) image > 5MB.
**How to avoid:** Use `new URL(image, Astro.site)` to generate absolute URL. Place image in `public/` so it's copied to dist verbatim. Use 1200x630px PNG under 300KB. Test with opengraph.xyz or sharing in Slack.
**Warning signs:** Sharing URL in Slack/Discord shows no preview card.

### Pitfall 5: Script Deduplication Breaking Multiple Animations

**What goes wrong:** Astro deduplicates `<script>` tags -- if the animation script is in a component that appears multiple times, it only runs once.
**Why it happens:** Astro's default script processing ensures each unique script runs exactly once per page.
**How to avoid:** This is actually CORRECT for our use case. We want one script that uses CSS selectors (`".reveal-section"`, `".reveal-card"`) to target ALL matching elements. Don't put the animation logic inside individual card components -- put it in one place (BaseLayout or a single AnimationInit component).
**Warning signs:** Animation only affects first instance of a component.

### Pitfall 6: JS Bundle Exceeding 50kb Budget

**What goes wrong:** Total JavaScript bundle exceeds the 50kb success criterion.
**Why it happens:** Importing React-specific motion exports, not tree-shaking, or importing unused features.
**How to avoid:** Only import `{ animate, inView, stagger }` from `"motion"`. Astro's default `<script>` processing uses Vite, which tree-shakes unused exports. Verify with `ls -lh dist/_astro/*.js` after build. Expected: ~4-5kb.
**Warning signs:** JS files in dist/_astro/ larger than expected.

## Code Examples

Verified patterns from official sources:

### Complete Animation Script for Astro

```javascript
// Source: https://developers.netlify.com/guides/motion-animation-library-with-astro/
// Source: https://examples.motion.dev/js/scroll-triggered
import { animate, inView, stagger } from "motion";

// Sections: fade up on scroll
inView(".reveal-section", (element) => {
  animate(
    element,
    { opacity: [0, 1], y: [30, 0] },
    { duration: 0.6, ease: [0.17, 0.55, 0.55, 1] }
  );
  // No return cleanup -- once revealed, stay revealed
}, { amount: 0.15 });

// Card containers: stagger children
inView(".reveal-stagger", ({ target }) => {
  const cards = target.querySelectorAll(".reveal-card");
  if (cards.length > 0) {
    animate(
      cards,
      { opacity: [0, 1], y: [20, 0] },
      { duration: 0.5, ease: [0.17, 0.55, 0.55, 1], delay: stagger(0.1) }
    );
  }
}, { amount: 0.15 });
```

**Key notes:**
- `amount: 0.15` triggers when 15% of the element is visible
- No return value from `inView` callback = animation plays once (does not reverse on scroll out)
- `y` shorthand in `animate()` maps to `translateY` (no layout shift)
- `ease: [0.17, 0.55, 0.55, 1]` is a smooth deceleration curve

### CSS Initial State

```css
/* Source: CLS prevention best practices */
.reveal-section,
.reveal-card {
  opacity: 0;
  transform: translateY(30px);
}

@media (prefers-reduced-motion: reduce) {
  .reveal-section,
  .reveal-card {
    opacity: 1;
    transform: none;
  }
}
```

### BaseLayout Meta Tags

```astro
---
// Source: https://ogpreview.io/guide/twitter
// Source: https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/markup
interface Props {
  title: string;
  description?: string;
  image?: string;
}

const {
  title,
  description = "An AI-powered DevOps agent running inside your Kubernetes cluster, accessible from your phone via Claude's Remote Control",
  image = "/og-image.png"
} = Astro.props;

const canonicalURL = new URL(Astro.url.pathname, Astro.site);
const imageURL = new URL(image, Astro.site);
---
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="canonical" href={canonicalURL} />
  <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
  <link rel="icon" href="/favicon.ico" sizes="32x32" />

  <!-- Primary Meta Tags -->
  <title>{title}</title>
  <meta name="description" content={description} />
  <meta name="generator" content={Astro.generator} />

  <!-- Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:url" content={canonicalURL} />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:image" content={imageURL} />
  <meta property="og:site_name" content="RemoteKube" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:url" content={canonicalURL} />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={imageURL} />
</head>
```

**Key notes:**
- OG tags use `property=` attribute, Twitter tags use `name=` attribute -- mixing these causes silent failures
- `Astro.site` is already configured as `https://remotekube.patrykgolabek.dev` in astro.config.mjs
- `new URL()` generates absolute URLs, which OG requires
- `twitter:card` must be `summary_large_image` for the 1200x630 preview format
- Description should be 120-160 characters for optimal display

### Adding CSS Classes to Existing Components

```astro
<!-- Features.astro: add .reveal-stagger to grid container -->
<section class="reveal-section py-16 md:py-20 lg:py-24 px-4 sm:px-6 lg:px-8">
  <div class="max-w-7xl mx-auto">
    <!-- heading content -->
    <div class="reveal-stagger grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <!-- FeatureCard components get .reveal-card via their template -->
    </div>
  </div>
</section>

<!-- FeatureCard.astro: add .reveal-card -->
<div class:list={["reveal-card bg-bg-secondary border border-border rounded-2xl p-6", colClass, rowClass]}>
  <!-- card content -->
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Framer Motion (React-only, 34kb+) | Motion vanilla JS (`animate`+`inView`, ~4.3kb) | Motion 10.x+ (2023) | Vanilla JS API enables use without React; dramatic size reduction |
| AOS.js / ScrollReveal.js | Motion `inView()` + `animate()` | 2023-2024 | AOS unmaintained; Motion is actively maintained, smaller, uses modern APIs |
| Custom IntersectionObserver + requestAnimationFrame | Motion `inView()` built on IntersectionObserver | Current | Same underlying API, but motion handles animation scheduling and cleanup |
| Manual OG tag management | Astro props + `Astro.site` / `Astro.url` | Astro 2.x+ | Built-in URL resolution makes absolute OG URLs trivial |
| CSS `scroll-driven-animations` (`animation-timeline: view()`) | Motion `inView()` for cross-browser support | 2025-2026 | CSS scroll-driven animations not yet in Firefox/Safari; motion works everywhere today |

**Deprecated/outdated:**
- **AOS.js (Animate On Scroll):** Last release 2019, unmaintained, larger bundle. Do not use.
- **ScrollReveal.js:** Last major update 2020. Motion is lighter and more current.
- **Framer Motion (as a vanilla alternative):** Framer Motion is React-specific. The `motion` package now provides a standalone vanilla JS API. Import from `"motion"`, not `"framer-motion"`.

## Open Questions

1. **OG Image Design**
   - What we know: Must be 1200x630px PNG, < 300KB, placed in `public/og-image.png`
   - What's unclear: Exact visual design of the OG image (text, colors, layout). Should match the site's dark theme and convey "AI DevOps agent for Kubernetes."
   - Recommendation: Create a simple branded image with the site name ("RemoteKube"), tagline ("Deploy once, control from anywhere"), and a Kubernetes/container visual motif using the oklch color palette. Can be created with any design tool or even an SVG-to-PNG conversion.

2. **Sitemap Integration**
   - What we know: `@astrojs/sitemap` is zero-config with `site` already set in astro.config.mjs. Would add sitemap-index.xml and sitemap-0.xml to build output.
   - What's unclear: Whether the user considers this in-scope for Phase 12 or deferred.
   - Recommendation: Add it. It's one line in astro.config.mjs, zero runtime cost, and improves SEO. Single command: `npx astro add sitemap`.

3. **robots.txt**
   - What we know: No robots.txt currently exists. Can create as `public/robots.txt` or programmatically as `src/pages/robots.txt.ts`.
   - What's unclear: Whether this is in-scope.
   - Recommendation: Add a simple `public/robots.txt` with `User-agent: *\nAllow: /\nSitemap: https://remotekube.patrykgolabek.dev/sitemap-index.xml`. Static file is simpler.

## Sources

### Primary (HIGH confidence)
- [Motion examples - scroll-triggered (vanilla JS)](https://examples.motion.dev/js/scroll-triggered) - Verified `inView` + `animate` pattern with working code
- [Netlify Guide: Motion with Astro](https://developers.netlify.com/guides/motion-animation-library-with-astro/) - Verified `inView` + `animate` + `stagger` pattern for Astro specifically
- [Motion `inView` documentation](https://motion.dev/docs/inview) - 0.5kb, IntersectionObserver-based, selector targeting
- [Motion `animate` documentation](https://motion.dev/docs/animate) - 3.8kb core, Web Animations API-based
- [Motion `stagger` documentation](https://motion.dev/docs/stagger) - Delay sequencing for multiple elements
- [Astro client-side scripts docs](https://docs.astro.build/en/guides/client-side-scripts/) - Script bundling, deduplication, TypeScript support
- [Twitter Card markup docs](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/markup) - Required meta tags, `name=` not `property=`
- [GitHub issue #2771: Motion auto-disables transforms for reduced motion](https://github.com/motiondivision/motion/issues/2771) - Confirmed `animate()` respects `prefers-reduced-motion` automatically
- [GitHub discussion #2928: Stagger with inView](https://github.com/motiondivision/motion/discussions/2928) - Must target parent with `inView`, children with `animate` selector

### Secondary (MEDIUM confidence)
- [OG Preview Guide - Twitter Cards](https://ogpreview.io/guide/twitter) - Image requirements: 1200x630px, < 5MB, HTTPS required
- [Complete Astro SEO Guide (2025)](https://eastondev.com/blog/en/posts/dev/20251202-astro-seo-complete-guide/) - BaseHead pattern, canonical URLs, OG tags
- [CLS Prevention Best Practices](https://blog.pixelfreestudio.com/preventing-layout-shifts-mastering-css-transitions-and-animations/) - Only animate opacity + transform for zero CLS
- [Bundlephobia motion data](https://bundlephobia.com/package/motion) - Full package size (tree-shakeable)

### Tertiary (LOW confidence)
- Motion vanilla JS `animate()` size of exactly 3.8kb -- this was from a LogRocket article referencing an older "Motion One" version. The current `motion` 12.34.x may differ slightly. **Validate:** Check actual JS file size in `dist/_astro/` after build.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - motion 12.34.x is a prior decision; API verified via official examples and Netlify guide
- Architecture: HIGH - Astro script processing, inView/animate pattern, and OG meta tag patterns well-documented
- Pitfalls: HIGH - CLS prevention techniques well-established; Motion reduced-motion behavior confirmed via GitHub issue
- Bundle size: MEDIUM - Individual function sizes from docs (3.8kb + 0.5kb), but exact combined tree-shaken size for v12.34.x needs post-build validation

**Research date:** 2026-02-26
**Valid until:** 2026-03-28 (30 days -- stable libraries, well-documented patterns)
