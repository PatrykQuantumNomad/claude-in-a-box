# Feature Research: Landing Page for Claude In A Box

**Domain:** Open-source DevOps tool marketing landing page
**Researched:** 2026-02-25
**Confidence:** HIGH

## Feature Landscape

This documents the feature landscape for a **marketing landing page** at `remotekube.patrykgolabek.dev` -- NOT the core product features (those are in `.planning/research/FEATURES.md`). Every feature below is a page section, design element, or interactive component that makes the landing page effective.

### Table Stakes (Users Expect These)

Missing any of these and the page feels amateur or incomplete. These are non-negotiable for a developer tool landing page in 2026.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Hero section with bold headline + subheadline** | The Evil Martians study of 100 dev tool pages confirms: centered hero with big bold headline and supporting visual below is the dominant pattern. Without it the page has no identity. Warp, Linear, Railway, Vercel, Coolify all follow this. | LOW | Centered layout. One-liner headline ("Debug your cluster from your phone" or similar). Subheadline explains what the product does. Two CTAs: primary (GitHub/Install) + secondary (Docs). No "Get Started" -- use specific language like "Deploy Now" or "View on GitHub". |
| **Two hero CTAs (open source + docs)** | Developer tools need dual paths: one for immediate action (GitHub repo, install command), one for learning more (docs). The Evil Martians research found two CTAs in the hero lets you "both convert paid customers and provide immediate value to developers." Generic "Get started" underperforms specific CTAs. | LOW | Primary: "View on GitHub" (links to repo). Secondary: "Read the Docs" or "Quickstart". Use specific product language, not generic SaaS copy. |
| **Feature cards section (3-6 cards)** | Every developer tool page presents key capabilities in a scannable grid. K9s uses a bulleted list (functional but boring). Linear, Vercel, Railway use rich cards with icons and short descriptions. The user specifically requested 3-6 feature cards. | LOW | Grid of 3-6 cards highlighting: phone-first Remote Control, 32+ pre-installed tools, Kubernetes RBAC, session persistence, Helm chart deployment, MCP intelligence layer. Each card: icon + title + 1-2 sentence description. No dense card borders (creates visual heaviness per Evil Martians research). |
| **Quickstart / installation section** | Developers want to try before they commit. Every successful open-source tool page (K9s, Coolify, Helm, Bun) includes a copy-paste install command. This is the #1 conversion driver for OSS projects. Bun puts `curl -fsSL https://bun.sh/install | bash` front and center. | LOW | Dark-themed code block with syntax highlighting. Copy-to-clipboard button. Show 2-3 commands: `helm repo add`, `helm install`, done. Terminal-style presentation with monospace font (JetBrains Mono or similar). |
| **Footer with links** | Standard web hygiene. Links to GitHub, docs, license. The user explicitly requested a footer. Without it the page feels unfinished. | LOW | GitHub link, documentation link, license (MIT/Apache), author attribution. Keep minimal -- this is a single-page site, not a SaaS product with 50 footer links. |
| **Dark theme** | Developer tools overwhelmingly use dark themes. Warp: `#121212` background. Railway: deep purples. Coolify: `#101010`. Linear: dark with subtle gradients. Light themes feel corporate/non-technical to the target audience. The user said "not boring corporate." | LOW | Dark background (`#0a0a0a` to `#121212` range). Light text. Accent color for interactive elements. Consider subtle gradients or noise textures for depth. |
| **Responsive / mobile-friendly layout** | Ironic for a "debug from your phone" product to have a broken mobile experience. All modern landing pages are responsive. Tailwind CSS handles this with minimal effort. | LOW | Tailwind responsive utilities handle this. Stack cards vertically on mobile. Reduce hero text size. Test on actual phone since the product's value prop is mobile-first. |
| **Social proof element** | Developers trust peer validation. GitHub stars badge, "Trusted by" logos, or user count. Railway shows "2.3M+ users, 33M+ monthly deployments." Even for early-stage projects, a GitHub stars badge provides credibility. PostHog, Coolify, and K9s all prominently display community size. | LOW | GitHub stars badge (dynamic via shields.io or GitHub API). If available: Docker pull count, Helm install count. Even "Built during a 1-day sprint" is social proof of the builder's capability. |

### Differentiators (Competitive Advantage)

