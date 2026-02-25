# Phase 7: Production Packaging - Research

**Researched:** 2026-02-25
**Domain:** Helm chart packaging, GitHub Actions CI/CD, container vulnerability scanning, SBOM generation
**Confidence:** HIGH (Helm chart patterns) / MEDIUM (Helm 4.x specifics) / HIGH (CI/CD pipeline)

## Summary

Phase 7 wraps the existing raw Kubernetes manifests from Phase 4 (`k8s/base/` and `k8s/overlays/`) into a Helm chart and adds a CI/CD pipeline for image scanning and artifact traceability. The critical design constraint is that `helm template` output must match the validated raw manifests -- the Helm chart parameterizes but does not rewrite.

The Helm chart uses `apiVersion: v2` (the current standard for Helm 3+ and Helm 4). Helm 4 (v4.1.1, already pinned in the Dockerfile) maintains full backward compatibility with v2 charts. The proposed Chart v3 format (HIP-0020) is not yet released and ships after Helm 4.0 -- it is not relevant for this phase. The main Helm 4 behavioral change is Server-Side Apply (SSA) becoming the default in Helm 4.1, which replaces the three-way merge but does not affect `helm template` rendering or chart structure.

The CI pipeline uses GitHub Actions with `docker/build-push-action` for image builds, `aquasecurity/trivy-action` for vulnerability scanning, and `anchore/sbom-action` for SBOM generation. All three are well-established GitHub Actions with stable APIs. The pipeline triggers on every push, builds and tags the image, runs Trivy with a fail-on-critical gate, generates an SPDX SBOM, and publishes artifacts to GHCR.

**Primary recommendation:** Create a Helm chart at `helm/claude-in-a-box/` with `apiVersion: v2`, convert the four existing base manifests into parameterized templates, provide three security profile values files, validate with golden file diff tests, and build a single-workflow GitHub Actions CI pipeline.

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Helm | 4.1.1 | Kubernetes package manager; chart templating and deployment | Already pinned in Dockerfile; industry standard for K8s packaging |
| Chart apiVersion | v2 | Helm chart specification format | Current stable format; v3 not yet released (HIP-0020 is post-4.0) |
| docker/build-push-action | v6 | GitHub Action to build and push Docker images with Buildx | Official Docker action; supports multi-arch, caching, GHCR push |
| docker/metadata-action | v5 | Generate image tags and OCI labels from Git context | Handles SHA, semver, branch tagging automatically |
| aquasecurity/trivy-action | 0.33.1 | Container image vulnerability scanning in CI | Official Trivy action; SARIF output for GitHub Security tab |
| anchore/sbom-action | v0 | SBOM generation from container images using Syft | Standard SBOM action; SPDX and CycloneDX output; auto-attaches to releases |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| docker/login-action | v3 | Authenticate to GHCR before push | Every CI run that pushes images |
| docker/setup-buildx-action | v3 | Set up Docker Buildx for multi-platform builds | Required by build-push-action |
| github/codeql-action/upload-sarif | v3 | Upload Trivy SARIF to GitHub Security tab | When format is SARIF |
| helm lint | built-in | Validate chart structure and best practices | Pre-commit and CI validation |
| helm template | built-in | Render chart to raw YAML for golden file comparison | Golden file tests |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Trivy | Grype (already in image) | Grype focuses on SBOM-based scanning; Trivy is the CI standard with native GitHub Action and SARIF support |
| anchore/sbom-action (Syft) | docker buildx --sbom (built-in) | buildx SBOM is newer and tightly coupled; Syft is more mature with explicit format control |
| GHCR (ghcr.io) | Docker Hub | GHCR is free for public repos, integrated with GitHub permissions, no rate limits for GitHub Actions |
| Golden file diff | helm-unittest plugin | Golden files are simpler, require no plugin, and directly verify the "wraps not rewrites" requirement |

## Architecture Patterns

### Recommended Chart Structure

