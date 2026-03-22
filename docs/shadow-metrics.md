# Shadow Metrics

## Concept

A Shadow Metric is a runtime measurement that evaluates whether a
policy-compliant claim is actually correct for its workload. It bridges
the [semantic gap](semantic-gap.md) between "valid" and "correct."

Shadow Metrics **never block**. They annotate claims with risk signals
that surface in dashboards and alerts. The platform team decides whether
to act on the signal.

## How It Works

1. Platform engineer authors a `ShadowMetricRule` CR
2. The rule defines a Prometheus query and thresholds
3. A Crossplane function evaluates rules every reconciliation cycle
4. Claims exceeding thresholds get annotated
5. The Grafana Shadow Metrics dashboard shows flagged claims

## Rules in This Repository

| Rule | Prometheus Signal | Thresholds |
|------|------------------|------------|
| **database-sizing** | `rate(http_requests_total[24h])` | >10k: warning (upgrade to medium), >100k: critical (upgrade to large) |
| **region-latency** | `histogram_quantile(0.95, http_request_duration_seconds)` | >500ms: warning, >1s: critical |
| **cost-efficiency** | `container_cpu_usage / resource_limits` (7d avg) | <10%: warning (over-provisioned), <5%: info (downsize candidate) |
| **ha-requirement** | `1 - (5xx_rate / total_rate)` (7d) | >99.9%: warning (needs HA), >99.99%: critical (needs HA immediately) |

## Design Decisions

**Non-blocking:** Shadow Metrics annotate; they never reject. A warning
is not a veto — it's data for human decision-making.

**Prometheus-native:** Rules use standard PromQL. Platform engineers
already know how to write these queries.

**CRD-driven:** Rules are Kubernetes resources managed via GitOps. Teams
can propose new rules via PR.

**Continuous evaluation:** Runs every reconciliation cycle, not just at
admission time. A valid claim can become wrong as traffic patterns change.

## Demo Example

The claim in `golden-path/examples/claim-shadow-metric-warning.yaml`
passes all 6 Kyverno policies. But:

- `database-sizing` would flag it: checkout handles 50k+ req/day,
  `small` is undersized
- `ha-requirement` would flag it: checkout has a 99.95% SLO but
  `highAvailability: false`

This is the demo's pivot moment: "Kyverno says allowed. The dashboard
says wrong."
