#!/usr/bin/env bats
# RBAC tests for reader and operator tiers.
# Tests use kubectl auth can-i with ServiceAccount impersonation.
# No pod required -- RBAC checks run from the test machine.

load helpers

# -- Reader tier ALLOW tests (14 resource types from 02-rbac-reader.yaml) -----

@test "reader: can get pods" {
  assert_can get pods
}

@test "reader: can list services" {
  assert_can list services
}

@test "reader: can watch deployments.apps" {
  assert_can watch deployments.apps
}

@test "reader: can list events" {
  assert_can list events
}

@test "reader: can get nodes" {
  assert_can get nodes
}

@test "reader: can list namespaces" {
  assert_can list namespaces
}

@test "reader: can get configmaps" {
  assert_can get configmaps
}

@test "reader: can list ingresses.networking.k8s.io" {
  assert_can list ingresses.networking.k8s.io
}

@test "reader: can list persistentvolumeclaims" {
  assert_can list persistentvolumeclaims
}

@test "reader: can list jobs.batch" {
  assert_can list jobs.batch
}

@test "reader: can list cronjobs.batch" {
  assert_can list cronjobs.batch
}

@test "reader: can list statefulsets.apps" {
  assert_can list statefulsets.apps
}

@test "reader: can list daemonsets.apps" {
  assert_can list daemonsets.apps
}

@test "reader: can list replicasets.apps" {
  assert_can list replicasets.apps
}

# -- Reader tier DENY tests ---------------------------------------------------

@test "reader: cannot get secrets" {
  assert_cannot get secrets
}

@test "reader: cannot delete pods" {
  assert_cannot delete pods
}

@test "reader: cannot create pods" {
  assert_cannot create pods
}

@test "reader: cannot update deployments.apps" {
  assert_cannot update deployments.apps
}

# -- Operator tier tests (additive overlay applied before first test) ----------

@test "operator: can delete pods" {
  kubectl apply -f k8s/overlays/rbac-operator.yaml
  assert_can delete pods
}

@test "operator: can create pods/exec" {
  # Use --subresource flag for kubectl v1.31+ compatibility
  if ! kubectl auth can-i create pods --subresource=exec --as="${SA_FULL}" >/dev/null 2>&1; then
    echo "FAIL: expected permission for can-i create pods --subresource=exec" >&2
    return 1
  fi
}

@test "operator: can update deployments.apps" {
  assert_can update deployments.apps
}

@test "operator: can patch statefulsets.apps" {
  assert_can patch statefulsets.apps
}

# -- Cleanup: remove operator overlay after all tests -------------------------

teardown_file() {
  kubectl delete -f k8s/overlays/rbac-operator.yaml --ignore-not-found
}
