# ABOUTME: Unit tests for region-allowed policy — team-to-region enforcement.
# ABOUTME: Covers EU-only teams, US+EU teams, platform (all), and unknown teams.
package platform.region_test

import rego.v1

import data.platform.region

# --- checkout team: EU only ---
test_checkout_eu_west_allowed if {
    count(region.deny) == 0 with input as _claim("checkout", "eu-west-1", "small")
}

test_checkout_eu_central_allowed if {
    count(region.deny) == 0 with input as _claim("checkout", "eu-central-1", "small")
}

test_checkout_us_east_denied if {
    count(region.deny) > 0 with input as _claim("checkout", "us-east-1", "small")
}

test_checkout_us_west_denied if {
    count(region.deny) > 0 with input as _claim("checkout", "us-west-2", "small")
}

# --- payments team: EU only (PCI) ---
test_payments_eu_west_allowed if {
    count(region.deny) == 0 with input as _claim("payments", "eu-west-1", "small")
}

test_payments_us_east_denied if {
    count(region.deny) > 0 with input as _claim("payments", "us-east-1", "small")
}

# --- analytics team: US + EU ---
test_analytics_eu_west_allowed if {
    count(region.deny) == 0 with input as _claim("analytics", "eu-west-1", "small")
}

test_analytics_us_east_allowed if {
    count(region.deny) == 0 with input as _claim("analytics", "us-east-1", "small")
}

test_analytics_us_west_allowed if {
    count(region.deny) == 0 with input as _claim("analytics", "us-west-2", "small")
}

# --- platform team: all regions ---
test_platform_eu_west_allowed if {
    count(region.deny) == 0 with input as _claim("platform", "eu-west-1", "small")
}

test_platform_us_west_allowed if {
    count(region.deny) == 0 with input as _claim("platform", "us-west-2", "small")
}

# --- unknown team: always denied ---
test_unknown_team_denied if {
    count(region.deny) > 0 with input as _claim("rogue-team", "eu-west-1", "small")
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
