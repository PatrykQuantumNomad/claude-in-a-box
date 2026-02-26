# Phase 13: Fix Stagger Animation Bug - Research

**Researched:** 2026-02-26
**Domain:** Motion.js inView API / DOM animation bug fix
**Confidence:** HIGH

## Summary

Phase 13 is a targeted bug fix for a one-line error in `site/src/layouts/BaseLayout.astro` line 69. The `motion` library's `inView` function passes a plain DOM `Element` as the first argument to its callback, but the stagger animation callback incorrectly destructures `({ target })` as if it were receiving an `IntersectionObserverEntry`. Since DOM Elements have no `.target` property, `target` is `undefined` and `target.querySelectorAll(".reveal-card")` throws a `TypeError` at runtime. This causes all 10 cards (6 FeatureCards + 4 UseCaseCards) to remain invisible (stuck at their CSS initial state of `opacity: 0`).

The fix is to change `({ target })` to `(element)` and `target.querySelectorAll` to `element.querySelectorAll` on lines 69-70 of BaseLayout.astro. The section-level `inView` callback on line 60 already uses the correct `(element)` signature, providing a correct pattern to follow within the same file.

**Primary recommendation:** Change the `inView` stagger callback parameter from `({ target })` to `(element)` and update the body to use `element.querySelectorAll` instead of `target.querySelectorAll`.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| motion | 12.34.3 | Scroll-triggered animations (animate, inView, stagger) | Already installed, used by Phase 12 |
| astro | 5.17.x | Static site framework | Project framework |

### Supporting
No additional libraries needed for this bug fix.

### Alternatives Considered
No alternatives needed. This is a bug fix within the existing stack.

## Architecture Patterns

### Relevant File Structure
```
site/src/
  layouts/
    BaseLayout.astro         # Contains the buggy animation script (THE FIX TARGET)
  styles/
    global.css               # CSS initial hidden states (.reveal-card { opacity: 0 })
  components/
    sections/
      Features.astro         # Contains .reveal-stagger grid with 6 FeatureCards
      UseCases.astro         # Contains .reveal-stagger grid with 4 UseCaseCards
    ui/
      FeatureCard.astro      # Has .reveal-card class on root div
      UseCaseCard.astro       # Has .reveal-card class on root div
```

### Pattern: Motion inView Callback Signature
**What:** The `motion` library's `inView(selector, callback, options)` function calls `callback(element, entry)` where `element` is a DOM `Element` and `entry` is an `IntersectionObserverEntry`.
**When to use:** Any time you use `inView` from the `motion` package.
**Official type signature:**
```typescript
// Source: framer-motion/dist/dom.d.ts (motion re-exports from framer-motion/dom)
declare function inView(
  elementOrSelector: ElementOrSelector,
  onStart: (element: Element, entry: IntersectionObserverEntry) => void | ViewChangeHandler,
  { root, margin: rootMargin, amount }?: InViewOptions
): VoidFunction;
```

**Source code confirmation (motion/dist/motion.dev.js line 10923):**
```javascript
const newOnEnd = onStart(entry.target, entry);
//                       ^^^^^^^^^^^^ -- This is a DOM Element, NOT an IntersectionObserverEntry
```

### The Bug: Destructuring Confusion
The developer likely confused the `IntersectionObserverEntry` interface (which has `.target`, `.isIntersecting`, etc.) with the actual first argument to the `inView` callback. The `IntersectionObserverEntry` is passed as the SECOND argument, not the first.

Line 60 (CORRECT):
```javascript
inView(".reveal-section", (element) => {
  animate(element, ...);
```

Line 69 (BUGGY):
```javascript
inView(".reveal-stagger", ({ target }) => {
  const cards = target.querySelectorAll(".reveal-card");
  // target is undefined because Element has no .target property
  // This throws: TypeError: Cannot read properties of undefined (reading 'querySelectorAll')
```

### Anti-Patterns to Avoid
- **Destructuring the inView callback argument as IntersectionObserverEntry:** The first argument is the element itself, not the entry. If you need the entry, use the second parameter.
- **Double-triggering animations on the same element:** Both `.reveal-section` on the `<section>` and `.reveal-stagger` on the inner grid observe the same scroll region. Ensure the section fade-up and the card stagger are on different DOM nodes (they already are: section vs grid div).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll intersection detection | Custom IntersectionObserver | motion `inView()` | Already in the codebase, handles cleanup automatically |

**Key insight:** This phase is a bug fix, not a feature build. No new abstractions or libraries needed.

## Common Pitfalls

