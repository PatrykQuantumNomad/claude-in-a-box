# Phase 9: Tech Debt Cleanup - Research

**Researched:** 2026-02-25
**Domain:** Docker build context, Kubernetes probes, GitHub Actions CI, KIND cluster isolation, documentation correctness
**Confidence:** HIGH

## Summary

Phase 9 closes 5 tech debt items and 1 integration gap identified in the v1.0 milestone audit. All items are well-scoped, low-risk fixes to existing infrastructure -- no new features, no architectural changes. Each fix is independently verifiable with existing tooling.

The six work items are: (1) move `.dockerignore` to the repo root so Docker's build context excludes `.git` and `.planning`; (2) wire the existing `readiness.sh` script as the readiness probe in all K8s manifests and Helm templates; (3) add a CI job that stands up a KIND cluster with Calico and runs the 35 BATS integration tests; (4) rename the test KIND cluster to `claude-in-a-box-test` to prevent collision with the dev cluster; (5) fix the README Helm verification command to use the correct label selector; (6) mark 5 requirement checkboxes as complete in REQUIREMENTS.md.

**Primary recommendation:** Treat each item as an independent task. No item has hidden dependencies on another, though items 3 and 4 are logically related (CI integration tests need the correct test cluster name). Fix item 4 before item 3.

## Standard Stack

### Core (Already in Repo)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| KIND | v0.31.0 (CI action) | Ephemeral K8s clusters in Docker | Standard for K8s testing in CI; helm/kind-action is the official GitHub Action |
| BATS | v1.13.0 | Bash Automated Testing System | Already used in repo; standard for shell-level integration tests |
| Calico | v3.31.4 | CNI with NetworkPolicy enforcement | Already used in repo's `install-calico.sh`; required for NetworkPolicy tests |
| Docker Buildx | v3 (CI action) | Docker image builds | Already in CI workflow |

### GitHub Actions (New for CI Integration Tests)

| Action | Version | Purpose | Why This |
|--------|---------|---------|----------|
| `helm/kind-action` | v1 | Create KIND cluster in CI | Official Helm/KIND action; supports custom config, cluster name, wait |
| `bats-core/bats-action` | v4.0.0 | Install BATS in CI runner | Official BATS action; installs bats + support/assert/detik/file libs |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `helm/kind-action` | Manual KIND install via `go install` | Action is simpler, handles caching, version pinning |
| `bats-core/bats-action` | Clone bats-core like `setup-bats.sh` does | Action is cleaner for CI; repo script is for local dev |
| Calico | Cilium | Calico already in repo scripts; switching CNI is out of scope |

## Architecture Patterns

### Item 1: .dockerignore Relocation

**Current state:** `docker/.dockerignore` exists with correct patterns (`.git`, `.gitignore`, `.planning`, `.claude`, `*.md`, `LICENSE`) but is ignored by Docker because the build context is `.` (repo root). Docker only reads `.dockerignore` from the build context root, NOT from alongside the Dockerfile.

**Fix pattern:** Create `.dockerignore` at the repo root (`./`). Two valid approaches per Docker docs:

1. **Root `.dockerignore`** -- Place at `./.dockerignore`. This is the standard location Docker searches.
2. **Dockerfile-specific ignore** -- Name it `docker/Dockerfile.dockerignore`. Docker BuildKit (used in CI via `docker/build-push-action`) supports this naming convention.

**Recommendation:** Use option 1 (root `.dockerignore`). Reasons:
- Works with both `docker build` and `docker compose build` (the Makefile uses `docker build -f docker/Dockerfile .`)
- Works with BuildKit and legacy builder
- Simpler -- one canonical location
- The existing `docker/.dockerignore` can be removed or kept as a reference

**Patterns to include:**
```
.git
.gitignore
.planning
.claude
*.md
LICENSE
tests/
kind/
.github/
helm/
```