```
helm/claude-in-a-box/
  Chart.yaml                    # apiVersion: v2, name: claude-in-a-box
  values.yaml                   # Default values (readonly profile)
  values-readonly.yaml          # Explicit readonly security profile
  values-operator.yaml          # Operator tier: adds mutation RBAC
  values-airgapped.yaml         # Airgapped: restricted egress, private registry
  templates/
    _helpers.tpl                # Naming, labels, selector helpers
    serviceaccount.yaml         # From k8s/base/01-serviceaccount.yaml
    clusterrole-reader.yaml     # From k8s/base/02-rbac-reader.yaml (ClusterRole)
    clusterrolebinding-reader.yaml  # From k8s/base/02-rbac-reader.yaml (Binding)
    networkpolicy.yaml          # From k8s/base/03-networkpolicy.yaml
    service.yaml                # From k8s/base/04-statefulset.yaml (headless Service)
    statefulset.yaml            # From k8s/base/04-statefulset.yaml (StatefulSet)
    clusterrole-operator.yaml   # From k8s/overlays/rbac-operator.yaml (conditional)
    clusterrolebinding-operator.yaml  # From k8s/overlays/rbac-operator.yaml (conditional)
    NOTES.txt                   # Post-install usage instructions
  tests/
    golden/
      default-values.golden.yaml    # helm template with values.yaml
      readonly-values.golden.yaml   # helm template with values-readonly.yaml
      operator-values.golden.yaml   # helm template with values-operator.yaml
      airgapped-values.golden.yaml  # helm template with values-airgapped.yaml
```

### Pattern 1: Wrapping Existing Manifests (Parameterize, Don't Rewrite)

**What:** Convert each raw manifest into a Helm template by replacing hardcoded values with `{{ .Values.x }}` references while preserving the exact structure.
**When to use:** When existing manifests are already validated and the chart must produce equivalent output.
**Why:** Success criterion 4 requires `helm template` output to match the validated raw manifests. If the template restructures the YAML, the diff will fail.

**Approach:**
1. Copy each raw manifest verbatim into `templates/`
2. Replace only the values that need parameterization (namespace, image, resources, replicas, etc.)
3. Keep comments, field ordering, and structure identical
4. Validate with `helm template . | diff - <(cat k8s/base/*.yaml)` (after stripping Helm metadata)

**Example -- serviceaccount.yaml template:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "claude-in-a-box.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "claude-in-a-box.labels" . | nindent 4 }}
automountServiceAccountToken: true
```

### Pattern 2: Security Profile Values Files

**What:** Three values files that configure different RBAC and NetworkPolicy combinations via the same templates.
**When to use:** When deployments need different security postures in different environments.

**values-readonly.yaml (default):**
- `operator.enabled: false` -- no operator ClusterRole/ClusterRoleBinding
- `networkPolicy.egress.https.cidr: "0.0.0.0/0"` -- unrestricted HTTPS egress
- `networkPolicy.egress.k8sApi.cidr: "0.0.0.0/0"` -- unrestricted API server egress

**values-operator.yaml:**
- `operator.enabled: true` -- creates operator ClusterRole + ClusterRoleBinding
- Same NetworkPolicy as readonly

**values-airgapped.yaml:**
- `operator.enabled: false`
- `networkPolicy.egress.https.enabled: false` -- no HTTPS egress (or restricted CIDR)
- `networkPolicy.egress.k8sApi.cidr: "10.96.0.1/32"` -- only cluster API server
- `image.repository: "internal-registry.corp/claude-in-a-box"` -- private registry
- `image.pullPolicy: Never` or `IfNotPresent` -- no external pulls

### Pattern 3: Conditional Operator RBAC

**What:** Use `{{- if .Values.operator.enabled }}` to include or exclude the operator-tier ClusterRole and ClusterRoleBinding.
**When to use:** When a resource should only exist in certain security profiles.

```yaml
{{- if .Values.operator.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "claude-in-a-box.fullname" . }}-operator
  labels:
    {{- include "claude-in-a-box.labels" . | nindent 4 }}
    tier: operator
rules:
  # ... operator rules from k8s/overlays/rbac-operator.yaml
{{- end }}
```

### Pattern 4: Golden File Validation

**What:** Render the chart with each values file and compare against stored golden files.
**When to use:** CI validation and after any template change.

```bash
#!/usr/bin/env bash
# scripts/helm-golden-test.sh
set -euo pipefail

CHART_DIR="helm/claude-in-a-box"
GOLDEN_DIR="${CHART_DIR}/tests/golden"

