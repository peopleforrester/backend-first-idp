# Backend-First IDP v2 — Unified Implementation Plan

## Overview

Transform the v1 reference architecture (clean but shallow) into a production-validated
blueprint that substantiates every claim in the KubeCon EU 2026 abstract. The v1 repo
has 1 XRD, 3 compositions, OPA policies, and a demo script. The v2 repo will have 7 XRDs,
21 compositions, Kyverno CEL policies, 12 teams with 100+ claims, full observability
(OTel + Prometheus + OpenCost), Shadow Metrics, policy promotion pipeline, composition
drift detection, and External Secrets Operator integration.

**Branch:** `v2-rebuild` (v1 preserved on `staging`/`main`)
**Talk delivery:** March 23, 2026

---

## Version Manifest (Verified March 22, 2026)

| Component | V1 Version | V2 Target | Notes |
|-----------|-----------|-----------|-------|
| Crossplane | 1.17 (Helm) | **v2.1.x** | Major jump. Namespaced XRs, no native P&T. |
| ArgoCD | v2.13.3 | **v3.3.4** | Server-side apply required, new RBAC model. |
| OPA/Gatekeeper | 3.18 | **Remove** | Replaced by Kyverno. |
| Kyverno | N/A | **1.17.1** (chart 3.7.1) | CEL policies v1-promoted. CNCF Graduated. |
| External Secrets Operator | N/A | **v2.0.1** (chart 2.2.0) | Secrets management gap. |
| OpenTelemetry Collector | N/A | **v0.147.0** | Operator with v1beta1 CRs. |
| OpenCost | N/A | **Helm latest** | CNCF Incubating. MCP server built in. |
| Prometheus | N/A | **kube-prometheus-stack** | Required by OpenCost and OTel. |
| Upbound Providers | v1.17.0 | **v1.17.0** (keep) | Current. |
| function-patch-and-transform | v0.7.0 | **v0.9.0+** | Check Upbound marketplace. |

---

## Dependency Graph

```
Phase 0 (scaffold + tooling reset)
  │
  ├──▶ Phase 1 (Crossplane v2 XRDs — 7 types)
  │      │
  │      ├──▶ Phase 2 (compositions — 21 files, 3 sub-phases)
  │      │      │
  │      │      └──▶ Phase 9 (kustomize overlays — cloud + environment)
  │      │
  │      ├──▶ Phase 4 (teams + 100+ claims + generator script)
  │      │
  │      └──▶ Phase 12 (golden path examples update)
  │
  ├──▶ Phase 3 (Kyverno CEL policies — 6 cluster policies)
  │      │
  │      └──▶ Phase 8 (policy promotion pipeline — dev/staging/prod)
  │
  ├──▶ Phase 5 (External Secrets Operator)
  │
  ├──▶ Phase 6 (observability — OTel + Prometheus + OpenCost + Grafana)
  │      │
  │      ├──▶ Phase 7 (Shadow Metrics — CRD + rules + dashboards)
  │      │
  │      └──▶ Phase 10 (composition drift detection)
  │
  ├──▶ Phase 11 (ArgoCD v3 migration)
  │
  └──▶ Phase 13 (bootstrap rewrite — 12-step install)

Phase 14 (documentation rewrite) — depends on everything
Phase 15 (CI pipeline + GitHub repo polish) — depends on everything
Phase 16 (full integration test) — depends on everything
```

Critical paths:
- **Scale path:** 0 → 1 → 2 → 4 → 12 → 16
- **Policy path:** 0 → 3 → 8 → 14
- **Shadow Metrics path:** 0 → 6 → 7 → 14

Phases 2, 3, 5, 6, and 11 can build in parallel after Phase 0+1.

---

## Phase 0: Scaffolding & Test Tooling Reset

**Goal:** Strip OPA/Gatekeeper, install Kyverno CLI, rebuild test harness for v2.

### Steps

