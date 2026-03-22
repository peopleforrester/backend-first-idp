#!/usr/bin/env bash
# ABOUTME: Golden path integration test — validates claim examples exist and are well-formed.
# ABOUTME: Policy integration tests run via kyverno_test.sh; this covers structure and content.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

echo "=== Golden Path Tests ==="
echo ""

EXAMPLES_DIR="${REPO_ROOT}/golden-path/examples"
TEMPLATE="${REPO_ROOT}/golden-path/templates/new-service/service-resources.yaml"

# --- File existence ---
echo "--- File existence ---"
EXPECTED_EXAMPLES=("claim-database" "claim-database-WILL-FAIL" "claim-cache" "claim-message-queue" "claim-full-service" "claim-shadow-metric-warning")
for ex in "${EXPECTED_EXAMPLES[@]}"; do
    assert "${ex}.yaml exists" "$([[ -f "${EXAMPLES_DIR}/${ex}.yaml" ]] && echo true || echo false)"
done
assert "Service template exists" "$([[ -f "${TEMPLATE}" ]] && echo true || echo false)"

# --- YAML validity ---
echo ""
echo "--- YAML validity ---"
for f in "${EXAMPLES_DIR}"/*.yaml; do
    [[ -f "${f}" ]] || continue
    name="$(basename "${f}")"
    yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${f}" 2>&1 && echo true || echo false)
    assert "${name} valid YAML" "${yaml_valid}"
done
if [[ -f "${TEMPLATE}" ]]; then
    yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${TEMPLATE}" 2>&1 && echo true || echo false)
    assert "Service template valid YAML" "${yaml_valid}"
fi

# --- Content checks on core claims ---
echo ""
echo "--- Claim content ---"
GOOD_CLAIM="${EXAMPLES_DIR}/claim-database.yaml"
BAD_CLAIM="${EXAMPLES_DIR}/claim-database-WILL-FAIL.yaml"

if [[ -f "${GOOD_CLAIM}" && -f "${BAD_CLAIM}" ]]; then
    CLAIM_CHECKS=$(GOOD="${GOOD_CLAIM}" BAD="${BAD_CLAIM}" python3 << 'PYEOF'
import yaml, json, os

with open(os.environ["GOOD"]) as f:
    good = yaml.safe_load(f)
with open(os.environ["BAD"]) as f:
    bad = yaml.safe_load(f)

r = {}
r["good_api"] = good.get("apiVersion") == "platform.kubecon.io/v1alpha1"
r["good_kind"] = good.get("kind") == "DatabaseInstanceClaim"
r["good_team"] = good.get("spec", {}).get("team") == "checkout"
r["good_region"] = good.get("spec", {}).get("region") == "eu-west-1"
r["good_size"] = good.get("spec", {}).get("size") == "small"

r["bad_api"] = bad.get("apiVersion") == "platform.kubecon.io/v1alpha1"
r["bad_kind"] = bad.get("kind") == "DatabaseInstanceClaim"
r["bad_team"] = bad.get("spec", {}).get("team") == "checkout"
r["bad_region"] = bad.get("spec", {}).get("region") == "us-west-2"
r["bad_size"] = bad.get("spec", {}).get("size") == "large"

print(json.dumps(r))
PYEOF
    )

    assert "Working claim apiVersion correct" "$(echo "${CLAIM_CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin)['good_api'])")"
    assert "Working claim kind correct" "$(echo "${CLAIM_CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin)['good_kind'])")"
    assert "Working claim: checkout/eu-west-1/small" "$(echo "${CLAIM_CHECKS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['good_team'] and d['good_region'] and d['good_size'])")"
    assert "Failing claim: checkout/us-west-2/large" "$(echo "${CLAIM_CHECKS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['bad_team'] and d['bad_region'] and d['bad_size'])")"
else
    assert "Core claims exist for content checks" "false"
fi

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}GOLDEN PATH TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL GOLDEN PATH TESTS PASSED${NC}"
    exit 0
fi
