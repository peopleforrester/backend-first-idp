#!/usr/bin/env bash
# ABOUTME: One-shot bootstrap script for the backend-first IDP platform (v2).
# ABOUTME: 12-step install: cert-manager, Crossplane, provider, ArgoCD, Kyverno, ESO, OTel, Prometheus, OpenCost.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Version manifest (pinned March 2026) ---
PROVIDER=""
DRY_RUN=false
SKIP_OBSERVABILITY=false

CROSSPLANE_VERSION="2.1.0"
CROSSPLANE_FUNC_VERSION="v0.9.0"
ARGOCD_VERSION="v3.3.4"
KYVERNO_CHART_VERSION="3.7.1"
ESO_CHART_VERSION="2.2.0"
CERTMANAGER_VERSION="v1.17.1"
PROMETHEUS_CHART_VERSION="72.3.0"
OPENCOST_CHART_VERSION="1.46.0"

usage() {
    cat <<USAGE
Usage: $0 --provider <aws|gcp|azure> [--dry-run] [--skip-observability]

Bootstrap the backend-first IDP platform on the current Kubernetes cluster.

Options:
  --provider            Cloud provider (required): aws, gcp, or azure
  --dry-run             Print what would be installed without executing
  --skip-observability  Skip OTel, Prometheus, and OpenCost (lightweight install)
  --help                Show this help message

Example:
  $0 --provider aws
  $0 --provider gcp --dry-run
  $0 --provider azure --skip-observability
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-observability)
            SKIP_OBSERVABILITY=true
            shift
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

# --- Dry run mode ---
run() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "  [DRY RUN] $*"
    else
        "$@"
    fi
}

TOTAL_STEPS=12
if [[ "${SKIP_OBSERVABILITY}" == "true" ]]; then
    TOTAL_STEPS=8
fi

step_num=0
step() {
    ((step_num++)) || true
    echo ""
    echo "=== Step ${step_num}/${TOTAL_STEPS}: $1 ==="
}

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

if [[ "${DRY_RUN}" == "true" ]]; then
    echo ""
    echo "  *** DRY RUN MODE — no changes will be made ***"
fi

# --- Step 1: cert-manager (required by OTel Operator and Kyverno webhooks) ---
step "Installing cert-manager ${CERTMANAGER_VERSION}"
run kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml"
echo "  cert-manager installed."

# --- Step 2: Crossplane ---
step "Installing Crossplane ${CROSSPLANE_VERSION}"
run helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || true
run helm repo update crossplane-stable
run helm upgrade --install crossplane crossplane-stable/crossplane \
    --namespace crossplane-system \
    --create-namespace \
    --version "${CROSSPLANE_VERSION}" \
    --wait
echo "  Crossplane v2 installed."

# --- Step 3: Crossplane functions ---
step "Installing Crossplane functions"
run kubectl apply -f - <<FUNC
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:${CROSSPLANE_FUNC_VERSION}
FUNC
echo "  function-patch-and-transform ${CROSSPLANE_FUNC_VERSION} installed."

# --- Step 4: Cloud provider ---
step "Installing ${PROVIDER} provider"
PROVIDER_FILE="${SCRIPT_DIR}/providers/${PROVIDER}.yaml"
if [[ ! -f "${PROVIDER_FILE}" ]]; then
    echo "ERROR: Provider file not found: ${PROVIDER_FILE}"
    exit 1
fi
run kubectl apply -f "${PROVIDER_FILE}"
echo "  ${PROVIDER} provider installed."

# --- Step 5: ArgoCD ---
step "Installing ArgoCD ${ARGOCD_VERSION}"
run kubectl create namespace argocd 2>/dev/null || true
run kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
echo "  ArgoCD v3 installed (server-side apply)."

# --- Step 6: Kyverno ---
step "Installing Kyverno (chart ${KYVERNO_CHART_VERSION})"
run helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
run helm repo update kyverno
run helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --version "${KYVERNO_CHART_VERSION}" \
    --set admissionController.replicas=3 \
    --set backgroundController.enabled=true \
    --set reportsController.enabled=true \
    --wait
echo "  Kyverno installed."

# --- Step 7: External Secrets Operator ---
step "Installing External Secrets Operator (chart ${ESO_CHART_VERSION})"
run helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
run helm repo update external-secrets
run helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --create-namespace \
    --version "${ESO_CHART_VERSION}" \
    --wait
echo "  External Secrets Operator installed."

# --- Step 8: Apply platform resources ---
step "Applying platform resources"

echo "  Applying XRDs..."
run kubectl apply -f "${REPO_ROOT}/platform-api/xrds/"

