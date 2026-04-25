#!/usr/bin/env bash
# ABOUTME: Structure test — asserts all expected v2 files exist in the repo.
# ABOUTME: Run via 'make test-structure' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "=== Structure Tests (v2) ==="
echo ""

# --- Root files ---
echo "--- Root files ---"
assert_file_exists "README.md" "README.md"
assert_file_exists "LICENSE" "LICENSE"
assert_file_exists "DEMO.md" "DEMO.md"
assert_file_exists ".yamllint.yml" "yamllint config"
assert_file_exists "Makefile" "Makefile"
assert_file_exists ".github/workflows/test.yml" "GitHub Actions CI"

# --- XRDs (7 resource types) ---
echo ""
echo "--- Platform API: XRDs (7) ---"
assert_dir_exists "platform-api/xrds" "XRD directory"
XRD_TYPES=("database-instance" "cache-instance" "message-queue" "object-storage" "cdn-distribution" "dns-record" "kubernetes-namespace")
for xrd in "${XRD_TYPES[@]}"; do
    assert_file_exists "platform-api/xrds/${xrd}.yaml" "XRD: ${xrd}"
done

# --- Compositions (7 types × 3 clouds = 21) ---
echo ""
echo "--- Platform API: Compositions (21) ---"
CLOUDS=("aws" "gcp" "azure")
COMP_FILES=("database" "cache" "message-queue" "object-storage" "cdn-distribution" "dns-record" "namespace")
for cloud in "${CLOUDS[@]}"; do
    assert_dir_exists "platform-api/compositions/${cloud}" "${cloud} compositions dir"
    for comp in "${COMP_FILES[@]}"; do
        assert_file_exists "platform-api/compositions/${cloud}/${comp}.yaml" "${cloud}/${comp}"
    done
done

# --- Shadow Metrics ---
echo ""
echo "--- Shadow Metrics ---"
assert_file_exists "platform-api/shadow-metrics/shadow-metric-crd.yaml" "ShadowMetricRule CRD"
assert_file_exists "platform-api/shadow-metrics/README.md" "Shadow Metrics README"
SHADOW_RULES=("database-sizing" "region-latency" "cost-efficiency" "ha-requirement")
for rule in "${SHADOW_RULES[@]}"; do
    assert_file_exists "platform-api/shadow-metrics/rules/${rule}.yaml" "Shadow rule: ${rule}"
done
assert_file_exists "platform-api/shadow-metrics/functions/function-shadow-metrics.yaml" "Shadow Metrics function"

# --- Drift Detection ---
echo ""
echo "--- Drift Detection ---"
assert_file_exists "platform-api/drift-detection/drift-check-cronjob.yaml" "Drift CronJob"
assert_file_exists "platform-api/drift-detection/scripts/check-drift.sh" "Drift check script"
assert_file_exists "platform-api/drift-detection/prometheus-rule-drift.yaml" "Drift alert rule"
assert_drift_configmap_matches_canonical

# --- Kyverno Policies (6 cluster policies) ---
echo ""
echo "--- Kyverno Policies ---"
assert_dir_exists "policies/kyverno/cluster-policies" "Kyverno cluster-policies dir"
KYVERNO_POLICIES=("region-enforcement" "size-caps" "required-labels" "naming-conventions" "backup-retention-minimum" "ha-enforcement")
for policy in "${KYVERNO_POLICIES[@]}"; do
    assert_file_exists "policies/kyverno/cluster-policies/${policy}.yaml" "Policy: ${policy}"
done
assert_file_exists "policies/kyverno/policy-exceptions/platform-team-exceptions.yaml" "Policy exceptions"

# --- Kyverno Policy Tests ---
echo ""
echo "--- Kyverno Policy Tests ---"
for policy in "region-enforcement" "size-caps"; do
    assert_file_exists "policies/kyverno/policy-tests/${policy}/resource-pass.yaml" "${policy} pass resource"
    assert_file_exists "policies/kyverno/policy-tests/${policy}/resource-fail.yaml" "${policy} fail resource"
done

# --- Policy Promotion ---
echo ""
echo "--- Policy Promotion ---"
for env in "dev" "staging" "production"; do
    assert_file_exists "policies/kyverno/promotion/${env}/kustomization.yaml" "Promotion: ${env}"
done

# --- GitOps ---
echo ""
echo "--- GitOps ---"
assert_file_exists "gitops/argocd/appset-platform.yaml" "ArgoCD ApplicationSet"
assert_file_exists "gitops/kustomize/base/kustomization.yaml" "Kustomize base"
for cloud in "${CLOUDS[@]}"; do
    assert_file_exists "gitops/kustomize/overlays/${cloud}/kustomization.yaml" "Kustomize ${cloud} overlay"
done
for env in "dev" "staging" "production"; do
    assert_file_exists "gitops/kustomize/overlays/${env}/kustomization.yaml" "Kustomize ${env} overlay"
done

