---
name: network-debugging
description: >
  Debug Kubernetes network issues: DNS resolution failures, service connectivity,
  connection timeouts, TLS certificate errors, ingress misconfiguration,
  NetworkPolicy blocking, service mesh issues, endpoint not ready,
  port-forward debugging, cross-namespace communication.
---

# Network Debugging Workflow

> **You are running inside the cluster pod.** Run dig, curl, nmap, etc. directly — do NOT use `kubectl exec`. All network tools are installed locally in this container.

## Step 1: Verify DNS Resolution

Run these directly (you are inside the cluster network):
```bash
dig <service-name>.<namespace>.svc.cluster.local
nslookup <service-name>.<namespace>.svc.cluster.local
cat /etc/resolv.conf
```

If DNS fails, check CoreDNS via kubectl:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

## Step 2: Test Service Connectivity

Run directly from this pod:
```bash
curl -v --connect-timeout 5 http://<service>.<namespace>.svc.cluster.local:<port>/health
wget -qO- --timeout=5 http://<service>.<namespace>.svc.cluster.local:<port>
```

Check service and endpoints via kubectl:
```bash
kubectl get svc <service> -n <namespace> -o wide
kubectl get endpoints <service> -n <namespace>
```

If endpoints list is empty, the selector does not match any running pods.

## Step 3: Port Scanning

Scan specific ports directly:
```bash
nmap -p <port> <service>.<namespace>.svc.cluster.local
nmap -sT -p 5432,3306,6379 <service>.<namespace>.svc.cluster.local
```

## Step 4: Check NetworkPolicy

```bash
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
```

Common NetworkPolicy issues:
- Ingress policy blocks traffic from source namespace/pod
- Egress policy blocks outbound connections
- Missing port in policy spec
- Label selector mismatch

## Step 5: Inspect Ingress and Service Endpoints

```bash
kubectl get ingress -n <namespace>
kubectl describe ingress <name> -n <namespace>
kubectl get svc -n <namespace> -o wide
```

For NodePort/LoadBalancer:
```bash
kubectl get svc <name> -n <namespace> -o jsonpath='{.spec.ports[*]}'
```

## Common Network Issues

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| DNS resolution failure | CoreDNS down, wrong search domain | Check CoreDNS pods, verify resolv.conf |
| Service unreachable | No endpoints, selector mismatch | Check endpoints, verify pod labels match service selector |
| Connection timeout | NetworkPolicy, firewall, pod not listening | Check policies, verify port, test from same namespace |
| Connection refused | Pod not listening on port, wrong port | Verify containerPort matches service targetPort |
| TLS handshake error | Expired cert, wrong CA, SNI mismatch | Check cert expiry, verify secret contents |
| 503 from ingress | No healthy backends, readiness failing | Check endpoints, pod readiness probes |

## Tools Reference

| Tool | Use Case | How to run |
|------|----------|------------|
| `dig` / `nslookup` | DNS resolution testing | Directly (installed locally) |
| `curl` / `wget` | HTTP connectivity and response testing | Directly (installed locally) |
| `nmap` | Port scanning, service discovery | Directly (installed locally) |
| `kubectl get svc/endpoints` | Enumerate services and their selectors | Directly (kubectl configured with ServiceAccount) |
| MCP `list_services` | Structured service listing | Via MCP tool call |
| MCP `list_pods` | Find pods matching service selectors | Via MCP tool call |
