#!/usr/bin/env bash
# Install Calico CNI into a KIND cluster for NetworkPolicy enforcement.
# Usage: ./scripts/install-calico.sh
# Override version: CALICO_VERSION=3.31.4 ./scripts/install-calico.sh
set -euo pipefail

CALICO_VERSION="${CALICO_VERSION:-3.31.4}"

echo "==> Installing Calico v${CALICO_VERSION} operator..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "==> Installing Calico custom resources..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "==> Waiting for tigera-operator deployment..."
kubectl wait --for=condition=Available deployment/tigera-operator \
  -n tigera-operator --timeout=120s

echo "==> Fixing Reverse Path Filtering for KIND nodes..."
kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true 2>/dev/null \
  || kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

echo "==> Waiting for calico-node pods to be ready..."
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node \
  -n calico-system --timeout=120s 2>/dev/null \
  || kubectl wait --for=condition=Ready pods -l k8s-app=calico-node \
    -n kube-system --timeout=120s

echo "==> Restarting CoreDNS to recover from pre-CNI scheduling..."
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=60s

echo "==> Calico v${CALICO_VERSION} installed successfully."
exit 0