# --- Golden Path ---
echo ""
echo "--- Golden Path ---"
assert_file_exists "golden-path/examples/claim-database.yaml" "Working DB claim"
assert_file_exists "golden-path/examples/claim-database-WILL-FAIL.yaml" "Failing DB claim"
assert_file_exists "golden-path/examples/claim-cache.yaml" "Cache claim"
assert_file_exists "golden-path/examples/claim-message-queue.yaml" "Message queue claim"
assert_file_exists "golden-path/examples/claim-full-service.yaml" "Full service claim"
assert_file_exists "golden-path/examples/claim-shadow-metric-warning.yaml" "Shadow metric warning claim"
assert_file_exists "golden-path/templates/new-service/service-resources.yaml" "Service template"

# --- Teams (12 teams, 100+ claims) ---
echo ""
echo "--- Teams ---"
TEAMS=("checkout" "payments" "analytics" "platform" "identity" "catalog" "shipping" "notifications" "inventory" "search" "billing" "marketing")
for team in "${TEAMS[@]}"; do
    assert_dir_exists "teams/${team}/claims" "Team: ${team}/claims"
done
assert_file_exists "scripts/generate-team-claims.py" "Claim generator script"
assert_file_exists "scripts/teams.yaml" "Team manifest"

# --- Secrets / ESO ---
echo ""
echo "--- External Secrets Operator ---"
for cloud in "${CLOUDS[@]}"; do
    assert_file_exists "secrets/eso/cluster-secret-store-${cloud}.yaml" "ESO SecretStore: ${cloud}"
done
assert_file_exists "secrets/eso/external-secrets/database-credentials.yaml" "ESO: DB credentials"
assert_file_exists "secrets/eso/external-secrets/provider-credentials.yaml" "ESO: provider credentials"
assert_file_exists "secrets/eso/external-secrets/tls-certificates.yaml" "ESO: TLS certs"

# --- Observability ---
echo ""
echo "--- Observability ---"
assert_file_exists "observability/opentelemetry/collector-agent.yaml" "OTel agent"
assert_file_exists "observability/opentelemetry/collector-gateway.yaml" "OTel gateway"
assert_file_exists "observability/opentelemetry/instrumentation.yaml" "OTel instrumentation"
assert_file_exists "observability/opentelemetry/rbac.yaml" "OTel RBAC"
assert_file_exists "observability/prometheus/values-platform.yaml" "Prometheus values"
assert_file_exists "observability/prometheus/platform-rules/crossplane-alerts.yaml" "Crossplane alerts"
assert_file_exists "observability/prometheus/platform-rules/claim-latency.yaml" "Claim latency alerts"
assert_file_exists "observability/prometheus/platform-rules/drift-detection.yaml" "Drift detection alerts"
assert_file_exists "observability/prometheus/service-monitors/crossplane.yaml" "Crossplane ServiceMonitor"
assert_file_exists "observability/prometheus/service-monitors/argocd.yaml" "ArgoCD ServiceMonitor"
assert_file_exists "observability/prometheus/service-monitors/kyverno.yaml" "Kyverno ServiceMonitor"
assert_file_exists "observability/opencost/values-platform.yaml" "OpenCost values"
DASHBOARDS=("platform-overview" "claim-lifecycle" "policy-violations" "cost-per-team" "shadow-metrics")
for dash in "${DASHBOARDS[@]}"; do
    assert_file_exists "observability/grafana/dashboards/${dash}.json" "Dashboard: ${dash}"
done

# --- Bootstrap ---
echo ""
echo "--- Bootstrap ---"
assert_file_exists "bootstrap/install.sh" "Bootstrap script"
for cloud in "${CLOUDS[@]}"; do
    assert_file_exists "bootstrap/providers/${cloud}.yaml" "Provider: ${cloud}"
done

# --- Documentation ---
echo ""
echo "--- Documentation ---"
DOCS=("architecture" "semantic-gap" "shadow-metrics" "policy-promotion" "composition-drift" "why-kyverno")
for doc in "${DOCS[@]}"; do
    assert_file_exists "docs/${doc}.md" "Doc: ${doc}"
done

# --- Backstage Portal ---
echo ""
echo "--- Backstage Portal ---"
assert_dir_exists "portal/backstage/templates" "Backstage templates dir"
assert_file_exists "portal/backstage/app-config.yaml" "Backstage app-config"
assert_file_exists "portal/backstage/catalog-info.yaml" "Backstage catalog"
assert_file_exists "portal/backstage/templates/all-templates.yaml" "All templates index"
TEMPLATES=("database-claim" "cache-claim" "queue-claim" "storage-claim" "cdn-claim" "full-service")
for tmpl in "${TEMPLATES[@]}"; do
    assert_file_exists "portal/backstage/templates/${tmpl}/template.yaml" "Template: ${tmpl}"
done

# --- CLI ---
echo ""
echo "--- CLI ---"
assert_dir_exists "cli/cmd" "CLI cmd dir"
assert_dir_exists "cli/pkg/claim" "CLI claim package"
assert_dir_exists "cli/pkg/git" "CLI git package"
assert_dir_exists "cli/pkg/xrd" "CLI xrd package"
assert_file_exists "cli/go.mod" "Go module file"

# --- Project Config ---
echo ""
echo "--- Project Config ---"
assert_file_exists ".editorconfig" "EditorConfig"
assert_file_exists "requirements.txt" "Python requirements"
assert_dir_exists "docs/plans" "Archived plans dir"

print_results "STRUCTURE TESTS"
