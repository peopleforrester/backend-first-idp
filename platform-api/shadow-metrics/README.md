# Shadow Metrics — Closing the Semantic Gap

## The Problem

Admission policies (Kyverno, OPA, ValidatingAdmissionPolicy) validate what is
**allowed**. They cannot validate what **makes sense** for a workload.

A claim requesting `size: small, region: eu-west-1, team: checkout` will pass
every policy. But is it **right**?

- Is `small` enough for checkout's Black Friday traffic?
- Is `eu-west-1` where checkout's users actually are?
- Will this database's latency meet the SLO that checkout promised?

This is the **semantic gap** — the space between "valid" and "correct." Most
production incidents happen here, with perfectly valid configurations that are
wrong for their workload.

## The Solution: Shadow Metrics

A Shadow Metric is a runtime measurement that evaluates whether a valid claim
configuration is correct for its workload. Shadow Metrics **do not block** —
they annotate claims with risk signals that surface in dashboards and alerts.

### How It Works

```
1. Platform engineer authors a ShadowMetricRule CR
2. The rule defines:
   - Which claim kinds to evaluate
   - A Prometheus query to run
   - Thresholds that indicate a mismatch
   - An action (annotate, emit event, expose metric)
3. The evaluation function runs every reconciliation cycle
4. Claims that exceed thresholds get annotated
5. The Shadow Metrics Grafana dashboard shows flagged claims
```

### Architecture

```
┌──────────────────┐     ┌────────────────────┐
│ ShadowMetricRule │     │   Prometheus        │
│   (CRD)          │────▶│   Query Evaluation  │
│                  │     │                     │
│ - appliesTo      │     │ sum(rate(           │
│ - prometheusQuery│     │   http_requests_... │
│ - thresholds     │     │ ))                  │
└──────────────────┘     └─────────┬──────────┘
                                   │
                                   ▼
                         ┌────────────────────┐
                         │  Threshold Check    │
                         │                     │
                         │  > 10000 → warning  │
                         │  > 100000 → critical│
                         └─────────┬──────────┘
                                   │
                         ┌─────────▼──────────┐
                         │  Annotate Claim     │
                         │                     │
                         │  platform.kubecon.io│
                         │  /shadow-metric-... │
                         └─────────┬──────────┘
                                   │
                         ┌─────────▼──────────┐
                         │  Grafana Dashboard  │
                         │                     │
                         │  "3 claims flagged" │
                         │  "checkout-db:      │
                         │   undersized"       │
                         └────────────────────┘
```

## Rules in This Repository

| Rule | What It Checks | Signal Source |
|------|---------------|---------------|
| `database-sizing` | Is the DB size right for traffic volume? | `http_requests_total` rate |
| `region-latency` | Is the region optimal for users? | `http_request_duration_seconds` p95 |
| `cost-efficiency` | Is the resource over-provisioned? | CPU utilization vs limits (7d avg) |
| `ha-requirement` | Should HA be enabled based on SLO? | Error rate / uptime calculation |

## Demo Flow

> **Beat 4:** Show Kyverno policies → read the semantic gap annotation
>
> **Beat 4.5:** "This is where Shadow Metrics come in."
> - Show the `ShadowMetricRule` CRD
> - Show the Prometheus query in `database-sizing.yaml`
> - Show the Grafana Shadow Metrics dashboard
> - "The claim passed policy. But the dashboard says: **WARNING — undersized for traffic.**"

## Key Design Decisions

1. **Non-blocking:** Shadow Metrics annotate; they never reject. The platform
   team decides whether to act on the signal.

2. **Prometheus-native:** Rules use standard PromQL. No custom query language.
   Platform engineers already know how to write these queries.

3. **CRD-driven:** Rules are Kubernetes resources, managed via GitOps like
   everything else in the platform. Teams can propose new rules via PR.

4. **Continuous evaluation:** Runs every reconciliation cycle, not just at
   admission time. A valid claim can become wrong as traffic patterns change.