Features that elevate the page from "functional" to "memorable." These are what make visitors think "this is well-made" and share the link.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Animated architecture diagram** | The product's architecture (phone -> Anthropic relay -> container in cluster) is the "aha moment." A static diagram is fine; an animated one that shows the data flow is memorable. Railway uses animated backgrounds. Vercel uses animated code blocks. An SVG diagram with CSS animations showing the connection flow from phone to cluster would be a signature visual. | MEDIUM | SVG-based diagram with CSS animations: phone icon -> dotted line animates -> cloud relay -> dotted line animates -> Kubernetes cluster with pod. Use Astro's component model to build as a reusable component. Can be the hero visual or a standalone section. Staggered animations (connection establishes left-to-right) create narrative flow. |
| **Bento grid feature layout** | Instead of uniform feature cards, a bento grid (inspired by Apple, now standard in Tailwind UI) uses varied card sizes to create visual hierarchy. The flagship feature (Remote Control from phone) gets a large card; supporting features get smaller ones. This is the dominant 2026 layout pattern for feature sections -- Tailwind CSS ships official bento grid components. | MEDIUM | 2-row bento grid: first row has one large card (Remote Control) + one medium card (32+ tools). Second row has 3-4 smaller cards (RBAC, Helm, persistence, MCP). Tailwind UI has 5 bento grid variants ready to use. The asymmetry creates visual interest that uniform grids lack. |
| **Terminal-style quickstart with typing animation** | Instead of a static code block, animate the commands being "typed" with a blinking cursor. Warp's entire brand is built on making the terminal feel modern. A typing animation in the quickstart section makes the page feel alive and developer-native. K9s embeds an Asciinema recording; we can do better with a lighter-weight CSS animation. | MEDIUM | CSS typing animation with `@keyframes`. Show 3 commands appearing sequentially: add repo, install, connect. Blinking cursor. Monospace font. Dark terminal background with green or cyan text. Pause between commands for readability. Optional: show "output" appearing after each command. |
| **Use cases section with scenario cards** | The user requested use cases. Rather than generic persona cards ("for DevOps engineers"), show specific scenarios: "3AM PagerDuty alert -- diagnose from bed," "Pod crashlooping during deploy -- check from your phone," "Network policy blocking traffic -- trace from anywhere." Concrete scenarios resonate more than abstract personas. Vercel uses tabbed use-case navigation; we should use simpler cards given page scope. | LOW | 3-4 scenario cards. Each: emoji or icon + scenario title + 2-sentence description + which product feature solves it. Example: "Weekend On-Call" -> "Get paged at 2AM. Open your phone. Claude is already connected to the cluster. Diagnose the CrashLoopBackOff without opening your laptop." |
| **Gradient glow / accent effects** | Railway uses deep purple glows (`#4b0390`). Coolify uses purple (`#6B16ED`) with golden accents. Linear uses subtle animated grid patterns. Charm uses purple-to-pink gradients. Glow effects on cards, buttons, or the hero section add visual depth without being distracting. This is the "fun" factor the user wants. | LOW | CSS `box-shadow` with colored glow on hover for cards. Subtle radial gradient behind hero headline. Accent color: electric blue or cyan (matches terminal aesthetic, distinct from the purple that Railway/Coolify already own). CSS-only -- no JavaScript needed. |
| **"Phone + Cluster" split visual in hero** | The unique value prop is "debug your cluster from your phone." Show this visually: left side shows a phone mockup with Claude Code interface, right side shows a Kubernetes cluster diagram, connected by an animated line. This immediately communicates the product's core value better than any headline. | MEDIUM | Phone mockup (CSS/SVG, not a real screenshot -- keep it schematic). Cluster visualization (pods, nodes -- simplified). Animated dashed line connecting them through a cloud icon (Anthropic relay). This becomes the hero visual below the headline. Could reuse/extend the architecture diagram component. |
| **Eyebrow text above hero headline** | Small text above the main headline highlighting a key fact: "Open Source" or "v1.0 -- 32+ DevOps Tools" or "Built in 1 Day." The Evil Martians study found this pattern across most top dev tool pages -- it "packs extra information into the hero section" and creates a sense of activity/momentum. | LOW | Small, muted text above the main H1. Badge-style with border or pill shape. Content: version number, "Open Source", or a brief highlight. Updates with each release to keep the page feeling current. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem like good ideas but would hurt the landing page.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Pricing section** | SaaS landing pages always have pricing. "Every landing page needs pricing." | This is a free, open-source tool. There is nothing to price. A pricing section with "$0 Free" looks desperate and confusing. It also implies there might be a paid tier coming, which undermines trust. Coolify handles this well by linking to a separate pricing page for their cloud offering, not putting it on the main OSS page. | Skip entirely. The hero CTAs make it clear this is open source (GitHub link). If needed, a single line in the footer: "Free and open source under [license]." |
| **Blog / changelog section** | "Show the project is active with recent updates." | A blog section on a single-page landing site adds maintenance burden and scope. If the blog has 1 post from launch day and nothing else, it looks abandoned -- worse than having no blog. For a v1.0 product, there is no changelog worth showing yet. | Link to GitHub releases in the footer. The GitHub repo itself shows activity. A "Last updated: [date]" badge is lighter-weight proof of activity. |
| **Live demo / embedded terminal** | "Let users try it right on the page." | An actual live demo requires running infrastructure (a real Kubernetes cluster, a real Claude Code instance, API costs). For a landing page this is massive scope and ongoing cost. Warp's live demo is their entire product; we do not have that luxury. | The quickstart section IS the "try it" path. 3 commands to deploy in their own cluster. Alternatively, an animated GIF or Asciinema recording showing a real session. Low maintenance, high impact. |
| **Testimonials carousel** | Railway and Lens both have testimonial carousels. "Social proof from real users." | The product just shipped v1.0 in a single day. There are no real users yet. Fake testimonials are immediately obvious and destroy credibility. Even real early testimonials from friends feel manufactured. | GitHub stars badge. Docker pull count. "Built with" tech badges. Once real users exist (GitHub issues, stars, community), add testimonials organically. A single genuine quote is worth more than five manufactured ones. |
| **Comparison table vs competitors** | "Show how we compare to K8sGPT, kagent, claudebox." | Comparison tables on landing pages often come across as biased ("we win every category") and create adversarial positioning with potential community allies. For an open-source project, this alienates rather than attracts. The Evil Martians research found comparison pages work as separate pages (Warp has `/compare-terminal-tools/`), not as landing page sections. | A brief "How is this different?" paragraph or FAQ entry. Positive framing: "Unlike general-purpose AI frameworks, Claude In A Box ships ready to debug with 32+ tools pre-installed and phone-first access." No direct competitor bashing. |
| **Newsletter signup** | "Capture leads for updates." | For an open-source DevOps tool, a newsletter signup form feels like SaaS marketing creep. The target audience (DevOps engineers) is allergic to email capture. It also requires an email service (Mailchimp, Buttondown) and ongoing content creation. | "Star on GitHub" is the OSS equivalent of subscribing. GitHub's watch/release notification system handles update notifications. The footer can link to GitHub discussions for community engagement. |
| **Video hero / background video** | "Video heroes are engaging." Railway uses animated backgrounds. | Video significantly increases page load time (each second of load time drops conversions by 7% per SaaS benchmarks). Background videos on mobile are often disabled by browsers. A CSS/SVG animation achieves the same "alive" feeling at a fraction of the bandwidth. | CSS animations on the architecture diagram / hero visual. Lightweight, loads instantly, works on all devices. Save video for a separate "demo" link (YouTube/Loom) linked from the page. |
| **Multi-page site** | "Add About, Docs, Blog, Pricing pages." | Scope explosion. The mandate is a single landing page. Multi-page sites need navigation, routing, consistent layouts, and ongoing maintenance across pages. The product already has a README and docs in the repo. | Single page with smooth-scroll anchor links to sections. Docs link goes to GitHub README or a docs site (built separately if needed later). Keep the landing page as a focused conversion tool. |

