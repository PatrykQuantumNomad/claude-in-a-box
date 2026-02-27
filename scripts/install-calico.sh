#!/usr/bin/env bash
# =============================================================================
# install-calico.sh - Install Calico CNI into a KIND Cluster
# =============================================================================
#
# KIND (Kubernetes IN Docker) ships with a basic CNI (kindnet) that does NOT
# enforce NetworkPolicy resources. Calico replaces it with a full CNI that
# provides NetworkPolicy enforcement, so our NetworkPolicy Helm templates
# actually take effect during integration tests.
#
# Without Calico, all egress/ingress rules are silently ignored and the
# integration tests for network isolation would pass vacuously.
#
# Usage: ./scripts/install-calico.sh
# Override version: CALICO_VERSION=3.31.4 ./scripts/install-calico.sh
# =============================================================================
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-3.31.4}"

echo "==> Installing Calico v${CALICO_VERSION} operator..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"

# Wait for Calico CRDs before applying custom resources. The tigera-operator
# creates CRDs asynchronously -- applying custom resources before CRDs exist
# would fail with "no matches for kind" errors.
echo "==> Waiting for Calico CRDs to be registered..."
CRD_READY=false
for ((i=1; i<=60; i++)); do
  if kubectl get crd installations.operator.tigera.io &>/dev/null; then
    echo "    CRDs ready after ${i}s"
    CRD_READY=true
    break
  fi
  sleep 1
done

if [ "$CRD_READY" = false ]; then
  echo "ERROR: Calico CRDs not registered after 60s" >&2
  exit 1
fi

echo "==> Installing Calico custom resources..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "==> Waiting for tigera-operator deployment..."
kubectl wait --for=condition=Available deployment/tigera-operator \
  -n tigera-operator --timeout=120s

echo "==> Waiting for calico-node daemonset to be created..."
CALICO_NS=""
for ((i=1; i<=60; i++)); do
  if kubectl -n calico-system get daemonset/calico-node &>/dev/null; then
    CALICO_NS="calico-system"
    echo "    calico-node found in calico-system after ${i}s"
    break
  elif kubectl -n kube-system get daemonset/calico-node &>/dev/null; then
    CALICO_NS="kube-system"
    echo "    calico-node found in kube-system after ${i}s"
    break
  fi
  sleep 2
done

if [ -z "$CALICO_NS" ]; then
  echo "ERROR: calico-node daemonset not found after 120s" >&2
  exit 1
fi

echo "==> Waiting for calico-node pods to be ready (initial rollout)..."
kubectl rollout status daemonset/calico-node -n "$CALICO_NS" --timeout=300s

# KIND nodes use loose reverse path filtering (rp_filter=2) on their virtual
# interfaces. Calico's Felix dataplane rejects this by default and will crash-loop
# with "kernel's RPF check is set to 'loose'" errors. Setting FELIX_IGNORELOOSERPF=true
# tells Felix to accept the loose setting and continue operating normally.
echo "==> Fixing Reverse Path Filtering for KIND nodes..."
kubectl -n "$CALICO_NS" set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

echo "==> Waiting for calico-node rollout after env update..."
kubectl rollout status daemonset/calico-node -n "$CALICO_NS" --timeout=300s

# CoreDNS pods were scheduled before the Calico CNI was ready, so they may have
# stale network configuration from kindnet. Restarting CoreDNS ensures the pods
# get fresh network interfaces from Calico, which is required for DNS to work
# correctly with NetworkPolicy enforcement enabled.
echo "==> Restarting CoreDNS to recover from pre-CNI scheduling..."
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=60s

echo "==> Calico v${CALICO_VERSION} installed successfully."
exit 0
