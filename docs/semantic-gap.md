# The Semantic Gap

## Definition

The semantic gap is the space between a configuration that is **valid**
(passes all admission policies) and one that is **correct** (actually
appropriate for the workload it serves).

## The Problem

Admission policies — whether Kyverno, OPA, or ValidatingAdmissionPolicy —
operate on the **claim** alone. They can enforce:

- Is this team allowed in this region? (compliance)
- Is this size within the team's cap? (cost control)
- Does this claim have the required labels? (governance)

What they cannot evaluate:

- Is `small` enough for this team's actual traffic volume?
- Is `eu-west-1` where this team's users actually are?
- Will this database's latency meet the SLO the team promised?
- Is the cost justified by the workload's business value?

These questions require **runtime data** — request rates, latency
percentiles, utilization metrics, cost trends — that doesn't exist
at admission time.

## Why It Matters

Most production incidents happen inside the policy boundaries.
The configuration was valid. It just wasn't right.

- A `small` database passes every policy but falls over under Black Friday traffic
- An `eu-west-1` deployment is compliant but the users are in `us-east-1`
- A non-HA database meets the dev team's requirements but backs a 99.95% SLO service

These are not policy failures. They're **semantic failures** — the gap
between what the platform allows and what the workload needs.

## The Solution: Shadow Metrics

Shadow Metrics close the semantic gap by evaluating claims against
runtime data from Prometheus. They don't block — they annotate claims
with risk signals that surface in Grafana dashboards.

See [shadow-metrics.md](shadow-metrics.md) for the implementation.

## In the Talk

The semantic gap is the pivot point in Beat 4 of the demo. After showing
Kyverno policies, the speaker reads the annotation on `size-caps.yaml`
and transitions to Shadow Metrics:

> "Everything above validates what is ALLOWED. It does not validate
> what makes SENSE."

This transitions to Beat 5 (Shadow Metrics) where the audience sees
a claim that passes all policies but triggers a shadow metric warning.
