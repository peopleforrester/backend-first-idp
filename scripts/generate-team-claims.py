#!/usr/bin/env python3
# ABOUTME: Generates team claim YAML files from the teams.yaml manifest.
# ABOUTME: Produces 100+ claims across 12 teams for the "100+ service environment."

import yaml
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
TEAMS_FILE = SCRIPT_DIR / "teams.yaml"
TEAMS_DIR = REPO_ROOT / "teams"

# Resource type → (apiVersion, kind, claim_kind)
RESOURCE_MAP = {
    "database": ("platform.kubecon.io/v1alpha1", "DatabaseInstanceClaim"),
    "cache": ("platform.kubecon.io/v1alpha1", "CacheInstanceClaim"),
    "message-queue": ("platform.kubecon.io/v1alpha1", "MessageQueueClaim"),
    "object-storage": ("platform.kubecon.io/v1alpha1", "ObjectStorageClaim"),
    "cdn": ("platform.kubecon.io/v1alpha1", "CDNDistributionClaim"),
    "dns": ("platform.kubecon.io/v1alpha1", "DNSRecordClaim"),
    "namespace": ("platform.kubecon.io/v1alpha1", "KubernetesNamespaceClaim"),
}

# Default spec fields per resource type
DEFAULT_SPECS = {
    "database": {"engine": "postgres", "backupRetentionDays": 7},
    "cache": {"engine": "redis"},
    "message-queue": {"messageRetentionDays": 4, "fifo": False},
    "object-storage": {"versioning": False, "encryption": True},
    "cdn": {"cacheTtlSeconds": 86400, "httpsOnly": True},
    "dns": {},
    "namespace": {"cpuLimit": "4", "memoryLimit": "8Gi"},
}


def generate_claim(
    team_name: str,
    resource: dict,
    default_region: str,
) -> str:
    """Generate a single claim YAML string."""
    res_type = resource["type"]
    api_version, kind = RESOURCE_MAP[res_type]
    name = resource["name"]
    region = resource.get("region", default_region)

    # Build spec
    spec = {"team": team_name}

    # Add region for resources that use it
    if res_type not in ("cdn", "dns", "namespace"):
        spec["region"] = region

    # Add size if specified
    if "size" in resource:
        spec["size"] = resource["size"]

    # Merge type-specific defaults, then resource overrides
    defaults = DEFAULT_SPECS.get(res_type, {})
    for k, v in defaults.items():
        if k not in resource:
            spec[k] = v

    # Apply explicit overrides from the resource definition
    skip_keys = {"type", "name", "region"}
    for k, v in resource.items():
        if k not in skip_keys:
            spec[k] = v

    # CDN needs originDomain
    if res_type == "cdn" and "originDomain" not in spec:
        spec["originDomain"] = f"{name}.example.com"

    # Build the full manifest
    manifest = {
        "apiVersion": api_version,
        "kind": kind,
        "metadata": {
            "name": name,
            "namespace": team_name,
            "labels": {"team": team_name},
        },
        "spec": spec,
    }

    # Generate YAML with ABOUTME comments
    lines = [
        f"# ABOUTME: {kind} for {team_name} team — {name}.",
        f"# ABOUTME: Generated from scripts/teams.yaml by generate-team-claims.py.",
    ]
    yaml_str = yaml.dump(manifest, default_flow_style=False, sort_keys=False)
    lines.append(yaml_str)
    return "\n".join(lines)


def main() -> None:
    """Main entry point."""
    with open(TEAMS_FILE) as f:
        data = yaml.safe_load(f)

    teams = data["teams"]
    total_claims = 0

    for team_name, team_config in teams.items():
        default_region = team_config.get("region", "eu-west-1")
        resources = team_config.get("resources", [])

        # Create team claims directory
        claims_dir = TEAMS_DIR / team_name / "claims"
        claims_dir.mkdir(parents=True, exist_ok=True)

        for resource in resources:
            name = resource["name"]
            claim_yaml = generate_claim(team_name, resource, default_region)

            # Write claim file
            claim_file = claims_dir / f"{name}.yaml"
            claim_file.write_text(claim_yaml)
            total_claims += 1

        print(f"  {team_name}: {len(resources)} claims")

    # Second pass: generate environment variants for database and cache claims.
    # This simulates the realistic pattern where teams have dev/staging/prod
    # instances of their core data stores.
    ENV_VARIANTS = ["dev", "staging"]  # prod is the base claim already
    VARIANT_TYPES = {"database", "cache"}
    env_claims = 0

    for team_name, team_config in teams.items():
        default_region = team_config.get("region", "eu-west-1")
        resources = team_config.get("resources", [])

        claims_dir = TEAMS_DIR / team_name / "claims"

        for resource in resources:
            if resource["type"] not in VARIANT_TYPES:
                continue
            base_name = resource["name"]

            for env in ENV_VARIANTS:
                variant = dict(resource)
                variant["name"] = f"{base_name}-{env}"
                # Dev/staging get small size regardless
                variant["size"] = "small"
                # No HA for non-prod
                variant.pop("highAvailability", None)
                # Shorter backups for non-prod
                if "backupRetentionDays" in variant:
                    variant["backupRetentionDays"] = 3

                claim_yaml = generate_claim(team_name, variant, default_region)
                claim_file = claims_dir / f"{variant['name']}.yaml"
                claim_file.write_text(claim_yaml)
                env_claims += 1

    total_claims += env_claims
    print(f"  + {env_claims} environment variants (dev/staging)")
    print(f"\nTotal: {total_claims} claims across {len(teams)} teams")

    if total_claims < 100:
        print(f"WARNING: Only {total_claims} claims generated. Target is 100+.")
        sys.exit(1)
    else:
        print(f"Target met: {total_claims} >= 100")


if __name__ == "__main__":
    main()
