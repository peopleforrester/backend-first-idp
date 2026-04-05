# Backend-First IDP — KubeCon EU 2026

Reference architecture for KubeCon EU 2026 Platform Engineering Zero Day talk: "Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice." Thesis: portal-first IDPs fail at scale — build automation, guardrails, and GitOps first.

**Stack**: Crossplane v2.2.0, ArgoCD v3.3.6, Kyverno 1.17.1, External Secrets Operator v2.2.0, OpenTelemetry, Prometheus, OpenCost, Shadow Metrics

## Commands

- `make test` — Full suite: YAML lint, shellcheck, Kyverno CLI, XRD validation, composition validation, golden path, observability, ESO, scale (100+ claims), structure

## Git Workflow

- Active branch: `staging` (v1 archived, v2+v3 complete)
- Merge to `main` only after `make test` passes

## Conventions

- YAML for Kubernetes manifests and configuration
- Bash scripts must pass shellcheck
- Kyverno tests use `kyverno apply` CLI with pass/fail test resources
- All YAML must pass yamllint with `.yamllint.yml` config

## Key Files

- `platform-api/xrds/` — 7 CompositeResourceDefinitions (the platform API contract)
- `policies/kyverno/cluster-policies/size-caps.yaml` — semantic gap annotation
- `platform-api/shadow-metrics/` — ShadowMetricRule CRD and evaluation rules
- `teams/` — 12 teams, 100+ claims generated from `scripts/teams.yaml`
- `DEMO.md` — On-stage walkthrough script
