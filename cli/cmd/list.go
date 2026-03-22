// ABOUTME: List command — discovers available resource types and team claims.
// ABOUTME: Reads XRD files and teams/ directory for live inventory.
package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/peopleforrester/backend-first-idp/cli/pkg/xrd"
	"github.com/spf13/cobra"
)

var listTeamFlag string

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List platform resources",
}

var listTypesCmd = &cobra.Command{
	Use:   "types",
	Short: "List available resource types (reads XRDs)",
	RunE: func(cmd *cobra.Command, args []string) error {
		if repoRoot == "" {
			return fmt.Errorf("repo root not found; use --repo-root")
		}
		resources, err := xrd.DiscoverTypes(repoRoot)
		if err != nil {
			return err
		}
		fmt.Printf("Available resource types (%d):\n\n", len(resources))
		for _, r := range resources {
			fmt.Printf("  %s (claim: %s)\n", r.Kind, r.ClaimKind)
			for _, f := range r.Fields {
				line := fmt.Sprintf("    %-25s %s", f.Name, f.Type)
				if f.Required {
					line += "  [required]"
				}
				if f.Default != nil {
					line += fmt.Sprintf("  default=%v", f.Default)
				}
				if len(f.Enum) > 0 {
					line += fmt.Sprintf("  enum=[%s]", strings.Join(f.Enum, ", "))
				}
				fmt.Println(line)
			}
			fmt.Println()
		}
		return nil
	},
}

var listClaimsCmd = &cobra.Command{
	Use:   "claims",
	Short: "List claims for a team",
	RunE: func(cmd *cobra.Command, args []string) error {
		if repoRoot == "" {
			return fmt.Errorf("repo root not found; use --repo-root")
		}
		teamsDir := filepath.Join(repoRoot, "teams")

		if listTeamFlag != "" {
			return listTeamClaims(teamsDir, listTeamFlag)
		}

		// List all teams
		entries, err := os.ReadDir(teamsDir)
		if err != nil {
			return fmt.Errorf("reading teams directory: %w", err)
		}
		fmt.Printf("Teams (%d):\n\n", len(entries))
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			claimsDir := filepath.Join(teamsDir, e.Name(), "claims")
			count := countYAMLFiles(claimsDir)
			fmt.Printf("  %-20s %d claims\n", e.Name(), count)
		}
		return nil
	},
}

func listTeamClaims(teamsDir, team string) error {
	claimsDir := filepath.Join(teamsDir, team, "claims")
	entries, err := os.ReadDir(claimsDir)
	if err != nil {
		return fmt.Errorf("reading claims for team %s: %w", team, err)
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".yaml") {
			files = append(files, strings.TrimSuffix(e.Name(), ".yaml"))
		}
	}
	sort.Strings(files)

	fmt.Printf("Claims for team %s (%d):\n\n", team, len(files))
	for _, f := range files {
		fmt.Printf("  %s\n", f)
	}
	return nil
}

func countYAMLFiles(dir string) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	count := 0
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".yaml") {
			count++
		}
	}
	return count
}

func init() {
	rootCmd.AddCommand(listCmd)
	listCmd.AddCommand(listTypesCmd)
	listClaimsCmd.Flags().StringVar(&listTeamFlag, "team", "", "Filter by team name")
	listCmd.AddCommand(listClaimsCmd)
}
