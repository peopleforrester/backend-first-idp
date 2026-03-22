#!/usr/bin/env bash
# ABOUTME: One-shot bootstrap script for the backend-first IDP platform.
# ABOUTME: Installs Crossplane, ArgoCD, Gatekeeper, and applies platform resources.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
PROVIDER=""
CROSSPLANE_VERSION="1.17"
ARGOCD_VERSION="v3.3.4"
GATEKEEPER_VERSION="3.18"

usage() {
    cat <<USAGE
Usage: $0 --provider <aws|gcp|azure>

Bootstrap the backend-first IDP platform on the current Kubernetes cluster.

Options:
  --provider    Cloud provider (required): aws, gcp, or azure
  --help        Show this help message

Example:
  $0 --provider aws
USAGE
    exit 1
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "${PROVIDER}" ]]; then
    echo "ERROR: --provider is required"
    usage
fi

if [[ "${PROVIDER}" != "aws" && "${PROVIDER}" != "gcp" && "${PROVIDER}" != "azure" ]]; then
    echo "ERROR: --provider must be aws, gcp, or azure (got: ${PROVIDER})"
    exit 1
fi

# --- Pre-flight checks ---
echo "=== Pre-flight checks ==="

check_tool() {
    local tool="$1"
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} is required but not found in PATH"
        exit 1
    fi
    echo "  OK ${tool} found"
}

check_tool "kubectl"
check_tool "helm"

echo "  OK Cluster reachable: $(kubectl cluster-info 2>/dev/null | head -1 || echo 'WARNING: cluster not reachable')"
echo ""

# --- Step 1: Install Crossplane ---
echo "=== Step 1/6: Installing Crossplane ${CROSSPLANE_VERSION} ==="
helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || true
helm repo update crossplane-stable
helm upgrade --install crossplane crossplane-stable/crossplane \
    --namespace crossplane-system \
    --create-namespace \
    --version "${CROSSPLANE_VERSION}" \
    --wait
echo "  Crossplane installed."
echo ""

# --- Step 2: Install Crossplane functions ---
echo "=== Step 2/6: Installing Crossplane functions ==="
kubectl apply -f - <<'FUNC'
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.7.0
FUNC
echo "  function-patch-and-transform installed."
echo ""

# --- Step 3: Install cloud provider ---
echo "=== Step 3/6: Installing ${PROVIDER} provider ==="
PROVIDER_FILE="${SCRIPT_DIR}/providers/${PROVIDER}.yaml"
if [[ ! -f "${PROVIDER_FILE}" ]]; then
    echo "ERROR: Provider file not found: ${PROVIDER_FILE}"
    exit 1
fi
kubectl apply -f "${PROVIDER_FILE}"
echo "  ${PROVIDER} provider installed."
echo ""

# --- Step 4: Install ArgoCD ---
echo "=== Step 4/6: Installing ArgoCD ${ARGOCD_VERSION} ==="
kubectl create namespace argocd 2>/dev/null || true
# ArgoCD v3 requires server-side apply due to CRD size exceeding annotation limits
kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
echo "  ArgoCD v3 installed (server-side apply)."
echo ""

# --- Step 5: Install Gatekeeper ---
echo "=== Step 5/6: Installing Gatekeeper ${GATEKEEPER_VERSION} ==="
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
helm repo update gatekeeper
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
    --namespace gatekeeper-system \
    --create-namespace \
    --version "${GATEKEEPER_VERSION}" \
    --wait
echo "  Gatekeeper installed."
echo ""

# --- Step 6: Apply platform resources ---
echo "=== Step 6/6: Applying platform resources ==="

echo "  Applying XRDs..."
kubectl apply -f "${REPO_ROOT}/platform-api/xrds/"

echo "  Applying ${PROVIDER} compositions..."
kubectl apply -f "${REPO_ROOT}/platform-api/compositions/${PROVIDER}/"

echo "  Applying Gatekeeper policies..."
kubectl apply -f "${REPO_ROOT}/policies/gatekeeper/constraint-templates/"

echo "  Applying ArgoCD ApplicationSets..."
kubectl apply -f "${REPO_ROOT}/gitops/argocd/"

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Provider:    ${PROVIDER}"
echo "Crossplane:  ${CROSSPLANE_VERSION}"
echo "ArgoCD:      ${ARGOCD_VERSION}"
echo "Gatekeeper:  ${GATEKEEPER_VERSION}"
echo ""
echo "Next steps:"
echo "  1. Configure your ${PROVIDER} credentials (see bootstrap/providers/${PROVIDER}.yaml)"
echo "  2. Submit a claim:  kubectl apply -f golden-path/examples/claim-database.yaml"
echo "  3. Watch it provision:  kubectl get databaseinstanceclaim -w"
