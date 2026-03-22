# ABOUTME: OPA policy enforcing per-team size caps for DatabaseInstance claims.
# ABOUTME: Includes semantic gap commentary — the talk's pivot to Shadow Metrics.
package platform.size

import rego.v1

# Size ordering for comparison
size_rank := {
    "small": 1,
    "medium": 2,
    "large": 3,
}

# Maximum allowed size per team
# checkout: capped at medium (cost control, workload doesn't need large)
# payments: capped at large (transaction volume justifies it)
# analytics: capped at medium (read replicas preferred over vertical scaling)
# platform: capped at large (infrastructure team, full access)
team_max_size := {
    "checkout": "medium",
    "payments": "large",
    "analytics": "medium",
    "platform": "large",
}

claim := input.review.object

deny contains msg if {
    team := claim.spec.team
    not team_max_size[team]
    msg := sprintf("Unknown team '%s'. No size policy defined. Contact platform-team to onboard.", [team])
}

deny contains msg if {
    team := claim.spec.team
    requested := claim.spec.size
    max_allowed := team_max_size[team]
    size_rank[requested] > size_rank[max_allowed]
    msg := sprintf("Team '%s' requested size '%s' but is capped at '%s'.", [team, requested, max_allowed])
}

# =============================================================================
# THE SEMANTIC GAP — READ THIS ALOUD DURING THE TALK
# =============================================================================
#
# Everything above validates what is ALLOWED. It does not validate what
# makes SENSE.
#
# A request for { size: "small", region: "eu-west-1", team: "checkout" }
# will pass every policy in this file. OPA says "yes, this is permitted."
#
# But is it RIGHT?
#
# - Is small enough for checkout's Black Friday traffic?
# - Is eu-west-1 where checkout's users actually are?
# - Will this database's latency meet the SLO that checkout promised?
#
# OPA cannot answer these questions. Neither can Crossplane. Neither can
# any guardrail that operates on the CLAIM alone.
#
# To answer them, you need RUNTIME DATA:
#   - Current request rates (from Prometheus)
#   - Latency percentiles (from your SLO dashboard)
#   - Cost-per-query trends (from your FinOps tooling)
#   - Deployment history (from ArgoCD)
#
# This is the semantic gap between "valid" and "correct." Policies enforce
# the boundaries. But the space inside those boundaries is vast, and most
# production incidents happen there — with perfectly valid configurations
# that are wrong for the workload.
#
# This is where Shadow Metrics come in.
#
# [TRANSITION TO SLIDE: "Shadow Metrics — Closing the Semantic Gap"]
# =============================================================================