1. Create `v2-rebuild` branch from current staging
2. Remove `policies/opa/` and `policies/gatekeeper/` entirely
3. Remove `tests/opa_test.sh` and OPA references from Makefile/validate.sh
4. Install Kyverno CLI v1.17.1
5. Create new test scripts:
   - `tests/kyverno_test.sh` — Kyverno CLI apply tests
   - `tests/observability_test.sh` — OTel/Prometheus manifest validation
   - `tests/eso_test.sh` — ESO manifest validation
   - `tests/scale_test.sh` — 100+ claims existence and validity
6. Rewrite `tests/structure_test.sh` for the v2 file tree
7. Update Makefile with all new targets:
   ```
   test: test-yaml test-shell test-kyverno test-xrd test-compositions
         test-golden-path test-structure test-observability test-eso test-scale
   ```
8. Update `.yamllint.yml` if needed (current config is fine)

**TDD:** Structure test should show ~200+ failures (the red state for v2).

**Commit:** `"Phase 0: Strip OPA/Gatekeeper, scaffold Kyverno + v2 test structure"`

---

## Phase 1: Crossplane v2 XRDs — 7 Resource Types

**Goal:** Migrate existing XRD to v2 API and add 6 new resource types.

### Crossplane v2 Key Changes
- apiVersion: `apiextensions.crossplane.io/v2` (or keep v1 with LegacyCluster scope)
- Namespaced XRs replace claims (but LegacyCluster preserves claim workflow for demo)
- Native P&T removed — Pipeline mode required (repo already uses Pipeline, no change)

### XRDs to Create

```
platform-api/xrds/
├── database-instance.yaml        # Existing — migrate to v2, keep all fields
├── cache-instance.yaml           # Redis/Memcached. Fields: size, region, team, engine (redis/memcached), evictionPolicy
├── message-queue.yaml            # SQS/PubSub/ServiceBus. Fields: size, region, team, messageRetentionDays, fifo (bool)
├── object-storage.yaml           # S3/GCS/Blob. Fields: region, team, versioning (bool), lifecycleDays
├── cdn-distribution.yaml         # CloudFront/CloudCDN/FrontDoor. Fields: team, originDomain, cacheTtlSeconds
├── dns-record.yaml               # Route53/CloudDNS/AzureDNS. Fields: team, recordType, name, value, ttl
└── kubernetes-namespace.yaml     # Namespace + RBAC + Quota. Fields: team, cpuLimit, memoryLimit
```

All XRDs share: group `platform.kubecon.io`, version `v1alpha1`, `team` required field.

### TDD
1. Write `tests/xrd_test.sh` asserting all 7 XRDs have correct group, version, names, team field
2. Run test → expect FAIL (only 1 XRD exists, needs migration)
3. Create all 7 XRDs
4. Run test → expect PASS

**Commit:** `"Phase 1: Crossplane v2 XRDs — 7 resource types for multi-resource platform"`

---

## Phase 2: Compositions — 21 Files Across 3 Clouds

**Goal:** Create compositions for all 7 XRD types × 3 clouds = 21 composition files.

### Structure
```
platform-api/compositions/
├── aws/
│   ├── database-small.yaml       # Existing (update for v2)
│   ├── cache-small.yaml          # ElastiCache Redis
│   ├── message-queue-small.yaml  # SQS + SNS
│   ├── object-storage.yaml       # S3 + bucket policy
│   ├── cdn-distribution.yaml     # CloudFront
│   ├── dns-record.yaml           # Route53
│   └── namespace.yaml            # Namespace + RBAC + ResourceQuota
├── gcp/
│   ├── database-small.yaml       # Existing (update for v2)
│   ├── cache-small.yaml          # Memorystore Redis
│   ├── message-queue-small.yaml  # Pub/Sub topic + subscription
│   ├── object-storage.yaml       # GCS bucket
│   ├── cdn-distribution.yaml     # Cloud CDN + backend bucket
│   ├── dns-record.yaml           # Cloud DNS
│   └── namespace.yaml            # Namespace + RBAC + ResourceQuota
└── azure/
    ├── database-small.yaml       # Existing (update for v2)
    ├── cache-small.yaml          # Azure Cache for Redis
    ├── message-queue-small.yaml  # Service Bus
    ├── object-storage.yaml       # Blob Storage
    ├── cdn-distribution.yaml     # Azure Front Door
    ├── dns-record.yaml           # Azure DNS
    └── namespace.yaml            # Namespace + RBAC + ResourceQuota
```

