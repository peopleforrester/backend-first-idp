# Why Kyverno Over OPA/Gatekeeper

## Context

The v1 of this repo used OPA/Gatekeeper for admission control. The v2
migrates to Kyverno. This document explains why.

## The Decision

| Factor | OPA/Gatekeeper | Kyverno |
|--------|---------------|---------|
| **Policy language** | Rego (custom DSL) | CEL (Kubernetes-native) + YAML patterns |
| **Learning curve** | High — Rego is powerful but unfamiliar | Low — CEL is used in Gateway API, VAP |
| **CNCF status** | Graduated (OPA) | Graduated (Kyverno, since 2024) |
| **Policy reporting** | Requires separate audit infrastructure | Built-in PolicyReport CRs |
| **Policy exceptions** | Manual, via Rego logic | First-class PolicyException CR |
| **Mutation support** | Limited (via Gatekeeper mutation) | Native, same policy resource |
| **Generation support** | No | Yes (generate resources from policies) |
| **CEL support** | No | v1-promoted in 1.17 |
| **CLI testing** | `opa test` (good) | `kyverno apply` (good) |

## The Core Argument

In 2026, CEL is the Kubernetes expression language. It's used in:

- `ValidatingAdmissionPolicy` (Kubernetes native)
- Gateway API route matching
- Kyverno 1.17 policies (v1-promoted)
- Crossplane CEL-based composition functions

Choosing Kyverno aligns the policy engine with the broader Kubernetes
ecosystem direction. Platform consumers don't need to learn a separate
language (Rego) — they already know CEL from other Kubernetes contexts.

## What We Gained

1. **6 policies instead of 2** — Kyverno's native patterns (label matching,
   naming validation) made it easy to add governance policies that would
   have required complex Rego.

2. **Policy promotion pipeline** — Kyverno's `validationFailureAction` field
   (Audit vs Enforce) enables per-environment promotion via Kustomize patches.
   OPA/Gatekeeper requires separate constraint resources.

3. **Built-in reporting** — PolicyReports feed directly into Grafana without
   a separate reporting pipeline.

4. **PolicyException CRs** — First-class exceptions for the platform team,
   managed via GitOps like everything else.

## What We Lost

1. **Rego's expressiveness** — Complex cross-resource validation is easier
   in Rego than CEL. For this reference architecture, the policies are
   simple enough that this doesn't matter.

2. **OPA ecosystem** — OPA has a broader ecosystem beyond Kubernetes
   (Envoy, Terraform, etc.). If the platform needed non-Kubernetes policy
   evaluation, OPA would be the better choice.

## The Semantic Gap Comment

The OPA v1 had the semantic gap commentary embedded in `size-limits.rego`.
In v2, it's preserved as a Kyverno annotation on `size-caps.yaml` and
expanded into a standalone document at `docs/semantic-gap.md`. The
intellectual content is identical — only the container changed.
