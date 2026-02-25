#!/usr/bin/env bash
# Download and install BATS (Bash Automated Testing System) for integration tests.
# Clones bats-core into tests/bats/ if not already present.
# Usage: ./scripts/setup-bats.sh
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
git clone --depth 1 --branch "${BATS_VERSION}" \
  https://github.com/bats-core/bats-core.git "${BATS_DIR}"

echo "==> Verifying BATS installation..."
"${BATS_BIN}" --version

# Add tests/bats/ to .gitignore if not already present
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
