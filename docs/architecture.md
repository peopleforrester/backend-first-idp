# Architecture: Backend-First Internal Developer Platform (v2)

## Overview

This reference architecture implements a backend-first IDP using Crossplane v2,
ArgoCD v3, Kyverno, External Secrets Operator, and a full observability stack.
The thesis: build automation, guardrails, and GitOps pipelines first. The portal
is optional.

## Architecture Diagram

```
                          ┌─────────────────────────────┐
                          │      Developer Interface     │
                          │                              │
                          │   9-line YAML claim          │
                          │   (7 resource types)         │
                          └──────────────┬───────────────┘
                                         │ git push
                                         ▼
                          ┌──────────────────────────────┐
                          │          GitOps Layer         │
                          │                              │
                          │  ArgoCD v3 ApplicationSets   │
                          │  ├─ Platform components      │
                          │  ├─ Policy promotion         │
                          │  ├─ Team claims (12 teams)   │
                          │  └─ Observability stack      │
                          └──────────────┬───────────────┘
                                         │ sync
                                         ▼
                ┌────────────────────────────────────────────────┐
                │              Admission Control                 │
                │                                                │
                │  Kyverno 1.17 CEL Policies (6 rules)          │
                │  ├─ Region enforcement (PCI-DSS)               │
                │  ├─ Size caps (cost control)                   │
                │  ├─ Required labels (governance)               │
                │  ├─ Naming conventions (inventory)             │
                │  ├─ Backup retention (reliability)             │
                │  └─ HA enforcement (production safety)         │
                │                                                │
                │  Policy Promotion: dev → staging → production  │
                └────────────────────┬───────────────────────────┘
                                     │ admitted
                                     ▼
                          ┌──────────────────────────────┐
                          │        Platform API          │
                          │                              │
                          │  7 CompositeResourceDefs     │
                          │  ├─ DatabaseInstance          │
                          │  ├─ CacheInstance             │
                          │  ├─ MessageQueue              │
                          │  ├─ ObjectStorage             │
                          │  ├─ CDNDistribution           │
                          │  ├─ DNSRecord                 │
                          │  └─ KubernetesNamespace       │
                          └──────────────┬───────────────┘
                                         │ compose
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
         ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
         │  AWS (7 comps)   │ │  GCP (7 comps)   │ │ Azure (7 comps)  │
         │                  │ │                   │ │                  │
         │ RDS, ElastiCache │ │ Cloud SQL,        │ │ FlexibleServer,  │
         │ SQS, S3,         │ │ Memorystore,      │ │ Redis Cache,     │
         │ CloudFront,      │ │ Pub/Sub, GCS,     │ │ Service Bus,     │
         │ Route53, NS+RBAC │ │ CDN, DNS, NS+RBAC │ │ Blob, FD, NS    │
         └────────┬─────────┘ └────────┬──────────┘ └────────┬─────────┘
                  │                    │                     │
                  ▼                    ▼                     ▼
         ┌──────────────────────────────────────────────────────────────┐
         │                    Cloud Provider APIs                       │
         └──────────────────────────────────────────────────────────────┘

                    ┌────────────────────────────────────────┐
                    │         Runtime Validation              │
                    │                                        │
                    │  Shadow Metrics (4 rules)              │
                    │  ├─ Database sizing vs traffic          │
                    │  ├─ Region latency vs users             │
                    │  ├─ Cost efficiency vs utilization      │
                    │  └─ HA requirement vs SLO               │
                    │                                        │
                    │  Composition Drift Detection            │
                    │  └─ CronJob → Prometheus → Alert        │
                    └────────────────────────────────────────┘

                    ┌────────────────────────────────────────┐
                    │         Observability                   │
                    │                                        │
                    │  OpenTelemetry (agent + gateway)        │
                    │  Prometheus (rules + ServiceMonitors)   │
                    │  OpenCost (team cost allocation)        │
                    │  Grafana (5 dashboards)                 │
                    │  External Secrets (3 cloud stores)      │
                    └────────────────────────────────────────┘
```

## Component Versions

| Component | Version | Role |
|-----------|---------|------|
| Crossplane | v2.2.0 | Resource abstraction and cloud provisioning |
| ArgoCD | v3.3.6 | GitOps delivery (4 ApplicationSets) |
| Kyverno | 1.17.1 | Admission control (6 CEL policies) |
| ESO | v2.2.0 | Secrets management (3 cloud stores) |
| OTel Operator | latest | Telemetry collection (agent + gateway) |
| Prometheus | kube-prometheus-stack | Metrics, alerting, recording rules |
| OpenCost | latest | Cost allocation by team label |

## Data Flow

1. Developer commits a claim YAML to `teams/{team}/claims/`
2. ArgoCD team-claims ApplicationSet detects the change and syncs
3. Kyverno evaluates the claim against 6 cluster policies
4. If rejected: instant feedback with violation message
5. If accepted: Crossplane reconciles against the matching XRD
6. The matched Composition provisions cloud-native resources
7. Shadow Metrics evaluate the claim against runtime Prometheus data
8. Connection details written to a Kubernetes Secret (via ESO)
9. Drift detection CronJob continuously verifies composition integrity
10. Grafana dashboards surface health, latency, cost, and shadow metric alerts

## Scale

- 7 resource types (XRDs)
- 21 compositions (7 × 3 clouds)
- 12 teams
- 109 claims
- 6 admission policies
- 4 shadow metric rules
- 5 Grafana dashboards
- 3 PrometheusRules (9 alert rules total)
- 3 ServiceMonitors
