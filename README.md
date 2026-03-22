# Backend-First IDP

**Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice**

Reference architecture for KubeCon EU 2026 — Platform Engineering Zero Day.

> Portal-first IDPs fail at scale. Build the automation, guardrails, and GitOps
> pipelines first. The portal is optional.

## Architecture

```
  Developer           GitOps            Admission          Platform API         Cloud
  ┌──────────┐      ┌──────────┐      ┌───────────┐      ┌─────────────┐      ┌───────┐
  │  9-line  │─git─▶│  ArgoCD  │─sync▶│  Kyverno  │─ok──▶│  Crossplane │─────▶│  AWS  │
  │  claim   │ push │  v3 App  │      │  CEL      │      │  v2 XRD +   │      │  GCP  │
  │          │      │  Sets    │      │  Policies │      │  Pipeline   │      │ Azure │
  └──────────┘      └──────────┘      └───────────┘      │ Compositions│      └───────┘
                                            │             └─────────────┘
                                            │                    │
                                      ┌─────▼─────┐      ┌──────▼──────┐
                                      │  Policy   │      │   Shadow    │
                                      │ Promotion │      │   Metrics   │
                                      │ dev→prod  │      │  (runtime)  │
                                      └───────────┘      └─────────────┘
```

A developer writes a 9-line claim. ArgoCD syncs it. Kyverno validates against
CEL policies (region restrictions, size caps, naming, HA, backups). Crossplane
provisions the right cloud resources. Shadow Metrics evaluate whether the valid
configuration is actually correct for the workload. No portal needed.

## What's in This Repo

- **7 XRDs** — Database, Cache, Message Queue, Object Storage, CDN, DNS, Namespace
- **21 Compositions** — 7 resource types × 3 clouds (AWS, GCP, Azure)
- **6 Kyverno Policies** — Region enforcement (PCI-DSS), size caps, labels, naming, backup retention, HA
- **Policy Promotion Pipeline** — dev (Audit) → staging (mixed) → production (Enforce)
- **12 Teams, 109 Claims** — Realistic "100+ service environment"
- **Shadow Metrics** — CRD + 4 rules closing the semantic gap between "valid" and "correct"
- **Full Observability** — OpenTelemetry, Prometheus, OpenCost, 5 Grafana dashboards
- **Composition Drift Detection** — CronJob + Prometheus alerting
- **External Secrets Operator** — ClusterSecretStores for AWS/GCP/Azure
- **One-Command Bootstrap** — `./bootstrap/install.sh --provider aws`

See [docs/architecture.md](docs/architecture.md) for the full architecture breakdown.

## Quick Start

```bash
# Clone the repo
git clone git@github.com:peopleforrester/backend-first-idp.git
cd backend-first-idp

# Preview what would be installed (dry run)
./bootstrap/install.sh --provider aws --dry-run

# Bootstrap the full platform
./bootstrap/install.sh --provider aws    # or gcp, or azure

# Lightweight install (skip observability stack)
./bootstrap/install.sh --provider aws --skip-observability

# Submit a database claim
kubectl apply -f golden-path/examples/claim-database.yaml

# Watch it provision
kubectl get databaseinstanceclaim -w

# Try a full service (DB + cache + queue + storage)
kubectl apply -f golden-path/examples/claim-full-service.yaml

# See what happens when you break the rules
kubectl apply -f golden-path/examples/claim-database-WILL-FAIL.yaml
```

## Repository Structure

```
backend-first-idp/
├── platform-api/
│   ├── xrds/                    # 7 CompositeResourceDefinitions
│   ├── compositions/            # 21 cloud-specific implementations
│   │   ├── aws/                 #   RDS, ElastiCache, SQS, S3, CloudFront, Route53, NS
│   │   ├── gcp/                 #   Cloud SQL, Memorystore, Pub/Sub, GCS, Cloud CDN, DNS, NS
│   │   └── azure/               #   FlexibleServer, Redis Cache, Service Bus, Blob, Front Door, DNS, NS
│   ├── shadow-metrics/          # ShadowMetricRule CRD + 4 runtime validation rules
│   └── drift-detection/         # Composition drift CronJob + Prometheus alerting
├── policies/
│   └── kyverno/
│       ├── cluster-policies/    # 6 CEL policies (region, size, labels, naming, backup, HA)
│       ├── policy-exceptions/   # Platform team overrides
│       ├── policy-tests/        # Pass/fail test resources per policy
│       └── promotion/           # dev → staging → production overlays
├── gitops/
│   ├── argocd/                  # 4 ApplicationSets + team RBAC
│   └── kustomize/               # Base + cloud overlays + environment overlays
├── golden-path/
│   ├── examples/                # 6 claim examples (working, failing, shadow metric)
│   └── templates/               # Service scaffold with all 7 resource types
├── teams/                       # 12 teams, 109 claims (generated)
├── secrets/
│   └── eso/                     # ClusterSecretStores + ExternalSecret templates
├── observability/
│   ├── opentelemetry/           # Collector agents + gateway + instrumentation
│   ├── prometheus/              # Rules, ServiceMonitors, Helm values
│   ├── opencost/                # Cost allocation by team label
│   └── grafana/dashboards/      # 5 JSON dashboards
├── bootstrap/
│   ├── install.sh               # 12-step one-command setup
│   └── providers/               # AWS (IRSA), GCP (WI), Azure (OIDC)
├── scripts/                     # Team claim generator
├── tests/                       # 10 test suites
├── docs/                        # Architecture, Shadow Metrics, Kyverno, drift detection
└── DEMO.md                      # On-stage walkthrough (6 beats, ~10 min)
```