### Notes
- Namespace composition uses Kubernetes provider, not cloud provider
- Existing database compositions need v2 compositeTypeRef update
- Keep compositions structurally complete but don't over-engineer — breadth over depth

### TDD
1. Extend `tests/composition_test.sh` to validate all 21 files
2. Build per cloud: AWS first, GCP second, Azure third
3. Each cloud is a sub-commit

**Commits:**
- `"Phase 2a: AWS compositions — 7 resource types"`
- `"Phase 2b: GCP compositions — 7 resource types"`
- `"Phase 2c: Azure compositions — 7 resource types"`

---

## Phase 3: Kyverno CEL Policies — Replacing OPA/Gatekeeper

**Goal:** 6 cluster policies using Kyverno 1.17 CEL expressions (v1 promoted).

### Why Kyverno Over OPA in 2026
- CEL is the Kubernetes-native expression language (Gateway API, ValidatingAdmissionPolicy)
- Kyverno CNCF Graduated since 2024
- No separate policy language — lower barrier for platform consumers
- Built-in policy reporting, no separate audit infrastructure

### Policies
```
policies/kyverno/
├── cluster-policies/
│   ├── region-enforcement.yaml        # Team→region mapping (PCI-DSS)
│   ├── size-caps.yaml                 # Per-team size limits
│   ├── required-labels.yaml           # All claims must have team label
│   ├── naming-conventions.yaml        # Claim names must follow {team}-{resource} pattern
│   ├── backup-retention-minimum.yaml  # Production claims need ≥7 day backups
│   └── ha-enforcement.yaml            # Production namespaces require HA=true
├── policy-exceptions/
│   └── platform-team-exceptions.yaml  # Platform team overrides
└── policy-tests/
    ├── region-enforcement/
    │   ├── resource-pass.yaml         # checkout + eu-west-1 = allow
    │   └── resource-fail.yaml         # checkout + us-west-2 = deny
    ├── size-caps/
    │   ├── resource-pass.yaml
    │   └── resource-fail.yaml
    └── ... (tests for each policy)
```

### Semantic Gap
- Preserve the semantic gap commentary as a Kyverno annotation on size-caps policy
- Also create standalone `docs/semantic-gap.md`

### TDD
1. Write `tests/kyverno_test.sh` using `kyverno apply` CLI
2. Create test resources (pass/fail) before policies
3. Write policies that make tests green

**Commit:** `"Phase 3: Kyverno CEL policies — 6 cluster policies replacing OPA/Gatekeeper"`

---

## Phase 4: Teams Directory & 100+ Service Claims

**Goal:** Create 12 teams with 100+ claims, substantiating the "100+ service environment."

### Teams
```
teams/
├── checkout/claims/       # 5 claims (db, cache, events, assets, cdn)
├── payments/claims/       # 6 claims (db, ledger-db, cache, events, audit-storage, receipts-cdn)
├── analytics/claims/      # 5 claims (warehouse-db, cache, events, datalake, reports-cdn)
├── platform/claims/       # 4 claims (db, cache, events, state-storage)
├── identity/claims/       # 4 claims (auth-db, session-cache, token-events, keys-storage)
├── catalog/claims/        # 5 claims (db, search-cache, product-events, image-storage, cdn)
├── shipping/claims/       # 4 claims (db, tracking-cache, events, label-storage)
├── notifications/claims/  # 3 claims (db, template-cache, events)
├── inventory/claims/      # 3 claims (db, stock-cache, events)
├── search/claims/         # 3 claims (db, cache, index-storage)
├── billing/claims/        # 3 claims (db, invoice-storage, events)
└── marketing/claims/      # 4 claims (db, campaign-cache, assets-storage, cdn)
Each team also gets a namespace.yaml claim.
```

