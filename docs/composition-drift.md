# Composition Drift Detection

## The Problem

When multiple teams extend the platform API, compositions can drift
from their git-committed state through:

- Manual `kubectl edit` on live compositions
- Failed ArgoCD syncs that leave partial state
- Version skew between clusters
- Emergency hotfixes that bypass GitOps

Drift means the live platform behavior no longer matches what's in git.
This breaks the GitOps contract and makes the repo an unreliable source
of truth.

## The Solution

A CronJob runs every 15 minutes, hashes every live composition, and
compares against expected hashes stored in a ConfigMap. Drift count
is pushed to Prometheus, which fires alerts.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│  CronJob         │────▶│  kubectl get     │
│  (every 15m)     │     │  compositions    │
└──────────────────┘     └────────┬─────────┘
                                  │ hash each
                                  ▼
                         ┌──────────────────┐
                         │  Compare against │
                         │  ConfigMap hashes│
                         └────────┬─────────┘
                                  │
                         ┌────────▼─────────┐
                         │  Push metric to  │
                         │  Pushgateway     │
                         └────────┬─────────┘
                                  │
                         ┌────────▼─────────┐
                         │  Prometheus      │
                         │  Alert Rule      │
                         │  (if drift > 0)  │
                         └──────────────────┘
```

## Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `platform_composition_drift_detected` | gauge | Number of drifted compositions |
| `platform_composition_total` | gauge | Total compositions checked |
| `platform_composition_drift_check_timestamp_seconds` | gauge | Last check timestamp |

## Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| CompositionDriftDetected | drift > 0 for 5m | warning |
| CompositionDriftCheckStale | no check in 30m | warning |

## Responding to Drift

1. Check which compositions drifted: review CronJob logs
2. Compare live vs git: `kubectl get composition <name> -o yaml`
3. If intentional (hotfix): update git to match, regenerate hashes
4. If unintentional: force ArgoCD sync to restore git state
5. Investigate root cause: who edited, when, why

## Files

- `platform-api/drift-detection/drift-check-cronjob.yaml` — CronJob + RBAC
- `platform-api/drift-detection/scripts/check-drift.sh` — standalone script
- `platform-api/drift-detection/prometheus-rule-drift.yaml` — alert rules
