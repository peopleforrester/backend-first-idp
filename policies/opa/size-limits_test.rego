# ABOUTME: Unit tests for size-limits policy — team tier size caps.
# ABOUTME: Covers per-team size enforcement and boundary cases.
package platform.size_test

import rego.v1

import data.platform.size

# --- checkout: capped at medium ---
test_checkout_small_allowed if {
    count(size.deny) == 0 with input as _claim("checkout", "eu-west-1", "small")
}

test_checkout_medium_allowed if {
    count(size.deny) == 0 with input as _claim("checkout", "eu-west-1", "medium")
}

test_checkout_large_denied if {
    count(size.deny) > 0 with input as _claim("checkout", "eu-west-1", "large")
}

# --- payments: capped at large (all sizes allowed) ---
test_payments_small_allowed if {
    count(size.deny) == 0 with input as _claim("payments", "eu-west-1", "small")
}

test_payments_large_allowed if {
    count(size.deny) == 0 with input as _claim("payments", "eu-west-1", "large")
}

# --- analytics: capped at medium ---
test_analytics_medium_allowed if {
    count(size.deny) == 0 with input as _claim("analytics", "us-east-1", "medium")
}

test_analytics_large_denied if {
    count(size.deny) > 0 with input as _claim("analytics", "us-east-1", "large")
}

# --- platform: capped at large (all sizes allowed) ---
test_platform_large_allowed if {
    count(size.deny) == 0 with input as _claim("platform", "eu-west-1", "large")
}

# --- unknown team: no size cap defined, should deny ---
test_unknown_team_denied if {
    count(size.deny) > 0 with input as _claim("rogue-team", "eu-west-1", "small")
}

# Helper: build a minimal claim input
_claim(team, region, size) := {"review": {"object": {
    "apiVersion": "platform.kubecon.io/v1alpha1",
    "kind": "DatabaseInstanceClaim",
    "spec": {
        "team": team,
        "region": region,
        "size": size,
    },
}}}
