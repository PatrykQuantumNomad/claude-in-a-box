---
name: pod-diagnosis
description: >
  Diagnose unhealthy Kubernetes pods: CrashLoopBackOff, ImagePullBackOff,
  OOMKilled, pending pods, readiness probe failures, liveness probe failures,
  container restart loops, init container failures, resource quota exceeded.
---

# Pod Diagnosis Workflow

> **You are running inside the cluster pod.** Run network tools (dig, curl, nmap) directly via Bash — do NOT use `kubectl exec`. Use kubectl for Kubernetes API queries (get, describe, logs, top, events).

## Step 1: Get Pod Status

Use MCP kubernetes tools to list pods and their statuses:
- `list_pods` with namespace filter to get current state
- Check STATUS column: Running, Pending, CrashLoopBackOff, ImagePullBackOff, Error, Terminating

For complex queries, fall back to kubectl:
```bash
kubectl get pods -n <namespace> -o wide
kubectl get pods --field-selector=status.phase!=Running -A
```

## Step 2: Check Events

```bash
kubectl events -n <namespace> --for pod/<name> --types=Warning
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

## Step 3: Read Logs

```bash
kubectl logs <pod> -n <namespace> --tail=100
kubectl logs <pod> -n <namespace> --previous   # crashed container
kubectl logs <pod> -n <namespace> -c <init-container>  # init failures
```

## Step 4: Inspect Pod Details

```bash
kubectl describe pod <name> -n <namespace>
```

Look for: conditions, container states, last termination reason, resource requests/limits.

## Step 5: Check Related Resources

- Deployment/StatefulSet: `kubectl get deploy,sts -n <namespace>`
- ConfigMaps/Secrets referenced: verify they exist
- PVCs: check if bound, storage class available
- Service account: verify RBAC permissions

## Common Failure Patterns

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| CrashLoopBackOff | App crash on start, config error, missing dependency | Check logs (current + previous), describe pod for exit code |
| ImagePullBackOff | Wrong image tag, private registry auth, network issue | Check events for pull error, verify image exists |
| OOMKilled | Memory limit too low or memory leak | Check describe for last termination reason, review limits |
| Pending | Insufficient resources, node affinity, taint/toleration | Check events, describe for scheduling failures |
| Readiness failure | App not ready, wrong probe config, dependency down | Check probe config in describe, test endpoint manually |
| Init container fail | Missing config, dependency not ready | Check init container logs with -c flag |