Note: The existing `docker/.dockerignore` excludes `*.md` which would exclude `CLAUDE.md` from build context, but `CLAUDE.md` is generated at runtime by `generate-claude-md.sh`, not copied into the image. The `.mcp.json` file IS copied (line 270 of Dockerfile) and is NOT a `.md` file, so it is safe. The `scripts/` directory must NOT be excluded since the Dockerfile copies from it.

### Item 2: Readiness Probe Wiring

**Current state:** `readiness.sh` runs `claude auth status` and is already in the image at `/usr/local/bin/readiness.sh`. All three K8s manifests (StatefulSet, dev pod, Helm) use `healthcheck.sh` (pgrep-based) for BOTH liveness AND readiness probes.

**Fix pattern:** Change the readiness probe `command` from `healthcheck.sh` to `readiness.sh` in these files:
1. `k8s/base/04-statefulset.yaml` -- lines 64-69
2. `kind/pod.yaml` -- lines 24-29
3. `helm/claude-in-a-box/values.yaml` -- lines 92-97
4. All 4 Helm golden files must be regenerated (they embed the probe config)

**Probe timing considerations:**
- `readiness.sh` spawns a Node.js process (`claude auth status`) which takes 3-5 seconds (documented in readiness.sh header)
- Current `timeoutSeconds: 5` is tight -- the probe could timeout intermittently
- Current `periodSeconds: 30` is reasonable for a heavy probe
- `initialDelaySeconds: 10` is fine -- gives the container time to start before first probe
- **Recommendation:** Increase `timeoutSeconds` to 10 for the readiness probe to prevent flaky timeouts on cold starts. Keep `periodSeconds: 30` as documented in readiness.sh research guidance.

**Impact on existing tests:**
- Integration tests in `tests/integration/` do `wait_for_pod` which uses `kubectl wait --for=condition=Ready`. If `claude auth status` fails (no token), the pod will never become Ready.
- The dev/test workflow does NOT provide an OAuth token -- pods are authenticated interactively AFTER deployment.
- **This means the readiness probe will fail in dev/test clusters until a token is provided.**
- Mitigation options:
  a. Accept that `make deploy` will timeout waiting for Ready (bad developer experience)
  b. Use a startup probe with `healthcheck.sh` and readiness probe with `readiness.sh` -- pod becomes schedulable via startup probe, readiness indicates auth complete
  c. Keep dev pod (`kind/pod.yaml`) using `healthcheck.sh` for readiness and only wire `readiness.sh` in StatefulSet + Helm
  d. Wire `readiness.sh` everywhere but change `make deploy` / `make test-setup` wait to use a different condition

**Recommendation:** Option (c) is safest -- wire `readiness.sh` as readiness probe in `k8s/base/04-statefulset.yaml` and `helm/claude-in-a-box/values.yaml` (production-facing manifests), but keep `kind/pod.yaml` (dev-only manifest) using `healthcheck.sh` for readiness so `make bootstrap` and `make test-setup` continue to work without an OAuth token. Document this difference.

Alternatively, option (b) is cleaner: add a `startupProbe` using `healthcheck.sh` with generous timing (failureThreshold: 30, periodSeconds: 10 = 5 minutes), and use `readiness.sh` for the readinessProbe everywhere. The startupProbe succeeds once the process is running, and readiness tracks auth state. Kubernetes delays liveness/readiness probes until the startup probe passes. However, this still causes `make deploy` to report "not Ready" until auth completes. This is more honest but may break the dev workflow's `kubectl wait --for=condition=Ready` in the Makefile.

**Final recommendation:** Go with option (c). The dev pod manifest is explicitly labeled "Minimal dev pod manifest for Phase 3 development testing" -- keeping it simpler is appropriate. The production manifests (StatefulSet, Helm) should use the auth-aware readiness probe.

### Item 3: CI Integration Tests

**Current state:** CI workflow (`.github/workflows/ci.yaml`) has two jobs: `build-scan-publish` and `helm-lint`. BATS integration tests are manual-only via `make test-setup && make test`.

**Fix pattern:** Add a third job `integration-tests` to the CI workflow:

```yaml
integration-tests:
  runs-on: ubuntu-latest
  needs: [build-scan-publish]  # Needs the built image
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Set up BATS
      uses: bats-core/bats-action@4.0.0

    - name: Create KIND cluster with Calico
      uses: helm/kind-action@v1
      with:
        cluster_name: claude-in-a-box-test
        config: kind/cluster-test.yaml
        wait: 120s

    - name: Install Calico CNI
      run: scripts/install-calico.sh

    - name: Build and load image
      run: |
        docker build -f docker/Dockerfile -t claude-in-a-box:dev .
        kind load docker-image claude-in-a-box:dev --name claude-in-a-box-test

    - name: Deploy manifests
      run: |
        kubectl apply -f k8s/base/
        kubectl wait --for=condition=Ready pod -l app=claude-agent \
          -n default --timeout=120s

    - name: Run BATS integration tests
      run: bats --tap tests/integration/*.bats
```

**Key decisions:**
- The job needs the image. Two options: (a) use the image from `build-scan-publish` job via GHCR, or (b) rebuild the image in the integration-tests job. Option (b) is simpler and avoids GHCR auth complexity on PRs (where push is disabled). Build caching via `type=gha` means the rebuild is fast.
- `helm/kind-action` creates the KIND cluster. The `config` parameter accepts the test cluster config file.
- Calico install uses the existing `scripts/install-calico.sh`.
- BATS runs via the `bats` binary installed by `bats-core/bats-action` (NOT `tests/bats/bin/bats` which is the local clone).
- Calico install adds 60-120 seconds to CI. Total CI time estimate: ~5-8 minutes for this job.
- The existing `setup-bats.sh` script clones bats-core into `tests/bats/` -- this is fine for local dev but unnecessary in CI where the action installs it system-wide.

**Image loading consideration:** `helm/kind-action` creates the cluster. After that, `kind load docker-image` loads the locally built image. This avoids needing to pull from a registry.

**BATS helpers note:** The existing `tests/integration/helpers.bash` is self-contained (no external bats-support/assert/detik library imports). It uses raw BATS assertions (`[ "$status" -eq 0 ]`). The `bats-core/bats-action` installs extra libraries, but they are optional and the existing tests do not use them. No changes needed to test files.

### Item 4: Test Cluster Name Isolation

**Current state:** Both `kind/cluster.yaml` and `kind/cluster-test.yaml` use `name: claude-in-a-box`. The Makefile uses `CLUSTER_NAME ?= claude-in-a-box` for both `bootstrap` and `test-setup`.

**Fix pattern:**
1. Change `name:` in `kind/cluster-test.yaml` from `claude-in-a-box` to `claude-in-a-box-test`
2. Add `TEST_CLUSTER_NAME ?= claude-in-a-box-test` to the Makefile
3. Update `test-setup`, `test`, and `test-teardown` targets to use `TEST_CLUSTER_NAME`
4. Update `kind load` in test-setup to use `--name $(TEST_CLUSTER_NAME)`

**Files to change:**
- `kind/cluster-test.yaml` -- line 6: `name: claude-in-a-box-test`
- `Makefile` -- add `TEST_CLUSTER_NAME` var and update test targets

**Ripple effects:**
- The CI integration test job (item 3) should use `cluster_name: claude-in-a-box-test` to match
- No test code changes needed -- tests use `kubectl` which operates on the current context, and KIND sets the context automatically

### Item 5: README Helm Label Fix

**Current state:** README has `kubectl get pods -l app=claude-agent` on lines 100, 150, and 243. Lines 100 and 150 are in the KIND/raw-manifests section where `app=claude-agent` IS correct (raw k8s manifests use `app: claude-agent`). Line 243 is in the Helm section where it is WRONG -- Helm pods use `app: claude-in-a-box` (from `_helpers.tpl` selectorLabels template).

**Fix:** Change ONLY line 243 from `app=claude-agent` to `app=claude-in-a-box`. Lines 100 and 150 are correct and must NOT be changed.

