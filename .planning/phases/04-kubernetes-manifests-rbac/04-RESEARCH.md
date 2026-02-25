# Phase 4: Kubernetes Manifests & RBAC - Research

**Researched:** 2026-02-25
**Domain:** Kubernetes raw manifests -- StatefulSet, RBAC (ClusterRole/ClusterRoleBinding), NetworkPolicy, PVC, ServiceAccount
**Confidence:** HIGH

## Summary

Phase 4 produces the production-grade Kubernetes manifest set that replaces the Phase 3 bare Pod. The manifest set must deploy via a single `kubectl apply -f k8s/` into any cluster, providing a StatefulSet with stable pod identity (claude-agent-0), tiered RBAC (read-only default, operator opt-in), egress-only NetworkPolicy, and persistent storage for OAuth tokens and session data at `/app/.claude`.

The core challenge is straightforward: these are well-documented, stable Kubernetes API objects (apps/v1, rbac.authorization.k8s.io/v1, networking.k8s.io/v1). The complexity lies in three areas: (1) correct API group mapping for the 14+ resource types in the read-only ClusterRole, (2) NetworkPolicy egress rules that handle DNS, Anthropic API, and K8s API server access without FQDN support (standard NetworkPolicy only supports CIDR-based rules), and (3) ensuring the PVC volume permissions work with the non-root user (UID 10000/GID 10000) via fsGroup in the SecurityContext.

**Primary recommendation:** Use volumeClaimTemplates in the StatefulSet (not standalone PVC), split RBAC into a reader ClusterRole (always applied) and operator ClusterRole (separate file, opt-in), and use 0.0.0.0/0 for Anthropic API egress on port 443 since their IP ranges can change with notice.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| K8S-01 | StatefulSet with single replica and stable pod identity (claude-agent-0) | StatefulSet API is apps/v1, stable. Use `serviceName` with headless Service, `replicas: 1`, `volumeClaimTemplates` for PVC. Pod name will be `claude-agent-0` automatically. |
| K8S-02 | ServiceAccount with read-only ClusterRole (get/list/watch on 14 resource types) | ClusterRole with 4 API group rules covering core (""), apps, batch, networking.k8s.io. Bound via ClusterRoleBinding to dedicated ServiceAccount. |
| K8S-03 | Egress-only NetworkPolicy allowing Anthropic API (TCP 443), K8s API server (TCP 6443), and DNS (UDP/TCP 53) | NetworkPolicy networking.k8s.io/v1. Deny all ingress via empty ingress array. Egress rules for DNS (UDP+TCP 53), HTTPS (TCP 443 to 0.0.0.0/0), K8s API (TCP 6443 to control plane CIDR). |
| K8S-04 | PersistentVolumeClaim for OAuth token and session persistence at ~/.claude/ | Use volumeClaimTemplates in StatefulSet with ReadWriteOnce access mode. Mount at /app/.claude. fsGroup: 10000 in SecurityContext. |
| K8S-05 | Operator-tier ClusterRole (opt-in) adding delete pods, create pods/exec, update/patch deployments and statefulsets | Separate ClusterRole + ClusterRoleBinding in own file. Not applied by default -- user applies manually. |
</phase_requirements>

## Standard Stack

### Core

| Component | API Version | Purpose | Why Standard |
|-----------|-------------|---------|--------------|
| StatefulSet | apps/v1 | Workload with stable pod identity and PVC | Only workload controller providing ordinal naming and volumeClaimTemplates |
| Headless Service | v1 | DNS identity for StatefulSet pods | Required by StatefulSet spec (serviceName field) |
| ServiceAccount | v1 | Pod identity for RBAC binding | Required for least-privilege RBAC |
| ClusterRole | rbac.authorization.k8s.io/v1 | Permission definitions (reader + operator tiers) | Cluster-wide read access to resources across namespaces |
| ClusterRoleBinding | rbac.authorization.k8s.io/v1 | Binds ClusterRole to ServiceAccount | Connects permissions to pod identity |
| NetworkPolicy | networking.k8s.io/v1 | Egress filtering and ingress denial | Standard K8s network isolation primitive |
| PersistentVolumeClaim | v1 | Storage for OAuth tokens and session data | Created via StatefulSet volumeClaimTemplates |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Namespace | Isolation boundary | Optional -- manifests use `default` namespace but support override |
| ConfigMap | Non-sensitive configuration | If environment variables grow beyond inline env spec |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| StatefulSet | Deployment + standalone PVC | Loses automatic PVC lifecycle management and stable pod naming |
| ClusterRole/ClusterRoleBinding | Role/RoleBinding | Would restrict read access to single namespace -- requirements need cross-namespace visibility (nodes, namespaces) |
| volumeClaimTemplates | Standalone PVC resource | Extra manifest to manage, manual PVC-to-pod binding, no automatic cleanup |
| 0.0.0.0/0 CIDR for Anthropic API | Anthropic's published CIDR 160.79.104.0/23 | Published CIDRs can change with notice; 0.0.0.0/0:443 is safer for port-based restriction |

