#!/usr/bin/env bash
# ABOUTME: Composition drift detection — compares live compositions against git hashes.
# ABOUTME: Run by CronJob; pushes metrics to Prometheus pushgateway on drift.

set -euo pipefail

NAMESPACE="${NAMESPACE:-crossplane-system}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-composition-hashes}"
CONFIGMAP_NAMESPACE="${CONFIGMAP_NAMESPACE:-crossplane-system}"
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://prometheus-pushgateway.observability.svc.cluster.local:9091}"

echo "=== Composition Drift Check ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Get expected hashes from ConfigMap
echo "Reading expected hashes from ${CONFIGMAP_NAMESPACE}/${CONFIGMAP_NAME}..."
EXPECTED_HASHES=$(kubectl get configmap "${CONFIGMAP_NAME}" \
    -n "${CONFIGMAP_NAMESPACE}" \
    -o jsonpath='{.data}' 2>/dev/null || echo "{}")

if [[ "${EXPECTED_HASHES}" == "{}" ]]; then
    echo "WARNING: No expected hashes found. Generating baseline..."

    # Generate baseline from live compositions
    HASH_DATA=""
    while IFS= read -r comp_name; do
        [[ -z "${comp_name}" ]] && continue
        hash=$(kubectl get composition "${comp_name}" -o yaml \
            | grep -v "resourceVersion\|uid\|creationTimestamp\|generation\|managedFields" \
            | sha256sum | cut -d' ' -f1)
        HASH_DATA="${HASH_DATA}    ${comp_name}: ${hash}\n"
    done < <(kubectl get compositions -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

    # Create the ConfigMap
    kubectl create configmap "${CONFIGMAP_NAME}" \
        -n "${CONFIGMAP_NAMESPACE}" \
        --from-literal="generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "Baseline generated. Next run will detect drift."
    exit 0
fi

# Compare live compositions against expected hashes
DRIFT_COUNT=0
TOTAL_CHECKED=0

while IFS= read -r comp_name; do
    [[ -z "${comp_name}" ]] && continue
    ((TOTAL_CHECKED++)) || true

    live_hash=$(kubectl get composition "${comp_name}" -o yaml \
        | grep -v "resourceVersion\|uid\|creationTimestamp\|generation\|managedFields" \
        | sha256sum | cut -d' ' -f1)

    expected_hash=$(echo "${EXPECTED_HASHES}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('${comp_name}', 'MISSING'))
" 2>/dev/null || echo "MISSING")

    if [[ "${live_hash}" != "${expected_hash}" ]]; then
        echo "DRIFT DETECTED: ${comp_name}"
        echo "  Expected: ${expected_hash}"
        echo "  Live:     ${live_hash}"
        ((DRIFT_COUNT++)) || true
    fi
done < <(kubectl get compositions -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

echo ""
echo "Checked: ${TOTAL_CHECKED} compositions"
echo "Drifted: ${DRIFT_COUNT}"

# Push metrics to Prometheus pushgateway
cat <<METRICS | curl -s --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/composition-drift-check"
# HELP platform_composition_drift_detected Number of compositions that have drifted from git
# TYPE platform_composition_drift_detected gauge
platform_composition_drift_detected ${DRIFT_COUNT}
# HELP platform_composition_total Total compositions checked
# TYPE platform_composition_total gauge
platform_composition_total ${TOTAL_CHECKED}
# HELP platform_composition_drift_check_timestamp_seconds Last drift check timestamp
# TYPE platform_composition_drift_check_timestamp_seconds gauge
platform_composition_drift_check_timestamp_seconds $(date +%s)
METRICS

echo ""
if [[ ${DRIFT_COUNT} -gt 0 ]]; then
    echo "WARNING: ${DRIFT_COUNT} composition(s) have drifted from expected state."
    exit 1
else
    echo "OK: All compositions match expected state."
    exit 0
fi
