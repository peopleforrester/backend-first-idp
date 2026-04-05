#!/usr/bin/env bash
# ABOUTME: ESO manifest validation — ClusterSecretStores and ExternalSecrets.
# ABOUTME: Run via 'make test-eso' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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

print_results "ESO TESTS"
