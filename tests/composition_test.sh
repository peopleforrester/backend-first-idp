#!/usr/bin/env bash
# ABOUTME: Composition validation test — asserts all 21 cloud compositions (7 types × 3 clouds).
# ABOUTME: Run via 'make test-compositions' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMP_DIR="${REPO_ROOT}/platform-api/compositions"
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

echo "=== Composition Validation Tests (v2 — 21 compositions) ==="
echo ""

# All expected composition files and their XRD kind mapping
RESULTS=$(COMP_DIR="${COMP_DIR}" python3 << 'PYEOF'
import yaml, json, os
from pathlib import Path

comp_dir = Path(os.environ["COMP_DIR"])

# (filename, expected XRD kind)
comp_specs = [
    ("database-small", "DatabaseInstance"),
    ("cache-small", "CacheInstance"),
    ("message-queue-small", "MessageQueue"),
    ("object-storage", "ObjectStorage"),
    ("cdn-distribution", "CDNDistribution"),
    ("dns-record", "DNSRecord"),
    ("namespace", "KubernetesNamespace"),
]

clouds = ["aws", "gcp", "azure"]
all_checks = {}

for cloud in clouds:
    for filename, xrd_kind in comp_specs:
        key_prefix = f"{cloud}/{filename}"
        filepath = comp_dir / cloud / f"{filename}.yaml"

        all_checks[f"{key_prefix}:exists"] = filepath.is_file()
        if not filepath.is_file():
            continue

        try:
            with open(filepath) as f:
                docs = list(yaml.safe_load_all(f))
            doc = docs[0]
        except Exception:
            all_checks[f"{key_prefix}:parseable"] = False
            continue

        all_checks[f"{key_prefix}:parseable"] = True

        # Kind
        all_checks[f"{key_prefix}:kind_is_composition"] = doc.get("kind") == "Composition"

        # API version
        all_checks[f"{key_prefix}:apiVersion"] = doc.get("apiVersion") == "apiextensions.crossplane.io/v1"

        # Composite type ref
        spec = doc.get("spec", {})
        ctr = spec.get("compositeTypeRef", {})
        all_checks[f"{key_prefix}:xrd_api"] = ctr.get("apiVersion") == "platform.kubecon.io/v1alpha1"
        all_checks[f"{key_prefix}:xrd_kind"] = ctr.get("kind") == xrd_kind

        # Pipeline mode
        all_checks[f"{key_prefix}:pipeline_mode"] = spec.get("mode") == "Pipeline"

        # Has pipeline with function-patch-and-transform
        pipeline = spec.get("pipeline", [])
        all_checks[f"{key_prefix}:has_pipeline"] = len(pipeline) > 0
        func_names = [s.get("functionRef", {}).get("name", "") for s in pipeline]
        all_checks[f"{key_prefix}:has_patch_transform"] = "function-patch-and-transform" in func_names

        # Has at least one resource in the pipeline input
        resource_count = 0
        for step in pipeline:
            inp = step.get("input", {})
            resource_count += len(inp.get("resources", []))
        all_checks[f"{key_prefix}:has_resources"] = resource_count > 0

        # Provider label
        labels = doc.get("metadata", {}).get("labels", {})
        all_checks[f"{key_prefix}:provider_label"] = labels.get("provider") == cloud

print(json.dumps(all_checks))
PYEOF
)

# Parse and print results grouped by cloud
CURRENT_GROUP=""
while IFS='=' read -r key val; do
    group="${key%%/*}"
    if [[ "${group}" != "${CURRENT_GROUP}" ]]; then
        echo ""
        echo "--- ${group^^} ---"
        CURRENT_GROUP="${group}"
    fi
    assert "${key}" "${val}"
done < <(echo "${RESULTS}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k, v in sorted(data.items()):
    print(f'{k}={str(v).lower()}')
")

echo ""
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
