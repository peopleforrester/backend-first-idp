#!/usr/bin/env bash
# ABOUTME: XRD validation test — asserts DatabaseInstance XRD structure and schema.
# ABOUTME: Run via 'make test-xrd' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XRD_FILE="${REPO_ROOT}/platform-api/xrds/database-instance.yaml"
PASS=0
FAIL=0

# Colors
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

echo "=== XRD Validation Tests ==="
echo ""

# File existence
assert "XRD file exists" "$([[ -f "${XRD_FILE}" ]] && echo true || echo false)"

if [[ ! -f "${XRD_FILE}" ]]; then
    echo ""
    echo -e "${RED}XRD file not found — cannot run remaining tests${NC}"
    echo ""
    echo "=== Results ==="
    echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
    exit 1
fi

# YAML validity
YAML_VALID=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${XRD_FILE}" 2>&1 && echo true || echo false)
assert "Valid YAML" "${YAML_VALID}"

# Requires python3 + PyYAML for deep inspection
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "  SKIP — python3 yaml module not available"
    exit 1
fi

# Extract fields with python for reliable YAML parsing
CHECKS=$(XRD_PATH="${XRD_FILE}" python3 << 'PYEOF'
import yaml, sys, json, os

with open(os.environ["XRD_PATH"]) as f:
    docs = list(yaml.safe_load_all(f))

results = {}
doc = docs[0]

# Kind check
results["kind_is_xrd"] = doc.get("kind") == "CompositeResourceDefinition"

# API version
results["api_version"] = doc.get("apiVersion") == "apiextensions.crossplane.io/v1"

# Group
spec = doc.get("spec", {})
results["group"] = spec.get("group") == "platform.kubecon.io"

# Names
names = spec.get("names", {})
results["kind_name"] = names.get("kind") == "DatabaseInstance"
results["plural_name"] = names.get("plural") == "databaseinstances"

# Version
versions = spec.get("versions", [])
results["has_version"] = len(versions) > 0
if versions:
    v = versions[0]
    results["version_name"] = v.get("name") == "v1alpha1"
    results["served"] = v.get("served") is True
    results["referenceable"] = v.get("referenceable") is True

    # Spec fields
    schema = v.get("schema", {}).get("openAPIV3Schema", {})
    spec_props = schema.get("properties", {}).get("spec", {}).get("properties", {})

    # size — enum with small/medium/large
    size = spec_props.get("size", {})
    results["size_exists"] = "size" in spec_props
    results["size_enum"] = set(size.get("enum", [])) == {"small", "medium", "large"}

    # region — enum with 4 regions
    region = spec_props.get("region", {})
    results["region_exists"] = "region" in spec_props
    expected_regions = {"eu-west-1", "eu-central-1", "us-east-1", "us-west-2"}
    results["region_enum"] = set(region.get("enum", [])) == expected_regions

    # team — string, required
    results["team_exists"] = "team" in spec_props
    results["team_type"] = spec_props.get("team", {}).get("type") == "string"
    required = schema.get("properties", {}).get("spec", {}).get("required", [])
    results["team_required"] = "team" in required

    # engine — default postgres
    engine = spec_props.get("engine", {})
    results["engine_exists"] = "engine" in spec_props
    results["engine_default"] = engine.get("default") == "postgres"

    # highAvailability — bool, default false
    ha = spec_props.get("highAvailability", {})
    results["ha_exists"] = "highAvailability" in spec_props
    results["ha_type"] = ha.get("type") == "boolean"
    results["ha_default"] = ha.get("default") is False

    # backupRetentionDays — int, default 7
    backup = spec_props.get("backupRetentionDays", {})
    results["backup_exists"] = "backupRetentionDays" in spec_props
    results["backup_type"] = backup.get("type") == "integer"
    results["backup_default"] = backup.get("default") == 7

    # Status fields
    status_props = schema.get("properties", {}).get("status", {}).get("properties", {})
    for field in ["connectionSecret", "endpoint", "port", "status"]:
        results[f"status_{field}"] = field in status_props

    # claimNames (so devs can create DatabaseInstanceClaim)
    claim_names = spec.get("claimNames", {})
    results["claim_kind"] = claim_names.get("kind") == "DatabaseInstanceClaim"
else:
    pass

print(json.dumps(results))
PYEOF
)

# Parse results
assert "Kind is CompositeResourceDefinition" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('kind_is_xrd','false'))")"
assert "apiVersion is apiextensions.crossplane.io/v1" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('api_version','false'))")"
assert "Group is platform.kubecon.io" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('group','false'))")"
assert "Kind name is DatabaseInstance" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('kind_name','false'))")"
assert "Plural name is databaseinstances" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('plural_name','false'))")"
assert "Has v1alpha1 version" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version_name','false'))")"
assert "Version is served" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('served','false'))")"
assert "Version is referenceable" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('referenceable','false'))")"

echo ""
echo "--- Spec fields ---"
assert "size field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('size_exists','false'))")"
assert "size enum: small/medium/large" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('size_enum','false'))")"
assert "region field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region_exists','false'))")"
assert "region enum: eu-west-1/eu-central-1/us-east-1/us-west-2" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region_enum','false'))")"
assert "team field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('team_exists','false'))")"
assert "team type is string" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('team_type','false'))")"
assert "team is required" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('team_required','false'))")"
assert "engine field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine_exists','false'))")"
assert "engine default is postgres" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('engine_default','false'))")"
assert "highAvailability field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ha_exists','false'))")"
assert "highAvailability type is boolean" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ha_type','false'))")"
assert "highAvailability default is false" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ha_default','false'))")"
assert "backupRetentionDays field exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('backup_exists','false'))")"
assert "backupRetentionDays type is integer" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('backup_type','false'))")"
assert "backupRetentionDays default is 7" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('backup_default','false'))")"

echo ""
echo "--- Status fields ---"
assert "status.connectionSecret exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_connectionSecret','false'))")"
assert "status.endpoint exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_endpoint','false'))")"
assert "status.port exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_port','false'))")"
assert "status.status exists" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status_status','false'))")"

echo ""
echo "--- Claim ---"
assert "claimNames kind is DatabaseInstanceClaim" "$(echo "${CHECKS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('claim_kind','false'))")"

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}XRD TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL XRD TESTS PASSED${NC}"
    exit 0
fi