### Steps
1. Create `scripts/generate-team-claims.py` — reads a team manifest, generates all claim YAML
2. Create `scripts/teams.yaml` — defines all 12 teams, their allowed regions, resources
3. Run generator to produce 100+ claim files
4. Each claim must pass yamllint and Kyverno validation

### TDD
- `tests/scale_test.sh`: assert ≥100 claims, all valid YAML, all have team field,
  all reference known apiVersion, none violate Kyverno policies

**Commit:** `"Phase 4: 12 teams, 100+ service claims — substantiating the scale claim"`

---

## Phase 5: External Secrets Operator Integration

**Goal:** Add ESO manifests for secrets management (critical production gap).

### Structure
```
secrets/
├── eso/
│   ├── cluster-secret-store-aws.yaml     # AWS Secrets Manager (IRSA auth)
│   ├── cluster-secret-store-gcp.yaml     # GCP Secret Manager (WI auth)
│   ├── cluster-secret-store-azure.yaml   # Azure Key Vault (OIDC auth)
│   └── external-secrets/
│       ├── database-credentials.yaml     # Template for DB connection secrets
│       ├── provider-credentials.yaml     # Crossplane provider auth
│       └── tls-certificates.yaml         # Platform TLS certs
```

### TDD
- `tests/eso_test.sh`: validate YAML, correct apiVersion (`external-secrets.io/v1`),
  correct SecretStore references

**Commit:** `"Phase 5: External Secrets Operator — closing the secrets management gap"`

---

## Phase 6: Observability Stack — OTel + Prometheus + OpenCost

**Goal:** The infrastructure that makes Shadow Metrics possible.

### Structure
```
observability/
├── opentelemetry/
│   ├── collector-agent.yaml        # DaemonSet (OTel Operator v1beta1 CR)
│   ├── collector-gateway.yaml      # Deployment (aggregation)
│   ├── instrumentation.yaml        # Auto-instrumentation CR
│   └── rbac.yaml                   # ServiceAccount + ClusterRole
├── prometheus/
│   ├── values-platform.yaml        # Helm values for kube-prometheus-stack
│   ├── platform-rules/
│   │   ├── crossplane-alerts.yaml  # PrometheusRule for Crossplane health
│   │   ├── claim-latency.yaml      # Claim provisioning time alerts
│   │   └── drift-detection.yaml    # ArgoCD sync drift alerts
│   └── service-monitors/
│       ├── crossplane.yaml         # ServiceMonitor for Crossplane
│       ├── argocd.yaml             # ServiceMonitor for ArgoCD
│       └── kyverno.yaml            # ServiceMonitor for Kyverno
├── opencost/
│   ├── values-platform.yaml        # Helm values
│   └── cost-allocation/
│       └── team-labels.yaml        # Label-based cost allocation config
└── grafana/
    └── dashboards/
        ├── platform-overview.json  # Platform health
        ├── claim-lifecycle.json    # Provisioning latency by type/cloud/team
        ├── policy-violations.json  # Kyverno violation trends
        └── cost-per-team.json      # OpenCost team cost breakdown
```

### OTel Collector Config
- Receivers: OTLP, Prometheus, k8s_cluster
- Processors: batch, memory_limiter, k8sattributes, resource
- Exporters: prometheus (for scraping), otlp (for backends)

### TDD
- `tests/observability_test.sh`: validate OTel CRs have correct apiVersion (v1beta1),
  PrometheusRule structure, Grafana JSON parseable, OpenCost values exist

