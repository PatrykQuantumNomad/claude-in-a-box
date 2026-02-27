---
name: incident-triage
description: >
  Triage Kubernetes cluster incidents: service outage, degraded performance,
  cluster-wide failures, node pressure, pod evictions, resource exhaustion,
  deployment rollback, cascading failures, incident severity classification.
---

# Incident Triage Workflow

> **You are running inside the cluster pod.** Run network tools (dig, curl, nmap) directly via Bash — do NOT use `kubectl exec`. Use kubectl for Kubernetes API queries (get, describe, logs, top, events).

## Step 1: Assess Scope

Determine how widespread the issue is:
```bash
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get nodes -o wide
kubectl top nodes    # resource usage
kubectl top pods -A --sort-by=memory | head -20
```

Questions to answer:
- How many pods/services are affected?
- Is it one namespace or cluster-wide?
- Are nodes healthy?

## Step 2: Check Cluster Health

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status
kubectl describe nodes | grep -A5 "Conditions:"
kubectl get events -A --sort-by='.lastTimestamp' --types=Warning | tail -30
```

Look for: NotReady nodes, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable.

## Step 3: Identify Root Cause

Check for recent changes:
```bash
kubectl get events -A --sort-by='.lastTimestamp' | tail -50
kubectl rollout history deploy/<name> -n <namespace>
```

Common root causes:
- Bad deployment (rollout just happened)
- Node failure (check node status)
- Resource exhaustion (check top nodes/pods)
- Network issue (check CNI, NetworkPolicy)
- External dependency down (check service endpoints)

## Step 4: Document Findings

Record: what is affected, when it started, probable cause, actions taken, current status.

## Severity Classification

| Level | Scope | Examples | Response |
|-------|-------|----------|----------|
| P1 | Cluster-wide | All nodes NotReady, API server down, CNI failure | Immediate escalation |
| P2 | Namespace/service | Key service down, deployment failing, PVC issues | Investigate and fix |
| P3 | Single pod | One pod crashing, one replica unhealthy | Diagnose, may self-heal |
| P4 | Informational | Warning events, non-critical pod restart | Monitor, no action needed |

## Escalation Criteria

Escalate to human operator when:
- P1 severity (cluster-wide impact)
- Data loss risk (PVC issues, stateful workload failures)
- Security incident (unauthorized access, compromised pod)
- Cannot determine root cause after investigation
- Fix requires infrastructure changes (node scaling, network reconfiguration)
- Issue persists after attempted remediation
