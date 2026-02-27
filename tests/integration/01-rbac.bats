#!/usr/bin/env bats
# RBAC tests for reader and operator tiers.
# Tests use kubectl auth can-i with ServiceAccount impersonation.
# No pod required -- RBAC checks run from the test machine.
#
# Test order matters: reader tests run first (before operator overlay),
# then operator overlay is applied for the operator tests.

load helpers

# -- Reader tier ALLOW tests (14 resource types from 02-rbac-reader.yaml) -----

@test "reader: can get/list/watch core resources (pods, services, events, nodes, namespaces, configmaps, pvcs)" {
  for resource in pods services events nodes namespaces configmaps persistentvolumeclaims; do
    for verb in get list watch; do
      assert_can "$verb" "$resource"
    done
  done
}

@test "reader: can get/list/watch apps resources (deployments, statefulsets, daemonsets, replicasets)" {
  for resource in deployments.apps statefulsets.apps daemonsets.apps replicasets.apps; do
    for verb in get list watch; do
      assert_can "$verb" "$resource"
    done
  done
}

@test "reader: can get/list/watch batch resources (jobs, cronjobs)" {
  for resource in jobs.batch cronjobs.batch; do
    for verb in get list watch; do
      assert_can "$verb" "$resource"
    done
  done
}

@test "reader: can get/list/watch networking resources (ingresses)" {
  for verb in get list watch; do
    assert_can "$verb" ingresses.networking.k8s.io
  done
}

# -- Reader tier DENY tests ---------------------------------------------------

@test "reader: cannot access secrets" {
  assert_cannot get secrets
}

@test "reader: cannot mutate resources" {
  assert_cannot delete pods
  assert_cannot create pods
  assert_cannot update deployments.apps
}

# -- Operator tier tests (additive overlay) -----------------------------------

@test "operator: can delete pods" {
  kubectl apply -f "${BATS_TEST_DIRNAME}/../../k8s/overlays/rbac-operator.yaml"
  assert_can delete pods
}

@test "operator: can create pods/exec" {
  if ! kubectl auth can-i create pods --subresource=exec --as="${SA_FULL}" >/dev/null 2>&1; then
    echo "FAIL: expected permission for can-i create pods --subresource=exec" >&2
    return 1
  fi
}

@test "operator: can update and patch deployments and statefulsets" {
  assert_can update deployments.apps
  assert_can patch statefulsets.apps
  assert_can update statefulsets.apps
  assert_can patch deployments.apps
}

# -- Cleanup: remove operator overlay after all tests -------------------------

teardown_file() {
  kubectl delete -f "${BATS_TEST_DIRNAME}/../../k8s/overlays/rbac-operator.yaml" --ignore-not-found
}