**Commit:** `"Phase 6: Observability stack — OTel + Prometheus + OpenCost + Grafana"`

---

## Phase 7: Shadow Metrics — Closing the Semantic Gap

**Goal:** Turn the semantic gap from philosophy into an operational mechanism.

A shadow metric is a runtime measurement evaluating whether a *valid* claim is *correct*
for its workload. It doesn't block — it annotates with risk signals.

### Structure
```
platform-api/shadow-metrics/
├── README.md                          # Concept documentation
├── shadow-metric-crd.yaml             # CRD: ShadowMetricRule
├── rules/
│   ├── database-sizing.yaml           # Is this DB size right for traffic?
│   ├── region-latency.yaml            # Is this region optimal for users?
│   ├── cost-efficiency.yaml           # Is this the cheapest viable option?
│   └── ha-requirement.yaml            # Should this be HA based on SLO?
└── functions/
    └── function-shadow-metrics.yaml   # Crossplane function evaluating rules
```

### ShadowMetricRule CRD
```yaml
apiVersion: platform.kubecon.io/v1alpha1
kind: ShadowMetricRule
metadata:
  name: database-sizing-check
spec:
  applies_to:
    - kind: DatabaseInstanceClaim
  check:
    name: "right-sized"
    prometheus_query: |
      sum(rate(http_requests_total{namespace="${claim.metadata.namespace}"}[24h]))
    thresholds:
      - when: "> 10000"
        size_should_be: "medium"
        message: "Traffic exceeds 10k req/day — small may be undersized"
      - when: "> 100000"
        size_should_be: "large"
        message: "Traffic exceeds 100k req/day — medium will hit connection limits"
  action: annotate
  annotation_key: "platform.kubecon.io/shadow-metric-sizing"
```

### Additional Artifacts
- Prometheus recording rule pre-computing shadow metric scores per namespace
- Grafana dashboard (`dashboards/shadow-metrics.json`) showing flagged claims
- Update DEMO.md with Shadow Metrics beat after semantic gap pivot

**Commit:** `"Phase 7: Shadow Metrics — closing the semantic gap with runtime validation"`

---

## Phase 8: Policy Promotion Pipeline

**Goal:** Substantiate "how policy is authored, bundled, and promoted."

### Structure
```
policies/kyverno/promotion/
├── dev/kustomization.yaml           # All policies in Audit mode
├── staging/kustomization.yaml       # Region/size Enforce, others Audit
├── production/kustomization.yaml    # All policies Enforce
├── policy-reporter.yaml             # Kyverno PolicyReport aggregation
└── kustomization.yaml               # Base for promotion stages
```

### Steps
1. Create Kustomize overlays patching `validationFailureAction` per environment
2. Create ArgoCD ApplicationSet for policy promotion (cluster env label → overlay)
3. Add PolicyReport Grafana dashboard
4. Document in `docs/policy-promotion.md`

**Commit:** `"Phase 8: Policy promotion pipeline — dev → staging → production"`

---

## Phase 9: Kustomize Overlays Update

**Goal:** Full cloud + environment overlay matrix.

### Structure
```
gitops/kustomize/
├── base/kustomization.yaml              # All XRDs + Kyverno policies
├── overlays/
│   ├── aws/kustomization.yaml           # All AWS compositions
│   ├── gcp/kustomization.yaml           # All GCP compositions
│   ├── azure/kustomization.yaml         # All Azure compositions
│   ├── dev/kustomization.yaml           # Dev patches (Kyverno Audit)
│   ├── staging/kustomization.yaml       # Staging patches
│   └── production/kustomization.yaml    # Prod patches (HA, backup minimums)
```

**Commit:** `"Phase 9: Kustomize — cloud overlays + environment overlays"`

---

## Phase 10: Composition Drift Detection

**Goal:** Address "Composition Sprawl" (Chapter 2, Angle 2).

