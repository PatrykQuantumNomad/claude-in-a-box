#!/usr/bin/env bash
# =============================================================================
# setup-bats.sh - Install BATS for Local Development
# =============================================================================
#
# Downloads and installs BATS (Bash Automated Testing System) for running
# integration tests locally. Clones bats-core into tests/bats/ if not already
# present.
#
# This is for LOCAL development only. In CI, BATS is installed by the
# ci.yaml workflow directly (apt-get install bats), so this script is not
# used in the CI pipeline.
#
# Usage: ./scripts/setup-bats.sh
# =============================================================================
set -euo pipefail

BATS_DIR="tests/bats"
BATS_BIN="${BATS_DIR}/bin/bats"
BATS_VERSION="v1.13.0"

if [ -x "${BATS_BIN}" ]; then
  echo "BATS already installed at ${BATS_BIN}"
  "${BATS_BIN}" --version
  exit 0
fi

echo "==> Installing BATS ${BATS_VERSION}..."
# Remove partial state from interrupted clone so git clone can succeed
if [ -d "${BATS_DIR}" ]; then
  echo "    Removing incomplete ${BATS_DIR}/ directory..."
  rm -rf "${BATS_DIR}"
fi
git clone --depth 1 --branch "${BATS_VERSION}" \
  https://github.com/bats-core/bats-core.git "${BATS_DIR}"

echo "==> Verifying BATS installation..."
"${BATS_BIN}" --version

# Add tests/bats/ to .gitignore if not already present.
# tests/bats/ is a cloned third-party repo (bats-core), not project code,
# so it must not be committed to the repository.
if [ -f .gitignore ]; then
  if ! grep -qF "tests/bats/" .gitignore; then
    echo "tests/bats/" >> .gitignore
    echo "==> Added tests/bats/ to .gitignore"
  fi
else
  echo "tests/bats/" > .gitignore
  echo "==> Created .gitignore with tests/bats/"
fi

echo "==> BATS ${BATS_VERSION} installed successfully."
exit 0
