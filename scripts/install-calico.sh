#!/usr/bin/env bash
# Install Calico CNI into a KIND cluster for NetworkPolicy enforcement.
# Usage: ./scripts/install-calico.sh
# Override version: CALICO_VERSION=3.31.4 ./scripts/install-calico.sh
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-3.31.4}"

echo "==> Installing Calico v${CALICO_VERSION} operator..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "==> Waiting for Calico CRDs to be registered..."
for i in $(seq 1 30); do
  if kubectl get crd installations.operator.tigera.io &>/dev/null; then
    echo "    CRDs ready after ${i}s"
    break
  fi
  sleep 1
done

echo "==> Installing Calico custom resources..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "==> Waiting for tigera-operator deployment..."
kubectl wait --for=condition=Available deployment/tigera-operator \
  -n tigera-operator --timeout=120s

echo "==> Waiting for calico-node daemonset to be created..."
CALICO_NS=""
for i in $(seq 1 60); do
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
  echo "ERROR: calico-node daemonset not found after 120s"
  exit 1
fi

echo "==> Fixing Reverse Path Filtering for KIND nodes..."
kubectl -n "$CALICO_NS" set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

echo "==> Waiting for calico-node pods to be ready..."
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node \
  -n "$CALICO_NS" --timeout=120s

echo "==> Restarting CoreDNS to recover from pre-CNI scheduling..."
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=60s

echo "==> Calico v${CALICO_VERSION} installed successfully."
exit 0
