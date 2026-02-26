# Roadmap: Claude In A Box

## Milestones

- [x] **v1.0 MVP** - Phases 1-9 (shipped 2026-02-25)
- [ ] **v1.1 Landing Page** - Phases 10-12 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 MVP (Phases 1-9) - SHIPPED 2026-02-25</summary>

- [x] **Phase 1: Container Foundation** - Multi-stage Dockerfile with 32+ DevOps tools
- [x] **Phase 2: Entrypoint & Authentication** - 3-mode entrypoint with OAuth support
- [x] **Phase 3: Local Development Environment** - KIND cluster bootstrap and dev workflow
- [x] **Phase 4: Kubernetes Manifests & RBAC** - StatefulSet, tiered RBAC, NetworkPolicy
- [x] **Phase 5: Integration Testing** - 35-test BATS suite with Calico-enabled KIND cluster
- [x] **Phase 6: Intelligence Layer** - MCP integration, DevOps skills, dynamic CLAUDE.md
- [x] **Phase 7: Production Packaging** - Helm chart with 3 security profiles, CI/CD pipeline
- [x] **Phase 8: Documentation & Release** - README, architecture diagram, troubleshooting guide
- [x] **Phase 9: Tech Debt Cleanup** - Milestone audit items, test isolation, CI integration tests

See milestones/v1.0-ROADMAP.md for full phase details.

</details>

### v1.1 Landing Page

- [ ] **Phase 10: Foundation & Infrastructure** - Astro scaffold, CI/CD, custom domain, design system
- [ ] **Phase 11: Page Content & Components** - Hero, features, architecture, quickstart, use cases, footer, responsive, 404
- [ ] **Phase 12: Polish & Deployment** - Scroll animations, SEO/OG meta tags, final verification

## Phase Details

### Phase 10: Foundation & Infrastructure
**Goal**: A deployable Astro site scaffold is live at remotekube.patrykgolabek.dev with correct CI/CD isolation, custom domain, and a design system ready for component development
**Depends on**: Phase 9 (v1.0 complete)
**Requirements**: SITE-01, SITE-02, SITE-03, SITE-04, SITE-05, DESIGN-01
**Success Criteria** (what must be TRUE):
  1. Running `npm run build` in the site/ directory produces a working static site with no errors
  2. Pushing a change to any file under site/ triggers only the deploy-site workflow (not the existing CI pipeline) and the site is live at remotekube.patrykgolabek.dev with HTTPS
  3. Pushing a change to any file outside site/ triggers only the existing CI pipeline (not the deploy workflow)
  4. The site uses a consistent dark theme design system with defined color tokens, typography (Inter + JetBrains Mono), and spacing -- visible on even a placeholder page
  5. Docker build context does not include the site/ directory (verified via .dockerignore)
**Plans**: 2 plans

Plans:
- [x] 10-01-PLAN.md — Scaffold Astro project with Tailwind CSS v4, dark theme design system, placeholder page
- [ ] 10-02-PLAN.md — CI/CD isolation (deploy workflow, paths-ignore), CNAME, .dockerignore

### Phase 11: Page Content & Components
**Goal**: Visitors see a complete, responsive landing page with all content sections that communicates the product value and drives them to the GitHub repo
**Depends on**: Phase 10
**Requirements**: PAGE-01, PAGE-02, PAGE-03, PAGE-04, PAGE-05, PAGE-06, DESIGN-03, DESIGN-05
**Success Criteria** (what must be TRUE):
  1. A visitor landing on the page sees a hero with headline, tagline, and two working CTAs (View on GitHub links to the repo, Quickstart scrolls to the quickstart section)
  2. Scrolling down reveals feature cards, an architecture diagram showing the phone-to-cluster data flow, a quickstart section with copy-to-clipboard terminal blocks for all 3 deployment methods, and use case scenarios
  3. The page renders correctly and is fully usable on mobile (375px), tablet (768px), and desktop (1280px+) viewports
  4. Navigating to a non-existent path (e.g., /foo) shows a custom 404 page that matches the site design, not the default GitHub 404
  5. The footer displays GitHub link, license info, and Anthropic attribution
**Plans**: TBD

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD
- [ ] 11-03: TBD

### Phase 12: Polish & Deployment
**Goal**: The landing page has scroll-triggered animations and proper SEO/social sharing metadata, elevating it from functional to polished
**Depends on**: Phase 11
**Requirements**: DESIGN-02, DESIGN-04
**Success Criteria** (what must be TRUE):
  1. Feature cards and sections animate into view on scroll (not visible until scrolled to, then reveal with motion)
  2. Sharing the site URL on Twitter/Slack/Discord shows a rich preview with correct title, description, and preview image (Open Graph tags working)
  3. The page loads with no layout shift from animations and total JavaScript bundle stays under 50kb
**Plans**: TBD

Plans:
- [ ] 12-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 10 -> 11 -> 12

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 | 17/17 | Complete | 2026-02-25 |
| 10. Foundation & Infrastructure | v1.1 | 1/2 | In Progress | - |
| 11. Page Content & Components | v1.1 | 0/0 | Not started | - |
| 12. Polish & Deployment | v1.1 | 0/0 | Not started | - |
