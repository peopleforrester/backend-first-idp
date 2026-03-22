#!/usr/bin/env bash
# ABOUTME: Master test runner — executes all test suites in sequence.
# ABOUTME: Run via 'make test' or directly with bash.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

run_suite() {
    local name="$1"
    local script="$2"
    echo ""
    echo "========================================"
    echo "  Running: ${name}"
    echo "========================================"
    echo ""
    if bash "${script}"; then
        ((PASS++))
    else
        ((FAIL++))
    fi
}

echo "========================================"
echo "  Backend-First IDP — Full Test Suite"
echo "========================================"

run_suite "YAML Lint" "${TESTS_DIR}/yaml_test.sh"
run_suite "Shellcheck" "${TESTS_DIR}/shellcheck_test.sh"
run_suite "OPA Policy Tests" "${TESTS_DIR}/opa_test.sh"
run_suite "Structure Tests" "${TESTS_DIR}/structure_test.sh"

echo ""
echo "========================================"
echo "  Summary: ${PASS} passed, ${FAIL} failed"
echo "========================================"

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
