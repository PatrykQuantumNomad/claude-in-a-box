# Requirements: Claude In A Box

**Defined:** 2026-02-25
**Core Value:** Deploy once, control from anywhere — an AI-powered DevOps agent running inside your cluster that you can access from your phone without losing context, environment access, or session state.

## v1.1 Requirements

Requirements for the landing page milestone. Each maps to roadmap phases.

### Site Infrastructure

- [x] **SITE-01**: Astro project scaffolded in site/ directory with Tailwind CSS v4 and production build passing
- [ ] **SITE-02**: GitHub Actions deploy workflow deploys Astro site to GitHub Pages on push to main
- [ ] **SITE-03**: Custom domain remotekube.patrykgolabek.dev configured with CNAME and working HTTPS
- [ ] **SITE-04**: Existing CI workflow ignores site/ changes (paths-ignore filter)
- [ ] **SITE-05**: Docker build context excludes site/ directory (.dockerignore updated)

### Page Content

- [ ] **PAGE-01**: Hero section with headline, tagline, and two CTAs (View on GitHub + Quickstart)
- [ ] **PAGE-02**: Feature showcase as bento grid with 4-6 cards highlighting key capabilities
- [ ] **PAGE-03**: Architecture diagram (SVG) showing phone → Anthropic relay → Kubernetes cluster data flow
- [ ] **PAGE-04**: Quickstart section with terminal-styled code blocks and copy-to-clipboard for all 3 deployment methods
- [ ] **PAGE-05**: Use cases section showing 3-4 real-world scenarios (incident response, debugging, monitoring)
- [ ] **PAGE-06**: Footer with GitHub link, license info, and Anthropic attribution

### Design & Polish

- [x] **DESIGN-01**: Dark theme design system with consistent color tokens, typography, and spacing
- [ ] **DESIGN-02**: Scroll-triggered reveal animations on feature cards and sections using motion.js
- [ ] **DESIGN-03**: Responsive layout working on mobile, tablet, and desktop breakpoints
- [ ] **DESIGN-04**: SEO meta tags and Open Graph tags for social sharing with preview image
- [ ] **DESIGN-05**: Custom 404 page matching site design

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Multi-Cluster

- **MULTI-01**: Support for multiple kubeconfig contexts for fleet debugging
- **MULTI-02**: Per-cluster RBAC configuration via Helm values

### Observability

- **OBS-01**: Grafana/Prometheus dashboards for Claude Code session metrics
- **OBS-02**: Integration with cluster log aggregation (Fluentd, Loki)

### GitOps

- **GITOPS-01**: ArgoCD Application definition for self-deploying Claude In A Box
- **GITOPS-02**: ArgoCD ApplicationSet for fleet deployment

### Site Enhancements

- **SITE-ENH-01**: Blog section using MDX for release announcements and tutorials
- **SITE-ENH-02**: Advanced animations (animated architecture SVG, typing terminal effect, glow hover effects)
- **SITE-ENH-03**: Dark/light theme toggle

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full documentation site (Starlight) | v1.1 is a landing page, not a docs site — README serves as docs |
| Pricing page | Open source project, no pricing |
| Testimonials section | No real users yet — would be fabricated |
| Live demo / interactive playground | Massive scope, requires running container — link to README instead |
| Newsletter signup | Alienates DevOps audience, no mailing infrastructure |
| Multi-page site | Scope explosion — single landing page is the goal |
| Blog | Deferred to v2 as SITE-ENH-01 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SITE-01 | Phase 10 | Complete |
| SITE-02 | Phase 10 | Pending |
| SITE-03 | Phase 10 | Pending |
| SITE-04 | Phase 10 | Pending |
| SITE-05 | Phase 10 | Pending |
| PAGE-01 | Phase 11 | Pending |
| PAGE-02 | Phase 11 | Pending |
| PAGE-03 | Phase 11 | Pending |
| PAGE-04 | Phase 11 | Pending |
| PAGE-05 | Phase 11 | Pending |
| PAGE-06 | Phase 11 | Pending |
| DESIGN-01 | Phase 10 | Complete |
| DESIGN-02 | Phase 12 | Pending |
| DESIGN-03 | Phase 11 | Pending |
| DESIGN-04 | Phase 12 | Pending |
| DESIGN-05 | Phase 11 | Pending |

**Coverage:**
- v1.1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0

---
*Requirements defined: 2026-02-25*
*Last updated: 2026-02-25 after roadmap creation*