## Feature Dependencies

```
[Dark Theme + Color System]
    |--required-by--> [Hero Section]
    |--required-by--> [Feature Cards / Bento Grid]
    |--required-by--> [Quickstart Terminal Block]
    |--required-by--> [Architecture Diagram]
    |--required-by--> [Footer]

[Hero Section]
    |--contains--> [Eyebrow Text]
    |--contains--> [Headline + Subheadline]
    |--contains--> [Two CTAs]
    |--contains--> [Hero Visual (phone+cluster or arch diagram)]

[Architecture Diagram SVG Component]
    |--reused-by--> [Hero Visual]
    |--reused-by--> [Standalone Architecture Section]

[Feature Cards / Bento Grid]
    |--enhanced-by--> [Gradient Glow Effects]
    |--depends-on--> [Product copy/content]

[Quickstart Terminal Block]
    |--enhanced-by--> [Typing Animation]
    |--depends-on--> [Actual install commands from repo]

[Use Cases Section]
    |--depends-on--> [Product copy/content]
    |--enhanced-by--> [Gradient Glow Effects]

[Responsive Layout]
    |--required-by--> ALL sections
    |--depends-on--> [Tailwind CSS setup]

[Social Proof]
    |--depends-on--> [GitHub API / shields.io integration]
```