## Architecture Patterns

### Recommended Manifest Structure

```
k8s/
  base/
    namespace.yaml          # Optional namespace definition
    serviceaccount.yaml     # ServiceAccount for claude-agent
    rbac-reader.yaml        # ClusterRole + ClusterRoleBinding (read-only)
    statefulset.yaml        # StatefulSet with volumeClaimTemplates + headless Service
    networkpolicy.yaml      # Egress-only NetworkPolicy
  overlays/
    rbac-operator.yaml      # Operator-tier ClusterRole + ClusterRoleBinding (opt-in)
```

**Rationale for structure:**
- `k8s/base/` contains everything applied with `kubectl apply -f k8s/base/`
- `k8s/overlays/rbac-operator.yaml` is applied separately by users who want elevated permissions
- File naming uses alphabetical ordering so `kubectl apply -f` processes them in a dependency-safe order (namespace before serviceaccount before rbac before statefulset)
- The dev pod manifest at `kind/pod.yaml` remains untouched for Phase 3 dev workflows

**Alternative flat structure (simpler, also valid):**
```
k8s/
  00-namespace.yaml         # Optional
  01-serviceaccount.yaml
  02-rbac-reader.yaml
  03-networkpolicy.yaml
  04-statefulset.yaml
  operator/
    rbac-operator.yaml      # Opt-in
```

Numbered prefixes guarantee ordering with `kubectl apply -f k8s/`. The operator overlay lives in a subdirectory so `kubectl apply -f k8s/` does not include it (kubectl does NOT recurse into subdirectories by default).

### Pattern 1: StatefulSet with Embedded volumeClaimTemplates

**What:** Define the PVC template inside the StatefulSet spec rather than as a standalone PVC resource.
**When to use:** Always for StatefulSets -- this is the standard pattern.
**Why:** StatefulSet automatically creates PVC `claude-data-claude-agent-0` on first deploy. PVC persists across pod restarts and StatefulSet updates. No manual PVC management needed.