for values_file in "${CHART_DIR}"/values*.yaml; do
    basename=$(basename "$values_file" .yaml)
    golden="${GOLDEN_DIR}/${basename}.golden.yaml"
    rendered=$(helm template test-release "${CHART_DIR}" -f "${values_file}" 2>&1)

    if [ ! -f "$golden" ]; then
        echo "MISSING golden file: $golden"
        echo "Run with --update to create it"
        exit 1
    fi

    if ! diff <(echo "$rendered") "$golden" > /dev/null 2>&1; then
        echo "MISMATCH: $basename"
        diff <(echo "$rendered") "$golden" || true
        exit 1
    fi
    echo "PASS: $basename"
done
```

### Pattern 5: CI Pipeline Structure

**What:** Single GitHub Actions workflow that builds, scans, generates SBOM, and publishes.
**Trigger:** On every push to any branch and on tags matching `v*`.

```yaml
# .github/workflows/ci.yaml
name: CI
on:
  push:
    branches: ["*"]
    tags: ["v*"]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write
  security-events: write

jobs:
  build-scan-publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          file: docker/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@0.33.1
        with:
          image-ref: ghcr.io/${{ github.repository }}:sha-${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: "1"

      - name: Upload Trivy SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-results.sarif

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/${{ github.repository }}:sha-${{ github.sha }}
          format: spdx-json
          output-file: sbom.spdx.json

  helm-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Helm
        uses: azure/setup-helm@v4
      - name: Lint chart
        run: helm lint helm/claude-in-a-box --strict
      - name: Golden file test
        run: bash scripts/helm-golden-test.sh
```

### Anti-Patterns to Avoid

- **Rewriting manifests in templates:** The templates must wrap the existing validated YAML. Do not restructure the ordering of fields, change indentation style, or add resources not in the raw manifests. The diff test will catch deviations.
- **Parameterizing everything:** Only parameterize values that actually differ between deployments (namespace, image, resources, RBAC tier, NetworkPolicy CIDRs). Hardcode things that are always the same (API versions, probe commands, volume mount paths).
- **Putting values files outside the chart:** The three security profile values files (`values-readonly.yaml`, `values-operator.yaml`, `values-airgapped.yaml`) belong inside the chart directory so `helm install -f` can reference them relative to the chart.
- **Using Helm 4 Charts v3 format:** Chart v3 is a proposal (HIP-0020), not yet released. Use `apiVersion: v2` for all charts.
- **Scanning only on tagged releases:** The requirement says "on every push." Run Trivy and SBOM on every push, not just releases.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image tagging | Custom shell script for tag generation | docker/metadata-action | Handles SHA, branch, semver, PR tags automatically from Git context |
| Vulnerability scanning | Custom Trivy shell invocation | aquasecurity/trivy-action | Built-in caching, SARIF output, GitHub Security tab integration |
| SBOM generation | Custom Syft shell invocation | anchore/sbom-action | Automatic artifact upload, release asset attachment, format handling |
| Chart linting | Manual YAML validation | `helm lint --strict` | Catches chart structure issues, missing required fields, template errors |
| Template rendering comparison | Manual kubectl diff | Golden file tests with `helm template` | Deterministic, no cluster required, catches drift automatically |
| Docker layer caching in CI | Manual cache management | `cache-from: type=gha` in build-push-action | GitHub Actions cache integration, automatic invalidation |

**Key insight:** Every CI/CD component has a well-maintained official GitHub Action. Hand-rolling shell scripts for scanning, SBOM, or image tagging introduces maintenance burden and misses built-in integrations (SARIF upload, release asset attachment, cache management).

## Common Pitfalls

### Pitfall 1: Helm Template Output Includes Metadata Not in Raw Manifests

**What goes wrong:** `helm template` adds `# Source:` comments and Helm-specific labels/annotations to rendered output, causing golden file diffs to fail against raw manifests.
**Why it happens:** Helm automatically injects `helm.sh/chart`, `app.kubernetes.io/managed-by: Helm` labels and source comments.
**How to avoid:** The golden files should capture the Helm-rendered output (with Helm metadata), not the raw manifests. Success criterion 4 ("matches the validated raw manifests") means structural equivalence after stripping Helm metadata -- test by comparing the resource specs, not byte-for-byte.
**Warning signs:** Golden file tests fail on every `helm template` run due to Helm-injected annotations.

### Pitfall 2: Server-Side Apply (SSA) Conflicts on Upgrade

**What goes wrong:** `helm upgrade` fails with field ownership conflicts when upgrading from a release deployed with Helm 3 (three-way merge) to Helm 4 (SSA default).
**Why it happens:** Helm 4.1 defaults to SSA which tracks field ownership. Fields previously managed by Helm 3's annotation-based tracking may conflict.
**How to avoid:** For fresh installs, SSA works seamlessly. For upgrades from Helm 3 releases, use `--force-conflicts=true` on the first upgrade. Document this in chart NOTES.txt.
**Warning signs:** `helm upgrade` errors with "Apply failed ... conflict ... field is owned by ...".

### Pitfall 3: GHCR Authentication Scope Issues

**What goes wrong:** `docker push` to GHCR fails with 403 despite GITHUB_TOKEN being set.
**Why it happens:** The workflow needs `packages: write` permission explicitly declared. Default token permissions may be read-only.
**How to avoid:** Set `permissions: packages: write` at the job level. Use `docker/login-action@v3` with `registry: ghcr.io`.
**Warning signs:** Push fails only in CI (works locally with PAT).

### Pitfall 4: Trivy Scanning Fails on Locally-Built Image Not Yet Pushed

**What goes wrong:** Trivy cannot find the image reference because it was only built locally and not pushed to the registry yet.
**Why it happens:** The action defaults to pulling from registry. If the image is built but not pushed (e.g., on PR), the scan has nothing to pull.
**How to avoid:** For PRs (no push), use `scan-type: fs` to scan the Dockerfile/filesystem, or build with `--load` and scan the local image. For pushes, scan after push completes.
**Warning signs:** Trivy action fails with "image not found" on pull requests.

### Pitfall 5: Namespace Parameterization Breaks ClusterRole Bindings

**What goes wrong:** Changing the namespace in values.yaml causes ClusterRoleBinding subjects to reference the wrong namespace.
**Why it happens:** ClusterRoleBinding subjects include a `namespace` field for ServiceAccount references. If the template uses `{{ .Release.Namespace }}` for the ServiceAccount but hardcodes `default` in the binding, they mismatch.
**How to avoid:** Use `{{ .Release.Namespace }}` consistently in all ServiceAccount namespace references, including ClusterRoleBinding subjects.
**Warning signs:** Pod has no RBAC permissions despite ClusterRole and ClusterRoleBinding existing.

### Pitfall 6: Values File Precedence Surprises

**What goes wrong:** Users expect `values-operator.yaml` to contain all settings, but it only contains overrides from `values.yaml`.
**Why it happens:** Helm merges values files -- later files override earlier ones. If `values-operator.yaml` only sets `operator.enabled: true`, all other values come from the chart's `values.yaml`.
**How to avoid:** Document clearly that the profile files are overlays on top of `values.yaml`. Usage: `helm install -f values-operator.yaml` (Helm auto-loads `values.yaml` first, then merges the profile file). The profile files should be minimal -- only the values that differ from defaults.
**Warning signs:** Users duplicate all of `values.yaml` into each profile file, causing maintenance burden.

## Code Examples

### Chart.yaml

```yaml
# Source: Helm chart specification https://helm.sh/docs/topics/charts/
apiVersion: v2
name: claude-in-a-box
description: AI-powered DevOps agent with full debugging toolkit
type: application
version: 0.1.0
appVersion: "dev"
```

### values.yaml (Default / Readonly Profile)

```yaml
# Default values for claude-in-a-box.
# This is the readonly security profile.

# -- Number of replicas (StatefulSet)
replicaCount: 1

image:
  # -- Container image repository
  repository: claude-in-a-box
  # -- Image pull policy
  pullPolicy: IfNotPresent
  # -- Image tag (overrides appVersion)
  tag: "dev"

# -- Image pull secrets for private registries
imagePullSecrets: []

# -- Override the release name
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # -- Create a ServiceAccount
  create: true
  # -- ServiceAccount name (auto-generated if empty)
  name: ""
  # -- Automount API credentials
  automountServiceAccountToken: true

# -- Claude Code operating mode (interactive, remote-control, headless)
claudeMode: "interactive"

# Operator-tier RBAC (elevated debugging permissions)
operator:
  # -- Enable operator ClusterRole and ClusterRoleBinding
  enabled: false

# NetworkPolicy configuration
networkPolicy:
  # -- Create NetworkPolicy resource
  enabled: true
  egress:
    dns:
      # -- Allow DNS egress (UDP/TCP 53)
      enabled: true
    https:
      # -- Allow HTTPS egress (TCP 443)
      enabled: true
      # -- CIDR for HTTPS egress (Anthropic API)
      cidr: "0.0.0.0/0"
    k8sApi:
      # -- Allow K8s API server egress (TCP 6443)
      enabled: true
      # -- CIDR for K8s API server
      cidr: "0.0.0.0/0"

# Pod security context
podSecurityContext:
  runAsUser: 10000
  runAsGroup: 10000
  fsGroup: 10000
  fsGroupChangePolicy: OnRootMismatch
  runAsNonRoot: true

# Resource requests and limits
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "2000m"

# Persistent storage
persistence:
  # -- Storage size for PVC
  size: "1Gi"
  # -- Storage class (empty = cluster default)
  storageClassName: ""
  # -- Access mode
  accessMode: ReadWriteOnce

# Probes
livenessProbe:
  exec:
    command: ["/usr/local/bin/healthcheck.sh"]
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5

readinessProbe:
  exec:
    command: ["/usr/local/bin/healthcheck.sh"]
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5

# -- Termination grace period
terminationGracePeriodSeconds: 60
```

### values-operator.yaml (Overlay)

```yaml
# Operator security profile.
# Adds mutation permissions (pod delete, exec, rollout restart).
# Usage: helm install claude-agent ./helm/claude-in-a-box -f helm/claude-in-a-box/values-operator.yaml

operator:
  enabled: true
```

### values-airgapped.yaml (Overlay)

```yaml
# Airgapped security profile.
# Restricts egress to cluster-internal only. Uses private registry.
# Usage: helm install claude-agent ./helm/claude-in-a-box -f helm/claude-in-a-box/values-airgapped.yaml

image:
  repository: "internal-registry.corp/claude-in-a-box"
  pullPolicy: IfNotPresent

networkPolicy:
  egress:
    https:
      enabled: false
    k8sApi:
      cidr: "10.96.0.1/32"
```

### _helpers.tpl

```yaml
{{/*
Chart name truncated to 63 chars.
*/}}
{{- define "claude-in-a-box.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "claude-in-a-box.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "claude-in-a-box.labels" -}}
app: {{ include "claude-in-a-box.name" . }}
app.kubernetes.io/name: {{ include "claude-in-a-box.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "claude-in-a-box.chart" . }}
{{- end }}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "claude-in-a-box.selectorLabels" -}}
app: {{ include "claude-in-a-box.name" . }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "claude-in-a-box.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "claude-in-a-box.serviceAccountName" -}}
{{- if .Values.serviceAccount.name }}
{{- .Values.serviceAccount.name }}
{{- else }}
{{- include "claude-in-a-box.fullname" . }}
{{- end }}
{{- end }}
```

### Template: statefulset.yaml (Key Parameterizations)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "claude-in-a-box.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "claude-in-a-box.labels" . | nindent 4 }}
spec:
  clusterIP: None
  selector:
    {{- include "claude-in-a-box.selectorLabels" . | nindent 4 }}
  ports:
    - port: 80
      name: placeholder
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "claude-in-a-box.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "claude-in-a-box.labels" . | nindent 4 }}
spec:
  serviceName: {{ include "claude-in-a-box.fullname" . }}
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "claude-in-a-box.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "claude-in-a-box.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "claude-in-a-box.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: claude-agent
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            - name: CLAUDE_MODE
              value: {{ .Values.claudeMode | quote }}
          volumeMounts:
            - name: claude-data
              mountPath: /app/.claude
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          stdin: true
          tty: true
  volumeClaimTemplates:
    - metadata:
        name: claude-data
      spec:
        accessModes: [{{ .Values.persistence.accessMode | quote }}]
        {{- if .Values.persistence.storageClassName }}
        storageClassName: {{ .Values.persistence.storageClassName | quote }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.persistence.size }}
