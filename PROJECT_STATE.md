# Project State

## Current Status
Senior review fix round 2 in progress. Phases 1-6 of 9 complete on staging.
Plan: docs/plans/senior-review-fixes.md.

## Stack Versions (April 2026)
- Crossplane v2.2.0
- ArgoCD v3.3.6
- Kyverno 1.17.1
- External Secrets Operator v2.2.0
- OpenTelemetry Operator v0.149.0
- Go 1.26.1

## Metrics
- 294 total files (excluding .git, cli/vendor)
- 233 YAML files, 5 JSON dashboards, 13 shell scripts, 1 Python script
- 12 teams, 109 claims
- 7 XRDs, 21 compositions (illustrative), 6 Kyverno policies, 4 shadow metric rules
- 5 Grafana dashboards, 4 PrometheusRules (3 platform + 1 drift), 3 ServiceMonitors
- 600+ test assertions across 10 bash suites, 0 failures
- 26 Go tests across 4 packages, 0 failures

## Hardening Checklist (Round 1 — completed)
- [x] Phase 1: gitignore pptx, OTel TLS comments, LICENSE
- [x] Phase 2: Remove validate.sh duplication
- [x] Phase 3: Extract shared test library (tests/lib.sh)
- [x] Phase 4: CI actions pin to SHA (checkout v6, setup-python v6, setup-go v6)
- [x] Phase 5: Go CLI input validation + branch safety
- [x] Phase 6: Go CLI test coverage (validate_input, submit, xrd reader)
- [x] Phase 7: Policy default-deny for unlisted teams + chainguard/kubectl
- [x] Phase 8: Repo organization (editorconfig, requirements.txt, composition renames)
- [x] Phase 9: Version bumps (Crossplane 2.2.0, ArgoCD v3.3.6, Go 1.26.1)
- [x] Phase 10: Backstage template tests + final structure assertions

## Senior Review Fix Round 2 (in progress)
- [x] Phase 1: Drift script single source of truth (canonical script + CI assertion)
- [x] Phase 2: Drift CronJob pod hardening (securityContext, resources, /tmp emptyDir)
- [x] Phase 3: Default-deny extends to all 7 claim kinds + teams.yaml drift test
- [x] Phase 4: Bootstrap robustness (CRD waits, OTel pin v0.149.0, helm repo update fix)
- [x] Phase 5: Grafana adminPassword via ESO ExternalSecret
- [x] Phase 6: ApplicationSet targetRevision: HEAD parameterization
- [x] Phase 7: README numerical truth + composition disclaimer
- [ ] Phase 8: Go validator empty-engine default
- [ ] Phase 9: Python generator XRD enum validation

## Branch Status
- `staging`: round-2 fixes landing here
- `main`: awaiting merge after round 2 finishes and full suite is green