### Dependency Notes

- **Dark theme + color system is foundational:** Every visual component references the color tokens. Define the palette (background, text, accent, glow) before building any section. This is a 30-minute task but gates everything.
- **Architecture diagram is reusable:** Build it as an Astro component once, use in hero and/or as a standalone section. The SVG + CSS animation approach means it works in both contexts without duplication.
- **Content gates visuals:** Feature card copy, use case scenarios, and quickstart commands must be written before the sections can be built. Writing marketing copy and building components can happen in parallel if stubbed first.
- **Responsive is not a phase -- it is a constraint:** Use Tailwind responsive utilities from the start. Do not build desktop-only and "add mobile later." That doubles the CSS work.

## MVP Definition

### Launch With (v1)

The minimum landing page that effectively communicates the product and drives visitors to the GitHub repo.

- [ ] **Hero section** -- Bold headline, subheadline, two CTAs (GitHub + Docs), eyebrow text with version/OSS badge. This is the first thing visitors see; it must be perfect.
- [ ] **Feature bento grid (5-6 cards)** -- Asymmetric bento layout highlighting Remote Control (large card), 32+ tools, RBAC, Helm deployment, session persistence, MCP layer. Communicates breadth of the product.
- [ ] **Architecture diagram** -- SVG showing phone -> relay -> cluster flow. Can be static with CSS hover effects for v1; animate later. This is the "aha moment" visual.
- [ ] **Quickstart section** -- Terminal-styled code block with copy button. 3 commands to deploy. This is the conversion point -- visitors who reach here are ready to try it.
- [ ] **Use cases section** -- 3-4 scenario cards (on-call debugging, deploy troubleshooting, cluster exploration, incident response). Answers "when would I use this?"
- [ ] **Footer** -- GitHub, docs, license, author. Minimal and clean.
- [ ] **Dark theme with accent color system** -- Professional dark background, readable text, one accent color for interactive elements and glows.
- [ ] **Responsive layout** -- Works on phone (ironic if it does not, given the product).
- [ ] **GitHub stars badge** -- Minimal social proof that is real and automatic.

### Add After Validation (v1.x)

Features to add once the base page is live and the repo has traction.

- [ ] **Typing animation on quickstart** -- Animate commands being typed. Adds polish but not critical for launch. Trigger: page is live and working.
- [ ] **Animated architecture diagram** -- CSS animations showing data flow (connections establishing, data moving). Trigger: base SVG diagram is solid.
- [ ] **Gradient glow hover effects on cards** -- Colored glow on card hover, subtle radial gradients. Trigger: design system is stable.
- [ ] **Asciinema/GIF demo embed** -- Real terminal recording showing a debugging session via Remote Control. Trigger: product has a polished demo workflow.
- [ ] **Dynamic GitHub stats** -- Live star count, latest release version, Docker pulls. Trigger: repo has meaningful traffic.
- [ ] **"Phone + Cluster" split hero visual** -- Phone mockup on left, cluster diagram on right, animated connection. Trigger: basic hero is working and needs upgrade.

### Future Consideration (v2+)

Features to defer until the landing page has proven its value and the project has a community.