**Verification:** The Helm golden file `values.golden.yaml` confirms: `matchLabels: app: claude-in-a-box` (line 154-155).

### Item 6: REQUIREMENTS.md Checkbox Updates

**Current state:** REQUIREMENTS.md has 5 items marked `[ ]` that should be `[x]`:
- `[ ] **DEV-01**` -- KIND cluster configuration (completed in Phase 3)
- `[ ] **DEV-02**` -- Bootstrap/teardown/redeploy scripts (completed in Phase 3)
- `[ ] **DEV-03**` -- Makefile wrapping build-load-deploy chain (completed in Phase 3)
- `[ ] **DEV-05**` -- Docker Compose reference file (completed in Phase 3)
- `[ ] **DOC-01**` -- README.md (completed in Phase 8)

**Fix:** Change `[ ]` to `[x]` for these 5 items. Also update the traceability table at the bottom where these show `Pending` -- change to `Complete`.

### Anti-Patterns to Avoid

- **Changing .dockerignore exclusions without checking Dockerfile COPY lines:** Every `COPY` source in the Dockerfile must not be excluded. Currently: `scripts/`, `.mcp.json`, `.claude/skills/` are all COPY'd and must remain included.
- **Wiring readiness.sh in dev pod without considering auth flow:** The dev pod has no OAuth token at deploy time. Using auth-aware readiness probe in the dev pod would break `make bootstrap`.
- **Regenerating golden files as a separate step:** Golden files must be regenerated in the same commit that changes Helm values, or the golden file CI test will fail.
- **Using `needs: [build-scan-publish]` in CI without actually sharing the image:** If the integration-tests job rebuilds the image locally, it does not strictly need the build job to complete first. However, making it depend on build-scan-publish means integration tests only run if the image builds and passes Trivy scan, which is a reasonable gate.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| KIND cluster in CI | Manual install scripts | `helm/kind-action@v1` | Handles install, config, caching, cleanup |
| BATS in CI | Clone from git | `bats-core/bats-action@4.0.0` | Pre-built, versioned, includes assertion libs |
| Docker build context filtering | Complex Dockerfile logic | `.dockerignore` at repo root | Docker's built-in mechanism; zero runtime cost |

**Key insight:** All five tech debt items use existing mechanisms that are already built into Docker, Kubernetes, or the repo's tooling. No custom solutions needed.

## Common Pitfalls

### Pitfall 1: .dockerignore Excluding Required Build Files
**What goes wrong:** Adding too-broad patterns to `.dockerignore` causes `COPY` directives in the Dockerfile to fail at build time.
**Why it happens:** The Dockerfile copies from `scripts/`, `.mcp.json`, and `.claude/skills/`. Excluding any of these breaks the build.
**How to avoid:** After creating `.dockerignore`, run `docker build -f docker/Dockerfile .` locally to verify. Cross-reference every `COPY` source in the Dockerfile against `.dockerignore` patterns.
**Warning signs:** Docker build fails with "COPY failed: file not found in build context" or similar.

### Pitfall 2: Readiness Probe Timeout Causing CrashLoopBackOff
**What goes wrong:** `readiness.sh` takes 3-5 seconds to complete (`claude auth status` spawns Node.js). If `timeoutSeconds` is too low, the probe is killed before it completes, and after `failureThreshold` consecutive failures (default 3), the pod's Ready condition stays false.
**Why it happens:** `claude auth status` cold-starts the Node.js runtime on every invocation.
**How to avoid:** Set `timeoutSeconds: 10` for the readiness probe. Use `periodSeconds: 30` to avoid hammering the Node.js process.
**Warning signs:** Pod shows `0/1 READY` indefinitely even though `kubectl exec` works.

