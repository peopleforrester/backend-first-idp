#!/usr/bin/env bash
# ABOUTME: XRD validation test — asserts all 7 platform XRDs have correct structure and schema.
# ABOUTME: Run via 'make test-xrd' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

XRD_DIR="${REPO_ROOT}/platform-api/xrds"

echo "=== XRD Validation Tests (v2 — 7 resource types) ==="
echo ""

# Requires python3 + PyYAML
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "SKIP — python3 yaml module not available"
    exit 1
fi

# Run all XRD validations via Python
RESULTS=$(XRD_DIR="${XRD_DIR}" python3 << 'PYEOF'
import yaml, json, os, sys
from pathlib import Path

xrd_dir = Path(os.environ["XRD_DIR"])
results = []

# Define expected XRDs: (filename, kind, plural, required_spec_fields, optional_spec_fields_with_types)
xrd_specs = [
    {
        "file": "database-instance.yaml",
        "kind": "DatabaseInstance",
        "plural": "databaseinstances",
        "claim_kind": "DatabaseInstanceClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "size": {"type": "string", "has_enum": True},
            "region": {"type": "string", "has_enum": True},
            "team": {"type": "string"},
            "engine": {"type": "string", "has_default": True},
            "highAvailability": {"type": "boolean", "has_default": True},
            "backupRetentionDays": {"type": "integer", "has_default": True},
        },
        "expected_status_fields": ["connectionSecret", "endpoint", "port", "status"],
    },
    {
        "file": "cache-instance.yaml",
        "kind": "CacheInstance",
        "plural": "cacheinstances",
        "claim_kind": "CacheInstanceClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "size": {"type": "string", "has_enum": True},
            "region": {"type": "string", "has_enum": True},
            "team": {"type": "string"},
            "engine": {"type": "string", "has_default": True},
        },
        "expected_status_fields": ["endpoint", "port", "status"],
    },
    {
        "file": "message-queue.yaml",
        "kind": "MessageQueue",
        "plural": "messagequeues",
        "claim_kind": "MessageQueueClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "region": {"type": "string", "has_enum": True},
            "team": {"type": "string"},
        },
        "expected_status_fields": ["endpoint", "status"],
    },
    {
        "file": "object-storage.yaml",
        "kind": "ObjectStorage",
        "plural": "objectstorages",
        "claim_kind": "ObjectStorageClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "region": {"type": "string", "has_enum": True},
            "team": {"type": "string"},
        },
        "expected_status_fields": ["endpoint", "status"],
    },
    {
        "file": "cdn-distribution.yaml",
        "kind": "CDNDistribution",
        "plural": "cdndistributions",
        "claim_kind": "CDNDistributionClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "team": {"type": "string"},
        },
        "expected_status_fields": ["endpoint", "status"],
    },
    {
        "file": "dns-record.yaml",
        "kind": "DNSRecord",
        "plural": "dnsrecords",
        "claim_kind": "DNSRecordClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "team": {"type": "string"},
        },
        "expected_status_fields": ["status"],
    },
    {
        "file": "kubernetes-namespace.yaml",
        "kind": "KubernetesNamespace",
        "plural": "kubernetesnamespaces",
        "claim_kind": "KubernetesNamespaceClaim",
        "required_spec": ["team"],
        "expected_spec_fields": {
            "team": {"type": "string"},
        },
        "expected_status_fields": ["status"],
    },
]

for spec in xrd_specs:
    xrd_file = xrd_dir / spec["file"]
    prefix = spec["kind"]
    checks = {}

    # File existence
    checks[f"{prefix}:exists"] = xrd_file.is_file()
    if not xrd_file.is_file():
        results.append(checks)
        continue

    # Parse YAML
    try:
        with open(xrd_file) as f:
            docs = list(yaml.safe_load_all(f))
        doc = docs[0]
    except Exception as e:
        checks[f"{prefix}:parseable"] = False
        results.append(checks)
        continue

    checks[f"{prefix}:parseable"] = True

    # Kind and API version
    checks[f"{prefix}:kind"] = doc.get("kind") == "CompositeResourceDefinition"
    api = doc.get("apiVersion", "")
    checks[f"{prefix}:apiVersion"] = api.startswith("apiextensions.crossplane.io/")

    # Group
    s = doc.get("spec", {})
    checks[f"{prefix}:group"] = s.get("group") == "platform.kubecon.io"

    # Names
    names = s.get("names", {})
    checks[f"{prefix}:kind_name"] = names.get("kind") == spec["kind"]
    checks[f"{prefix}:plural_name"] = names.get("plural") == spec["plural"]

    # Claim names
    claim_names = s.get("claimNames", {})
    checks[f"{prefix}:claim_kind"] = claim_names.get("kind") == spec["claim_kind"]

    # Version
    versions = s.get("versions", [])
    checks[f"{prefix}:has_version"] = len(versions) > 0
    if versions:
        v = versions[0]
        checks[f"{prefix}:v1alpha1"] = v.get("name") == "v1alpha1"
        checks[f"{prefix}:served"] = v.get("served") is True
        checks[f"{prefix}:referenceable"] = v.get("referenceable") is True

        # Spec fields
        schema = v.get("schema", {}).get("openAPIV3Schema", {})
        spec_props = schema.get("properties", {}).get("spec", {}).get("properties", {})
        required = schema.get("properties", {}).get("spec", {}).get("required", [])

        # Team must be required
        for req_field in spec["required_spec"]:
            checks[f"{prefix}:{req_field}_required"] = req_field in required

        # Expected spec fields
        for field_name, field_spec in spec["expected_spec_fields"].items():
            checks[f"{prefix}:spec.{field_name}_exists"] = field_name in spec_props
            if field_name in spec_props:
                prop = spec_props[field_name]
                if "type" in field_spec:
                    checks[f"{prefix}:spec.{field_name}_type"] = prop.get("type") == field_spec["type"]
                if field_spec.get("has_enum"):
                    checks[f"{prefix}:spec.{field_name}_has_enum"] = "enum" in prop and len(prop["enum"]) > 0
                if field_spec.get("has_default"):
                    checks[f"{prefix}:spec.{field_name}_has_default"] = "default" in prop

        # Status fields
        status_props = schema.get("properties", {}).get("status", {}).get("properties", {})
        for field in spec["expected_status_fields"]:
            checks[f"{prefix}:status.{field}"] = field in status_props

    results.append(checks)

# Flatten all checks
all_checks = {}
for r in results:
    all_checks.update(r)
print(json.dumps(all_checks))
PYEOF
)

# Parse and assert each check
CURRENT_XRD=""
while IFS='=' read -r key val; do
    # Extract XRD name and check name
    xrd_name="${key%%:*}"
    check_name="${key#*:}"

    # Print header when XRD changes
    if [[ "${xrd_name}" != "${CURRENT_XRD}" ]]; then
        echo ""
        echo "--- ${xrd_name} ---"
        CURRENT_XRD="${xrd_name}"
    fi

    assert "${xrd_name}: ${check_name}" "${val}"
done < <(echo "${RESULTS}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k, v in data.items():
    print(f'{k}={str(v).lower()}')
")

print_results "XRD TESTS"