```yaml
# Source: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: claude-agent
spec:
  serviceName: claude-agent
  replicas: 1
  selector:
    matchLabels:
      app: claude-agent
  template:
    metadata:
      labels:
        app: claude-agent
    spec:
      serviceAccountName: claude-agent
      securityContext:
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000
        runAsNonRoot: true
      containers:
      - name: claude-agent
        image: claude-in-a-box:dev
        # ... env, probes, volumeMounts
        volumeMounts:
        - name: claude-data
          mountPath: /app/.claude
  volumeClaimTemplates:
  - metadata:
      name: claude-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

### Pattern 2: Tiered RBAC with Separate Bindings

**What:** Two ClusterRoles -- reader (default) and operator (opt-in) -- bound to the same ServiceAccount via separate ClusterRoleBindings.
**When to use:** When you need escalation tiers without changing the pod identity.
**Why:** RBAC permissions are additive. Applying the operator binding adds to (never removes from) the reader permissions. Users can apply or remove the operator binding independently.

```yaml
# Reader tier (always applied)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-agent-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services", "events", "nodes", "namespaces", "configmaps", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
---
# Operator tier (opt-in, separate file)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-agent-operator
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["delete"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["update", "patch"]
```

### Pattern 3: Egress-Only NetworkPolicy with DNS Allowance

**What:** Deny all ingress, allow only specific egress destinations.
**When to use:** For pods that must reach external APIs but should not accept inbound connections.
**Why:** NetworkPolicy is additive -- once a pod is selected by any policy, only explicitly allowed traffic passes.

```yaml
# Source: https://kubernetes.io/docs/concepts/services-networking/network-policies/
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: claude-agent-netpol
spec:
  podSelector:
    matchLabels:
      app: claude-agent
  policyTypes:
  - Ingress
  - Egress
  ingress: []  # Deny all ingress
  egress:
  # DNS resolution (UDP + TCP port 53)
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Anthropic API (HTTPS port 443)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
  # Kubernetes API server (port 6443)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 6443
```

### Anti-Patterns to Avoid

- **Wildcard verbs in RBAC:** Never use `verbs: ["*"]` -- explicitly list each verb. The requirements spec explicitly excludes secrets access and mutations from the reader tier.
- **Standalone PVC with StatefulSet:** Do not create a separate PVC manifest and reference it in the StatefulSet -- use volumeClaimTemplates instead. Standalone PVCs cannot be managed by StatefulSet lifecycle.
- **Default ServiceAccount usage:** Do not use the `default` ServiceAccount in the namespace. Create a dedicated `claude-agent` ServiceAccount for clear RBAC binding.
- **Using Role/RoleBinding for cluster-wide resources:** Resources like `nodes` and `namespaces` are cluster-scoped -- they require ClusterRole/ClusterRoleBinding, not namespace-scoped Role/RoleBinding.
- **Recursive kubectl apply:** `kubectl apply -f k8s/` does NOT recurse into subdirectories by default. This is actually desired -- the operator overlay should be in a subdirectory so it is not applied by default.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stable pod identity | Custom naming with Deployment | StatefulSet | Automatic ordinal naming, PVC binding, ordered rollout |
| PVC lifecycle | Manual PVC create/delete scripts | volumeClaimTemplates | StatefulSet manages PVC creation; PVCs survive pod/StatefulSet deletion by default |
| Permission escalation | Custom admission webhook | Tiered ClusterRoles + separate bindings | RBAC is additive -- second binding adds permissions without touching the first |
| DNS-based egress filtering | Custom proxy sidecar | Standard NetworkPolicy CIDR rules | FQDN-based filtering needs Calico Enterprise or Cilium; CIDR rules work with any CNI |
| Pod security hardening | Custom init containers for chown | SecurityContext fsGroup | Kubernetes natively sets volume group ownership via fsGroup |

**Key insight:** Every requirement in this phase maps directly to a stable, well-documented Kubernetes API object. There is zero need for custom controllers, operators, or sidecars. The only "build" work is writing correct YAML.

## Common Pitfalls

### Pitfall 1: Wrong API Groups in ClusterRole Rules

**What goes wrong:** ClusterRole rules silently fail when apiGroups don't match the resource. No error is thrown -- the permission simply doesn't apply.
**Why it happens:** Resources are spread across 4 different API groups: core (""), apps, batch, networking.k8s.io. Easy to put `ingresses` under core ("") instead of `networking.k8s.io`.
**How to avoid:** Verify with `kubectl api-resources | grep <resource>` to confirm API group. Use the mapping table in this document.
**Warning signs:** `kubectl auth can-i list ingresses --as=system:serviceaccount:default:claude-agent` returns "no" despite the ClusterRole existing.

**Complete API Group Mapping for Required Resources:**

| Resource | API Group | apiGroups value |
|----------|-----------|-----------------|
| pods | core | `""` |
| services | core | `""` |
| events | core | `""` |
| nodes | core | `""` |
| namespaces | core | `""` |
| configmaps | core | `""` |
| persistentvolumeclaims | core | `""` |
| deployments | apps | `"apps"` |
| statefulsets | apps | `"apps"` |
| daemonsets | apps | `"apps"` |
| replicasets | apps | `"apps"` |
| jobs | batch | `"batch"` |
| cronjobs | batch | `"batch"` |
| ingresses | networking.k8s.io | `"networking.k8s.io"` |

### Pitfall 2: NetworkPolicy Has No Effect Without CNI Support

**What goes wrong:** NetworkPolicy resources are created successfully but traffic is not filtered.
**Why it happens:** The default KIND CNI (kindnet) does NOT enforce NetworkPolicy. You need Calico, Cilium, or another policy-aware CNI.
**How to avoid:** For testing in KIND, install Calico by setting `networking.disableDefaultCNI: true` and `networking.podSubnet: 192.168.0.0/16` in the KIND cluster config, then applying Calico manifests. For production clusters, verify CNI supports NetworkPolicy.
**Warning signs:** All traffic works regardless of NetworkPolicy rules. `kubectl get pods -n calico-system` shows no calico pods.

**KIND + Calico setup (update kind/cluster.yaml for Phase 5 testing):**
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: claude-in-a-box
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```
Note: This change is for Phase 5 (Integration Testing). Phase 4 produces the manifests; Phase 5 validates them in KIND with Calico.

### Pitfall 3: PVC Permissions Denied for Non-Root User

**What goes wrong:** Container starts but cannot write to `/app/.claude` on the PVC because the volume is owned by root.
**Why it happens:** Default PVC volume ownership is root:root. Without `fsGroup` in SecurityContext, the non-root user (UID 10000) cannot write.
**How to avoid:** Set `securityContext.fsGroup: 10000` at the pod level. Kubernetes will chown the volume to GID 10000 on mount.
**Warning signs:** Pod logs show "Permission denied" when writing to `/app/.claude`. `kubectl exec -- ls -la /app/` shows `.claude` owned by root.

### Pitfall 4: Headless Service Missing or Misconfigured

**What goes wrong:** StatefulSet creation fails or pod DNS identity is not resolvable.
**Why it happens:** StatefulSet requires `spec.serviceName` to reference an existing headless Service (clusterIP: None). Forgetting the Service or setting clusterIP to a value breaks the contract.
**How to avoid:** Always define the headless Service in the same manifest file as (or before) the StatefulSet. Set `clusterIP: None` explicitly.
**Warning signs:** StatefulSet events show "service not found" or pod DNS `claude-agent-0.claude-agent.default.svc.cluster.local` does not resolve.

### Pitfall 5: kubectl apply -f Directory Ordering

**What goes wrong:** Resources fail to create because dependencies (ServiceAccount, Namespace) don't exist yet.
**Why it happens:** `kubectl apply -f <directory>` processes files in filesystem order, which is not guaranteed to be alphabetical on all systems.
**How to avoid:** Use numbered filename prefixes (00-, 01-, 02-, etc.) to enforce ordering. Or combine dependent resources into a single file with `---` separators.
**Warning signs:** First `kubectl apply` fails with "not found" errors but re-running succeeds (because the dependency was created on the first attempt).

### Pitfall 6: Secrets Access Not Explicitly Denied

**What goes wrong:** Requirements say the reader role "cannot access secrets" but nothing explicitly prevents it.
**Why it happens:** RBAC is deny-by-default for unlisted resources. If you don't grant `secrets` access, it is already denied. However, this needs verification because built-in ClusterRoles like `view` DO include secrets.
**How to avoid:** Do NOT use aggregation labels that inherit from built-in roles. Define a custom ClusterRole with explicit resource lists. Verify with `kubectl auth can-i get secrets --as=system:serviceaccount:default:claude-agent`.
**Warning signs:** `kubectl auth can-i` returns "yes" for secrets when it should return "no".

## Code Examples

Verified patterns from official Kubernetes documentation:

### Complete ServiceAccount Definition

```yaml
# Source: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
apiVersion: v1
kind: ServiceAccount
metadata:
  name: claude-agent
  namespace: default
  labels:
    app: claude-agent
```

### Headless Service for StatefulSet

```yaml
# Source: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
apiVersion: v1
kind: Service
metadata:
  name: claude-agent
  namespace: default
  labels:
    app: claude-agent
spec:
  clusterIP: None
  selector:
    app: claude-agent
  ports:
  - port: 80
    name: placeholder
```

Note: The headless Service needs at least one port defined even though claude-agent does not serve HTTP. Use a placeholder port or omit the `ports` field entirely (both are valid for headless Services used only for DNS identity).

### StatefulSet with SecurityContext and volumeClaimTemplates

```yaml
# Source: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
# Source: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: claude-agent
  namespace: default
  labels:
    app: claude-agent
spec:
  serviceName: claude-agent
  replicas: 1
  selector:
    matchLabels:
      app: claude-agent
  template:
    metadata:
      labels:
        app: claude-agent
    spec:
      serviceAccountName: claude-agent
      terminationGracePeriodSeconds: 60
      securityContext:
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000
        fsGroupChangePolicy: OnRootMismatch
        runAsNonRoot: true
      containers:
      - name: claude-agent
        image: claude-in-a-box:dev
        imagePullPolicy: IfNotPresent
        env:
        - name: CLAUDE_MODE
          value: "interactive"
        volumeMounts:
        - name: claude-data
          mountPath: /app/.claude
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
        stdin: true
        tty: true
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
  volumeClaimTemplates:
  - metadata:
      name: claude-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

### Read-Only ClusterRole (Complete)

```yaml
# Source: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-agent-reader
  labels:
    app: claude-agent
    tier: reader
rules:
# Core API group: pods, services, events, nodes, namespaces, configmaps, PVCs
- apiGroups: [""]
  resources:
  - pods
  - services
  - events
  - nodes
  - namespaces
  - configmaps
  - persistentvolumeclaims
  verbs: ["get", "list", "watch"]
# Apps API group: deployments, statefulsets, daemonsets, replicasets
- apiGroups: ["apps"]
  resources:
  - deployments
  - statefulsets
  - daemonsets
  - replicasets
  verbs: ["get", "list", "watch"]
# Batch API group: jobs, cronjobs
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["get", "list", "watch"]
# Networking API group: ingresses
- apiGroups: ["networking.k8s.io"]
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: claude-agent-reader
  labels:
    app: claude-agent
subjects:
- kind: ServiceAccount
  name: claude-agent
  namespace: default
roleRef:
  kind: ClusterRole
  name: claude-agent-reader
  apiGroup: rbac.authorization.k8s.io
```

### Operator-Tier ClusterRole (Opt-In)

```yaml
# Source: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-agent-operator
  labels:
    app: claude-agent
    tier: operator
rules:
# Delete pods (for pod restarts)
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["delete"]
# Create pods/exec (for kubectl exec)
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
# Update/patch deployments and statefulsets (for rollout restarts)
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: claude-agent-operator
  labels:
    app: claude-agent
subjects:
- kind: ServiceAccount
  name: claude-agent
  namespace: default
roleRef:
  kind: ClusterRole
  name: claude-agent-operator
  apiGroup: rbac.authorization.k8s.io
```

### NetworkPolicy (Egress-Only)

```yaml
# Source: https://kubernetes.io/docs/concepts/services-networking/network-policies/
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: claude-agent-netpol
  namespace: default
  labels:
    app: claude-agent
spec:
  podSelector:
    matchLabels:
      app: claude-agent
  policyTypes:
  - Ingress
  - Egress
  ingress: []  # Deny all inbound traffic
  egress:
  # Rule 1: Allow DNS resolution (CoreDNS)
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Rule 2: Allow HTTPS egress (Anthropic API on TCP 443)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
  # Rule 3: Allow Kubernetes API server (TCP 6443)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 6443
```

**Design decision on Anthropic API CIDR:** The requirements say "Anthropic API (TCP 443)". Anthropic publishes inbound IP ranges at `160.79.104.0/23` (IPv4), but these are the IPs where Anthropic **receives** connections. Using 0.0.0.0/0 with port 443 is more resilient -- it allows egress to any IP on port 443, which is sufficient since the pod only makes outbound HTTPS connections. For tighter lockdown, use `160.79.104.0/23` but accept the risk of breakage if Anthropic changes IPs (they promise notice). The requirement text says "TCP 443" without a specific CIDR, suggesting port-based restriction is sufficient.

**Design decision on K8s API server:** The requirement says "TCP 6443". In-cluster pods typically access the API server via the `kubernetes.default.svc` ClusterIP (10.96.0.1:443), which DNATs to the actual API server on port 6443. However, the requirement explicitly says port 6443. Using 0.0.0.0/0:6443 is safe because only the API server listens on this port. For tighter lockdown, discover the API server IP with `kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}'`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| extensions/v1beta1 Ingress | networking.k8s.io/v1 Ingress | K8s 1.19 (2020) | Use `networking.k8s.io` in RBAC apiGroups, not `extensions` |
| ReadWriteOnce only | ReadWriteOncePod available | K8s 1.22+ (GA in 1.29) | RWOP is stricter but RWO is fine for single-replica StatefulSet |
| PodSecurityPolicy | Pod Security Standards (PSS) | K8s 1.25 (PSP removed) | Use SecurityContext fields directly; no PSP needed |
| Manual fsGroup chown | fsGroupChangePolicy: OnRootMismatch | K8s 1.20+ (GA in 1.28) | Faster pod startup for large volumes |
| automountServiceAccountToken default true | Still true but best practice is explicit | Ongoing | Set `automountServiceAccountToken: true` explicitly for clarity |

