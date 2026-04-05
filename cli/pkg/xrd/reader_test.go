// ABOUTME: Tests for XRD reader — discovers resource types from platform-api/xrds/.
// ABOUTME: Validates against the real XRD files in the repository.
package xrd

import (
	"os"
	"path/filepath"
	"testing"
)

func findRepoRoot(t *testing.T) string {
	t.Helper()
	// Walk up from test file to find repo root (has platform-api/xrds/)
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getting working directory: %v", err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "platform-api", "xrds")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Skip("could not find repo root with platform-api/xrds/")
		}
		dir = parent
	}
}

func TestDiscoverTypes_FindsAllXRDs(t *testing.T) {
	root := findRepoRoot(t)
	resources, err := DiscoverTypes(root)
	if err != nil {
		t.Fatalf("DiscoverTypes failed: %v", err)
	}

	if len(resources) != 7 {
		t.Fatalf("expected 7 resource types, got %d", len(resources))
	}
}

func TestDiscoverTypes_ExpectedKinds(t *testing.T) {
	root := findRepoRoot(t)
	resources, err := DiscoverTypes(root)
	if err != nil {
		t.Fatalf("DiscoverTypes failed: %v", err)
	}

	expectedKinds := map[string]bool{
		"DatabaseInstance":    false,
		"CacheInstance":       false,
		"MessageQueue":        false,
		"ObjectStorage":       false,
		"CDNDistribution":     false,
		"DNSRecord":           false,
		"KubernetesNamespace": false,
	}

	for _, r := range resources {
		if _, ok := expectedKinds[r.Kind]; ok {
			expectedKinds[r.Kind] = true
		} else {
			t.Errorf("unexpected kind: %s", r.Kind)
		}
	}

	for kind, found := range expectedKinds {
		if !found {
			t.Errorf("expected kind %s not found in XRDs", kind)
		}
	}
}

func TestDiscoverTypes_DatabaseHasEnums(t *testing.T) {
	root := findRepoRoot(t)
	resources, err := DiscoverTypes(root)
	if err != nil {
		t.Fatalf("DiscoverTypes failed: %v", err)
	}

	var dbInfo *ResourceInfo
	for i := range resources {
		if resources[i].Kind == "DatabaseInstance" {
			dbInfo = &resources[i]
			break
		}
	}
	if dbInfo == nil {
		t.Fatal("DatabaseInstance not found")
	}

	if dbInfo.ClaimKind != "DatabaseInstanceClaim" {
		t.Errorf("expected claim kind DatabaseInstanceClaim, got %s", dbInfo.ClaimKind)
	}

	// Check that size field has enums
	var sizeField *FieldInfo
	for i := range dbInfo.Fields {
		if dbInfo.Fields[i].Name == "size" {
			sizeField = &dbInfo.Fields[i]
			break
		}
	}
	if sizeField == nil {
		t.Fatal("size field not found on DatabaseInstance")
	}
	if len(sizeField.Enum) == 0 {
		t.Error("size field should have enum values")
	}
}

func TestDiscoverTypes_InvalidDir(t *testing.T) {
	_, err := DiscoverTypes("/nonexistent/path")
	if err == nil {
		t.Fatal("expected error for invalid path")
	}
}
