// ABOUTME: Tests for claim parameter validation against XRD enum constraints.
// ABOUTME: Covers valid params, invalid size/region/engine for each resource type.
package claim

import (
	"strings"
	"testing"
)

func TestValidateParams_ValidDatabase(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "small", Region: "eu-west-1", Engine: "postgres"}
	if err := ValidateParams(TypeDatabase, params); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateParams_ValidCache(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "medium", Region: "eu-central-1", Engine: "redis"}
	if err := ValidateParams(TypeCache, params); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateParams_ValidQueue(t *testing.T) {
	params := ClaimParams{Team: "checkout", Region: "us-east-1"}
	if err := ValidateParams(TypeQueue, params); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateParams_EmptyTeam(t *testing.T) {
	params := ClaimParams{Size: "small", Region: "eu-west-1", Engine: "postgres"}
	err := ValidateParams(TypeDatabase, params)
	if err == nil {
		t.Fatal("expected error for empty team")
	}
	if !strings.Contains(err.Error(), "team is required") {
		t.Errorf("expected 'team is required' error, got: %v", err)
	}
}

func TestValidateParams_InvalidSize(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "xlarge", Region: "eu-west-1", Engine: "postgres"}
	err := ValidateParams(TypeDatabase, params)
	if err == nil {
		t.Fatal("expected error for invalid size")
	}
	if !strings.Contains(err.Error(), "invalid size") {
		t.Errorf("expected 'invalid size' error, got: %v", err)
	}
}

func TestValidateParams_InvalidRegion(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "small", Region: "narnia-1", Engine: "postgres"}
	err := ValidateParams(TypeDatabase, params)
	if err == nil {
		t.Fatal("expected error for invalid region")
	}
	if !strings.Contains(err.Error(), "invalid region") {
		t.Errorf("expected 'invalid region' error, got: %v", err)
	}
}

func TestValidateParams_InvalidDBEngine(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "small", Region: "eu-west-1", Engine: "oracle"}
	err := ValidateParams(TypeDatabase, params)
	if err == nil {
		t.Fatal("expected error for invalid database engine")
	}
	if !strings.Contains(err.Error(), "invalid database engine") {
		t.Errorf("expected 'invalid database engine' error, got: %v", err)
	}
}

func TestValidateParams_InvalidCacheEngine(t *testing.T) {
	params := ClaimParams{Team: "checkout", Size: "small", Region: "eu-west-1", Engine: "hazelcast"}
	err := ValidateParams(TypeCache, params)
	if err == nil {
		t.Fatal("expected error for invalid cache engine")
	}
	if !strings.Contains(err.Error(), "invalid cache engine") {
		t.Errorf("expected 'invalid cache engine' error, got: %v", err)
	}
}

func TestValidateParams_CDNSkipsSizeRegion(t *testing.T) {
	// CDN doesn't validate size or region
	params := ClaimParams{Team: "catalog", Size: "anything", Region: "anywhere"}
	if err := ValidateParams(TypeCDN, params); err != nil {
		t.Fatalf("CDN should not validate size/region, got: %v", err)
	}
}

func TestValidateParams_DNSSkipsSizeRegion(t *testing.T) {
	params := ClaimParams{Team: "platform"}
	if err := ValidateParams(TypeDNS, params); err != nil {
		t.Fatalf("DNS should not validate size/region, got: %v", err)
	}
}

func TestValidateParams_AllValidSizes(t *testing.T) {
	for _, size := range ValidSizes {
		params := ClaimParams{Team: "checkout", Size: size, Region: "eu-west-1", Engine: "postgres"}
		if err := ValidateParams(TypeDatabase, params); err != nil {
			t.Errorf("size %q should be valid, got: %v", size, err)
		}
	}
}

func TestValidateParams_AllValidRegions(t *testing.T) {
	for _, region := range ValidRegions {
		params := ClaimParams{Team: "checkout", Size: "small", Region: region, Engine: "postgres"}
		if err := ValidateParams(TypeDatabase, params); err != nil {
			t.Errorf("region %q should be valid, got: %v", region, err)
		}
	}
}
