---
name: network-debugging
description: >
  Debug Kubernetes network issues: DNS resolution failures, service connectivity,
  connection timeouts, TLS certificate errors, ingress misconfiguration,
  NetworkPolicy blocking, service mesh issues, endpoint not ready,
  port-forward debugging, cross-namespace communication.
---

# Network Debugging Workflow

## Step 1: Verify DNS Resolution

```bash
kubectl exec <pod> -n <namespace> -- nslookup <service-name>
kubectl exec <pod> -n <namespace> -- nslookup <service>.<namespace>.svc.cluster.local
kubectl exec <pod> -n <namespace> -- cat /etc/resolv.conf
```

If DNS fails, check CoreDNS:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

## Step 2: Test Service Connectivity

```bash
kubectl exec <pod> -n <namespace> -- curl -v http://<service>:<port>/health
kubectl exec <pod> -n <namespace> -- wget -qO- --timeout=5 http://<service>:<port>
```

Check service and endpoints:
```bash
kubectl get svc <service> -n <namespace> -o wide
kubectl get endpoints <service> -n <namespace>
```

If endpoints list is empty, the selector does not match any running pods.

## Step 3: Check NetworkPolicy

```bash
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
```

Common NetworkPolicy issues:
- Ingress policy blocks traffic from source namespace/pod
- Egress policy blocks outbound connections
- Missing port in policy spec
- Label selector mismatch

## Step 4: Inspect Ingress and Service Endpoints

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

| Tool | Use Case |
|------|----------|
| `dig` / `nslookup` | DNS resolution testing |
| `curl` / `wget` | HTTP connectivity and response testing |
| `nmap` | Port scanning, service discovery |
| `kubectl port-forward` | Direct pod access bypassing service/ingress |
| MCP `list_services` | Enumerate services and their selectors |
| MCP `list_pods` | Find pods matching service selectors |
