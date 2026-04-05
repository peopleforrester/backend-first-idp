// ABOUTME: Create command — generates platform resource claims from flags.
// ABOUTME: Subcommands for each resource type: database, cache, queue, storage, cdn, dns, namespace, service.
package cmd

import (
	"fmt"
	"os"

	"github.com/peopleforrester/backend-first-idp/cli/pkg/claim"
	gitpkg "github.com/peopleforrester/backend-first-idp/cli/pkg/git"
	"github.com/spf13/cobra"
)

var (
	flagTeam               string
	flagSize               string
	flagRegion             string
	flagEngine             string
	flagHA                 bool
	flagBackupDays         int
	flagName               string
	flagDryRun             bool
	flagSubmit             bool
	flagFIFO               bool
	flagDLQ                bool
	flagVersioning         bool
	flagEncryption         bool
	flagOriginDomain       string
	flagCacheTTL           int
	flagCPULimit           string
	flagMemoryLimit        string
	flagRecordType         string
	flagDNSName            string
	flagDNSValue           string
	flagTTL                int
	flagMessageRetention   int
)

var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a platform resource claim",
	Long:  "Generate claim YAML for a platform resource. Use subcommands for specific types.",
}

func init() {
	rootCmd.AddCommand(createCmd)

	// Register all resource subcommands
	for _, sub := range []struct {
		name  string
		short string
		rt    claim.ResourceType
	}{
		{"database", "Create a database claim (PostgreSQL/MySQL)", claim.TypeDatabase},
		{"cache", "Create a cache claim (Redis/Memcached)", claim.TypeCache},
		{"queue", "Create a message queue claim (SQS/PubSub/ServiceBus)", claim.TypeQueue},
		{"storage", "Create an object storage claim (S3/GCS/Blob)", claim.TypeStorage},
		{"cdn", "Create a CDN distribution claim (CloudFront/CDN/FrontDoor)", claim.TypeCDN},
		{"dns", "Create a DNS record claim (Route53/CloudDNS/AzureDNS)", claim.TypeDNS},
		{"namespace", "Create a Kubernetes namespace claim (NS+RBAC+Quota)", claim.TypeNamespace},
	} {
		rt := sub.rt
		c := &cobra.Command{
			Use:   sub.name,
			Short: sub.short,
			RunE: func(cmd *cobra.Command, args []string) error {
				return runCreate(rt)
			},
		}
		addCommonFlags(c)
		addTypeFlags(c, rt)
		createCmd.AddCommand(c)
	}

	// Full service preset
	serviceCmd := &cobra.Command{
		Use:   "service",
		Short: "Create a full service (DB + cache + queue + storage)",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runCreateService()
		},
	}
	addCommonFlags(serviceCmd)
	createCmd.AddCommand(serviceCmd)
}

func addCommonFlags(c *cobra.Command) {
	c.Flags().StringVar(&flagTeam, "team", "", "Team name (required)")
	c.Flags().StringVar(&flagName, "name", "", "Claim name (default: {team}-{type})")
	c.Flags().StringVar(&flagSize, "size", "small", "Instance size: small, medium, large")
	c.Flags().StringVar(&flagRegion, "region", "eu-west-1", "Region: eu-west-1, eu-central-1, us-east-1, us-west-2")
	c.Flags().BoolVar(&flagDryRun, "dry-run", false, "Print YAML without writing")
	c.Flags().BoolVar(&flagSubmit, "submit", false, "Write to teams/{team}/claims/, commit, and push")
	_ = c.MarkFlagRequired("team")
}