## Multi-Cloud Support

The same claim works across all three clouds:

| Field | AWS | GCP | Azure |
|-------|-----|-----|-------|
| **eu-west-1** | eu-west-1 | europe-west1 | westeurope |
| **eu-central-1** | eu-central-1 | europe-west3 | germanywestcentral |
| **us-east-1** | us-east-1 | us-east1 | eastus |
| **us-west-2** | us-west-2 | us-west1 | westus2 |

| Size | AWS (DB) | GCP (DB) | Azure (DB) |
|------|----------|----------|------------|
| **small** | db.t4g.medium | db-custom-2-4096 | B_Standard_B2s |
| **medium** | db.t4g.large | db-custom-4-8192 | GP_Standard_D2ds_v4 |
| **large** | db.r6g.xlarge | db-custom-8-32768 | GP_Standard_D4ds_v4 |

## The Golden Path

What developers interact with — a single claim:

```yaml
apiVersion: platform.kubecon.io/v1alpha1
kind: DatabaseInstanceClaim
metadata:
  name: checkout-db
  namespace: checkout
spec:
  size: small
  region: eu-west-1
  team: checkout
```

Nine lines. That's the entire developer interface. Everything else is platform.

## Policy Enforcement

6 Kyverno CEL policies enforce team-level guardrails at admission time:

| Policy | What It Enforces | Severity |
|--------|-----------------|----------|
| Region enforcement | checkout/payments EU-only (PCI-DSS) | High |
| Size caps | checkout/analytics capped at medium | Medium |
| Required labels | All claims must have `team` label | Medium |
| Naming conventions | Names must start with team name | Low |
| Backup retention | Prod DBs need ≥7 day backups | High |
| HA enforcement | Prod DBs must enable HA | High |

Policies are promoted through environments: **dev** (Audit) → **staging** (mixed) → **production** (Enforce).

## Shadow Metrics — Closing the Semantic Gap

Policies validate what is _allowed_. Shadow Metrics validate what _makes sense_.

A claim that passes every Kyverno policy can still be wrong for the workload.
Shadow Metrics evaluate runtime data (traffic volume, latency percentiles,
utilization) and annotate claims with risk signals:

| Rule | What It Checks | Signal |
|------|---------------|--------|
| Database sizing | Is the DB size right for traffic? | Request rate |
| Region latency | Is the region optimal for users? | P95 latency |
| Cost efficiency | Is the resource over-provisioned? | CPU utilization |
| HA requirement | Should HA be enabled for this SLO? | Error rate |

See [docs/shadow-metrics.md](docs/shadow-metrics.md) and
[platform-api/shadow-metrics/README.md](platform-api/shadow-metrics/README.md).

## Version Manifest

| Component | Version | Notes |
|-----------|---------|-------|
| Crossplane | v2.1.0 | Namespaced XRs, Pipeline mode only |
| ArgoCD | v3.3.4 | Server-side apply, fine-grained RBAC |
| Kyverno | chart 3.7.1 | CEL policies v1-promoted |
| External Secrets Operator | chart 2.2.0 | IRSA/WI/OIDC auth |
| OpenTelemetry Operator | latest | v1beta1 Collector CRs |
| kube-prometheus-stack | chart 72.3.0 | Prometheus + Grafana |
| OpenCost | chart 1.46.0 | Team-label cost allocation |
| Upbound Providers | v1.17.0 | AWS, GCP, Azure |

## Testing

```bash
make test              # Run all 10 test suites
make test-yaml         # YAML lint (208 files)
make test-shell        # Shellcheck (13 scripts)
make test-kyverno      # Kyverno CLI policy tests (25 assertions)
make test-xrd          # XRD schema validation (150 assertions)
make test-compositions # Composition structure (231 assertions)
make test-golden-path  # Golden path examples (18 assertions)
make test-observability # OTel/Prometheus/Grafana (15 assertions)
make test-eso          # External Secrets (12 assertions)
make test-scale        # 100+ claims validation (5 assertions)
make test-structure    # File tree completeness
```

## What to Try After Cloning

1. **Read the golden path:** `golden-path/examples/claim-database.yaml` — 9 lines
2. **Read the XRD:** `platform-api/xrds/database-instance.yaml` — the API contract
3. **See three clouds:** Compare `platform-api/compositions/aws/database-small.yaml` vs `gcp/` vs `azure/`
4. **Test a policy violation:** `kyverno apply policies/kyverno/cluster-policies/region-enforcement.yaml --resource golden-path/examples/claim-database-WILL-FAIL.yaml`
5. **See the semantic gap:** Read the annotation on `policies/kyverno/cluster-policies/size-caps.yaml`
6. **Explore Shadow Metrics:** `platform-api/shadow-metrics/README.md`
7. **Bootstrap on a kind cluster:** `./bootstrap/install.sh --provider aws --dry-run`

## Demo

See [DEMO.md](DEMO.md) for the 6-beat on-stage walkthrough (~10 minutes).

## License

Apache 2.0 — see [LICENSE](LICENSE).
