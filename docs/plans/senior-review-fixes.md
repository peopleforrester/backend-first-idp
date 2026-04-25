<!-- ABOUTME: Plan for senior-review hardening round 2 — fixes from 2026-04-25 review. -->
<!-- ABOUTME: Phase-based, TDD-first; covers workload hardening, policy gaps, bootstrap robustness. -->

# Senior Review Fix Plan — Round 2

Source: `/review-senior` output recorded 2026-04-25 against branch `staging`.
Approach: **TDD per phase** — write a failing assertion first, implement, run full suite green, commit, then advance.

## Conventions

- Every phase has: (1) test or assertion to add **first**, (2) implementation, (3) full `make test` run, (4) commit.
- No timelines. No "soon." Phases are sized to land independently and revert independently.
- All commits target `staging`. Merge to `main` only after the full suite is green at the end.
- File creations follow the global rule: 2-line `ABOUTME:` header on every code/config file.

## Phase Map

| # | Phase | Senior-review item(s) | Test layer |
|---|-------|------------------------|------------|
| 1 | Drift script: single source of truth | #1 | `tests/structure_test.sh` |
| 2 | Drift CronJob: pod hardening | #2 | `tests/structure_test.sh` |
| 3 | Default-deny: extend to all 7 claim kinds + drift test against teams.yaml | #6, #15 | `tests/structure_test.sh` + Kyverno cases |
| 4 | Bootstrap robustness: CRD waits, OTel pin, `helm repo update` fix | #11, #12, #25 | `tests/structure_test.sh` |
| 5 | Grafana adminPassword via ESO ExternalSecret | #14 | `tests/structure_test.sh` |
| 6 | ApplicationSet `targetRevision` parameterization | #13 | `tests/structure_test.sh` |
| 7 | README/PROJECT_STATE numerical truth + composition disclaimer | #4, #5 | `tests/structure_test.sh` |
| 8 | Go validator: empty engine treated as default | #3 | `cli/pkg/claim/validate_input_test.go` |
| 9 | Python generator: validate region/size against XRD enums | #8 | `tests/structure_test.sh` (subprocess invocation with bad input) |

Items intentionally deferred from this round (low priority, not visible during the talk):
- #9, #10, #18, #19, #20, #21, #22, #23, #24, #26 — captured as TODO in `docs/plans/todo.md` if not already there. Revisit post-talk.

## Phase 1 — Drift Script: Single Source of Truth

**Problem.** `platform-api/drift-detection/scripts/check-drift.sh` is the canonical script. The `drift-check-cronjob.yaml` ConfigMap inlines a *different* shorter version. The CronJob mounts the inline version, so any fix to the canonical file is invisible at runtime.

**Decision.** Make the inline ConfigMap content equal to the canonical script verbatim, and add a structure test that asserts the ConfigMap data matches the file on disk. This avoids introducing kustomize at this stage; the assertion catches divergence at CI time.

**Test first.** Add to `tests/structure_test.sh`:
```bash
assert_drift_script_matches_configmap
```
which extracts the `data.check-drift.sh` block from the YAML and diffs it against `platform-api/drift-detection/scripts/check-drift.sh`. The assertion lives in `tests/lib.sh`.

**Implementation.** Replace the inline script body (lines ~63-90 of `drift-check-cronjob.yaml`) with the canonical script content, indented for the `data:` block. Keep the `# Inline copy of …` lead-in comment but make it explicit: "must match scripts/check-drift.sh — enforced by structure_test.sh".

**Acceptance.** New assertion passes. Full test suite green.

## Phase 2 — Drift CronJob: Pod Hardening

**Problem.** The only real workload in the repo runs as root, no resources, no `securityContext`, no `automountServiceAccountToken` annotation despite needing the SA token (kubectl uses it).

