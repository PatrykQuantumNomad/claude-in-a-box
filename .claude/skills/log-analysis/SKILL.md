---
name: log-analysis
description: >
  Analyze Kubernetes container logs: error investigation, crash root cause,
  performance issues, stack trace analysis, OOM detection, connection errors,
  timeout diagnosis, application startup failures, log pattern recognition.
---

# Log Analysis Workflow

> **You are running inside the cluster pod.** Run kubectl and stern directly — they are installed locally and configured with the pod's ServiceAccount.

## Step 1: Identify Target Pods

Use MCP kubernetes tools or kubectl to find the relevant pods:
```bash
kubectl get pods -n <namespace> -l app=<label>
```

For multi-replica deployments, check all replicas -- the issue may be on one pod.

## Step 2: Fetch Recent Logs

```bash
kubectl logs <pod> -n <namespace> --tail=200
kubectl logs <pod> -n <namespace> --since=1h
kubectl logs -l app=<label> -n <namespace> --tail=50  # all replicas
```

Use stern for multi-pod tailing with color-coded output:
```bash
stern <pod-name-prefix> -n <namespace> --tail=100
stern -l app=<label> -n <namespace> --since=10m
```

## Step 3: Check Previous Container

If the pod restarted, the previous container's logs often contain the root cause:
```bash
kubectl logs <pod> -n <namespace> --previous
```

## Step 4: Pattern Recognition

Scan logs for these high-signal patterns:

| Pattern | Indicates |
|---------|-----------|
| `ERROR`, `FATAL`, `PANIC` | Application error (check surrounding context) |
| Stack traces (indented lines, `at ...`) | Exception with call chain |
| `OOM`, `out of memory`, `cannot allocate` | Memory pressure -- check limits |
| `connection refused`, `ECONNREFUSED` | Dependency down or wrong endpoint |
| `timeout`, `deadline exceeded` | Slow dependency or network issue |
| `permission denied`, `RBAC`, `forbidden` | Authorization failure |
| `no such file`, `not found` | Missing config, volume, or dependency |
| `TLS`, `certificate`, `x509` | Certificate expiry or mismatch |

## Step 5: Multi-Container Pods

For pods with sidecars or init containers:
```bash
kubectl logs <pod> -n <namespace> -c <container-name>
kubectl logs <pod> -n <namespace> --all-containers
```

## Output Format

When reporting findings, use this structure:

**Summary:** One-line description of the issue.

**Evidence:** Specific log lines with timestamps:
```
2024-01-15T10:23:45Z ERROR [main] Connection refused to db:5432
2024-01-15T10:23:46Z FATAL [main] Cannot start: database unavailable
```

**Timeline:** When did it start, any pattern (every N minutes = restart loop).

**Recommendation:** Specific action to resolve (fix config, increase limits, restart dependency).