- [ ] **Testimonials section** -- Add when real users provide genuine feedback (GitHub issues, tweets, etc).
- [ ] **Comparison page** -- Separate page (not section) comparing to K8sGPT, kagent, etc. Add when search traffic warrants it.
- [ ] **Interactive demo** -- Embedded terminal or playground. Add when there is budget for always-on infrastructure.
- [ ] **Documentation site** -- Separate Astro content collection for full docs. Add when README outgrows its format.
- [ ] **Blog / changelog** -- Add when there are enough releases to warrant ongoing content.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Hero section (headline + CTAs) | HIGH | LOW | P1 |
| Dark theme + color system | HIGH | LOW | P1 |
| Feature bento grid (5-6 cards) | HIGH | LOW | P1 |
| Quickstart terminal block | HIGH | LOW | P1 |
| Architecture diagram (static SVG) | HIGH | MEDIUM | P1 |
| Use cases section | MEDIUM | LOW | P1 |
| Footer | MEDIUM | LOW | P1 |
| Responsive layout | HIGH | LOW | P1 |
| GitHub stars badge | MEDIUM | LOW | P1 |
| Eyebrow text / version badge | LOW | LOW | P1 |
| Bento grid (asymmetric upgrade) | MEDIUM | MEDIUM | P2 |
| Typing animation on quickstart | LOW | MEDIUM | P2 |
| Animated architecture diagram | MEDIUM | MEDIUM | P2 |
| Gradient glow hover effects | LOW | LOW | P2 |
| Phone + Cluster split visual | MEDIUM | MEDIUM | P2 |
| Asciinema/GIF demo embed | MEDIUM | LOW | P2 |
| Dynamic GitHub stats | LOW | LOW | P2 |
| Testimonials | MEDIUM | LOW | P3 |
| Comparison page | LOW | MEDIUM | P3 |
| Interactive demo | MEDIUM | HIGH | P3 |
| Documentation site | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch -- the page is incomplete without it
- P2: Polish and delight -- add after the page is live
- P3: Future -- add when project has traction

## Competitor Landing Page Analysis

| Design Element | K9s (k9scli.io) | Coolify (coolify.io) | Railway (railway.com) | Warp (warp.dev) | Linear (linear.app) | Our Approach |
|----------------|-----------------|----------------------|-----------------------|-----------------|----------------------|--------------|
| **Theme** | Light, simple | Dark, purple accent | Dark, deep purple + cyan | Dark, `#121212` | Dark, subtle gradients | Dark, electric blue/cyan accent |
| **Hero style** | Logo + tagline, playful ("Who Let The Pods Out?") | Bold tagline ("Self-hosting with superpowers") | Animated tagline + train visual | Minimal, centered headline | Minimal, animated grid background | Bold centered headline + architecture visual |
| **Feature presentation** | Bulleted list + screenshots | Card grid (15+ cards) | 5 feature blocks with alt comparisons | Feature blocks with product UI | Sequential scrolling sections | Bento grid (5-6 cards, asymmetric) |
| **Quickstart** | Docs link only | No quickstart on main page | "Deploy" CTA leads to app | Download buttons | No quickstart (SaaS) | Terminal code block with copy button |
| **Visual creativity** | Low -- functional, text-heavy | Medium -- clean cards, sponsor grid | High -- animated backgrounds, testimonial carousel, themed visuals | Medium -- clean typography, product screenshots | High -- animated grids, parallax | Medium-High -- animated SVG diagram, glow effects |
| **Social proof** | Asciinema embed, screenshots | 80+ sponsor avatars, Discord count | 2.3M users, Twitter testimonials, company logos | "Backed by" investors | Enterprise logos | GitHub stars badge, tech badges |
| **Personality** | Playful (dog puns, "In Style!") | Direct ("superpowers") | Atmospheric ("Ship software peacefully") | Professional, clean | Systematic, minimal | Confident, slightly irreverent (TBD in copy phase) |
| **What makes it stand out** | The dog theme and puns create memorable brand identity | Massive sponsor wall proves community support | Atmospheric visuals + real metrics create trust | Typography excellence and product polish | Animation quality and systematic design language | Architecture diagram as hero visual -- nobody else visualizes the phone-to-cluster flow |

### What We Learn From Each

**From K9s:** Personality matters. "Who Let The Pods Out?" is unforgettable. Our page needs a personality -- not corporate, not tryhard. The product name "Claude In A Box" already has personality; lean into it.

**From Coolify:** Sponsor/community proof works for open source. The wall of 80+ sponsor avatars is more convincing than any testimonial. We do not have this yet, but the GitHub stars badge serves a similar purpose at smaller scale.

**From Railway:** Atmospheric design creates emotional response. Their deep purple palette with animated train visuals makes infrastructure feel almost romantic. We should aim for a similar emotional quality -- debugging from your phone should feel empowering, not mundane.