### Structure
```
platform-api/drift-detection/
├── composition-hash-configmap.yaml    # Expected hashes from Git
├── drift-check-cronjob.yaml           # CronJob comparing live vs git
├── scripts/
│   └── check-drift.sh                 # Compare and report script
└── prometheus-rule-drift.yaml         # Alert on drift detected
```

### Steps
1. CronJob hashes live compositions, compares against ConfigMap
2. Prometheus custom metric `platform_composition_drift_detected`
3. Alert rule fires on drift
4. Document in `docs/composition-drift.md`

**Commit:** `"Phase 10: Composition drift detection — CronJob + Prometheus alerting"`

---

## Phase 11: ArgoCD v3 Migration

**Goal:** Update all ArgoCD manifests to v3.3.4 conventions.

### Key v3 Changes
- `--server-side --force-conflicts` required for install
- Fine-grained RBAC no longer inherits to sub-resources
- `logs` RBAC enforced by default

### Steps
1. Update install command in bootstrap script
2. Add third ApplicationSet for policy promotion
3. Add fourth ApplicationSet for observability stack
4. Add RBAC configuration for team-scoped access
5. Verify goTemplate/goTemplateOptions still valid

**Commit:** `"Phase 11: ArgoCD v3.3.4 — server-side apply, policy AppSet, RBAC"`

---

## Phase 12: Golden Path Examples Update

**Goal:** Multi-resource examples + shadow metric demo.

### Files
```
golden-path/examples/
├── claim-database.yaml              # Keep the 9-line hero
├── claim-database-WILL-FAIL.yaml    # Now fails Kyverno (not OPA)
├── claim-cache.yaml                 # Working Redis claim
├── claim-message-queue.yaml         # Working SQS claim
├── claim-full-service.yaml          # Complete: DB + cache + queue + storage
└── claim-shadow-metric-warning.yaml # Passes policy, triggers shadow metric
```

Update `golden-path/templates/new-service/` with all resource types.

**Commit:** `"Phase 12: Golden path — multi-resource examples + shadow metric demo"`

---

## Phase 13: Bootstrap Script Rewrite

**Goal:** One command, full stack, 12-step install.

### Install Sequence
1. Pre-flight checks (kubectl, helm, cluster)
2. cert-manager (required by OTel Operator + Kyverno webhooks)
3. Crossplane v2.1
4. Crossplane functions (function-patch-and-transform v0.9.0+)
5. Cloud provider (aws/gcp/azure)
6. ArgoCD v3.3.4 (server-side apply)
7. Kyverno 1.17.1 (chart 3.7.1)
8. External Secrets Operator v2.0.1 (chart 2.2.0)
9. OpenTelemetry Operator
10. kube-prometheus-stack (Prometheus + Grafana)
11. OpenCost
12. Apply platform resources (XRDs, compositions, policies, OTel, dashboards)

### Flags
- `--provider aws|gcp|azure` (required)
- `--dry-run` (print what would be installed)
- `--skip-observability` (lightweight install)

**Commit:** `"Phase 13: Bootstrap rewrite — 12-step install, full stack, version-pinned"`

---

## Phase 14: Documentation Rewrite

### Files
1. **README.md** — full stack architecture diagram, version table, quick start, 12 teams/100+ services, Shadow Metrics section
2. **DEMO.md** — 6 beats now:
   - Beat 1: Golden Path (9-line claim)
   - Beat 2: Platform API (7 XRDs)
   - Beat 3: Three Clouds, One Claim (Crossplane v2)
   - Beat 4: Kyverno Guardrails → Semantic Gap
   - Beat 4.5: Shadow Metrics demo
   - Beat 5: One Command (12-step bootstrap)
   - Beat 6: Policy promotion (if time)
