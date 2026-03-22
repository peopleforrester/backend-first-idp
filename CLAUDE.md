# Project: Backend-First IDP — KubeCon EU 2026

## Context
Reference architecture for Abhinav's KubeCon EU 2026 Platform Engineering Zero Day talk:
"Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice."
Thesis: portal-first IDPs fail at scale. Build automation, guardrails, and GitOps first.

## Git Workflow
- Work on `staging` branch. Never push directly to `main`.
- Merge to `main` only after `make test` passes.

## Conventions
- Python as primary language where code is needed.
- YAML for Kubernetes manifests and configuration.
- Rego for OPA policies.
- Bash for scripts (must pass shellcheck).
- All code files start with a 2-line ABOUTME comment.

## Testing
- `make test` runs the full suite (YAML lint, shellcheck, OPA, XRD, compositions, golden path, structure).
- OPA tests use `opa test` with `_test.rego` files alongside policies.
- All YAML must pass yamllint with `.yamllint.yml` config.
- All shell scripts must pass shellcheck.

## Key Files
- `platform-api/xrds/database-instance.yaml` — the platform API contract (XRD)
- `policies/opa/size-limits.rego` — contains the semantic gap comment (talk pivot point)
- `DEMO.md` — on-stage walkthrough script (5 beats, ~8 min)
