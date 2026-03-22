# Implementation Plan: Backend-First IDP Reference Architecture

## Architecture Overview

This is a **reference architecture repo** for a KubeCon EU 2026 talk. It contains:
- Crossplane XRDs and Compositions (the platform API)
- OPA/Gatekeeper policies (the guardrails)
- ArgoCD ApplicationSets (the GitOps delivery)
- A bootstrap script (the one-command setup)
- Golden path examples (the developer interface)
- Demo script and documentation

**No running cluster is required.** All files are valid Kubernetes/Crossplane/OPA manifests
that can be validated structurally.

## Testing Strategy

Since this is infrastructure-as-code (YAML + Rego + Bash), TDD means:

1. **YAML validation** — `yamllint` for syntax, `kubeconform` for K8s schema validation
2. **Rego unit tests** — OPA's built-in test framework (`opa test`)
3. **Bash validation** — `shellcheck` for the bootstrap script
4. **Structure tests** — a script that asserts all expected files exist and cross-references are valid
5. **Integration tests** — claim examples validated against OPA policies to confirm accept/reject behavior

We install test tooling first, write tests, then build manifests to pass them.

---

## Phase 0: Test Tooling & Validation Framework

**Goal:** Set up the test harness so every subsequent phase has a red→green cycle.

**What gets built:**
- `tests/validate.sh` — master test runner
- `tests/structure_test.sh` — asserts expected file tree exists
- `.yamllint.yml` — yamllint config
- Install/pin test tool versions (yamllint, kubeconform, opa, shellcheck)
- `Makefile` with `make test`, `make lint`, `make validate` targets

**Commit after this phase.**

---

## Phase 1: Platform API — XRD

**Goal:** Define the platform's API contract — the CompositeResourceDefinition.

### Step 1a: Write the XRD schema test

Write a test that:
- Validates `platform-api/xrds/database-instance.yaml` exists
- Is valid YAML
- Contains a CRD with group `platform.kubecon.io`, version `v1alpha1`
- Has all required spec fields: size (enum), region (enum), team (string), engine (default), highAvailability (bool), backupRetentionDays (int)
- Has status fields: connectionSecret, endpoint, port, status

