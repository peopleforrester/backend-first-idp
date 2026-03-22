# On-Stage Demo Walkthrough

**Talk:** Architecting a Production-Ready IDP: Argo CD, Crossplane & OPA in Practice
**Event:** KubeCon EU 2026 — Platform Engineering Zero Day
**Duration:** ~10 minutes across 6 beats

---

## Setup Before Going On Stage

- Terminal open to repo root
- Editor with files pre-loaded in tabs (claim, XRD, compositions, Kyverno, shadow metrics, bootstrap)
- Font size: 24pt minimum for audience readability
- Grafana dashboards loaded if live cluster available

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

> Pause. Let it sink in.

"But this isn't just databases. We have seven resource types."

> Quickly show `golden-path/examples/claim-full-service.yaml`

"Database, cache, message queue, object storage — about thirty lines
for a complete service. Still no portal."

**Transition:** "Nine lines only works if something behind them
is doing the heavy lifting. Let me show you what's behind the curtain."

---

## Beat 2: The Platform API Contract (~1.5 min)

**File:** `platform-api/xrds/database-instance.yaml`

> Scroll to the spec fields.

"This is a Crossplane CompositeResourceDefinition — the platform's API
contract. Seven of these cover every resource type our teams need:
databases, caches, queues, storage, CDN, DNS, and namespaces."

> Point out the enums and defaults.

"The constraints are baked into the schema. You can't request a region
we don't operate in. You can't use an engine we don't support. The API
itself is the first layer of guardrails."

**Transition:** "But an API contract is just a schema. What happens when
someone submits that claim?"

---

## Beat 3: Three Clouds, One Claim (~2 min)

**Files:** Tab through:
- `platform-api/compositions/aws/database-small.yaml`
- `platform-api/compositions/gcp/database-small.yaml`
- `platform-api/compositions/azure/database-small.yaml`

"Same claim. Three completely different cloud implementations.
Twenty-one compositions total — seven resource types across three clouds."

> Show AWS composition briefly — highlight RDS, IAM, SecurityGroup.

"On AWS, that nine-line claim becomes an RDS instance with encryption,
performance insights, an IAM role for monitoring, and a security group."

> Switch to GCP.

"On GCP, same claim, but now it's Cloud SQL with query insights
and automatic region mapping. eu-west-1 becomes europe-west1."

> Switch to Azure.

"Azure: FlexibleServer. Same developer experience, completely different
infrastructure. The developer never sees any of this."

**Transition:** "The platform handles complexity. But who decides what's allowed?"

---

## Beat 4: Kyverno Guardrails → The Semantic Gap (~2.5 min)

**Files:**
- `policies/kyverno/cluster-policies/region-enforcement.yaml`
- `policies/kyverno/cluster-policies/size-caps.yaml`

> Show the region policy.

"Six Kyverno policies. The checkout and payments teams can only deploy in
EU regions — PCI compliance. Analytics gets US and EU. Platform team gets
everything. These are CEL expressions, the same language Kubernetes itself
uses for validation."

> Show the size-caps policy.

"Size caps per team. Checkout capped at medium. Payments can go to large."

> Show the failing claim demo.

"Watch what happens when someone breaks the rules."

```bash
kyverno apply policies/kyverno/cluster-policies/ \
  --resource golden-path/examples/claim-database-WILL-FAIL.yaml
```

"Three violations. Instant feedback. No ticket required."

> Now scroll to the SEMANTIC GAP ANNOTATION on size-caps.yaml. Read it.

"But here's the thing... Everything above validates what is ALLOWED.
It does not validate what makes SENSE."

> Pause.

"A request for small, eu-west-1, checkout passes every policy.
Kyverno says yes. But is small enough for Black Friday traffic?
Is eu-west-1 where the users actually are?"

"This is the semantic gap. And this is where Shadow Metrics come in."

---

## Beat 5: Shadow Metrics (~2 min)

**Files:**
- `platform-api/shadow-metrics/README.md`
- `platform-api/shadow-metrics/rules/database-sizing.yaml`
- Grafana: `observability/grafana/dashboards/shadow-metrics.json`

> Show the ShadowMetricRule CRD.

"A Shadow Metric is a runtime measurement. It evaluates whether a valid
claim is correct for its workload. It doesn't block — it annotates."

> Show the database-sizing rule.

"This rule queries Prometheus for the actual request rate hitting the
namespace. If checkout handles 50,000 requests a day and the database
is sized small — the dashboard flags it."

> Show the shadow metric warning claim.

"This claim passes every Kyverno policy. But the Shadow Metrics
dashboard says: WARNING — undersized for traffic."

> If live cluster: show the Grafana shadow-metrics dashboard.
> If not: show the JSON and explain what it would display.

"Policies enforce the boundaries. Shadow Metrics tell you when
you're inside the boundaries but still wrong."

**Transition:** "So that's the full loop. Let me show you how it all deploys."

---

## Beat 6: One Command + Scale (~1.5 min)

**Files:**
- `bootstrap/install.sh`
- `teams/` directory

> Show the bootstrap script structure (don't run it live).

"One command. Pick your cloud. Twelve steps: cert-manager, Crossplane v2,
ArgoCD v3, Kyverno, External Secrets, the observability stack, and all
the platform resources."

```bash
./bootstrap/install.sh --provider aws
```

> Show the teams directory.

"Twelve teams, a hundred and nine claims. Checkout, payments, analytics,
identity, catalog, shipping, notifications, inventory, search, billing,
marketing, and the platform team itself."

> Show the ArgoCD ApplicationSets.

"Four ApplicationSets. One for platform infrastructure, one for policy
promotion, one for team claims, one for observability. The teams directory
is the ArgoCD git generator source — commit a claim, ArgoCD syncs it."

> Close.

"No portal. No tickets. No snowflake workflows. Git is the interface.
The platform is the backend. Everything you've seen is in this repo."

---

## Failing Claim Demo (if time permits)

**File:** `golden-path/examples/claim-database-WILL-FAIL.yaml`

```bash
# Three violations: region (PCI), size (cost), labels (governance)
kyverno apply policies/kyverno/cluster-policies/ \
  --resource golden-path/examples/claim-database-WILL-FAIL.yaml
```

---

## Slide Mapping

| Beat | Slide Topic | Duration |
|------|-------------|----------|
| 1 | Golden Path / Developer Experience | ~1.5 min |
| 2 | Platform API Contract (7 XRDs) | ~1.5 min |
| 3 | Multi-Cloud Compositions (21 total) | ~2 min |
| 4 | Kyverno Guardrails → Semantic Gap Pivot | ~2.5 min |
| 5 | Shadow Metrics — Closing the Gap | ~2 min |
| 6 | One Command + Scale (12 teams, 109 claims) | ~1.5 min |
