#!/usr/bin/env bash
# ABOUTME: ESO manifest validation — ClusterSecretStores and ExternalSecrets.
# ABOUTME: Run via 'make test-eso' or directly with bash.

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

echo "=== ESO Tests ==="
echo ""

ESO_DIR="${REPO_ROOT}/secrets/eso"

if [[ ! -d "${ESO_DIR}" ]]; then
    echo "No secrets/eso directory found — skipping."
    exit 0
fi

# Validate ClusterSecretStores
echo "--- ClusterSecretStores ---"
for cloud in aws gcp azure; do
    f="${ESO_DIR}/cluster-secret-store-${cloud}.yaml"
    if [[ -f "${f}" ]]; then
        has_kind=$(grep -q "kind: ClusterSecretStore" "${f}" && echo true || echo false)
        assert "${cloud} ClusterSecretStore has correct kind" "${has_kind}"
        yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${f}" 2>&1 && echo true || echo false)
        assert "${cloud} ClusterSecretStore valid YAML" "${yaml_valid}"
    else
        assert "${cloud} ClusterSecretStore exists" "false"
    fi
done

# Validate ExternalSecrets
echo ""
echo "--- ExternalSecrets ---"
for es in "database-credentials" "provider-credentials" "tls-certificates"; do
    f="${ESO_DIR}/external-secrets/${es}.yaml"
    if [[ -f "${f}" ]]; then
        has_api=$(grep -q "external-secrets.io" "${f}" && echo true || echo false)
        assert "${es} has ESO apiVersion" "${has_api}"
        yaml_valid=$(yamllint -c "${REPO_ROOT}/.yamllint.yml" "${f}" 2>&1 && echo true || echo false)
        assert "${es} valid YAML" "${yaml_valid}"
    else
        assert "${es} exists" "false"
    fi
done

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}ESO TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL ESO TESTS PASSED${NC}"
    exit 0
fi
