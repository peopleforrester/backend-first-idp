# Project State

## Current Status
Senior review hardening complete. All 10 phases done. Full test suite green. Ready for push to staging, then merge to main.

## Stack Versions (April 2026)
- Crossplane v2.2.0
- ArgoCD v3.3.6
- Kyverno 1.17.1
- External Secrets Operator v2.2.0
- Go 1.26.1

## Metrics
- 251 total files
- 209 YAML files, 5 JSON dashboards, 13 shell scripts, 1 Python script
- 12 teams, 109 claims
- 7 XRDs, 21 compositions, 6 Kyverno policies, 4 shadow metric rules
- 5 Grafana dashboards, 3 PrometheusRules, 3 ServiceMonitors
- 581+ test assertions across 10 bash suites, 0 failures
- 26 Go tests across 4 packages, 0 failures

## Hardening Checklist
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

## Branch Status
- `staging`: active development, hardening complete
- `main`: awaiting merge from staging
