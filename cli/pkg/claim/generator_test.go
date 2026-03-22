// ABOUTME: Unit tests for claim generator — verifies YAML output matches golden path.
// ABOUTME: Tests all 7 resource types and the full-service preset.
package claim

import (
	"strings"
	"testing"
)

func TestGenerateDatabase(t *testing.T) {
	params := ClaimParams{
		Team:                "checkout",
		Size:                "small",
		Region:              "eu-west-1",
		Engine:              "postgres",
		BackupRetentionDays: 7,
	}
	yaml, err := Generate(TypeDatabase, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: DatabaseInstanceClaim")
	assertContains(t, yaml, "name: checkout-database")
	assertContains(t, yaml, "team: checkout")
	assertContains(t, yaml, "size: small")
	assertContains(t, yaml, "region: eu-west-1")
	assertContains(t, yaml, "engine: postgres")
	assertContains(t, yaml, "platform.kubecon.io/v1alpha1")
}

func TestGenerateCache(t *testing.T) {
	params := ClaimParams{
		Team:   "checkout",
		Size:   "small",
		Region: "eu-west-1",
		Engine: "redis",
	}
	yaml, err := Generate(TypeCache, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: CacheInstanceClaim")
	assertContains(t, yaml, "engine: redis")
}

func TestGenerateQueue(t *testing.T) {
	params := ClaimParams{
		Team:            "checkout",
		Region:          "eu-west-1",
		FIFO:            true,
		DeadLetterQueue: true,
	}
	yaml, err := Generate(TypeQueue, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: MessageQueueClaim")
	assertContains(t, yaml, "fifo: true")
	assertContains(t, yaml, "deadLetterQueue: true")
}

func TestGenerateStorage(t *testing.T) {
	params := ClaimParams{
		Team:       "catalog",
		Region:     "eu-west-1",
		Encryption: true,
	}
	yaml, err := Generate(TypeStorage, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: ObjectStorageClaim")
	assertContains(t, yaml, "encryption: true")
}

func TestGenerateCDN(t *testing.T) {
	params := ClaimParams{
		Team:         "catalog",
		OriginDomain: "images.example.com",
		CacheTTL:     3600,
	}
	yaml, err := Generate(TypeCDN, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: CDNDistributionClaim")
	assertContains(t, yaml, "originDomain: images.example.com")
}

func TestGenerateDNS(t *testing.T) {
	params := ClaimParams{
		Team:       "platform",
		RecordType: "CNAME",
		DNSName:    "api.platform.kubecon.io",
		DNSValue:   "lb.example.com",
		TTL:        300,
	}
	yaml, err := Generate(TypeDNS, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: DNSRecordClaim")
	assertContains(t, yaml, "recordType: CNAME")
}

func TestGenerateNamespace(t *testing.T) {
	params := ClaimParams{
		Team:        "checkout",
		CPULimit:    "8",
		MemoryLimit: "16Gi",
	}
	yaml, err := Generate(TypeNamespace, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: KubernetesNamespaceClaim")
	assertContains(t, yaml, "cpuLimit: \"8\"")
	assertContains(t, yaml, "memoryLimit: 16Gi")
}

func TestGenerateCustomName(t *testing.T) {
	params := ClaimParams{
		Team:   "checkout",
		Name:   "checkout-primary-db",
		Size:   "medium",
		Region: "eu-west-1",
		Engine: "postgres",
	}
	yaml, err := Generate(TypeDatabase, params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "name: checkout-primary-db")
}

func TestGenerateFullService(t *testing.T) {
	params := ClaimParams{
		Team:   "catalog",
		Size:   "medium",
		Region: "eu-west-1",
	}
	yaml, err := GenerateFullService(params)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertContains(t, yaml, "kind: DatabaseInstanceClaim")
	assertContains(t, yaml, "kind: CacheInstanceClaim")
	assertContains(t, yaml, "kind: MessageQueueClaim")
	assertContains(t, yaml, "kind: ObjectStorageClaim")
	assertContains(t, yaml, "name: catalog-db")
	assertContains(t, yaml, "name: catalog-cache")
	assertContains(t, yaml, "name: catalog-events")
	assertContains(t, yaml, "name: catalog-storage")

	// Should have 4 documents separated by ---
	docs := strings.Count(yaml, "---")
	if docs != 3 {
		t.Errorf("expected 3 document separators, got %d", docs)
	}
}

func TestGenerateUnknownType(t *testing.T) {
	_, err := Generate("unknown", ClaimParams{Team: "test"})
	if err == nil {
		t.Fatal("expected error for unknown type")
	}
}

func assertContains(t *testing.T, yaml, expected string) {
	t.Helper()
	if !strings.Contains(yaml, expected) {
		t.Errorf("expected YAML to contain %q, got:\n%s", expected, yaml)
	}
}
