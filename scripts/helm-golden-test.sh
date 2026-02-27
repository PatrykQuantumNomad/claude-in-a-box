#!/usr/bin/env bash
# =============================================================================
# helm-golden-test.sh - Helm Chart Golden File Tests
# =============================================================================
#
# Golden file testing is a pattern where you render template output once,
# store the result as a "known-good" (golden) file, and then compare future
# renders against it. Any difference indicates an unintended change to the
# chart's rendered output, catching regressions from template logic changes,
# value defaults shifting, or helper function modifications.
#
# Compares helm template output against stored golden files in
# helm/claude-in-a-box/tests/golden/.
#
# Usage:
#   bash scripts/helm-golden-test.sh            # Compare against golden files
#   bash scripts/helm-golden-test.sh --update   # Regenerate golden files
# =============================================================================
set -euo pipefail

CHART_DIR="helm/claude-in-a-box"
GOLDEN_DIR="${CHART_DIR}/tests/golden"
UPDATE=false
FAILED=0
PASSED=0

if [[ "${1:-}" == "--update" ]]; then
    UPDATE=true
    mkdir -p "${GOLDEN_DIR}"
fi

# Test each values file
# The default values.yaml is tested without -f (uses built-in values.yaml)
# Each values-*.yaml overlay is tested with -f
test_values_file() {
    local values_file="$1"
    local basename
    basename=$(basename "$values_file" .yaml)
    local golden="${GOLDEN_DIR}/${basename}.golden.yaml"

    # For the default values.yaml, render without -f flag
    local rendered
    if [[ "$basename" == "values" ]]; then
        rendered=$(helm template test-release "${CHART_DIR}" 2>&1)
    else
        rendered=$(helm template test-release "${CHART_DIR}" -f "${values_file}" 2>&1)
    fi

    if $UPDATE; then
        echo "$rendered" > "$golden"
        echo "UPDATED: ${basename}"
        return 0
    fi

    if [[ ! -f "$golden" ]]; then
        echo "MISSING golden file: ${golden}"
        echo "Run with --update to create it"
        return 1
    fi

    if ! diff <(echo "$rendered") "$golden" > /dev/null 2>&1; then
        echo "FAIL: ${basename}"
        diff <(echo "$rendered") "$golden" || true
        return 1
    fi

    echo "PASS: ${basename}"
    return 0
}

# Test default values (no -f flag)
if test_values_file "${CHART_DIR}/values.yaml"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
    if ! $UPDATE; then
        exit 1
    fi
fi

# Test each overlay values file
for values_file in "${CHART_DIR}"/values-*.yaml; do
    if test_values_file "$values_file"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        if ! $UPDATE; then
            exit 1
        fi
    fi
done

echo ""
if $UPDATE; then
    echo "Golden files updated: $((PASSED)) files"
else
    echo "Results: ${PASSED} passed, ${FAILED} failed"
    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
fi
