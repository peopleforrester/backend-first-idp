#!/usr/bin/env bash
# ABOUTME: Master test runner — executes all v2 test suites in sequence.
# ABOUTME: Run via 'make validate' or directly with bash.

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
        ((PASS++)) || true
    else
        ((FAIL++)) || true
    fi
}

echo "========================================"
echo "  Backend-First IDP v2 — Full Test Suite"
echo "========================================"

run_suite "YAML Lint" "${TESTS_DIR}/yaml_test.sh"
run_suite "Shellcheck" "${TESTS_DIR}/shellcheck_test.sh"
run_suite "Kyverno Policies" "${TESTS_DIR}/kyverno_test.sh"
run_suite "XRD Validation" "${TESTS_DIR}/xrd_test.sh"
run_suite "Composition Validation" "${TESTS_DIR}/composition_test.sh"
run_suite "Golden Path" "${TESTS_DIR}/golden_path_test.sh"
run_suite "Observability" "${TESTS_DIR}/observability_test.sh"
run_suite "External Secrets" "${TESTS_DIR}/eso_test.sh"
run_suite "Scale (100+ claims)" "${TESTS_DIR}/scale_test.sh"
run_suite "Structure" "${TESTS_DIR}/structure_test.sh"

echo ""
echo "========================================"
echo "  Summary: ${PASS} suites passed, ${FAIL} suites failed"
echo "========================================"

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
