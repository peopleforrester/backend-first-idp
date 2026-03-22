// ABOUTME: Validate command — runs Kyverno policy checks on claim files locally.
// ABOUTME: No cluster needed; uses kyverno CLI against repo policies.
package cmd

import (
	"fmt"

	"github.com/peopleforrester/backend-first-idp/cli/pkg/claim"
	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate <file>",
	Short: "Validate a claim file against Kyverno policies",
	Long:  "Runs kyverno apply against the repo's cluster policies. No cluster needed.",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		if repoRoot == "" {
			return fmt.Errorf("repo root not found; use --repo-root")
		}
		output, err := claim.ValidateFile(repoRoot, args[0])
		fmt.Print(output)
		if err != nil {
			return fmt.Errorf("validation failed")
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(validateCmd)
}
