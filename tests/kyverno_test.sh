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

# Count policies
POLICY_COUNT=$(find "${POLICY_DIR}/cluster-policies" -name '*.yaml' -type f | wc -l)
echo "Found ${POLICY_COUNT} cluster policies."
assert "At least 6 cluster policies" "$([[ ${POLICY_COUNT} -ge 6 ]] && echo true || echo false)"
echo ""

# Test each policy that has a policy-tests directory
for test_dir in "${POLICY_DIR}/policy-tests"/*/; do
    [[ -d "${test_dir}" ]] || continue
    policy_name="$(basename "${test_dir}")"
    policy_file="${POLICY_DIR}/cluster-policies/${policy_name}.yaml"

    echo "--- Policy: ${policy_name} ---"

    if [[ ! -f "${policy_file}" ]]; then
        assert "${policy_name}: policy file exists" "false"
        echo ""
        continue
    fi
    assert "${policy_name}: policy file exists" "true"

    # YAML validity
    yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${policy_file}" 2>&1 && echo true || echo false)
    assert "${policy_name}: valid YAML" "${yaml_valid}"

    # Test passing resource (should exit 0 with pass > 0)
    if [[ -f "${test_dir}/resource-pass.yaml" ]]; then
        output=$(kyverno apply "${policy_file}" --resource "${test_dir}/resource-pass.yaml" 2>&1)
        exit_code=$?
        if [[ ${exit_code} -eq 0 ]] && echo "${output}" | grep -q "pass:"; then
            pass_count=$(echo "${output}" | grep -oP 'pass: \K[0-9]+')
            assert "${policy_name}: pass resource accepted (pass=${pass_count})" "$([[ ${pass_count} -gt 0 ]] && echo true || echo false)"
        else
            assert "${policy_name}: pass resource accepted" "false"
        fi
    fi

    # Test failing resource (should exit non-0 or have fail > 0)
    if [[ -f "${test_dir}/resource-fail.yaml" ]]; then
        output=$(kyverno apply "${policy_file}" --resource "${test_dir}/resource-fail.yaml" 2>&1 || true)
        fail_count=$(echo "${output}" | grep -oP 'fail: \K[0-9]+' || echo "0")
        assert "${policy_name}: fail resource rejected (fail=${fail_count})" "$([[ ${fail_count} -gt 0 ]] && echo true || echo false)"
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