### Pitfall 1: Confusing inView Callback Signature with IntersectionObserver API
**What goes wrong:** The `IntersectionObserver` native API passes `IntersectionObserverEntry` objects to its callback. Motion's `inView` wrapper extracts `entry.target` and passes it as the first argument directly. Developers familiar with the native API may destructure `{ target }` thinking they receive an entry.
**Why it happens:** The native `IntersectionObserver` callback receives `(entries, observer)` where each entry has `.target`. Motion's `inView` simplifies this to `(element, entry)`.
**How to avoid:** Always reference the motion type signature: first arg is `Element`, second arg is `IntersectionObserverEntry`.
**Warning signs:** Any `({ target })` or `({ isIntersecting })` destructuring in an `inView` callback.

### Pitfall 2: Cards Remaining Invisible After Fix
**What goes wrong:** If the CSS initial state (`opacity: 0; transform: translateY(30px)`) is applied but the animation never fires, cards stay invisible.
**Why it happens:** Possible if the fix introduces a new error, or if the `.reveal-stagger` selector doesn't match the grid container.
**How to avoid:** After the fix, verify in a browser (or via build check) that no console errors occur and cards become visible on scroll.
**Warning signs:** Build passes but cards still invisible in production.

### Pitfall 3: Editing the Wrong inView Call
**What goes wrong:** There are two `inView` calls in BaseLayout.astro. The first (line 60, `.reveal-section`) is correct. The second (line 69, `.reveal-stagger`) is buggy. Editing the wrong one would break section animations.
**Why it happens:** Both calls look similar and are adjacent in the file.
**How to avoid:** Target line 69 specifically. The fix is on the `.reveal-stagger` callback only.
**Warning signs:** The `.reveal-section` callback starts losing its `(element)` parameter.

## Code Examples

### The Exact Fix (verified against source)
```javascript
// BEFORE (line 69-70 of BaseLayout.astro) -- BUGGY
inView(".reveal-stagger", ({ target }) => {
  const cards = target.querySelectorAll(".reveal-card");

// AFTER -- FIXED
inView(".reveal-stagger", (element) => {
  const cards = element.querySelectorAll(".reveal-card");
```

### Full Corrected Script Block
```astro
<script>
  import { animate, inView, stagger } from "motion";

  // Reveal sections with fade-up on scroll
  inView(".reveal-section", (element) => {
    animate(
      element,
      { opacity: [0, 1], y: [30, 0] },
      { duration: 0.6, ease: [0.17, 0.55, 0.55, 1] }
    );
  }, { amount: 0.15 });

  // Stagger reveal cards within their parent container
  inView(".reveal-stagger", (element) => {
    const cards = element.querySelectorAll(".reveal-card");
    if (cards.length > 0) {
      animate(
        cards,
        { opacity: [0, 1], y: [20, 0] },
        { duration: 0.5, ease: [0.17, 0.55, 0.55, 1], delay: stagger(0.1) }
      );
    }
  }, { amount: 0.15 });
</script>
```

### How the Animation Chain Works (post-fix)
1. CSS sets `.reveal-card { opacity: 0; transform: translateY(30px); }` on page load
2. User scrolls, `.reveal-stagger` grid enters viewport (15% visible)
3. `inView` fires callback with the grid `Element` as first argument
4. Callback queries `.reveal-card` children within the grid element
5. `animate(cards, ...)` with `stagger(0.1)` animates each card 100ms apart
6. Cards become visible with fade-up stagger effect
7. No return value from callback = one-shot animation (no reverse on scroll out)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `framer-motion` package name | `motion` package name | v12+ (2024) | `motion` is the current package; `framer-motion` re-exports from it |

**Deprecated/outdated:**
- The pattern `inView(selector, ({ target }) => ...)` was NEVER correct for the `motion` library. The confusion likely arose from the native `IntersectionObserver` API pattern.

## Open Questions

None. The bug root cause is confirmed, the fix is verified against the library source code and TypeScript type definitions, and the change is a two-word edit on a single line.

## Sources

### Primary (HIGH confidence)
- `site/node_modules/motion/dist/motion.dev.js` line 10910-10944 -- `inView` function implementation confirming `onStart(entry.target, entry)` call pattern (first arg is Element)
- `site/node_modules/framer-motion/dist/dom.d.ts` line 162 -- TypeScript type: `onStart: (element: Element, entry: IntersectionObserverEntry) => void | ViewChangeHandler`
- `site/src/layouts/BaseLayout.astro` lines 60-78 -- current buggy code (line 60 correct pattern, line 69 buggy pattern)
- `.planning/v1.1-MILESTONE-AUDIT.md` -- audit identifying the bug as a gap in DESIGN-02

### Secondary (MEDIUM confidence)
- `.planning/phases/12-polish-deployment/12-01-PLAN.md` line 180 -- original plan that introduced the bug with `({ target })` destructuring

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - library already installed, version confirmed (12.34.3)
- Architecture: HIGH - bug location precisely identified, fix verified against source
- Pitfalls: HIGH - single-line fix with clear before/after, confirmed by type definitions

**Research date:** 2026-02-26
**Valid until:** 2027-02-26 (stable -- this is a bug fix against a confirmed API)
