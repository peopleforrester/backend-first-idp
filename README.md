# Backend-First IDP

**Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice**

Reference architecture for KubeCon EU 2026 — Platform Engineering Zero Day.

> Portal-first IDPs fail at scale. Build the automation, guardrails, and GitOps
> pipelines first. The portal is optional.

## Architecture

```
  Developer          GitOps           Admission         Platform API        Cloud
  ┌─────────┐      ┌─────────┐      ┌──────────┐      ┌────────────┐      ┌─────┐
  │ 9-line  │─git─▶│ ArgoCD  │─sync▶│Gatekeeper│─ok──▶│ Crossplane │─────▶│ AWS │
  │  claim  │ push │ AppSets │      │   OPA    │      │    XRD +   │      │ GCP │
  └─────────┘      └─────────┘      └──────────┘      │Compositions│      │Azure│
                                                       └────────────┘      └─────┘
```

A developer writes a 9-line claim. ArgoCD syncs it. Gatekeeper validates it
against OPA policies (region restrictions, size caps). Crossplane provisions
the right cloud resources through the matching composition. No portal needed.

See [docs/architecture.md](docs/architecture.md) for the full architecture
diagram and component breakdown.

## Quick Start

```bash
# Clone the repo
git clone git@github.com:peopleforrester/backend-first-idp.git
cd backend-first-idp

# Bootstrap the platform (pick your cloud)
./bootstrap/install.sh --provider aws    # or gcp, or azure

# Submit a database claim
kubectl apply -f golden-path/examples/claim-database.yaml

# Watch it provision
kubectl get databaseinstanceclaim -w
```

## Repository Structure

```
backend-first-idp/
├── platform-api/
│   ├── xrds/                    # CompositeResourceDefinitions (the API contract)
│   └── compositions/            # Cloud-specific implementations
│       ├── aws/                 #   RDS + IAM + SecurityGroup
│       ├── gcp/                 #   Cloud SQL + Database + User
│       └── azure/               #   FlexibleServer + Database
├── policies/
│   ├── opa/                     # Rego policies (region + size enforcement)
│   └── gatekeeper/              # ConstraintTemplate + Constraint
├── gitops/
│   ├── argocd/                  # ApplicationSets (platform + team claims)
│   └── kustomize/               # Base + per-cloud overlays
├── golden-path/
│   ├── examples/                # Working claim + deliberate failure
│   └── templates/               # Service scaffolding
├── bootstrap/
│   ├── install.sh               # One-command setup
│   └── providers/               # AWS (IRSA), GCP (WI), Azure (OIDC)
├── docs/                        # Architecture documentation
├── tests/                       # Validation test suite
├── DEMO.md                      # On-stage demo walkthrough (5 beats, ~8 min)
└── Makefile                     # make test / make lint / make validate
```

## Multi-Cloud Support

The same 9-line claim works across all three clouds:

| Field | AWS | GCP | Azure |
|-------|-----|-----|-------|
| **eu-west-1** | eu-west-1 | europe-west1 | westeurope |
| **eu-central-1** | eu-central-1 | europe-west3 | germanywestcentral |
| **us-east-1** | us-east-1 | us-east1 | eastus |
| **us-west-2** | us-west-2 | us-west1 | westus2 |
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

## Policy Enforcement

OPA policies enforce team-level guardrails at admission time:

- **Region restrictions:** checkout/payments EU-only (PCI-DSS), analytics US+EU, platform all
- **Size caps:** checkout capped at medium, payments/platform at large, analytics at medium

## The Semantic Gap

Policies validate what is _allowed_, not what _makes sense_. A valid claim
can still be wrong for the workload. See the comment block in
[`policies/opa/size-limits.rego`](policies/opa/size-limits.rego) for the
full discussion — this is the talk's transition to Shadow Metrics.

## Testing

```bash
make test          # Run all tests
make test-yaml     # YAML lint
make test-shell    # Shellcheck
make test-opa      # OPA policy unit tests (21 tests)
make test-xrd      # XRD schema validation (30 assertions)
make test-compositions  # Composition structure validation
make test-golden-path   # Golden path + OPA integration tests
make test-structure     # File tree completeness check
```

## Demo

See [DEMO.md](DEMO.md) for the 5-beat on-stage walkthrough (~8 minutes),
mapping to the slide sequence.

## License

Apache 2.0 — see [LICENSE](LICENSE).
