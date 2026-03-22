# Architecture: Backend-First Internal Developer Platform

## Overview

This reference architecture implements a backend-first IDP using Crossplane,
ArgoCD, and OPA/Gatekeeper. The thesis: build automation, guardrails, and
GitOps pipelines first. The portal is optional.

## Architecture Diagram

```
                          ┌─────────────────────────────┐
                          │      Developer Interface     │
                          │                              │
                          │   9-line YAML claim          │
                          │   (DatabaseInstanceClaim)    │
                          └──────────────┬───────────────┘
                                         │ git push
                                         ▼
                          ┌──────────────────────────────┐
                          │          GitOps Layer         │
                          │                              │
                          │  ArgoCD ApplicationSets      │
                          │  ├─ Platform components      │
                          │  │  (cluster generator)      │
                          │  └─ Team claims              │
                          │     (git generator)          │
                          └──────────────┬───────────────┘
                                         │ sync
                                         ▼
                ┌────────────────────────────────────────────────┐
                │              Admission Control                 │
                │                                                │
                │  Gatekeeper ConstraintTemplate                 │
                │  ├─ Region enforcement (PCI compliance)        │
                │  └─ Size caps (cost control)                   │
                │                                                │
                │  ┌──────────────────────────────────────────┐  │
                │  │         THE SEMANTIC GAP                 │  │
                │  │  Policies validate what is ALLOWED,      │  │
                │  │  not what makes SENSE for the workload.  │  │
                │  │  → Shadow Metrics close this gap.        │  │
                │  └──────────────────────────────────────────┘  │
                └────────────────────┬───────────────────────────┘
                                     │ admitted
                                     ▼
                          ┌──────────────────────────────┐
                          │        Platform API          │
                          │                              │
                          │  CompositeResourceDefinition │
                          │  (DatabaseInstance XRD)       │
                          │                              │
                          │  Fields: size, region, team,  │
                          │  engine, HA, backup retention │
                          └──────────────┬───────────────┘
                                         │ compose
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
         ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
         │   AWS Composition │ │  GCP Composition  │ │ Azure Composition │
         │                  │ │                   │ │                  │
         │ • RDS Instance   │ │ • Cloud SQL       │ │ • FlexibleServer │
         │ • IAM Role       │ │ • Database        │ │ • FlexibleServer │
         │ • SecurityGroup  │ │ • User            │ │   Database       │
         │ • SG Rule        │ │                   │ │                  │
         │                  │ │  Region mapping:  │ │  Region mapping: │
         │  Direct region   │ │  eu-west-1 →      │ │  eu-west-1 →     │
         │  passthrough     │ │  europe-west1     │ │  westeurope      │
         └────────┬─────────┘ └────────┬──────────┘ └────────┬─────────┘
                  │                    │                     │
                  ▼                    ▼                     ▼
         ┌──────────────────────────────────────────────────────────────┐
         │                    Cloud Provider APIs                       │
         │         (via Upbound Crossplane Providers)                   │
         └──────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### Crossplane XRDs (Platform API)

The `CompositeResourceDefinition` is the API contract between platform
engineers and application developers. It abstracts cloud-specific details
behind a uniform interface.

- **Inputs:** size, region, team, engine, highAvailability, backupRetentionDays
- **Outputs:** connectionSecret, endpoint, port, status
- **Claims:** Developers submit `DatabaseInstanceClaim` resources

### Compositions (Cloud Adapters)

Each composition maps the same XRD to cloud-native resources. Pipeline
mode with `function-patch-and-transform` handles field mapping, including
region translation for GCP and Azure.

| Cloud | Resources Created | Authentication |
|-------|-------------------|----------------|
| AWS | RDS, IAM Role, SecurityGroup, SG Rule | IRSA |
| GCP | Cloud SQL Instance, Database, User | Workload Identity |
| Azure | FlexibleServer, FlexibleServerDatabase | OIDC |

### OPA/Gatekeeper (Guardrails)

Admission-time validation before resources are created:

- **Region policy:** Team-to-region mapping enforcing data residency
  (checkout/payments EU-only for PCI-DSS)
- **Size policy:** Per-team size caps preventing cost overruns

### ArgoCD (GitOps Delivery)

Two ApplicationSets handle deployment:

1. **Platform components:** Cluster generator deploys XRDs, compositions,
   and policies to clusters based on their `provider` label
2. **Team claims:** Git generator watches `teams/*/claims` directories
   for self-service database requests

### Bootstrap Script

Single entry point for platform setup:

```bash
./bootstrap/install.sh --provider aws
```

Installs Crossplane, cloud provider, ArgoCD, Gatekeeper, and applies
all platform resources.

## The Semantic Gap

The architecture enforces what is _allowed_ but cannot determine what is
_correct_ for a given workload. A valid claim (small/eu-west-1/checkout)
may be wrong if:

- Traffic exceeds small instance capacity
- Users are geographically distant from eu-west-1
- Latency SLOs require a different configuration

This gap between policy compliance and workload fitness is addressed by
Shadow Metrics — runtime observability data that evaluates whether
valid configurations are actually appropriate.

## Data Flow

1. Developer commits a `DatabaseInstanceClaim` YAML
2. ArgoCD syncs the claim to the target cluster
3. Gatekeeper validates against OPA policies (region + size)
4. Crossplane reconciles the claim against the XRD
5. The matched Composition provisions cloud-native resources
6. Connection details are written to a Kubernetes Secret
7. The developer's application connects via the Secret
