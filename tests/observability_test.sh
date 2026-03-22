#!/usr/bin/env bash
# ABOUTME: Observability manifest validation — OTel, Prometheus, OpenCost, Grafana dashboards.
# ABOUTME: Run via 'make test-observability' or directly with bash.

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

echo "=== Observability Tests ==="
echo ""

OBS_DIR="${REPO_ROOT}/observability"

if [[ ! -d "${OBS_DIR}" ]]; then
    echo "No observability/ directory found — skipping."
    exit 0
fi

# Validate OTel CRs have correct apiVersion
echo "--- OpenTelemetry ---"
for cr in "collector-agent" "collector-gateway"; do
    f="${OBS_DIR}/opentelemetry/${cr}.yaml"
    if [[ -f "${f}" ]]; then
        has_api=$(grep -q "opentelemetry.io/v1beta1" "${f}" && echo true || echo false)
        assert "OTel ${cr} has v1beta1 apiVersion" "${has_api}"
    else
        assert "OTel ${cr} exists" "false"
    fi
done

# Validate PrometheusRule manifests
echo ""
echo "--- Prometheus ---"
for rule_file in "${OBS_DIR}"/prometheus/platform-rules/*.yaml; do
    [[ -f "${rule_file}" ]] || continue
    name="$(basename "${rule_file}" .yaml)"
    has_kind=$(grep -q "kind: PrometheusRule" "${rule_file}" && echo true || echo false)
    assert "PrometheusRule: ${name}" "${has_kind}"
done

# Validate ServiceMonitors
for sm_file in "${OBS_DIR}"/prometheus/service-monitors/*.yaml; do
    [[ -f "${sm_file}" ]] || continue
    name="$(basename "${sm_file}" .yaml)"
    has_kind=$(grep -q "kind: ServiceMonitor" "${sm_file}" && echo true || echo false)
    assert "ServiceMonitor: ${name}" "${has_kind}"
done

# Validate Grafana dashboards are parseable JSON
echo ""
echo "--- Grafana Dashboards ---"
for dash_file in "${OBS_DIR}"/grafana/dashboards/*.json; do
    [[ -f "${dash_file}" ]] || continue
    name="$(basename "${dash_file}" .json)"
    is_valid=$(python3 -c "import json; json.load(open('${dash_file}'))" 2>/dev/null && echo true || echo false)
    assert "Dashboard JSON valid: ${name}" "${is_valid}"
done

# Validate OpenCost values
echo ""
echo "--- OpenCost ---"
f="${OBS_DIR}/opencost/values-platform.yaml"
if [[ -f "${f}" ]]; then
    assert "OpenCost values exists" "true"
    yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${f}" 2>&1 && echo true || echo false)
    assert "OpenCost values valid YAML" "${yaml_valid}"
else
    assert "OpenCost values exists" "false"
fi

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}OBSERVABILITY TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL OBSERVABILITY TESTS PASSED${NC}"
    exit 0
fi