**Deprecated/outdated:**
- `extensions/v1beta1` for Ingress: Removed in K8s 1.22. Use `networking.k8s.io/v1`.
- PodSecurityPolicy: Removed in K8s 1.25. Use SecurityContext + Pod Security Admission.
- `kubectl apply -f` with `--recursive`: Still works but not needed since operator overlay is in a subdirectory that is naturally excluded.

## Open Questions

1. **Anthropic API CIDR vs 0.0.0.0/0 for egress**
   - What we know: Anthropic publishes `160.79.104.0/23` for inbound IPs. Claude Code connects to `api.anthropic.com` which may resolve to these or CDN IPs. Remote Control likely uses different endpoints.
   - What's unclear: Whether Remote Control traffic goes to the same IP range as the API, and whether CDN/proxy IPs are included.
   - Recommendation: Use `0.0.0.0/0` on port 443 for Phase 4. Phase 5 integration tests can verify connectivity. Phase 7 Helm chart can parameterize the CIDR for tighter environments.

2. **KIND cluster NetworkPolicy testing scope**
   - What we know: KIND's default CNI (kindnet) does NOT enforce NetworkPolicy. Calico must be installed for testing.
   - What's unclear: Whether Phase 4 should modify the KIND cluster config or leave that to Phase 5.
   - Recommendation: Phase 4 produces manifests only. Phase 5 (Integration Testing) handles KIND + Calico setup and NetworkPolicy validation. Document the Calico requirement in the manifests as a comment.

