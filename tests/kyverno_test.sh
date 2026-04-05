#!/usr/bin/env bash
# ABOUTME: Kyverno policy test runner — validates policies against test resources using kyverno CLI.
# ABOUTME: Run via 'make test-kyverno' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

POLICY_DIR="${REPO_ROOT}/policies/kyverno"

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

print_results "KYVERNO TESTS"