```

### Template: networkpolicy.yaml (Conditional Egress)

```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "claude-in-a-box.fullname" . }}-netpol
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "claude-in-a-box.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "claude-in-a-box.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  egress:
    {{- if .Values.networkPolicy.egress.dns.enabled }}
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    {{- end }}
    {{- if .Values.networkPolicy.egress.https.enabled }}
    - to:
        - ipBlock:
            cidr: {{ .Values.networkPolicy.egress.https.cidr }}
      ports:
        - protocol: TCP
          port: 443
    {{- end }}
    {{- if .Values.networkPolicy.egress.k8sApi.enabled }}
    - to:
        - ipBlock:
            cidr: {{ .Values.networkPolicy.egress.k8sApi.cidr }}
      ports:
        - protocol: TCP
          port: 6443
    {{- end }}
{{- end }}
```

## Helm 4 Compatibility Assessment

**Confidence: MEDIUM** -- Helm 4 docs are not yet fully updated; findings are cross-referenced from multiple sources.

| Aspect | Helm 3 | Helm 4 | Impact on This Project |
|--------|--------|--------|----------------------|
| Chart apiVersion | v2 | v2 (v3 proposed but not shipped) | None -- use `apiVersion: v2` |
| Apply strategy | Three-way merge | SSA default (4.1+) | None for `helm template`; affects `helm install/upgrade` behavior |
| CLI flags | Stable | Some renamed (details sparse in docs) | LOW risk -- we use `helm template`, `helm lint`, `helm install` basics |
| Template functions | Sprig library | Adds `mustToYaml`, `mustToJson` | Additions only, no removals -- existing functions work |
| OCI support | Experimental in 3.x | GA with digest support | No impact on chart structure; relevant for registry publishing |
| Plugin system | Classic plugins | WebAssembly + classic | No impact -- we don't use plugins |
| Content caching | Name/version based | Content hash based | Prevents cache collisions; transparent improvement |

**Key finding:** The Helm 4 research flag from Phase 4 ("Helm 4.x chart API has breaking changes from Helm 3") is **overstated**. Helm 4 maintains full backward compatibility for v2 charts. The "breaking changes" are in the Go SDK API and some CLI flag renames -- neither affects chart authoring. Chart v3 is a future proposal (HIP-0020) that will ship after Helm 4.0. **Use `apiVersion: v2` with confidence.**

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Helm 3 three-way merge | Helm 4 Server-Side Apply (SSA) | Helm 4.1 (Nov 2025) | Better conflict detection; `--force-conflicts` for migration |
| Chart apiVersion v1 | Chart apiVersion v2 | Helm 3.0 (2019) | v2 is still current; v3 is proposed |
| docker/build-push-action v5 | v6 | 2024 | Build summary support, improved caching |
| Manual SBOM generation | Built-in to docker buildx or anchore/sbom-action | 2023+ | SBOM is now standard CI practice |
| Trivy CLI in scripts | aquasecurity/trivy-action with SARIF | 2023+ | Native GitHub Security tab integration |

**Deprecated/outdated:**
- `helm/chart-testing-action` v1/v2: Use v3+ for Helm 4 compatibility
- `docker/build-push-action` v4/v5: v6 is current with improved caching
- Manual `trivy image` commands in CI: Use the official GitHub Action for caching and SARIF support
- Chart apiVersion v1: Only for legacy Helm 2 compatibility; not relevant here

## Open Questions

1. **Trivy scan on PR builds (image not pushed)**
   - What we know: Trivy action needs an image reference. On PRs, images are built but not pushed to GHCR.
   - What's unclear: Whether to use `--load` with local Docker daemon or scan the filesystem instead.
   - Recommendation: Use `docker/build-push-action` with `load: true` for PRs (no push), then reference the local image. For pushed images, reference the GHCR tag. Implement as two conditional steps.

2. **Golden file comparison granularity**
   - What we know: `helm template` adds Helm-specific labels and `# Source:` comments not present in raw manifests.
   - What's unclear: Whether success criterion 4 means exact byte-for-byte match or structural equivalence.
   - Recommendation: Golden files capture the full `helm template` output. Separately, a structural comparison script strips Helm metadata and diffs against raw manifests. Both tests run in CI.