3. **Resource requests/limits for StatefulSet**
   - What we know: Claude Code is a Node.js process that can be memory-intensive during analysis.
   - What's unclear: Exact resource consumption patterns for different Claude Code modes.
   - Recommendation: Set reasonable defaults (512Mi request / 2Gi limit for memory, 250m / 2000m for CPU) and document that these should be tuned per environment.

4. **Namespace parameterization**
   - What we know: Manifests currently hardcode `namespace: default`. Helm chart (Phase 7) will parameterize this.
   - What's unclear: Whether Phase 4 manifests should support namespace override.
   - Recommendation: Hardcode `default` namespace in Phase 4 manifests. Add a comment noting Phase 7 Helm chart will parameterize. Keep manifests simple.

## Makefile Integration

The existing Makefile deploys using `POD_MANIFEST ?= kind/pod.yaml`. Phase 4 should update the Makefile to support deploying the full manifest set:

```makefile
# Phase 4 addition
K8S_MANIFESTS ?= k8s/base
OPERATOR_RBAC ?= k8s/overlays/rbac-operator.yaml

deploy: ## Apply manifests and wait for Ready
	kubectl apply -f $(K8S_MANIFESTS)
	kubectl wait --for=condition=Ready pod -l app=claude-agent \
		-n $(NAMESPACE) --timeout=120s

deploy-operator: ## Apply operator-tier RBAC (opt-in)
	kubectl apply -f $(OPERATOR_RBAC)

undeploy-operator: ## Remove operator-tier RBAC
	kubectl delete -f $(OPERATOR_RBAC) --ignore-not-found
```

