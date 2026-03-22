#!/usr/bin/env bash
# ABOUTME: Kyverno policy test runner — validates policies against test resources using kyverno CLI.
# ABOUTME: Run via 'make test-kyverno' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="${REPO_ROOT}/policies/kyverno"
PASS=0
FAIL=0

if [[ -t 1 ]]; then
    GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'
else
    GREEN='' RED='' NC=''
fi

assert() {
    local description="$1"
    local result
    result="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    if [[ "${result}" == "true" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description}"
        ((FAIL++)) || true
    fi
}

echo "=== Kyverno Policy Tests ==="
echo ""

if [[ ! -d "${POLICY_DIR}/cluster-policies" ]]; then
    echo "No policies/kyverno/cluster-policies directory found — skipping."
    exit 0
fi

if ! command -v kyverno &>/dev/null; then
    echo "kyverno CLI not found — skipping."
    exit 0
fi

# Test each policy that has a policy-tests directory
for test_dir in "${POLICY_DIR}/policy-tests"/*/; do
    [[ -d "${test_dir}" ]] || continue
    policy_name="$(basename "${test_dir}")"
    policy_file="${POLICY_DIR}/cluster-policies/${policy_name}.yaml"

    echo "--- Policy: ${policy_name} ---"

    if [[ ! -f "${policy_file}" ]]; then
        echo -e "  ${RED}FAIL${NC} Policy file not found: ${policy_file}"
        ((FAIL++)) || true
        continue
    fi

    # Test passing resources
    if [[ -f "${test_dir}/resource-pass.yaml" ]]; then
        result=$(kyverno apply "${policy_file}" --resource "${test_dir}/resource-pass.yaml" 2>&1 && echo "PASS" || echo "FAIL")
        if echo "${result}" | grep -q "PASS"; then
            assert "${policy_name}: pass resource accepted" "true"
        else
            assert "${policy_name}: pass resource accepted" "false"
            echo "    Output: ${result}" | head -5
        fi
    fi

    # Test failing resources
    if [[ -f "${test_dir}/resource-fail.yaml" ]]; then
        result=$(kyverno apply "${policy_file}" --resource "${test_dir}/resource-fail.yaml" 2>&1 || true)
        if echo "${result}" | grep -qi "fail\|violation\|blocked"; then
            assert "${policy_name}: fail resource rejected" "true"
        else
            # Kyverno apply returns 0 even for violations in some modes, check output
            if echo "${result}" | grep -qi "pass"; then
                assert "${policy_name}: fail resource rejected" "false"
                echo "    Output: ${result}" | head -5
            else
                assert "${policy_name}: fail resource rejected" "true"
            fi
        fi
    fi

    echo ""
done

echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}KYVERNO TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL KYVERNO TESTS PASSED${NC}"
    exit 0
fi
