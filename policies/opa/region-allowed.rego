# ABOUTME: OPA policy enforcing team-to-region constraints for DatabaseInstance claims.
# ABOUTME: checkout/payments restricted to EU (PCI), analytics to US+EU, platform to all.
package platform.region

import rego.v1

# Team-to-allowed-region mapping
# checkout and payments: EU only (PCI-DSS data residency)
# analytics: US + EU
# platform: all regions (infrastructure team)
team_regions := {
    "checkout": {"eu-west-1", "eu-central-1"},
    "payments": {"eu-west-1", "eu-central-1"},
    "analytics": {"eu-west-1", "eu-central-1", "us-east-1", "us-west-2"},
    "platform": {"eu-west-1", "eu-central-1", "us-east-1", "us-west-2"},
}

claim := input.review.object

deny contains msg if {
    team := claim.spec.team
    not team_regions[team]
    msg := sprintf("Unknown team '%s'. Contact platform-team to onboard.", [team])
}

deny contains msg if {
    team := claim.spec.team
    region := claim.spec.region
    allowed := team_regions[team]
    not region in allowed
    msg := sprintf("Team '%s' is not allowed to deploy in region '%s'. Allowed regions: %v", [team, region, allowed])
}
