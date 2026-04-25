// ABOUTME: Input validation for claim parameters against XRD enum values.
// ABOUTME: Catches invalid size, region, and engine before YAML generation.
package claim

import (
	"fmt"
	"strings"
)

// Valid enum values matching platform-api/xrds/ definitions.
var (
	ValidSizes   = []string{"small", "medium", "large"}
	ValidRegions = []string{"eu-west-1", "eu-central-1", "us-east-1", "us-west-2"}
	ValidDBEngines    = []string{"postgres", "mysql"}
	ValidCacheEngines = []string{"redis", "memcached"}
)

// ValidateParams checks claim parameters against XRD enum constraints.
func ValidateParams(rt ResourceType, params ClaimParams) error {
	if params.Team == "" {
		return fmt.Errorf("team is required")
	}

	// Size validation (applies to database, cache)
	if rt == TypeDatabase || rt == TypeCache {
		if !contains(ValidSizes, params.Size) {
			return fmt.Errorf("invalid size: %q. Valid: %s", params.Size, strings.Join(ValidSizes, ", "))
		}
	}

	// Region validation (applies to all types that have a region field)
	switch rt {
	case TypeDatabase, TypeCache, TypeQueue, TypeStorage:
		if !contains(ValidRegions, params.Region) {
			return fmt.Errorf("invalid region: %q. Valid: %s", params.Region, strings.Join(ValidRegions, ", "))
		}
	}

	// Engine validation. Empty string is treated as "use the XRD default"
	// (postgres for database, redis for cache) so callers that don't pre-fill
	// the field still pass — the XRD itself materializes the default at apply
	// time. Non-empty unknown values are still rejected.
	switch rt {
	case TypeDatabase:
		if params.Engine != "" && !contains(ValidDBEngines, params.Engine) {
			return fmt.Errorf("invalid database engine: %q. Valid: %s", params.Engine, strings.Join(ValidDBEngines, ", "))
		}
	case TypeCache:
		if params.Engine != "" && !contains(ValidCacheEngines, params.Engine) {
			return fmt.Errorf("invalid cache engine: %q. Valid: %s", params.Engine, strings.Join(ValidCacheEngines, ", "))
		}
	}

	return nil
}

func contains(slice []string, val string) bool {
	for _, s := range slice {
		if s == val {
			return true
		}
	}
	return false
}