**Run test → expect FAIL (file doesn't exist yet).**

### Step 1b: Write the XRD

Create `platform-api/xrds/database-instance.yaml`:
- `CompositeResourceDefinition` for `DatabaseInstance`
- Group: `platform.kubecon.io`, version: `v1alpha1`
- Full OpenAPI v3 schema with enums, defaults, and required fields

**Run test → expect PASS.**

**Commit: "Add DatabaseInstance XRD — platform API contract"**

---

## Phase 2: Compositions — AWS

**Goal:** First cloud provider composition mapping XRD to AWS resources.

### Step 2a: Write composition validation test

Test that:
- `platform-api/compositions/aws/database-small.yaml` exists and is valid YAML
- Uses pipeline mode with `function-patch-and-transform`
- References the correct XRD (`xdatabaseinstances.platform.kubecon.io`)
- Patches map XRD fields to RDS Instance, IAM Role, SecurityGroup, SG Rule

**Run test → expect FAIL.**

### Step 2b: Write the AWS composition

Create `platform-api/compositions/aws/database-small.yaml`:
- Pipeline mode composition
- Resources: RDS Instance (db.t4g.medium, gp3, encrypted, performance insights), IAM Role, SecurityGroup, SG Rule
- Patches from XRD spec → resource fields

**Run test → expect PASS.**

**Commit: "Add AWS composition — RDS + IAM + SecurityGroup"**

---

## Phase 3: Compositions — GCP

**Goal:** Second cloud composition with region mapping.

### Step 3a: Write GCP composition test

Same structure as AWS test, plus:
- Region mapping assertions (eu-west-1→europe-west1, etc.)
- Resources: Cloud SQL DatabaseInstance, Database, User

**Run test → expect FAIL.**

### Step 3b: Write the GCP composition

Create `platform-api/compositions/gcp/database-small.yaml`:
- Pipeline mode with region mapping via transforms
- Resources: Cloud SQL (db-custom-2-4096, PD_SSD, query insights), Database, User

**Run test → expect PASS.**

**Commit: "Add GCP composition — Cloud SQL + Database + User"**

---

## Phase 4: Compositions — Azure

**Goal:** Third cloud composition completing multi-cloud support.

### Step 4a: Write Azure composition test

Same pattern, Azure region mapping, FlexibleServer resources.

**Run test → expect FAIL.**

### Step 4b: Write the Azure composition

Create `platform-api/compositions/azure/database-small.yaml`:
- Pipeline mode with Azure region mapping
- Resources: FlexibleServer (B_Standard_B2s), FlexibleServerDatabase

**Run test → expect PASS.**

**Commit: "Add Azure composition — FlexibleServer + Database"**

---

## Phase 5: OPA Policies

**Goal:** Write guardrail policies with proper Rego unit tests.

### Step 5a: Write Rego unit tests FIRST

Create:
- `policies/opa/region-allowed_test.rego` — tests for:
  - checkout team allowed eu-west-1 → allow
  - checkout team requesting us-west-2 → deny
  - analytics team allowed us-east-1 → allow
  - platform team allowed anywhere → allow
  - unknown team → deny
- `policies/opa/size-limits_test.rego` — tests for:
  - checkout requesting small → allow
  - checkout requesting large → deny (capped at medium)
  - payments requesting large → allow
  - analytics requesting large → deny (capped at medium)

**Run `opa test policies/opa/` → expect FAIL (no policy files yet).**

### Step 5b: Write the Rego policies

Create:
- `policies/opa/region-allowed.rego`:
  - Team-to-region map (checkout/payments: EU only, analytics: US+EU, platform: all)
  - Deny unknown teams
- `policies/opa/size-limits.rego`:
  - Size caps per team tier
  - **CRITICAL:** Semantic gap comment block at bottom

**Run `opa test policies/opa/` → expect PASS.**

**Commit: "Add OPA policies — region enforcement + size limits with semantic gap commentary"**

---

## Phase 6: Gatekeeper Integration

**Goal:** Wire OPA policies into Gatekeeper ConstraintTemplate + Constraint.

### Step 6a: Write Gatekeeper manifest test

Test that:
- `policies/gatekeeper/constraint-templates/platform-validation.yaml` is valid YAML
- Contains both a ConstraintTemplate and a Constraint
- ConstraintTemplate embeds Rego inline
- Constraint targets `platform.kubecon.io` resources

**Run test → expect FAIL.**

### Step 6b: Write the Gatekeeper manifests

Create `policies/gatekeeper/constraint-templates/platform-validation.yaml`:
- ConstraintTemplate with inline Rego (region + size rules)
- Constraint targeting DatabaseInstance claims

**Run test → expect PASS.**

**Commit: "Add Gatekeeper ConstraintTemplate + Constraint for platform validation"**

---

## Phase 7: Golden Path Examples

**Goal:** Create the developer-facing claim examples.

### Step 7a: Write golden path tests

Tests that:
- `claim-database.yaml` is valid YAML with correct apiVersion/kind
- `claim-database-WILL-FAIL.yaml` is valid YAML
- The passing claim specifies checkout team + eu-west-1 + small (valid combo)
- The failing claim specifies checkout team + us-west-2 + large (two violations)
- Run failing claim through OPA → confirm it produces exactly 2 deny messages

**Run test → expect FAIL.**

### Step 7b: Write the claim files

Create:
- `golden-path/examples/claim-database.yaml` — 9-line working claim
- `golden-path/examples/claim-database-WILL-FAIL.yaml` — deliberately violating claim
- `golden-path/templates/new-service/service-resources.yaml` — CHANGEME template

**Run test → expect PASS.**

**Commit: "Add golden path examples — working claim + deliberate OPA violation"**

---

## Phase 8: ArgoCD ApplicationSets

**Goal:** GitOps delivery configuration.

### Step 8a: Write ArgoCD manifest test

Test that:
- `gitops/argocd/appset-platform.yaml` is valid YAML
- Contains two ApplicationSet resources
- Platform AppSet uses cluster generator with provider label selector
- Team AppSet uses git generator pointing at `github.com/peopleforrester/backend-first-idp`

**Run test → expect FAIL.**

### Step 8b: Write the ApplicationSets

Create `gitops/argocd/appset-platform.yaml`:
- Platform ApplicationSet (cluster generator, selects by `provider` label)
- Team claims ApplicationSet (git generator, scans `teams/*/claims`)
- Repo URL: `github.com/peopleforrester/backend-first-idp`

**Run test → expect PASS.**

**Commit: "Add ArgoCD ApplicationSets — platform components + team claims"**

---

## Phase 9: Kustomize Overlays

**Goal:** Per-cloud kustomize configurations.

### Step 9a: Write kustomize test

Test that:
- Base kustomization references XRDs + Gatekeeper templates
- Each overlay (aws/gcp/azure) references base + cloud-specific composition

**Run test → expect FAIL.**

### Step 9b: Write the kustomize files

Create:
- `gitops/kustomize/base/kustomization.yaml`
- `gitops/kustomize/overlays/aws/kustomization.yaml`
- `gitops/kustomize/overlays/gcp/kustomization.yaml`
- `gitops/kustomize/overlays/azure/kustomization.yaml`

**Run test → expect PASS.**

**Commit: "Add kustomize base + cloud-specific overlays"**

---

## Phase 10: Bootstrap Script

**Goal:** One-command setup script.

### Step 10a: Write bootstrap script tests

- `shellcheck bootstrap/install.sh` passes
- Script uses `set -euo pipefail`
- Script accepts `--provider aws|gcp|azure` flag
- Script checks for `kubectl` and `helm` prerequisites
- Provider YAML files exist for aws, gcp, azure

**Run test → expect FAIL.**

### Step 10b: Write the bootstrap script + provider configs

Create:
- `bootstrap/install.sh` — installs Crossplane (helm), functions, provider, ArgoCD, Gatekeeper, applies XRDs + compositions + policies
- `bootstrap/providers/aws.yaml` — Upbound provider-family-aws + ProviderConfig (IRSA)
- `bootstrap/providers/gcp.yaml` — Upbound provider-family-gcp + ProviderConfig (Workload Identity)
- `bootstrap/providers/azure.yaml` — Upbound provider-family-azure + ProviderConfig (OIDC)

**Run test → expect PASS.**

**Commit: "Add bootstrap script + multi-cloud provider configs"**

---

## Phase 11: Documentation

**Goal:** README, DEMO.md, architecture doc, LICENSE.

### Step 11a: Write documentation tests

- README.md contains architecture ASCII diagram, quick start, multi-cloud section
- DEMO.md contains 5 beats with correct file references
- docs/architecture.md exists with ASCII diagram
- LICENSE file is Apache 2.0
- All file paths referenced in docs actually exist

**Run test → expect FAIL.**

### Step 11b: Write the documentation

Create/update:
- `README.md` — full overview with ASCII architecture diagram, quick start, multi-cloud
- `DEMO.md` — 5-beat on-stage walkthrough (~8 min, maps to slide sequence)
- `docs/architecture.md` — detailed architecture with ASCII diagram
- `LICENSE` — Apache 2.0 text

**Run test → expect PASS.**

**Commit: "Add documentation — README, demo script, architecture, Apache 2.0 license"**

---

## Phase 12: Full Integration Test & Final Polish

**Goal:** End-to-end validation, CLAUDE.md update, final commit.

- Run `make test` — all tests green
- Run yamllint across all YAML files
- Run shellcheck on install.sh
- Run `opa test` on all Rego
- Validate all cross-references (docs → files, kustomize → resources, ArgoCD → repo)
- Update CLAUDE.md with final project conventions
- Update PROJECT_STATE.md

**Commit: "Final validation pass — all tests green"**
**Push staging, merge to main.**

---

## Dependency Graph

```
Phase 0 (tooling)
    │
    ▼
Phase 1 (XRD) ──────────────────────────────┐
    │                                         │
    ├──▶ Phase 2 (AWS composition)            │
    ├──▶ Phase 3 (GCP composition)            │
    ├──▶ Phase 4 (Azure composition)          │
    │         │                               │
    │         ▼                               │
    │    Phase 9 (Kustomize) ◀────────────────┤
    │                                         │
    ▼                                         │
Phase 5 (OPA policies)                        │
    │                                         │
    ├──▶ Phase 6 (Gatekeeper)                 │
    │                                         │
    ├──▶ Phase 7 (Golden path) ◀──────────────┘
    │
    ▼
Phase 8 (ArgoCD)
    │
    ▼
Phase 10 (Bootstrap) ◀── needs all above
    │
    ▼
Phase 11 (Docs) ◀── needs all files to exist
    │
    ▼
Phase 12 (Integration)
```

Phases 2/3/4 can run in parallel. Phases 5-6 can overlap with 2-4.
Phase 7 depends on both the XRD (Phase 1) and OPA (Phase 5).

---

## Estimated Commits: 13 (including Phase 0 setup)

Each phase = one commit on staging. Final merge to main after Phase 12.