### Pitfall 3: Calico Install Timing in CI
**What goes wrong:** Calico operator and custom resources take 60-120 seconds to become ready. If the deploy step runs before Calico is ready, pods may fail to schedule (no CNI available).
**Why it happens:** KIND with `disableDefaultCNI: true` has no CNI until Calico is installed and ready.
**How to avoid:** The existing `install-calico.sh` already has `kubectl wait` commands. Ensure the CI job runs `install-calico.sh` BEFORE loading images or deploying manifests.
**Warning signs:** Pods stuck in `ContainerCreating` with events like "network not ready".

### Pitfall 4: KIND Cluster Name in CI vs Local Collision
**What goes wrong:** If CI uses the same cluster name as local dev (`claude-in-a-box`), and the developer has a local cluster, there could be confusion. More importantly, the Makefile targets need to use the correct cluster name.
**Why it happens:** The `kind load` command requires `--name <cluster-name>` to load into the correct cluster.
**How to avoid:** CI explicitly sets `cluster_name: claude-in-a-box-test`. Makefile test targets use `TEST_CLUSTER_NAME`.
**Warning signs:** `kind load docker-image` says "image already present" but pods pull `ErrImageNeverPull`.

### Pitfall 5: Golden File Drift After Values Changes
**What goes wrong:** Changing `readinessProbe` in `values.yaml` causes golden file tests to fail because the golden files still contain the old probe config.
**Why it happens:** Golden files are static snapshots of `helm template` output. Any values change requires regeneration.
**How to avoid:** After changing `values.yaml`, run `bash scripts/helm-golden-test.sh --update` and commit the updated golden files.
**Warning signs:** CI `helm-lint` job fails on the golden file comparison step.

## Code Examples

### .dockerignore at Repo Root
```
# Build context exclusions for claude-in-a-box
# Location: ./.dockerignore (repo root, where build context starts)
.git
.gitignore
.planning
.claude
*.md
LICENSE
tests/
kind/
.github/
helm/
```
Source: Derived from existing `docker/.dockerignore` content plus additional directories not needed in build context.

### Readiness Probe in StatefulSet
```yaml
readinessProbe:
  exec:
    command: ["/usr/local/bin/readiness.sh"]
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 10
```
Source: Adapted from existing `k8s/base/04-statefulset.yaml` with command changed and timeout increased.

### Readiness Probe in Helm values.yaml
```yaml
readinessProbe:
  exec:
    command: ["/usr/local/bin/readiness.sh"]
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 10
```
Source: Adapted from existing `helm/claude-in-a-box/values.yaml` lines 92-97.

### CI Integration Test Job
```yaml
integration-tests:
  runs-on: ubuntu-latest
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Set up BATS
      uses: bats-core/bats-action@4.0.0

    - name: Create KIND cluster with Calico CNI
      uses: helm/kind-action@v1
      with:
        cluster_name: claude-in-a-box-test
        config: kind/cluster-test.yaml
        wait: 120s

    - name: Install Calico
      run: bash scripts/install-calico.sh

    - name: Build and load image
      run: |
        docker build -f docker/Dockerfile -t claude-in-a-box:dev .
        kind load docker-image claude-in-a-box:dev --name claude-in-a-box-test

    - name: Deploy manifests
      run: |
        kubectl apply -f k8s/base/
        kubectl wait --for=condition=Ready pod -l app=claude-agent \
          -n default --timeout=120s

    - name: Run integration tests
      run: bats --tap tests/integration/*.bats
```
Source: Composed from research on `helm/kind-action`, `bats-core/bats-action`, and existing Makefile targets.

### Test Cluster Name Fix
```yaml
# kind/cluster-test.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: claude-in-a-box-test
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

### Makefile Test Cluster Name Variable
```makefile
TEST_CLUSTER_NAME ?= claude-in-a-box-test