**From Warp:** Typography and whitespace create perceived quality. Warp's page is mostly text with excellent type hierarchy (Matter + Inter + Fragment Mono). Good typography alone can make a page feel premium. Use 2-3 fonts: a display font for headlines, Inter/system for body, JetBrains Mono for code.

**From Linear:** Subtle animation creates sophistication. Linear's animated grid backgrounds add movement without distraction. The page feels alive but not busy. Our architecture diagram animation should follow this principle -- smooth, purposeful movement, not flashy transitions.

## Section-by-Section Specification

### 1. Hero Section

**Pattern:** Centered hero (dominant 2026 pattern per Evil Martians research)
**Components:**
- Eyebrow: `v1.0 | Open Source` in a subtle pill badge
- Headline: Bold, ~6-10 words. Example: "Your AI DevOps Agent, Running Inside Your Cluster"
- Subheadline: 1-2 sentences explaining the product. Example: "A containerized Claude Code deployment with 32+ debugging tools, Kubernetes RBAC, and phone-first access via Remote Control."
- CTA 1 (primary): "View on GitHub" -- bright accent button
- CTA 2 (secondary): "Quickstart" -- outlined/ghost button, scrolls to quickstart section
- Hero visual: Architecture diagram or phone+cluster split visual below the text

**Reference:** Railway's "Ship software peacefully" hero with visual below. Coolify's "Self-hosting with superpowers" directness.

### 2. Feature Bento Grid

**Pattern:** Asymmetric bento grid (Tailwind UI "two row bento grid with three column second row")
**Layout:**
- Row 1: 1 large card (60%) + 1 medium card (40%)
  - Large: Remote Control / phone-first access (the key differentiator)
  - Medium: 32+ pre-installed DevOps tools
- Row 2: 3 equal cards
  - Kubernetes RBAC (reader + operator tiers)
  - Helm chart deployment (one-command install)
  - Session persistence + MCP intelligence

**Each card:** Icon (Lucide or Heroicons), title, 2-3 sentence description. Subtle border, no harsh outlines. Background slightly lighter than page background. Glow effect on hover (P2).

**Reference:** Tailwind UI bento grid dark variant. Apple's product feature grids.

### 3. Architecture Diagram

**Pattern:** Custom SVG component with optional CSS animation
**Content:** Three-column flow:
- Left: Phone/browser icon labeled "You (anywhere)"
- Center: Cloud icon labeled "Anthropic Relay" with "Outbound HTTPS only" annotation
- Right: Kubernetes cluster box containing pod, service account, tools icons

**Animation (P2):** Dashed lines between components animate left-to-right. Pod "pulses" to indicate activity. Connection lines use `stroke-dasharray` + `stroke-dashoffset` animation.

**Reference:** Linear's animated grid background (subtlety). Railway's layered visual elements (depth).

### 4. Use Cases Section

**Pattern:** 3-4 scenario cards in a row
**Content:**
1. **Weekend On-Call** -- "Get paged at 2AM. Open your phone. Claude is already connected to your cluster. Diagnose the CrashLoopBackOff without opening your laptop."
2. **Deploy Gone Wrong** -- "Your CD pipeline just rolled out a bad config. Exec into the failing pod, check the logs, trace the network -- all from a browser tab."
3. **Cluster Exploration** -- "New to a cluster? Ask Claude to map the namespaces, check resource quotas, and summarize what is running. Instant situational awareness."
4. **Incident Response** -- "A real incident. Claude checks pod status, pulls recent events, tests DNS resolution, and drafts a summary. You verify and escalate."

**Reference:** Vercel's tabbed use-case navigation (simplified to cards for our scope).

### 5. Quickstart Section

**Pattern:** Terminal-styled code block with dark background
**Content:**
```bash
# Add the Helm repository
helm repo add claude-in-a-box https://...

# Deploy to your cluster
helm install claude ./claude-in-a-box/claude-in-a-box \
  --set auth.token=$CLAUDE_CODE_OAUTH_TOKEN

# Connect from anywhere
# Open claude.ai/code and connect to your instance
```

**Elements:** Monospace font (JetBrains Mono). Line numbers optional. Copy-to-clipboard button (top-right). Comment lines in muted color. Commands in bright color. Section headline: "Up and Running in 60 Seconds" or similar.

**Reference:** Bun's `curl` install command prominence. Coolify's direct install approach.

### 6. Footer

