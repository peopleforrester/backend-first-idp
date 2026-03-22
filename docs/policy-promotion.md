# Policy Promotion Pipeline

## Overview

Kyverno policies are promoted through three environments using Kustomize
overlays, deployed by ArgoCD based on cluster `environment` labels.

## Environments

| Environment | Enforcement | Use Case |
|-------------|-------------|----------|
| **dev** | All Audit | Policy development — violations logged, nothing blocked |
| **staging** | Mixed | Pre-production — critical policies enforced, others audited |
| **production** | All Enforce | Full enforcement — violations blocked, exceptions required |

## Staging Enforcement Matrix

| Policy | Dev | Staging | Production |
|--------|-----|---------|------------|
| region-enforcement | Audit | **Enforce** | **Enforce** |
| size-caps | Audit | **Enforce** | **Enforce** |
| required-labels | Audit | Audit | **Enforce** |
| naming-conventions | Audit | Audit | **Enforce** |
| backup-retention-minimum | Audit | **Enforce** | **Enforce** |
| ha-enforcement | Audit | Audit | **Enforce** |

## How It Works

Each environment has a Kustomize overlay in `policies/kyverno/promotion/`
that patches `validationFailureAction` on each ClusterPolicy:

```
policies/kyverno/promotion/
├── dev/kustomization.yaml           # All → Audit
├── staging/kustomization.yaml       # Critical → Enforce, others → Audit
└── production/kustomization.yaml    # All → Enforce + PolicyExceptions
```

The ArgoCD `platform-policies` ApplicationSet selects the right overlay
based on the cluster's `environment` label:

```yaml
generators:
  - clusters:
      selector:
        matchLabels:
          environment: production  # → policies/kyverno/promotion/production/
```

## Adding a New Policy

1. Create the ClusterPolicy in `policies/kyverno/cluster-policies/`
2. Add test resources in `policies/kyverno/policy-tests/{name}/`
3. Run `make test-kyverno` to verify pass/fail behavior
4. Add the policy to all three promotion overlays
5. Commit and let ArgoCD deploy it (starts in Audit on dev)
6. Review PolicyReports on dev/staging before promoting to Enforce

## Exceptions

The `platform-team-exceptions.yaml` PolicyException grants the platform
team bypass on size caps and naming conventions. It's included only in
the production overlay.

Teams needing exceptions for specific claims should submit a
PolicyException CR via PR — reviewed by the platform team.
