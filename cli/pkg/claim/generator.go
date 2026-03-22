// ABOUTME: Claim YAML generator — produces valid platform claims from parameters.
// ABOUTME: Templates mirror the golden-path examples exactly.
package claim

import (
	"bytes"
	"fmt"
	"text/template"
)

// ClaimParams holds the parameters for generating a claim.
type ClaimParams struct {
	Team               string
	Name               string
	Size               string
	Region             string
	Engine             string
	HighAvailability   bool
	BackupRetentionDays int
	// Queue-specific
	FIFO             bool
	DeadLetterQueue  bool
	MessageRetention int
	// Storage-specific
	Versioning bool
	Encryption bool
	// CDN-specific
	OriginDomain string
	CacheTTL     int
	// Namespace-specific
	CPULimit    string
	MemoryLimit string
	// DNS-specific
	RecordType string
	DNSName    string
	DNSValue   string
	TTL        int
}

// ResourceType represents a platform resource type.
type ResourceType string

const (
	TypeDatabase  ResourceType = "database"
	TypeCache     ResourceType = "cache"
	TypeQueue     ResourceType = "queue"
	TypeStorage   ResourceType = "storage"
	TypeCDN       ResourceType = "cdn"
	TypeDNS       ResourceType = "dns"
	TypeNamespace ResourceType = "namespace"
)

var templates = map[ResourceType]string{
	TypeDatabase: `apiVersion: platform.kubecon.io/v1alpha1
kind: DatabaseInstanceClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  size: {{ .Size }}
  region: {{ .Region }}
  team: {{ .Team }}
  engine: {{ .Engine }}
  highAvailability: {{ .HighAvailability }}
  backupRetentionDays: {{ .BackupRetentionDays }}
`,
	TypeCache: `apiVersion: platform.kubecon.io/v1alpha1
kind: CacheInstanceClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  size: {{ .Size }}
  region: {{ .Region }}
  team: {{ .Team }}
  engine: {{ .Engine }}
`,
	TypeQueue: `apiVersion: platform.kubecon.io/v1alpha1
kind: MessageQueueClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  region: {{ .Region }}
  team: {{ .Team }}
  fifo: {{ .FIFO }}
  deadLetterQueue: {{ .DeadLetterQueue }}
`,
	TypeStorage: `apiVersion: platform.kubecon.io/v1alpha1
kind: ObjectStorageClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  region: {{ .Region }}
  team: {{ .Team }}
  versioning: {{ .Versioning }}
  encryption: {{ .Encryption }}
`,
	TypeCDN: `apiVersion: platform.kubecon.io/v1alpha1
kind: CDNDistributionClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  team: {{ .Team }}
  originDomain: {{ .OriginDomain }}
  cacheTtlSeconds: {{ .CacheTTL }}
`,
	TypeDNS: `apiVersion: platform.kubecon.io/v1alpha1
kind: DNSRecordClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  team: {{ .Team }}
  recordType: {{ .RecordType }}
  name: {{ .DNSName }}
  value: {{ .DNSValue }}
  ttl: {{ .TTL }}
`,
	TypeNamespace: `apiVersion: platform.kubecon.io/v1alpha1
kind: KubernetesNamespaceClaim
metadata:
  name: {{ .Name }}
  namespace: {{ .Team }}
  labels:
    team: {{ .Team }}
spec:
  team: {{ .Team }}
  cpuLimit: "{{ .CPULimit }}"
  memoryLimit: {{ .MemoryLimit }}
`,
}

// Generate produces claim YAML for the given resource type and parameters.
func Generate(resourceType ResourceType, params ClaimParams) (string, error) {
	tmplStr, ok := templates[resourceType]
	if !ok {
		return "", fmt.Errorf("unknown resource type: %s", resourceType)
	}

	// Default the name if not set
	if params.Name == "" {
		params.Name = fmt.Sprintf("%s-%s", params.Team, resourceType)
	}

	tmpl, err := template.New(string(resourceType)).Parse(tmplStr)
	if err != nil {
		return "", fmt.Errorf("parsing template for %s: %w", resourceType, err)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, params); err != nil {
		return "", fmt.Errorf("executing template for %s: %w", resourceType, err)
	}

	return buf.String(), nil
}

// GenerateFullService produces claims for DB + cache + queue + storage.
func GenerateFullService(params ClaimParams) (string, error) {
	var result bytes.Buffer

	dbParams := params
	dbParams.Name = params.Team + "-db"
	if dbParams.Engine == "" {
		dbParams.Engine = "postgres"
	}
	if dbParams.BackupRetentionDays == 0 {
		dbParams.BackupRetentionDays = 7
	}
	db, err := Generate(TypeDatabase, dbParams)
	if err != nil {
		return "", err
	}
	result.WriteString(db)

	result.WriteString("---\n")
	cacheParams := params
	cacheParams.Name = params.Team + "-cache"
	if cacheParams.Engine == "" {
		cacheParams.Engine = "redis"
	}
	cache, err := Generate(TypeCache, cacheParams)
	if err != nil {
		return "", err
	}
	result.WriteString(cache)

	result.WriteString("---\n")
	queueParams := params
	queueParams.Name = params.Team + "-events"
	queueParams.DeadLetterQueue = true
	queue, err := Generate(TypeQueue, queueParams)
	if err != nil {
		return "", err
	}
	result.WriteString(queue)

	result.WriteString("---\n")
	storageParams := params
	storageParams.Name = params.Team + "-storage"
	storageParams.Encryption = true
	storage, err := Generate(TypeStorage, storageParams)
	if err != nil {
		return "", err
	}
	result.WriteString(storage)

	return result.String(), nil
}
