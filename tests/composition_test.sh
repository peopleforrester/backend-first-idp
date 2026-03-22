#!/usr/bin/env bash
# ABOUTME: Composition validation test — asserts structure of all cloud compositions.
# ABOUTME: Run via 'make test-compositions' or directly with bash.

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

# Validate a single composition file
validate_composition() {
    local cloud="$1"
    local file="${REPO_ROOT}/platform-api/compositions/${cloud}/database-small.yaml"
    local display_cloud
    display_cloud="$(echo "${cloud}" | tr '[:lower:]' '[:upper:]')"

    echo "--- ${display_cloud} Composition ---"

    assert "${display_cloud} composition file exists" "$([[ -f "${file}" ]] && echo true || echo false)"

    if [[ ! -f "${file}" ]]; then
        echo -e "  ${RED}Skipping remaining ${display_cloud} checks — file not found${NC}"
        echo ""
        return
    fi

    # YAML validity
    local yaml_valid
    yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${file}" 2>&1 && echo true || echo false)
    assert "${display_cloud} valid YAML" "${yaml_valid}"

    # Deep validation with Python
    local checks
    checks=$(COMP_PATH="${file}" CLOUD="${cloud}" python3 << 'PYEOF'
import yaml, json, os

cloud = os.environ["CLOUD"]
with open(os.environ["COMP_PATH"]) as f:
    docs = list(yaml.safe_load_all(f))

results = {}
doc = docs[0]

# Kind and API version
results["kind"] = doc.get("kind") == "Composition"
results["api_version"] = doc.get("apiVersion") == "apiextensions.crossplane.io/v1"

spec = doc.get("spec", {})

# Composite type ref
ctr = spec.get("compositeTypeRef", {})
results["xrd_api"] = ctr.get("apiVersion") == "platform.kubecon.io/v1alpha1"
results["xrd_kind"] = ctr.get("kind") == "DatabaseInstance"

# Pipeline mode
results["mode"] = spec.get("mode") == "Pipeline"

# Pipeline steps — must have function-patch-and-transform
pipeline = spec.get("pipeline", [])
results["has_pipeline"] = len(pipeline) > 0

func_names = [step.get("functionRef", {}).get("name", "") for step in pipeline]
results["has_patch_transform"] = "function-patch-and-transform" in func_names

# Cloud-specific resource checks
if pipeline:
    # Collect all resource base kinds from patch-and-transform input
    for step in pipeline:
        inp = step.get("input", {})
        resources = inp.get("resources", [])
        base_kinds = []
        for r in resources:
            base = r.get("base", {})
            base_kinds.append(base.get("kind", ""))

        if cloud == "aws":
            results["has_rds"] = "Instance" in base_kinds or "DBInstance" in base_kinds
            results["has_iam_role"] = "Role" in base_kinds
            results["has_sg"] = "SecurityGroup" in base_kinds
            results["has_sg_rule"] = "SecurityGroupRule" in base_kinds
        elif cloud == "gcp":
            results["has_cloudsql"] = "DatabaseInstance" in base_kinds
            results["has_database"] = "Database" in base_kinds
            results["has_user"] = "User" in base_kinds
        elif cloud == "azure":
            results["has_flexible_server"] = "FlexibleServer" in base_kinds
            results["has_flexible_db"] = "FlexibleServerDatabase" in base_kinds

print(json.dumps(results))
PYEOF
    )

    assert "${display_cloud} kind is Composition" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('kind','false'))")"
    assert "${display_cloud} apiVersion correct" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('api_version','false'))")"
    assert "${display_cloud} refs DatabaseInstance XRD" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('xrd_api','false'))")"
    assert "${display_cloud} refs correct kind" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('xrd_kind','false'))")"
    assert "${display_cloud} uses Pipeline mode" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mode','false'))")"
    assert "${display_cloud} has pipeline steps" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_pipeline','false'))")"
    assert "${display_cloud} uses function-patch-and-transform" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_patch_transform','false'))")"

    # Cloud-specific resource assertions
    case "${cloud}" in
        aws)
            assert "AWS has RDS Instance" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_rds','false'))")"
            assert "AWS has IAM Role" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_iam_role','false'))")"
            assert "AWS has SecurityGroup" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_sg','false'))")"
            assert "AWS has SecurityGroupRule" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_sg_rule','false'))")"
            ;;
        gcp)
            assert "GCP has Cloud SQL DatabaseInstance" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_cloudsql','false'))")"
            assert "GCP has Database" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_database','false'))")"
            assert "GCP has User" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_user','false'))")"
            ;;
        azure)
            assert "Azure has FlexibleServer" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_flexible_server','false'))")"
            assert "Azure has FlexibleServerDatabase" "$(echo "${checks}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_flexible_db','false'))")"
            ;;
    esac

    echo ""
}

echo "=== Composition Validation Tests ==="
echo ""

validate_composition "aws"
validate_composition "gcp"
validate_composition "azure"

echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}COMPOSITION TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL COMPOSITION TESTS PASSED${NC}"
    exit 0
fi
