# On-Stage Demo Walkthrough

**Talk:** Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice
**Event:** KubeCon EU 2026 — Platform Engineering Zero Day
**Duration:** ~8 minutes across 5 beats

---

## Setup Before Going On Stage

- Terminal open to repo root
- Editor with files pre-loaded in tabs (claim, XRD, compositions, OPA, bootstrap)
- Font size: 24pt minimum for audience readability

---

## Beat 1: The Golden Path (~1.5 min)

**File:** `golden-path/examples/claim-database.yaml`

> Open the claim file. Let the audience read it.

"This is the golden path. Nine lines. That's what a developer sees.
They don't need a portal. They don't need a ticket. They don't need
to know which cloud they're on. They commit this file, and they get
a database."

```yaml
apiVersion: platform.kubecon.io/v1alpha1
kind: DatabaseInstanceClaim
metadata:
  name: checkout-db
  namespace: checkout
spec:
  size: small
  region: eu-west-1
  team: checkout
```

> Pause. Let it sink in. The simplicity is the point.

**Transition:** "But nine lines only works if something behind them
is doing the heavy lifting. Let me show you what's behind the curtain."

---

## Beat 2: The Platform API Contract (~1.5 min)

**File:** `platform-api/xrds/database-instance.yaml`

> Scroll to the spec fields.

"This is a Crossplane CompositeResourceDefinition — the platform's API
contract. It defines what developers CAN ask for: size, region, team,
engine, high availability, backup retention."

> Point out the enums.

"Notice the constraints are baked into the schema. You can't request a
region we don't operate in. You can't ask for an engine we don't support.
The API itself is the first layer of guardrails."

**Transition:** "But an API contract is just a schema. The real question
is: what happens when someone submits that claim?"

---

## Beat 3: Three Clouds, One Claim (~2 min)

**Files:** Side-by-side if possible, or tab through:
- `platform-api/compositions/aws/database-small.yaml`
- `platform-api/compositions/gcp/database-small.yaml`
- `platform-api/compositions/azure/database-small.yaml`

"Same claim. Three completely different cloud implementations."

> Show AWS composition briefly — highlight RDS, IAM, SecurityGroup.

"On AWS, that nine-line claim becomes an RDS instance with encryption,
performance insights, an IAM role for monitoring, and a security group
with the right ingress rules."

> Switch to GCP.

"On GCP, same claim, but now it's Cloud SQL with query insights, PD_SSD
storage, and automatic region mapping. eu-west-1 becomes europe-west1."

> Switch to Azure.

"Azure: FlexibleServer with auto-grow storage. Same developer experience,
completely different infrastructure."

**Transition:** "So the platform handles the complexity. But who decides
what's ALLOWED?"

---

## Beat 4: The Guardrails — and the Gap (~2 min)

**Files:**
- `policies/opa/region-allowed.rego`
- `policies/opa/size-limits.rego`

> Show the region policy first.

"OPA policies. The checkout and payments teams can only deploy in EU
regions — PCI compliance. Analytics gets US and EU. The platform team
gets everything."

> Show the size limits.

"Size caps per team. Checkout is capped at medium. Payments can go to
large. This prevents cost surprises."

> Now scroll to the SEMANTIC GAP COMMENT at the bottom of size-limits.rego.
> READ IT ALOUD. This is the pivot moment.

"But here's the thing..."

> Read the comment block slowly, with emphasis:

"Everything above validates what is ALLOWED. It does not validate what
makes SENSE. A request for small, eu-west-1, checkout will pass every
policy. OPA says yes. But is it RIGHT? Is small enough for Black Friday?
Is eu-west-1 where the users actually are? Will the latency meet the SLO?"

> Pause.

"OPA can't answer those questions. Neither can Crossplane. To answer them,
you need runtime data. Prometheus. SLO dashboards. FinOps tooling."

"This is the semantic gap. Policies enforce boundaries. But most production
incidents happen INSIDE those boundaries — with perfectly valid configurations
that are wrong for the workload."

**Transition:** "This is where Shadow Metrics come in."

> [ADVANCE TO SLIDE: "Shadow Metrics — Closing the Semantic Gap"]

---

## Beat 5: One Command (~1 min)

**File:** `bootstrap/install.sh`

> Show the script structure. Don't run it live.

"One command. Pick your cloud. It installs Crossplane, the provider,
ArgoCD, Gatekeeper, and applies everything you just saw."

```bash
./bootstrap/install.sh --provider aws
```

> Scroll through the steps briefly.

"Pre-flight checks. Helm installs. Provider configuration. Policy
application. From zero to a working IDP backend in under ten minutes."

**Transition to next section of the talk.**

---

## Failing Claim Demo (Optional, if time permits)

**File:** `golden-path/examples/claim-database-WILL-FAIL.yaml`

> Show this claim — checkout requesting us-west-2 and large.

"Watch what happens when someone tries to break the rules."

> If cluster is live, `kubectl apply -f` and show the Gatekeeper rejection.
> If not, explain the two violations:
> 1. Region: checkout can't deploy in us-west-2
> 2. Size: checkout is capped at medium, requested large

"Two violations. Instant feedback. No ticket required."

---

## Slide Mapping

| Beat | Slide Topic | Duration |
|------|-------------|----------|
| 1 | Golden Path / Developer Experience | ~1.5 min |
| 2 | Platform API Contract (XRDs) | ~1.5 min |
| 3 | Multi-Cloud Compositions | ~2 min |
| 4 | OPA Guardrails → Semantic Gap Pivot | ~2 min |
| 5 | Bootstrap / One Command Setup | ~1 min |