3. **docs/architecture.md** — full stack diagram
4. **docs/semantic-gap.md** — standalone concept document
5. **docs/shadow-metrics.md** — how shadow metrics work
6. **docs/policy-promotion.md** — dev → staging → production flow
7. **docs/composition-drift.md** — drift detection pattern
8. **docs/why-kyverno.md** — justification document
9. **CLAUDE.md** — updated project conventions
10. **PROJECT_STATE.md** — updated

**Commit:** `"Phase 14: Documentation rewrite — full stack, Shadow Metrics, Kyverno justification"`

---

## Phase 15: CI Pipeline + GitHub Repo Polish

**Goal:** Wire test suite to GitHub Actions, add repo discoverability.

### Steps
1. Create `.github/workflows/test.yml` running `make test` on every PR
2. Add GitHub repo topics:
   ```bash
   gh repo edit --add-topic crossplane,argocd,kyverno,platform-engineering,kubecon,internal-developer-platform,gitops,shadow-metrics
   ```
3. Add "What to try after cloning" section in README:
   - Read the claim → Read the XRD → Run `kyverno apply` on failing claim → Bootstrap on kind cluster
4. Verify connection secret wiring in compositions (writeConnectionSecretToRef)

**Commit:** `"Phase 15: CI pipeline + GitHub Actions + repo polish"`

---

## Phase 16: Full Integration Test

### Validation Checklist
- [ ] `make test` — all suites green
- [ ] ≥100 claim files under `teams/`
- [ ] All YAML passes yamllint
- [ ] All shell scripts pass shellcheck
- [ ] All Kyverno CLI tests pass
- [ ] All passing claims pass Kyverno, all failing claims fail
- [ ] Every file referenced in docs exists
- [ ] 300+ total assertions across all test suites

### Abstract Substantiation Matrix

| Abstract Claim | What Backs It |
|---------------|--------------|
| "Production-validated blueprint" | 7 XRDs, 21 compositions, 3 clouds, full observability, policy pipeline |
| "Multi-tenant, 100+ service environment" | 12 teams, 100+ claim files, 7 resource types |
| "Backend-first wins" | Zero portal code — everything is Git + CLI + API |
| "Cut lead time from days to minutes" | Golden path: 9 lines → provisioned (measurable via claim-latency dashboard) |
| "Eliminated portal-only snowflake workflows" | Zero portal code in entire repo |
| "Reduced GitOps drift incidents by 70%" | Drift detection + ArgoCD sync monitoring + alerting framework |
| "Policy authored, bundled, and promoted" | Kyverno + Kustomize + ArgoCD promotion pipeline |
| "Prevent composition drift and policy sprawl" | Drift CronJob + policy promotion overlays |

**Commit:** `"Phase 16: Full integration — all tests green, 100+ claims validated"`
**Merge v2-rebuild → staging → main.**

---

## Estimated Scope

| Phase | Files | Complexity |
|-------|-------|-----------|
| 0: Scaffolding | ~15 | Low |
| 1: XRDs (7) | 7 + tests | Medium |
| 2: Compositions (21) | 21 + tests | High (most YAML) |
| 3: Kyverno (6 policies) | 6 + 12 test resources | Medium |
| 4: Teams + 100+ claims | 100+ + generator script | Medium |
| 5: ESO | 6 manifests | Low |
| 6: Observability | 15+ manifests + 4 dashboards | High |
| 7: Shadow Metrics | CRD + 4 rules + dashboard | High (novel) |
| 8: Policy promotion | 3 overlays + AppSet + docs | Medium |
| 9: Kustomize | 8 overlays | Low |
| 10: Drift detection | CronJob + script + alert | Medium |
| 11: ArgoCD v3 | 3 files | Low |
| 12: Golden path | 6 examples | Low |
| 13: Bootstrap rewrite | 1 large script | Medium |
| 14: Documentation | 10+ docs | Medium |
| 15: CI + polish | 2-3 files | Low |
| 16: Integration | Tests | Low |

**Total files:** ~200+
**Total commits:** ~20
