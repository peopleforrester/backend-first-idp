#!/usr/bin/env bash
# ABOUTME: OPA policy test runner — executes opa test on all Rego files.
# ABOUTME: Run via 'make test-opa' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPA_DIR="${REPO_ROOT}/policies/opa"

echo "=== OPA Policy Tests ==="
echo ""

if [[ ! -d "${OPA_DIR}" ]]; then
    echo "No policies/opa directory found — skipping."
    exit 0
fi

# Check for test files
TEST_FILES=$(find "${OPA_DIR}" -name '*_test.rego' -type f 2>/dev/null || true)

if [[ -z "${TEST_FILES}" ]]; then
    echo "No Rego test files found — skipping."
    exit 0
fi

echo "Running OPA tests in ${OPA_DIR}..."
echo ""

opa test "${OPA_DIR}" -v

echo ""
echo "=== ALL OPA TESTS PASSED ==="