**Pattern:** Minimal, single-row footer
**Content:** GitHub link | Documentation | License (Apache 2.0/MIT) | "Built by [author]"
**Style:** Muted text, smaller font size. Accent color for links. Optional: "Built with Astro" badge.

## Design System Tokens

Based on analysis of Railway, Warp, Coolify, and Linear:

**Color palette recommendation:**
- Background: `#0a0a0a` (near-black, slightly warmer than pure black)
- Surface: `#141414` (card backgrounds, slightly elevated)
- Border: `#1f1f1f` (subtle card borders)
- Text primary: `#ededed` (off-white, easier on eyes than pure white)
- Text secondary: `#888888` (muted descriptions)
- Accent: `#00d4ff` (electric cyan -- terminal-inspired, distinct from Railway's purple and Coolify's purple)
- Accent glow: `#00d4ff33` (accent at 20% opacity for box-shadows)
- Success/code: `#22c55e` (green for terminal commands)

**Typography recommendation:**
- Headlines: Inter or system sans-serif at 700-900 weight
- Body: Inter or system sans-serif at 400 weight
- Code: JetBrains Mono or Fira Code at 400 weight

**Spacing:** 8px base grid. Generous whitespace between sections (120-160px vertical padding). Cards with 24-32px internal padding.

## Sources

### Primary (HIGH confidence -- direct page analysis)

- [Warp landing page](https://warp.dev) -- Dark theme, Matter/Inter/Fragment Mono typography, `#121212` background, minimal centered layout (analyzed via WebFetch)
- [Linear landing page](https://linear.app) -- Animated grid patterns, step-based opacity transitions, GPU-accelerated transforms, systematic design (analyzed via WebFetch)
- [Railway landing page](https://railway.com) -- "Ship software peacefully," deep purple palette, animated train visuals, testimonial carousel, 2.3M+ users stat, CSS theme variables with vaporwave mode (analyzed via WebFetch)
- [Coolify landing page](https://coolify.io) -- "Self-hosting with superpowers," `#6B16ED` purple accent, `#101010` background, 15+ feature cards, 80+ sponsor avatars, Discord count (analyzed via WebFetch)
- [Vercel landing page](https://vercel.com) -- "Build and deploy on the AI Cloud," framework selector, tabbed use-case navigation, Geist Mono font (analyzed via WebFetch)
- [K9s landing page](https://k9scli.io) -- "Who Let The Pods Out?" personality, bulleted feature list, Asciinema embed, screenshot gallery (analyzed via WebFetch)
- [Lens landing page](https://lenshq.io) -- "Power Tools for Kubernetes," 1M+ users, enterprise logos, product-specific accent colors, tabbed benefits, testimonial carousel (analyzed via WebFetch)
- [Charm.sh / charm.land](https://charm.land) -- Mascot-driven branding, playful language, purple-to-pink gradients, glass-morphism effects, "haters > /dev/null" footer irreverence (analyzed via WebFetch)

### Secondary (MEDIUM confidence -- research articles and pattern libraries)

- [Evil Martians: "We studied 100 dev tool landing pages"](https://evilmartians.com/chronicles/we-studied-100-devtool-landing-pages-here-is-what-actually-works-in-2025) -- Centered hero dominant pattern, "no salesy BS," two CTAs, eyebrow text, specific CTA language over generic
- [Markepear: Dev tool landing page examples](https://www.markepear.dev/examples/landing-page) -- 50+ dev tool page analysis, code-centric patterns, developer-first CTAs
- [LaunchKit (Evil Martians)](https://launchkit.evilmartians.io/) -- Free devtool landing page template: hero, feature cards, bento grid, code block, FAQ, CTA sections
- [Tailwind CSS Bento Grids](https://tailwindcss.com/plus/ui-blocks/marketing/sections/bento-grids) -- 5 official bento grid variants, light+dark, responsive
- [SaaS Landing Page: Features section examples](https://saaslandingpage.com/features/) -- 45+ feature page designs from top SaaS companies

### Tertiary (LOW confidence -- general patterns)

- [BentoGrids curated collection](https://bentogrids.com/) -- Bento layout inspiration gallery
- [Lapa Ninja: Development tools category](https://www.lapa.ninja/category/development-tools/) -- Developer tool landing page gallery
- [Supahero: Hero section library](https://supahero.io/) -- Hero section pattern collection

---
*Feature research for: Claude In A Box Landing Page (v1.1 milestone)*
*Researched: 2026-02-25*