echo "  Applying ${PROVIDER} compositions..."
run kubectl apply -f "${REPO_ROOT}/platform-api/compositions/${PROVIDER}/"

echo "  Applying Kyverno policies (production enforcement)..."
run kubectl apply -f "${REPO_ROOT}/policies/kyverno/cluster-policies/"

echo "  Applying Shadow Metric CRD..."
run kubectl apply -f "${REPO_ROOT}/platform-api/shadow-metrics/shadow-metric-crd.yaml"

echo "  Applying Shadow Metric rules..."
run kubectl apply -f "${REPO_ROOT}/platform-api/shadow-metrics/rules/"

echo "  Applying ESO ClusterSecretStores..."
run kubectl apply -f "${REPO_ROOT}/secrets/eso/cluster-secret-store-${PROVIDER}.yaml"

echo "  Applying ArgoCD ApplicationSets + RBAC..."
run kubectl apply -f "${REPO_ROOT}/gitops/argocd/"

echo "  Applying drift detection..."
run kubectl apply -f "${REPO_ROOT}/platform-api/drift-detection/drift-check-cronjob.yaml"

echo "  Platform resources applied."

# --- Observability stack (optional) ---
if [[ "${SKIP_OBSERVABILITY}" == "false" ]]; then

    # --- Step 9: OpenTelemetry Operator ---
    step "Installing OpenTelemetry Operator"
    run kubectl apply -f "https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml"
    echo "  OpenTelemetry Operator installed."

    # --- Step 10: kube-prometheus-stack ---
    step "Installing kube-prometheus-stack (chart ${PROMETHEUS_CHART_VERSION})"
    run helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    run helm repo update prometheus-community
    run helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace observability \
        --create-namespace \
        --version "${PROMETHEUS_CHART_VERSION}" \
        --values "${REPO_ROOT}/observability/prometheus/values-platform.yaml" \
        --wait
    echo "  kube-prometheus-stack installed."

    # --- Step 11: OpenCost ---
    step "Installing OpenCost (chart ${OPENCOST_CHART_VERSION})"
    run helm repo add opencost https://opencost.github.io/opencost-helm-chart 2>/dev/null || true
    run helm repo update opencost
    run helm upgrade --install opencost opencost/opencost \
        --namespace observability \
        --version "${OPENCOST_CHART_VERSION}" \
        --values "${REPO_ROOT}/observability/opencost/values-platform.yaml" \
        --wait
    echo "  OpenCost installed."

    # --- Step 12: Apply observability resources ---
    step "Applying observability resources"

    echo "  Applying OTel collectors..."
    run kubectl apply -f "${REPO_ROOT}/observability/opentelemetry/"

    echo "  Applying Prometheus rules..."
    run kubectl apply -f "${REPO_ROOT}/observability/prometheus/platform-rules/"

    echo "  Applying ServiceMonitors..."
    run kubectl apply -f "${REPO_ROOT}/observability/prometheus/service-monitors/"

    echo "  Applying OpenCost config..."
    run kubectl apply -f "${REPO_ROOT}/observability/opencost/cost-allocation/"

    echo "  Observability stack applied."
fi

# --- Summary ---
echo ""
echo "========================================="
echo "  Bootstrap complete"
echo "========================================="
echo ""
echo "  Provider:       ${PROVIDER}"
echo "  Crossplane:     v${CROSSPLANE_VERSION}"
echo "  ArgoCD:         ${ARGOCD_VERSION}"
echo "  Kyverno:        chart ${KYVERNO_CHART_VERSION}"
echo "  ESO:            chart ${ESO_CHART_VERSION}"
if [[ "${SKIP_OBSERVABILITY}" == "false" ]]; then
echo "  Prometheus:     chart ${PROMETHEUS_CHART_VERSION}"
echo "  OpenCost:       chart ${OPENCOST_CHART_VERSION}"
echo "  OTel Operator:  latest"
fi
echo ""
echo "  XRDs:           7 resource types"
echo "  Compositions:   7 (${PROVIDER})"
echo "  Policies:       6 Kyverno cluster policies"
echo "  Shadow Metrics: 4 rules"
echo ""
echo "Next steps:"
echo "  1. Configure ${PROVIDER} credentials (see bootstrap/providers/${PROVIDER}.yaml)"
echo "  2. Submit a claim:  kubectl apply -f golden-path/examples/claim-database.yaml"
echo "  3. Watch it provision:  kubectl get databaseinstanceclaim -w"
echo "  4. Try the failing claim:  kubectl apply -f golden-path/examples/claim-database-WILL-FAIL.yaml"
echo "  5. Check the Grafana dashboards at http://localhost:3000 (port-forward grafana service)"