The `bootstrap` and `redeploy` targets should also be updated to use the new manifest path.

## Sources

### Primary (HIGH confidence)
- [Kubernetes StatefulSet docs](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) - StatefulSet spec, volumeClaimTemplates, serviceName requirements, pod naming
- [Kubernetes RBAC docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) - ClusterRole/ClusterRoleBinding YAML structure, pods/exec subresource, aggregation
- [Kubernetes NetworkPolicy docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Egress rules, ipBlock CIDR, DNS allowance, deny-all patterns
- [Kubernetes SecurityContext docs](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) - fsGroup, runAsNonRoot, runAsUser
- [Kubernetes Ports and Protocols](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) - API server port 6443
- [Anthropic IP Addresses](https://docs.anthropic.com/en/api/ip-addresses) - Inbound CIDR 160.79.104.0/23 (IPv4), 2607:6bc0::/48 (IPv6)
- [Calico on KIND](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) - Calico 3.31 installation for KIND with NetworkPolicy support

### Secondary (MEDIUM confidence)
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) - Least privilege recommendations, service account best practices
- [kubectl apply -f directory ordering](https://github.com/kubernetes/kubernetes/issues/64203) - Filesystem order, not guaranteed alphabetical

### Tertiary (LOW confidence)
- Resource requests/limits values (512Mi/2Gi, 250m/2000m) - Based on general Node.js container patterns, not measured Claude Code usage

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Kubernetes API objects are stable (apps/v1, rbac.authorization.k8s.io/v1, networking.k8s.io/v1), well-documented
- Architecture: HIGH - Manifest structure, tiered RBAC, volumeClaimTemplates are established Kubernetes patterns
- Pitfalls: HIGH - API group mapping, fsGroup, headless Service requirement all verified against official docs
- NetworkPolicy CIDR choices: MEDIUM - Anthropic IP range verified but egress strategy (0.0.0.0/0 vs specific CIDR) is a design choice
- Resource limits: LOW - No measured data for Claude Code resource consumption

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (Kubernetes APIs are stable; Anthropic IPs may change with notice)