**Decision.** Add baseline-restricted `securityContext` (`runAsNonRoot: true`, `runAsUser: 65532`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`), `resources.requests/limits`, and explicit `automountServiceAccountToken: true` (it needs the token).

The chainguard/kubectl image runs as `nonroot` (UID 65532) by default and supports a read-only root FS. Need an `emptyDir` mount for `/tmp` because `kubectl` and `curl` write there.

**Test first.** Add to `structure_test.sh`:
- assert YAML contains `runAsNonRoot: true`
- assert YAML contains `drop:` followed by `ALL` (capability drop)
- assert YAML contains `requests:` and `limits:` blocks
- assert YAML contains `seccompProfile`

**Implementation.** Edit `drift-check-cronjob.yaml`. Add `securityContext` at pod level and container level, `resources` block, `volumes` for `/tmp` emptyDir.

**Acceptance.** New assertions pass. Existing tests still green.

## Phase 3 — Default-deny Extends to All 7 Claim Kinds + teams.yaml Drift Test

**Problem.** `default-deny-unlisted-teams` only matches `DatabaseInstanceClaim | CacheInstanceClaim | MessageQueueClaim | ObjectStorageClaim`. CDN, DNS, and Namespace claims are not gated. Also, the team list is duplicated between `region-enforcement.yaml` and `scripts/teams.yaml` with no test catching drift.

**Decision.**
- Extend `default-deny-unlisted-teams.match.any[].resources.kinds` to include `CDNDistributionClaim`, `DNSRecordClaim`, `KubernetesNamespaceClaim`.
- Add a structure assertion that diffs the team set in `teams.yaml` (top-level keys under `teams:`) vs. the team list in the `default-deny-unlisted-teams` precondition.

**Test first.**
- Add Kyverno test resources under `policies/kyverno/policy-tests/region-enforcement/`:
  - `resource-pass-cdn.yaml` — known team submitting a CDN claim → pass
  - `resource-fail-cdn-unknown-team.yaml` — unknown team submitting a CDN claim → fail
  - same for DNS and Namespace claims
- Add `assert_team_list_matches` to `tests/lib.sh` and call from `structure_test.sh`.

**Implementation.**
1. Update `region-enforcement.yaml` rule `default-deny-unlisted-teams` match block.
2. Add the new pass/fail test resources and reference them from the existing `kyverno-test.yaml` file in `policy-tests/region-enforcement/`.
3. Add the parser to `tests/lib.sh`.

**Acceptance.** All Kyverno test cases pass. Structure assertion passes. Full suite green.

## Phase 4 — Bootstrap Robustness

**Problem.**
- `bootstrap/install.sh` applies XRDs and downstream CRs (Shadow Metric rules) without waiting for CRDs to be Established → fails on cold cluster.
- OTel Operator URL uses `latest/download` → unpinned.
- `helm repo update <name>` requires Helm 3.13+; older versions do not accept the named-arg form.

**Decision.**
- After `kubectl apply -f platform-api/xrds/`, run `kubectl wait --for=condition=Established crd/<name>` for each XRD CRD.
- After `kubectl apply -f platform-api/shadow-metrics/shadow-metric-crd.yaml`, wait for that CRD too.
- Pin OTel Operator to `v0.121.0` (current GA April 2026 — verify before commit).
- Replace `helm repo update <repo>` with bare `helm repo update` (works on all 3.x).

**Test first.** Add to `structure_test.sh`:
- assert `install.sh` contains `kubectl wait --for=condition=Established` after each `kubectl apply -f .../xrds/` and `.../shadow-metric-crd.yaml`.
- assert `install.sh` does NOT contain `latest/download/opentelemetry-operator.yaml` (must use a pinned tag).
- assert `install.sh` does NOT contain `helm repo update <name>` patterns — only bare `helm repo update`.

**Implementation.** Edit `bootstrap/install.sh`. Add a `wait_crd` helper (uses bash function per project conventions). Verify the OTel Operator pinned URL exists before committing (curl HEAD).

**Acceptance.** Structure assertions pass. Bootstrap script shellchecks clean. Full suite green.

## Phase 5 — Grafana adminPassword via ESO ExternalSecret

**Problem.** `observability/prometheus/values-platform.yaml:24` hardcodes `adminPassword: CHANGEME`.

**Decision.** Replace with `admin.existingSecret: grafana-admin` + `admin.userKey: admin-user` + `admin.passwordKey: admin-password`. Add an `ExternalSecret` manifest under `secrets/eso/external-secrets/grafana-admin.yaml` that pulls from the configured ClusterSecretStore. Add a comment in values-platform.yaml pointing to that ExternalSecret.

**Test first.** Add to `structure_test.sh`:
- assert `secrets/eso/external-secrets/grafana-admin.yaml` exists.
- assert `observability/prometheus/values-platform.yaml` does NOT contain `CHANGEME`.
- assert `values-platform.yaml` contains `existingSecret: grafana-admin`.

**Implementation.** Edit values-platform.yaml. Create the new ExternalSecret manifest matching the patterns in `secrets/eso/external-secrets/database-credentials.yaml`.

**Acceptance.** Assertions pass. Full suite green.

## Phase 6 — ApplicationSet targetRevision Parameterization

**Problem.** All four ApplicationSets in `gitops/argocd/appset-platform.yaml` hardcode `targetRevision: main` while the active branch is `staging`. Cloners running the talk's instructions will see ArgoCD pull from `main`, possibly stale.

**Decision.** Change all `targetRevision: main` and `revision: main` to `HEAD`. ArgoCD interprets `HEAD` as the repo's default branch (configurable per fork). Add a comment at the top of the file documenting the choice and how to override per environment.

**Test first.** Add to `structure_test.sh`:
- assert `gitops/argocd/appset-platform.yaml` contains zero occurrences of `targetRevision: main` and zero `revision: main`.
- assert it contains at least one `targetRevision: HEAD` and one `revision: HEAD`.

**Implementation.** Edit `appset-platform.yaml`. Add header comment block.

**Acceptance.** Assertions pass. yamllint passes. Full suite green.

## Phase 7 — README Numerical Truth + Composition Disclaimer

**Problem.**
- README lists "3 PrometheusRules" but `prometheus-rule-drift.yaml` exists → 4 PrometheusRules.
- README claims "231 assertions" for compositions — unverified.
- AWS database composition stops at the SecurityGroupRule and never wires up connection secrets. README sells it as production-grade.

**Decision.**
- Recount on disk: PrometheusRules, Compositions, claims, dashboards, ServiceMonitors, XRDs, Kyverno policies, shadow rules.
- Update README and PROJECT_STATE to match disk reality.
- Add a comment block at the top of each composition under `platform-api/compositions/aws/database.yaml` (and equivalents) stating "Illustrative composition — connection secret extraction not wired. Not deployable as-is to a real cluster."
- Add a corresponding callout in `README.md` near the architecture overview.

**Test first.** Add a script `tests/lib.sh` helper `count_files <glob>` and structure assertions:
- count of PrometheusRules on disk == number stated in README (or just assert ≥4).
- assert each composition file contains the literal string `Illustrative composition`.

**Implementation.** Run counts; edit README, PROJECT_STATE.md, and each composition.

**Acceptance.** Assertions pass.

## Phase 8 — Go Validator: Empty Engine = Default

**Problem.** `ValidateParams(TypeDatabase, params)` rejects empty `Engine` as "invalid". The XRD specifies `default: postgres`. Callers that don't pre-fill the default get rejected.

**Decision.** When `params.Engine == ""`, treat as `postgres` for `TypeDatabase` and `redis` for `TypeCache`. Keep the rejection for non-empty unknown values.

**Test first.** Add to `validate_input_test.go`:
- `TestValidateParams_EmptyDBEngineIsValid` — empty engine on `TypeDatabase` → no error.
- `TestValidateParams_EmptyCacheEngineIsValid` — empty engine on `TypeCache` → no error.
- Confirm existing rejection of unknown values still passes.

**Implementation.** Edit `cli/pkg/claim/validate_input.go`. Add empty-string short-circuits in the `case TypeDatabase` / `case TypeCache` blocks.

**Acceptance.** Go tests pass. Full Make test suite green.

## Phase 9 — Python Generator: XRD Enum Validation

**Problem.** `scripts/generate-team-claims.py` does not validate region/size against the XRD enum. A bad value in `teams.yaml` produces invalid claims that only fail at admission time.

**Decision.** Parse `platform-api/xrds/database-instance.yaml` and `cache-instance.yaml` for the region and size enum lists. Before writing any claim, assert each region/size value is in the corresponding enum. Fail with a clear message if not.

**Test first.** Add to `tests/structure_test.sh` (cheapest path — no Python test framework adoption needed):
- run the generator with a known-good `teams.yaml` and assert exit 0.
- run the generator against a tampered teams.yaml (use a tmp copy with an invalid region) and assert non-zero exit.

**Implementation.** Add an `_load_xrd_enums()` helper in `generate-team-claims.py` and call it in `main()` before the generation pass. Use `pathlib` and `yaml.safe_load`.

**Acceptance.** New tests pass. Existing run still produces 109 claims.

## Verification & Closeout

- After every phase: `make test`. Green = commit. Red = stop, fix, re-run.
- After Phase 9: re-run the full suite, update `PROJECT_STATE.md` hardening checklist with this round's items, and commit.
- Push to `staging` only. Do not merge to `main` in this session unless explicitly authorized.
