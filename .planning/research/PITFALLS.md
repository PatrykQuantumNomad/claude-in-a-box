# Pitfalls Research

**Domain:** Adding Astro Landing Page to Existing DevOps Repo (GitHub Pages + Custom Domain)
**Researched:** 2026-02-25
**Confidence:** HIGH (verified across Astro official docs, GitHub Pages docs, GitHub community discussions, and multiple deployment guides)

## Critical Pitfalls

### Pitfall 1: CNAME File Deleted on Every Deployment (Custom Domain Resets)

**What goes wrong:**
After configuring the custom domain (`remotekube.patrykgolabek.dev`) in GitHub repo settings, the very first GitHub Actions deployment wipes the custom domain. The Pages settings revert to the default `<user>.github.io/<repo>` URL. Every subsequent push triggers this cycle: configure domain in settings, push code, domain disappears, site 404s on the custom domain.

**Why it happens:**
GitHub Pages stores the custom domain configuration via a CNAME file in the deployment artifact. When the `actions/deploy-pages` action deploys, it replaces the entire deployment artifact. If the CNAME file is not included in the built output, the custom domain configuration is lost. This is the single most reported GitHub Pages issue -- there are multiple long-running community discussions (GitHub Community #159544, #22366, #48422) with hundreds of reports.

The `withastro/action` builds the `dist/` directory and uploads it as the deployment artifact. If there is no CNAME file in the built output, the custom domain is gone.

**How to avoid:**
- Create `site/public/CNAME` containing exactly one line: `remotekube.patrykgolabek.dev` (no trailing newline, no protocol prefix, no trailing slash).
- Astro copies everything in `public/` to the build output root (`dist/`), so the CNAME file will be included in the deployment artifact automatically.
- Set `site: 'https://remotekube.patrykgolabek.dev'` in `astro.config.mjs` -- this must match the CNAME domain exactly.
- Do NOT set `base` when using a custom domain. The `base` config is only needed for `username.github.io/repo-name` deployments.
- Verify after first deployment: check GitHub repo Settings > Pages -- the custom domain should show the configured domain and not be blank.

**Warning signs:**
- Custom domain field in repo Settings > Pages is empty after a deployment.
- Site works at `<user>.github.io/<repo>` but 404s at the custom domain.
- DNS is correctly configured (verified with `dig`) but site still does not load.
- Deployment log shows success but the live site URL is wrong.

**Phase to address:**
Phase 1 (Project Setup) -- The `public/CNAME` file must be created alongside the initial Astro project scaffold. If missed, every subsequent deployment breaks the custom domain.

---

### Pitfall 2: GitHub Pages Source Not Set to "GitHub Actions" (Deploy Silently Fails)

**What goes wrong:**
The GitHub Actions workflow runs successfully, the build passes, the artifact uploads, but the deploy step fails with a permissions error or the site never actually updates. The deployment appears in the Actions tab as successful, but the site shows a 404 or stale content.

**Why it happens:**
GitHub Pages has two source modes: "Deploy from a branch" (legacy) and "GitHub Actions" (current). When a repository has never had Pages enabled, or was previously using branch-based deployment, the source must be explicitly switched to "GitHub Actions" in Settings > Pages > Source. The `actions/deploy-pages` action requires this setting. Without it, the action either fails silently or the deployment never becomes active.

Additionally, switching to "GitHub Actions" source creates a `github-pages` environment in the repository. This environment has protection rules that, by default, only allow the default branch (main) to deploy. If the deploy workflow runs on a non-default branch (e.g., during testing), it will fail with "Branch X is not allowed to deploy to github-pages due to environment protection rules."

**How to avoid:**
- Before the first deployment, manually go to Settings > Pages > Source and select "GitHub Actions."
- Document this as a one-time setup step in the project README or contributing guide.
- Ensure the deploy workflow only triggers on the `main` branch (not on all branches like the CI workflow).
- If testing from a feature branch, temporarily update the `github-pages` environment protection rules in Settings > Environments > github-pages > Deployment branches.

**Warning signs:**
- `actions/deploy-pages` step shows "Error: Deployment request failed" or similar.
- Settings > Pages still shows "Deploy from a branch" as the source.
- The github-pages environment does not exist under Settings > Environments.
- Deploy works from main but fails from any other branch.

**Phase to address:**
Phase 1 (Project Setup) -- This is a one-time repository configuration change that gates all deployments. Must be documented as a setup prerequisite.

---

### Pitfall 3: Astro `site` and `base` Misconfiguration Causes Broken Assets and Links

**What goes wrong:**
CSS, JavaScript, images, and internal links all 404 on the deployed site. The HTML loads but the page is unstyled, interactive elements are broken, and navigation links point to wrong paths. Alternatively, the sitemap, canonical URLs, and OG meta tags contain incorrect domains.

**Why it happens:**
Astro has two related but distinct configuration options that developers frequently confuse:
- `site`: The full deployment URL. Used for generating absolute URLs (sitemaps, canonical, OG tags). Example: `https://remotekube.patrykgolabek.dev`.
- `base`: A path prefix for all routes and assets. Only needed when deploying to a subdirectory like `username.github.io/repo-name`. Example: `/repo-name`.

The critical mistake: when using a custom domain, developers copy configuration examples that include `base: '/repo-name'` and fail to remove it. This causes all asset paths to be prefixed with `/repo-name/` even though the custom domain serves from root. Every CSS/JS/image request goes to `remotekube.patrykgolabek.dev/repo-name/styles.css` instead of `remotekube.patrykgolabek.dev/styles.css`.

The inverse mistake also occurs: not setting `site` at all, which causes Astro to generate relative URLs that break in certain contexts (RSS feeds, sitemaps, OG tags).

**How to avoid:**
- For custom domain deployment, the config is exactly:
  ```js
  export default defineConfig({
    site: 'https://remotekube.patrykgolabek.dev',
    // NO base property -- custom domain serves from root
  });
  ```
- Never copy `base` from GitHub Pages examples when using a custom domain.
- After the first build, inspect `dist/index.html` -- verify all asset paths start with `/` (not `/repo-name/`).
- Test locally with `astro preview` to catch path issues before deploying.

**Warning signs:**
- Site loads but is completely unstyled (CSS 404).
- Browser devtools Network tab shows 404s for all static assets.
- Internal navigation links include an unexpected path prefix.
- `astro.config.mjs` contains both `site` and `base` when using a custom domain.

**Phase to address:**
Phase 1 (Project Setup) -- This is set once in the initial `astro.config.mjs` and affects every page. Getting it wrong means every asset and link is broken.

---

### Pitfall 4: Deploy Workflow Triggers on Every Push (Unnecessary Builds for Non-Site Changes)

**What goes wrong:**
Every push to main -- whether it changes Helm charts, Kubernetes manifests, Dockerfiles, or CI configs -- triggers a full Astro build and GitHub Pages deployment. This wastes CI minutes, creates unnecessary deployments in the GitHub Pages environment history, and risks deploying a broken site if the Astro build environment is disrupted by unrelated changes.

**Why it happens:**
The default Astro deploy workflow template triggers on `push: branches: [main]` without path filtering. In a DevOps repo where the site lives in a `site/` subdirectory alongside Docker, K8s, Helm, and CI files, 90%+ of commits will be infrastructure changes that have nothing to do with the landing page.

The existing CI workflow (`ci.yaml`) already triggers on `push: branches: ["*"]` for all branches. Without path filtering on the deploy workflow, every push to main runs both the CI pipeline (Docker build, Trivy scan, Helm lint, integration tests) AND a redundant Astro build + deploy.

**How to avoid:**
- Add path filtering to the deploy workflow:
  ```yaml
  on:
    push:
      branches: [main]
      paths:
        - 'site/**'
        - '.github/workflows/deploy-site.yaml'
  ```
- Also add `workflow_dispatch` as a trigger so the deployment can be manually triggered when needed (e.g., after changing the workflow file itself or for debugging).
- Name the workflow file distinctly from the existing CI: `deploy-site.yaml` (not `deploy.yaml` which is ambiguous).
- Ensure the CI workflow (`ci.yaml`) ignores the `site/` directory via `paths-ignore` to avoid running Docker builds when only the site changes:
  ```yaml
  on:
    push:
      branches: ["*"]
      paths-ignore:
        - 'site/**'
  ```

**Warning signs:**
- GitHub Actions shows deploy-site workflow runs for commits that only touched Helm or Docker files.
- Pages deployment history shows many deployments with identical content.
- CI minutes being consumed faster than expected.
- Both CI and deploy workflows run for every single push to main.

**Phase to address:**
Phase 1 (Project Setup) -- Path filtering must be configured from the first workflow commit. Retrofitting it later means the deploy workflow has already been triggered dozens of times unnecessarily.

---

### Pitfall 5: Deploy Workflow Permissions Conflict with Existing CI Permissions

**What goes wrong:**
The Astro deploy workflow requires `pages: write` and `id-token: write` permissions. The existing CI workflow has `contents: read`, `packages: write`, and `security-events: write`. Developers either: (a) add pages permissions to the CI workflow (wrong -- CI should not deploy pages), (b) set permissions at the repository level to be permissive (security risk), or (c) forget to set permissions on the deploy workflow entirely (deploy fails with 403).

**Why it happens:**
GitHub Actions uses a least-privilege model. Each workflow declares its own permissions. The `actions/deploy-pages` action requires `id-token: write` for OIDC authentication with the Pages deployment API. This is an unusual permission that most developers have never seen. It is not needed for the CI workflow and should not be added there.

The `id-token: write` permission is particularly confusing because it sounds like it would allow writing arbitrary tokens. In reality, it is requesting permission to generate an OIDC JWT that GitHub's own infrastructure validates. Without it, the deploy step fails with a cryptic "Error: Ensure GITHUB_TOKEN has permission" message that does not mention `id-token` specifically.

**How to avoid:**
- Keep the deploy workflow (`deploy-site.yaml`) completely separate from CI (`ci.yaml`).
- Set permissions at the job level in the deploy workflow:
  ```yaml
  permissions:
    contents: read
    pages: write
    id-token: write
  ```
- Do NOT modify the existing CI workflow's permissions.
- Do NOT set repository-level default permissions to "Read and write" -- this is overly permissive.

**Warning signs:**
- Deploy step fails with "Error: Ensure GITHUB_TOKEN has permission to deploy to Pages."
- CI workflow suddenly has `pages: write` or `id-token: write` in its permissions block.
- Repository settings show "Read and write permissions" set at the organization or repository level.

**Phase to address:**
Phase 1 (Project Setup) -- Permissions must be correctly declared when the deploy workflow is first created. The error messages when permissions are wrong are not helpful, leading to trial-and-error that often ends with overly broad permissions.

---

### Pitfall 6: DNS Misconfiguration for Custom Subdomain (CNAME vs A Record Confusion)

**What goes wrong:**
The custom domain `remotekube.patrykgolabek.dev` is configured in GitHub Pages settings and in the Astro `public/CNAME`, but the site returns a DNS resolution error, an SSL certificate error, or redirects in an infinite loop. HTTPS enforcement fails with "Certificate not yet ready" indefinitely.

**Why it happens:**
For a subdomain like `remotekube.patrykgolabek.dev`, the DNS record must be a CNAME pointing to `<username>.github.io.` (with trailing dot). Common mistakes:
1. Creating an A record instead of a CNAME (A records are for apex domains like `patrykgolabek.dev`, not subdomains).
2. Including the repository name in the CNAME target (e.g., `username.github.io/claude-in-a-box` -- the CNAME target is just `username.github.io`).
3. Pointing the subdomain CNAME to the apex domain instead of to GitHub (creating a loop).
4. Missing the CAA record -- GitHub Pages uses Let's Encrypt for HTTPS certificates. If the DNS has a CAA record that does not include `letsencrypt.org`, certificate provisioning fails silently.
5. Not waiting for DNS propagation (up to 24 hours, though usually 5-30 minutes).

**How to avoid:**
- Configure exactly this DNS record at the domain registrar:
  ```
  remotekube.patrykgolabek.dev.  CNAME  <github-username>.github.io.
  ```
- If there are existing CAA records on `patrykgolabek.dev`, add: `0 issue "letsencrypt.org"`.
- After DNS configuration, verify with: `dig remotekube.patrykgolabek.dev +short` -- should return `<username>.github.io.`
- In GitHub Pages settings, enter the custom domain and wait for the DNS check to pass (green checkmark).
- Enable "Enforce HTTPS" only after the DNS check passes and the certificate is provisioned (can take up to 1 hour).
- Do NOT use wildcard DNS records (`*.patrykgolabek.dev`) -- GitHub explicitly warns against this due to subdomain takeover risk.

**Warning signs:**
- `dig` returns an IP address instead of a CNAME (wrong record type).
- `dig` returns the CNAME target with a path component (wrong value).
- GitHub Pages settings show "DNS check unsuccessful" or "Certificate not yet ready" for more than 1 hour.
- Browser shows "NET::ERR_CERT_AUTHORITY_INVALID" or similar SSL errors.
- Infinite redirect loop between HTTP and HTTPS.

**Phase to address:**
Phase 1 (Project Setup) -- DNS must be configured before the first deployment. Certificate provisioning adds latency so this should be done early to avoid blocking the first successful deploy.

---

### Pitfall 7: Astro Site in Subdirectory -- withastro/action `path` Parameter Misconfigured

**What goes wrong:**
The Astro build fails in GitHub Actions with "Could not find package.json" or "astro: command not found." Alternatively, the build runs at the repo root, finds no Astro project, and either produces an empty build or fails with obscure errors about missing `astro.config.mjs`.

**Why it happens:**
When the Astro project lives in a subdirectory (e.g., `site/`) rather than the repo root, the `withastro/action` needs to know where to find it. The action's `path` input parameter specifies the project root. Without it, the action assumes the Astro project is at the repository root -- which in this repo contains Docker, Helm, and Kubernetes files, not an Astro project.

Additionally, the `package.json` and lockfile (`package-lock.json`, `pnpm-lock.yaml`, etc.) must be inside the `site/` directory, not at the repo root. The action auto-detects the package manager by looking for a lockfile relative to the `path`. If the lockfile is missing, the action fails with a package manager detection error.

**How to avoid:**
- Set the `path` input in the deploy workflow:
  ```yaml
  - uses: withastro/action@v3
    with:
      path: ./site
  ```
- Ensure the `site/` directory contains its own `package.json`, lockfile, and `astro.config.mjs`.
- Do NOT place the Astro `package.json` at the repo root -- this would interfere with the existing repo structure and potentially confuse CI.
- Add `site/node_modules/` to `.gitignore` (the root `.gitignore` or a `site/.gitignore`).
- Test locally: `cd site && npm install && npm run build` should succeed independently.

**Warning signs:**
- Build log shows "Looking for lockfile in /home/runner/work/repo/repo/" (repo root, not site/).
- Build fails with "Cannot find module 'astro'" despite astro being in site/package.json.
- Build succeeds but `dist/` is empty or contains unexpected files from the repo root.
- The action falls back to a wrong package manager (e.g., npm when the project uses pnpm).

**Phase to address:**
Phase 1 (Project Setup) -- The workflow `path` must be configured when the workflow is first created. This is the most common monorepo-specific configuration mistake with Astro.

---

### Pitfall 8: Missing 404.html Causes Ugly Default GitHub Pages 404

**What goes wrong:**
Users who navigate to a non-existent URL (typo, old bookmark, broken external link) see GitHub's default 404 page -- a generic page with GitHub branding that looks completely unrelated to the project. This is jarring and unprofessional for a project landing page.

**Why it happens:**
GitHub Pages serves a custom `404.html` from the deployment root if it exists. Astro will generate `404.html` from `src/pages/404.astro`, but only if that file is created. It is not part of the default Astro project scaffold. Developers focus on the happy path (index, features, docs) and forget the error path.

**How to avoid:**
- Create `site/src/pages/404.astro` as part of the initial page scaffold.
- Use the same layout as other pages so the 404 matches the site design.
- Include a link back to the homepage.
- Test by navigating to a non-existent path after deployment.

**Warning signs:**
- No `404.html` in the `dist/` build output.
- Visiting `remotekube.patrykgolabek.dev/nonexistent` shows GitHub's default 404 page.

**Phase to address:**
Phase 2 (Content & Polish) -- Not a blocker for initial deployment, but should be addressed before any public launch or sharing.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Putting Astro package.json at repo root | Simpler workflow, no `path` config needed | Pollutes repo root with Node dependencies, conflicts with any other tooling, confuses contributors who expect a DevOps repo | Never -- the `site/` subdirectory is the correct pattern for a non-JS primary repo |
| Skipping path filters on deploy workflow | Simpler workflow config | Every push to main triggers a build+deploy, wastes CI minutes, creates deployment noise | Never -- path filtering is trivial to add and essential in a mixed repo |
| Hardcoding GitHub username in workflow | Works immediately | Breaks when repo is forked or transferred; contributor PRs may fail | Only for initial prototype. Replace with `${{ github.repository_owner }}` |
| Using `trailingSlash: 'always'` without testing | Matches some SEO best practices | GitHub Pages does not do server-side redirects for trailing slashes on static files. URLs without trailing slash will 404 instead of redirecting. | Never for GitHub Pages -- use `'ignore'` (default) or `'never'` |
| Deploying without concurrency control | Faster deploys, no queuing | Concurrent deploys can race and produce inconsistent state; stale deploys may overwrite newer ones | Never -- always set `concurrency: group: pages, cancel-in-progress: false` |

## Integration Gotchas

Common mistakes when connecting Astro deployment to GitHub Pages and DNS.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub Pages custom domain | Setting domain in repo settings UI only (no CNAME in source) | Create `public/CNAME` file so domain persists across deployments |
| DNS for subdomain | Using A record instead of CNAME for `remotekube.patrykgolabek.dev` | CNAME record pointing to `<username>.github.io.` |
| HTTPS enforcement | Enabling "Enforce HTTPS" before certificate is provisioned | Wait for green DNS check, then enable HTTPS. Allow up to 1 hour |
| GitHub Actions permissions | Adding `id-token: write` to the existing CI workflow | Create a separate deploy workflow with its own permissions block |
| Astro action lockfile | Not committing lockfile to `site/` directory | Run `npm install` in `site/`, commit the resulting lockfile |
| withastro/action path | Omitting `path` input when project is in subdirectory | Set `path: ./site` in the action configuration |
| Concurrency | No concurrency group on deploy workflow | Add `concurrency: { group: "pages", cancel-in-progress: false }` to prevent deployment races |

## Performance Traps

Patterns that waste CI resources or degrade site performance.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| No path filtering on deploy workflow | Every push to main triggers Astro build | Add `paths: ['site/**']` to workflow trigger | Immediately -- first non-site push to main |
| Large unoptimized images in public/ | Slow page loads, poor Lighthouse scores, large deployment artifacts | Use Astro's built-in image optimization (`astro:assets`), serve WebP/AVIF formats | When images exceed 200KB each |
| No build caching in workflow | Full rebuild from scratch on every deploy (30-60 seconds) | `withastro/action` has `cache: true` by default -- do not disable it | Noticeable after 10+ deploys |
| Importing heavy JS libraries for landing page | Bundle size balloons, slow FCP/LCI | Use Astro's zero-JS-by-default approach. Only add `client:*` directives when truly interactive | When total JS exceeds 50KB for a landing page |

## Security Mistakes

Domain-specific security issues for a GitHub Pages site on a custom domain.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Wildcard DNS record (`*.patrykgolabek.dev`) | Subdomain takeover -- anyone can claim unconfigured subdomains | Only create specific CNAME records for specific subdomains |
| Missing domain verification in GitHub | Another GitHub user could configure your domain on their Pages site | Verify the domain in GitHub account settings (Settings > Pages > Verified domains) |
| Hardcoded secrets in Astro source | API keys, tokens visible in client-side source (Astro generates static HTML) | Never put secrets in Astro components. Use environment variables only for build-time public values |
| No CSP headers | XSS risk if site ever includes user-generated content or third-party scripts | Add `<meta http-equiv="Content-Security-Policy">` in the layout. GitHub Pages does not support custom headers, so use meta tag |

## UX Pitfalls

Common user experience mistakes for DevOps project landing pages.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No clear "Get Started" path from landing page to actual repo | Visitors see the marketing but cannot find the code or docs | Prominent CTA linking to the GitHub repo and a quickstart section |
| Landing page shows different information than README | Confusion about which is authoritative, outdated landing page after repo evolves | Keep the landing page focused on value prop and CTA, point to README for detailed docs |
| No mobile responsiveness | Over 50% of developer browsing is mobile; broken layout kills credibility | Use responsive CSS from day one, test on mobile viewport |
| Missing OG/meta tags for social sharing | Sharing the link on Twitter/Discord/Slack shows a generic preview or no preview | Set `<meta property="og:*">` tags with title, description, and image |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Custom domain works:** Often missing -- `public/CNAME` file, DNS CNAME record, HTTPS enforcement enabled, `site` config set in astro.config.mjs
- [ ] **Deploy workflow is correct:** Often missing -- `path: ./site` in withastro/action, `id-token: write` permission, path filters on trigger, concurrency group
- [ ] **Site renders correctly:** Often missing -- no `base` when using custom domain, asset paths verified in build output, 404.astro page exists
- [ ] **Existing CI unaffected:** Often missing -- `paths-ignore: ['site/**']` on ci.yaml, no shared package.json at repo root, no accidental permission changes
- [ ] **DNS fully configured:** Often missing -- CNAME (not A) record for subdomain, CAA record includes letsencrypt.org, domain verified in GitHub account
- [ ] **Social sharing works:** Often missing -- og:title, og:description, og:image meta tags, tested on Twitter Card Validator or similar
- [ ] **Repository settings correct:** Often missing -- Pages source set to "GitHub Actions" (not "Deploy from branch"), github-pages environment exists

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CNAME file missing from deploy | LOW | Add `public/CNAME`, push, wait for redeploy. Custom domain restores automatically |
| `base` incorrectly set | LOW | Remove `base` from astro.config.mjs, push. All asset paths fix on next build |
| Wrong DNS record type | LOW | Delete A record, create CNAME record at registrar. Wait for propagation (5-30 min typically) |
| Pages source not set to Actions | LOW | Change in Settings > Pages > Source. Re-run workflow |
| HTTPS cert not provisioning | MEDIUM | Remove custom domain in settings, wait 5 min, re-add. This triggers a new cert request. Check CAA records |
| Deploy workflow permissions wrong | LOW | Update workflow yaml permissions block, push, re-run |
| Existing CI broken by site changes | MEDIUM | Add `paths-ignore` to ci.yaml, verify Docker build still triggers on actual infrastructure changes |
| Domain takeover risk from wildcard DNS | HIGH | Remove wildcard record immediately, create only specific records, verify domain ownership in GitHub |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| CNAME file deleted on deploy | Phase 1: Project Setup | Custom domain persists after 2+ consecutive deploys |
| Pages source misconfigured | Phase 1: Project Setup | Settings > Pages shows "GitHub Actions" and green checkmark |
| site/base misconfiguration | Phase 1: Project Setup | `dist/index.html` has correct asset paths; no `/repo-name/` prefix |
| Deploy triggers on all pushes | Phase 1: Project Setup | Push to main touching only `helm/` does NOT trigger deploy-site workflow |
| Permission conflicts with CI | Phase 1: Project Setup | CI workflow unchanged; deploy workflow has its own permissions |
| DNS misconfiguration | Phase 1: Project Setup | `dig remotekube.patrykgolabek.dev +short` returns correct CNAME target |
| withastro/action path wrong | Phase 1: Project Setup | Build log shows "Building Astro project at ./site" |
| Missing 404 page | Phase 2: Content & Polish | Navigating to `/nonexistent` shows custom-branded 404 page |
| No social sharing meta tags | Phase 2: Content & Polish | Twitter Card Validator shows correct preview for site URL |
| Existing CI interference | Phase 1: Project Setup | Pushing site-only changes does NOT trigger Docker build/scan/helm-lint jobs |

## Sources

- [Astro Official Docs: Deploy to GitHub Pages](https://docs.astro.build/en/guides/deploy/github/) -- HIGH confidence (official documentation, verified via WebFetch)
- [GitHub Docs: Troubleshooting Custom Domains and GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages) -- HIGH confidence (official documentation, verified via WebFetch)
- [GitHub Docs: Managing a Custom Domain](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) -- HIGH confidence
- [GitHub Docs: Configuring a Publishing Source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) -- HIGH confidence
- [GitHub Community Discussion #159544: Custom Domain Deleted After Pushing](https://github.com/orgs/community/discussions/159544) -- HIGH confidence (community reports confirming the CNAME overwrite issue)
- [GitHub Community Discussion #22366: Pages Resets Custom Domain on Deploy](https://github.com/orgs/community/discussions/22366) -- HIGH confidence
- [GitHub Community Discussion #39054: Branch Not Allowed to Deploy Due to Environment Protection](https://github.com/orgs/community/discussions/39054) -- HIGH confidence
- [withastro/action GitHub Repository](https://github.com/withastro/action) -- HIGH confidence (official action, verified inputs and configuration)
- [actions/deploy-pages Issue #304: CNAME File Does Not Work](https://github.com/actions/deploy-pages/issues/304) -- MEDIUM confidence (community workarounds)
- [actions/deploy-pages Issue #329: Clarity on id-token:write](https://github.com/actions/deploy-pages/issues/329) -- MEDIUM confidence
- [Astro Build Failures Guide (BetterLink Blog)](https://eastondev.com/blog/en/posts/dev/20251203-astro-build-failures-guide/) -- MEDIUM confidence
- [Astro Issue #4229: Base Option Producing Unexpected Asset Paths](https://github.com/withastro/astro/issues/4229) -- HIGH confidence (official issue tracker, documents the base/asset path interaction)
- [GitHub Docs: Workflow Syntax - paths filter](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) -- HIGH confidence

---
*Pitfalls research for: Adding Astro Landing Page to Existing DevOps Repo (Claude In A Box)*
*Researched: 2026-02-25*