3. **Release naming convention for Helm install**
   - What we know: Success criterion 1 says `helm install claude-agent ./helm/claude-in-a-box`.
   - What's unclear: Whether "claude-agent" is the release name or if fullnameOverride should force it.
   - Recommendation: Set `fullnameOverride: "claude-agent"` in values.yaml so that resource names match the raw manifests regardless of release name. The `_helpers.tpl` fullname logic handles this.

4. **Image registry for default values.yaml**
   - What we know: Raw manifests use `claude-in-a-box:dev` (no registry prefix). Production needs `ghcr.io/...`.
   - What's unclear: Whether default values.yaml should target GHCR or local dev.
   - Recommendation: Default to `claude-in-a-box` (no registry prefix) with `tag: dev` to match existing local dev workflow. GHCR is specified via CI override or production values.

## Sources

### Primary (HIGH confidence)
- [Helm Charts documentation](https://helm.sh/docs/topics/charts/) -- Chart.yaml apiVersion v2, directory structure, template functions
- [Helm 4 Overview](https://helm.sh/docs/overview/) -- v2 charts backward compatible, Charts v3 "coming soon"
- [HIP-0020: Charts v3 Enablement](https://helm.sh/community/hips/hip-0020/) -- Charts v3 ships after Helm 4.0, not yet released
- [Helm 4 Released blog post](https://helm.sh/blog/helm-4-released/) -- Release announcement, backward compatibility confirmation
- [aquasecurity/trivy-action](https://github.com/aquasecurity/trivy-action) -- v0.33.1, SARIF output, image scanning parameters
- [anchore/sbom-action](https://github.com/anchore/sbom-action) -- v0, SPDX/CycloneDX output, release asset integration
- [docker/build-push-action](https://github.com/docker/build-push-action) -- v6, Buildx, caching, multi-platform
- [docker/metadata-action](https://github.com/docker/metadata-action) -- v5, SHA/semver/branch tagging

### Secondary (MEDIUM confidence)
- [Enix blog: Helm 4 features and SSA](https://enix.io/en/blog/helm-4/) -- SSA default, --force-conflicts flag
- [Apefactory: Helm v4 vs v3](https://www.apefactory.com/en/insights/helm-v4-understanding-key-differences-from-helm-v3) -- apiVersion v3 claim (contradicted by official docs; treated as LOW)
- [Atmosly: Helm 4 Migration Guide](https://atmosly.com/blog/helm-4-release-whats-new-migration-guide-real-world-impact-2025) -- SSA in 4.1, phased migration
- [DeveloperZen: Golden Testing Helm Charts](https://developerzen.com/golden-testing-helm-charts/) -- Golden file approach, directory structure, CI integration
- [Helm Values Files docs](https://helm.sh/docs/chart_template_guide/values_files/) -- Multiple -f merge behavior, override precedence

### Tertiary (LOW confidence)
- Apefactory article claims `apiVersion: v3` is a Helm 4 requirement -- this contradicts official Helm docs and HIP-0020. Treated as incorrect. Official docs confirm v2 is current.
- Specific renamed CLI flags in Helm 4 -- no source provides an authoritative list. Impact is LOW since we use basic commands (`helm template`, `helm lint`, `helm install`).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All tools (Helm, Trivy, Syft, GitHub Actions) are stable, well-documented, and widely used
- Architecture (Helm chart structure): HIGH -- Standard Helm chart patterns, verified with official docs
- Architecture (CI pipeline): HIGH -- docker/build-push-action, trivy-action, sbom-action all have official GitHub Actions
- Helm 4 compatibility: MEDIUM -- v2 chart backward compatibility confirmed by multiple sources; SSA behavior change documented but CLI flag renames not fully enumerated
- Pitfalls: HIGH -- Helm metadata injection, SSA conflicts, GHCR auth, Trivy scan timing all documented in community sources
- Golden file testing: MEDIUM -- Well-established pattern but exact comparison strategy (byte-for-byte vs structural) needs design decision

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (Helm chart format is stable; GitHub Action versions may have minor updates)