func addTypeFlags(c *cobra.Command, rt claim.ResourceType) {
	switch rt {
	case claim.TypeDatabase:
		c.Flags().StringVar(&flagEngine, "engine", "postgres", "Database engine: postgres, mysql")
		c.Flags().BoolVar(&flagHA, "ha", false, "Enable high availability")
		c.Flags().IntVar(&flagBackupDays, "backup-days", 7, "Backup retention days (1-35)")
	case claim.TypeCache:
		c.Flags().StringVar(&flagEngine, "engine", "redis", "Cache engine: redis, memcached")
	case claim.TypeQueue:
		c.Flags().BoolVar(&flagFIFO, "fifo", false, "Enable FIFO ordering")
		c.Flags().BoolVar(&flagDLQ, "dlq", true, "Create dead-letter queue")
		c.Flags().IntVar(&flagMessageRetention, "retention-days", 4, "Message retention days")
	case claim.TypeStorage:
		c.Flags().BoolVar(&flagVersioning, "versioning", false, "Enable object versioning")
		c.Flags().BoolVar(&flagEncryption, "encryption", true, "Enable server-side encryption")
	case claim.TypeCDN:
		c.Flags().StringVar(&flagOriginDomain, "origin", "", "Origin domain (required)")
		c.Flags().IntVar(&flagCacheTTL, "cache-ttl", 86400, "Cache TTL in seconds")
	case claim.TypeDNS:
		c.Flags().StringVar(&flagRecordType, "type", "A", "Record type: A, AAAA, CNAME, TXT, MX")
		c.Flags().StringVar(&flagDNSName, "dns-name", "", "DNS record name (required)")
		c.Flags().StringVar(&flagDNSValue, "dns-value", "", "DNS record value (required)")
		c.Flags().IntVar(&flagTTL, "ttl", 300, "TTL in seconds")
	case claim.TypeNamespace:
		c.Flags().StringVar(&flagCPULimit, "cpu-limit", "4", "Namespace CPU limit")
		c.Flags().StringVar(&flagMemoryLimit, "memory-limit", "8Gi", "Namespace memory limit")
	}
}

func buildParams() claim.ClaimParams {
	return claim.ClaimParams{
		Team:                flagTeam,
		Name:                flagName,
		Size:                flagSize,
		Region:              flagRegion,
		Engine:              flagEngine,
		HighAvailability:    flagHA,
		BackupRetentionDays: flagBackupDays,
		FIFO:                flagFIFO,
		DeadLetterQueue:     flagDLQ,
		MessageRetention:    flagMessageRetention,
		Versioning:          flagVersioning,
		Encryption:          flagEncryption,
		OriginDomain:        flagOriginDomain,
		CacheTTL:            flagCacheTTL,
		CPULimit:            flagCPULimit,
		MemoryLimit:         flagMemoryLimit,
		RecordType:          flagRecordType,
		DNSName:             flagDNSName,
		DNSValue:            flagDNSValue,
		TTL:                 flagTTL,
	}
}

func runCreate(rt claim.ResourceType) error {
	params := buildParams()
	if err := claim.ValidateParams(rt, params); err != nil {
		return err
	}
	yaml, err := claim.Generate(rt, params)
	if err != nil {
		return err
	}

	if flagDryRun || !flagSubmit {
		fmt.Print(yaml)
		return nil
	}

	// Validate before submitting
	if repoRoot != "" {
		fmt.Println("Validating against Kyverno policies...")
		output, err := claim.ValidateYAML(repoRoot, yaml)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Policy validation failed:\n%s\n", output)
			return fmt.Errorf("claim rejected by policy")
		}
		fmt.Println("  Validation passed.")
	}

	claimName := params.Name
	if claimName == "" {
		claimName = fmt.Sprintf("%s-%s", flagTeam, rt)
	}
	return gitpkg.Submit(repoRoot, flagTeam, claimName, yaml)
}

func runCreateService() error {
	params := buildParams()
	params.Engine = "postgres"
	// Validate core params (region applies to all service sub-resources)
	if err := claim.ValidateParams(claim.TypeDatabase, params); err != nil {
		return err
	}
	yaml, err := claim.GenerateFullService(params)
	if err != nil {
		return err
	}

	if flagDryRun || !flagSubmit {
		fmt.Print(yaml)
		return nil
	}

	claimName := fmt.Sprintf("%s-full-service", flagTeam)
	return gitpkg.Submit(repoRoot, flagTeam, claimName, yaml)
}
