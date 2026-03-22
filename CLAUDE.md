# Project: Backend-First IDP — KubeCon EU 2026

## Context
Reference architecture for KubeCon EU 2026 Platform Engineering Zero Day talk:
"Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice."
Thesis: portal-first IDPs fail at scale. Build automation, guardrails, and GitOps first.

## Stack (v2)
- Crossplane v2.1 — 7 XRDs, 21 compositions across AWS/GCP/Azure
- ArgoCD v3.3.4 — ApplicationSets for platform components + team claims
- Kyverno 1.17.1 — 6 CEL cluster policies replacing OPA/Gatekeeper
- External Secrets Operator v2.0.1 — ClusterSecretStores per cloud
- OpenTelemetry + Prometheus + OpenCost — full observability stack
- Shadow Metrics — runtime validation closing the semantic gap

## Git Workflow
- Active branch: `v2-rebuild` (v1 archived on `staging`/`main`)
- Merge to `main` only after `make test` passes.

## Conventions
- Python as primary language where code is needed.
- YAML for Kubernetes manifests and configuration.
- Bash for scripts (must pass shellcheck).
- All code files start with a 2-line ABOUTME comment.

## Testing
- `make test` runs the full suite: YAML lint, shellcheck, Kyverno CLI, XRD validation,
  composition validation, golden path, observability, ESO, scale (100+ claims), structure.
- Kyverno tests use `kyverno apply` CLI with pass/fail test resources.
- All YAML must pass yamllint with `.yamllint.yml` config.
- All shell scripts must pass shellcheck.

## Key Files
- `platform-api/xrds/` — 7 CompositeResourceDefinitions (the platform API contract)
- `policies/kyverno/cluster-policies/size-caps.yaml` — contains the semantic gap annotation
- `platform-api/shadow-metrics/` — ShadowMetricRule CRD and evaluation rules
- `teams/` — 12 teams, 100+ claims generated from `scripts/teams.yaml`
- `DEMO.md` — on-stage walkthrough script
