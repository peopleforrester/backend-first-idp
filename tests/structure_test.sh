#!/usr/bin/env bash
# ABOUTME: Structure test — asserts all expected files exist in the repo.
# ABOUTME: Run via 'make test-structure' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# Colors (disable if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' NC=''
fi

assert_file_exists() {
    local file="$1"
    local description="${2:-$file}"
    if [[ -f "${REPO_ROOT}/${file}" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — file not found: ${file}"
        ((FAIL++)) || true
    fi
}

assert_dir_exists() {
    local dir="$1"
    local description="${2:-$dir}"
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — directory not found: ${dir}"
        ((FAIL++)) || true
    fi
}


echo "=== Structure Tests ==="
echo ""

echo "--- Root files ---"
assert_file_exists "README.md" "README.md exists"
assert_file_exists "LICENSE" "LICENSE exists"
assert_file_exists "DEMO.md" "DEMO.md exists"
assert_file_exists ".yamllint.yml" "yamllint config exists"
assert_file_exists "Makefile" "Makefile exists"

echo ""
echo "--- Platform API ---"
assert_dir_exists "platform-api/xrds" "XRD directory exists"
assert_file_exists "platform-api/xrds/database-instance.yaml" "DatabaseInstance XRD"
assert_dir_exists "platform-api/compositions/aws" "AWS compositions directory"
assert_file_exists "platform-api/compositions/aws/database-small.yaml" "AWS database composition"
assert_dir_exists "platform-api/compositions/gcp" "GCP compositions directory"
assert_file_exists "platform-api/compositions/gcp/database-small.yaml" "GCP database composition"
assert_dir_exists "platform-api/compositions/azure" "Azure compositions directory"
assert_file_exists "platform-api/compositions/azure/database-small.yaml" "Azure database composition"

echo ""
echo "--- Policies ---"
assert_file_exists "policies/opa/region-allowed.rego" "OPA region policy"
assert_file_exists "policies/opa/size-limits.rego" "OPA size limits policy"
assert_file_exists "policies/opa/region-allowed_test.rego" "OPA region policy tests"
assert_file_exists "policies/opa/size-limits_test.rego" "OPA size limits policy tests"
assert_file_exists "policies/gatekeeper/constraint-templates/platform-validation.yaml" "Gatekeeper ConstraintTemplate"

echo ""
echo "--- GitOps ---"
assert_file_exists "gitops/argocd/appset-platform.yaml" "ArgoCD ApplicationSet"
assert_file_exists "gitops/kustomize/base/kustomization.yaml" "Kustomize base"
assert_file_exists "gitops/kustomize/overlays/aws/kustomization.yaml" "Kustomize AWS overlay"
assert_file_exists "gitops/kustomize/overlays/gcp/kustomization.yaml" "Kustomize GCP overlay"
assert_file_exists "gitops/kustomize/overlays/azure/kustomization.yaml" "Kustomize Azure overlay"

echo ""
echo "--- Golden Path ---"
assert_file_exists "golden-path/examples/claim-database.yaml" "Working claim example"
assert_file_exists "golden-path/examples/claim-database-WILL-FAIL.yaml" "Failing claim example"
assert_file_exists "golden-path/templates/new-service/service-resources.yaml" "Service template"

echo ""
echo "--- Bootstrap ---"
assert_file_exists "bootstrap/install.sh" "Bootstrap install script"
assert_file_exists "bootstrap/providers/aws.yaml" "AWS provider config"
assert_file_exists "bootstrap/providers/gcp.yaml" "GCP provider config"
assert_file_exists "bootstrap/providers/azure.yaml" "Azure provider config"

echo ""
echo "--- Documentation ---"
assert_file_exists "docs/architecture.md" "Architecture doc"

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}  ${YELLOW}Skipped: ${SKIP}${NC}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
    echo -e "${RED}STRUCTURE TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL STRUCTURE TESTS PASSED${NC}"
    exit 0
fi