test-setup: build ## Create test cluster with Calico and deploy
	scripts/setup-bats.sh
	@if ! kind get clusters 2>/dev/null | grep -q "^$(TEST_CLUSTER_NAME)$$"; then \
		echo "Creating test cluster '$(TEST_CLUSTER_NAME)' with Calico CNI..."; \
		kind create cluster --name $(TEST_CLUSTER_NAME) --config $(KIND_TEST_CONFIG) --wait 60s; \
		scripts/install-calico.sh; \
	else \
		echo "Cluster '$(TEST_CLUSTER_NAME)' already exists, skipping creation"; \
	fi
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name $(TEST_CLUSTER_NAME)
	kubectl apply -f $(K8S_MANIFESTS)
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

test: ## Run integration test suite
	$(BATS) --tap $(TEST_DIR)/*.bats

test-teardown: ## Destroy test cluster
	kind delete cluster --name $(TEST_CLUSTER_NAME)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.dockerignore` alongside Dockerfile | `.dockerignore` at build context root OR `Dockerfile.dockerignore` | Docker BuildKit (2020+) added Dockerfile-specific naming | Root placement works universally; Dockerfile-specific naming is BuildKit-only |
| Manual KIND install in CI | `helm/kind-action@v1` | 2023+ widespread adoption | Simpler workflow, managed versioning |
| Manual BATS git clone in CI | `bats-core/bats-action@4.0.0` | 2024+ | Official action with library support |

**Deprecated/outdated:**
- None relevant. All tools and patterns in this phase are stable and current.

## Open Questions

1. **Should the dev pod (kind/pod.yaml) also use readiness.sh?**
   - What we know: Using `readiness.sh` would cause `make bootstrap` to report pod as "not Ready" until OAuth token is provided interactively.
   - What's unclear: Whether the team prefers honest readiness reporting (pod not Ready until auth) vs. smooth dev workflow (pod Ready immediately).
   - Recommendation: Keep dev pod using `healthcheck.sh` for readiness; document the difference.

2. **Should CI integration tests depend on the build-scan-publish job?**
   - What we know: The integration-tests job rebuilds the image locally, so it does not technically need the built artifact from build-scan-publish.
   - What's unclear: Whether gating integration tests behind Trivy scan is desired (slower but safer) or if they should run in parallel (faster total CI time).
   - Recommendation: Run in parallel with `build-scan-publish` and `helm-lint` for faster CI. All three jobs are independent.

3. **Should docker/.dockerignore be deleted after creating the root one?**
   - What we know: It will be dead code since Docker only reads from the build context root.
   - What's unclear: Whether keeping it as documentation/reference has value.
   - Recommendation: Delete it to avoid confusion. Its content is captured in the new root `.dockerignore`.

## Sources

### Primary (HIGH confidence)
- Docker build context docs: https://docs.docker.com/build/concepts/context/ -- `.dockerignore` location rules, Dockerfile-specific naming
- `helm/kind-action` GitHub repo: https://github.com/helm/kind-action -- Action inputs (version, config, cluster_name, wait)
- `bats-core/bats-action` GitHub repo: https://github.com/bats-core/bats-action -- Action inputs (bats-version, libraries)
- Kubernetes probe docs: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ -- Probe configuration parameters
- Codebase inspection: All findings verified against actual files in the repo

### Secondary (MEDIUM confidence)
- Docker/Moby issue #41079: https://github.com/moby/moby/issues/41079 -- Confirms `.dockerignore` must be at build context root (not alongside Dockerfile)

### Tertiary (LOW confidence)
- None. All findings are verified against codebase or official documentation.

## Metadata

**Confidence breakdown:**
- .dockerignore fix: HIGH -- Docker docs explicitly document behavior; verified against codebase
- Readiness probe wiring: HIGH -- Direct file inspection; probe script already exists and is tested
- CI integration tests: HIGH -- GitHub Actions used in existing CI; `helm/kind-action` and `bats-core/bats-action` are official
- Cluster name isolation: HIGH -- Trivial config change; verified both files share the name
- README label fix: HIGH -- Golden file confirms Helm uses `app: claude-in-a-box`; README line 243 confirmed wrong
- REQUIREMENTS.md checkboxes: HIGH -- Audit report confirms all requirements are satisfied

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable infrastructure; no fast-moving dependencies)
