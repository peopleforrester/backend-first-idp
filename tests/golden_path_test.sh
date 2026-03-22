#!/usr/bin/env bash
# ABOUTME: Golden path integration test — validates claims against OPA policies.
# ABOUTME: Confirms working claim passes and failing claim produces exactly 2 violations.

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

GOOD_CLAIM="${REPO_ROOT}/golden-path/examples/claim-database.yaml"
BAD_CLAIM="${REPO_ROOT}/golden-path/examples/claim-database-WILL-FAIL.yaml"
TEMPLATE="${REPO_ROOT}/golden-path/templates/new-service/service-resources.yaml"
POLICY_DIR="${REPO_ROOT}/policies/opa"

echo "--- File existence ---"
assert "Working claim exists" "$([[ -f "${GOOD_CLAIM}" ]] && echo true || echo false)"
assert "Failing claim exists" "$([[ -f "${BAD_CLAIM}" ]] && echo true || echo false)"
assert "Service template exists" "$([[ -f "${TEMPLATE}" ]] && echo true || echo false)"

echo ""
echo "--- YAML validity ---"
assert "Working claim valid YAML" "$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${GOOD_CLAIM}" 2>&1 && echo true || echo false)"
assert "Failing claim valid YAML" "$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${BAD_CLAIM}" 2>&1 && echo true || echo false)"
assert "Service template valid YAML" "$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${TEMPLATE}" 2>&1 && echo true || echo false)"

echo ""
echo "--- Claim content ---"
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

echo ""
echo "--- OPA policy integration ---"

if [[ ! -d "${POLICY_DIR}" ]]; then
    echo -e "  ${RED}SKIP${NC} — policies/opa not found"
else
    # Test working claim against both policies
    GOOD_INPUT=$(CLAIM="${GOOD_CLAIM}" python3 -c "
import yaml, json, os
with open(os.environ['CLAIM']) as f:
    c = yaml.safe_load(f)
print(json.dumps({'review': {'object': c}}))
")

    REGION_RESULT=$(echo "${GOOD_INPUT}" | opa eval -d "${POLICY_DIR}/region-allowed.rego" -I 'data.platform.region.deny' --format raw 2>&1)
    assert "Working claim passes region policy (0 denials)" "$([[ "${REGION_RESULT}" == "[]" ]] && echo true || echo false)"

    SIZE_RESULT=$(echo "${GOOD_INPUT}" | opa eval -d "${POLICY_DIR}/size-limits.rego" -I 'data.platform.size.deny' --format raw 2>&1)
    assert "Working claim passes size policy (0 denials)" "$([[ "${SIZE_RESULT}" == "[]" ]] && echo true || echo false)"

    # Test failing claim — should produce exactly 2 violations (region + size)
    BAD_INPUT=$(CLAIM="${BAD_CLAIM}" python3 -c "
import yaml, json, os
with open(os.environ['CLAIM']) as f:
    c = yaml.safe_load(f)
print(json.dumps({'review': {'object': c}}))
")

    REGION_DENY=$(echo "${BAD_INPUT}" | opa eval -d "${POLICY_DIR}/region-allowed.rego" -I 'data.platform.region.deny' --format json 2>&1)
    REGION_COUNT=$(echo "${REGION_DENY}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(len(r.get('result',[{}])[0].get('expressions',[{}])[0].get('value',[])))")
    assert "Failing claim triggers 1 region denial" "$([[ "${REGION_COUNT}" == "1" ]] && echo true || echo false)"

    SIZE_DENY=$(echo "${BAD_INPUT}" | opa eval -d "${POLICY_DIR}/size-limits.rego" -I 'data.platform.size.deny' --format json 2>&1)
    SIZE_COUNT=$(echo "${SIZE_DENY}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(len(r.get('result',[{}])[0].get('expressions',[{}])[0].get('value',[])))")
    assert "Failing claim triggers 1 size denial" "$([[ "${SIZE_COUNT}" == "1" ]] && echo true || echo false)"

    TOTAL_VIOLATIONS=$((REGION_COUNT + SIZE_COUNT))
    assert "Failing claim has exactly 2 total violations" "$([[ "${TOTAL_VIOLATIONS}" == "2" ]] && echo true || echo false)"
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
