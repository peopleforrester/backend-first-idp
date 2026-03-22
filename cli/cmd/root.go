// ABOUTME: Root command and global flags for the platform CLI.
// ABOUTME: Provides --repo-root flag for locating XRDs, policies, and teams.
package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

var repoRoot string

var rootCmd = &cobra.Command{
	Use:   "platform",
	Short: "Backend-first IDP platform CLI",
	Long: `A thin interface over the backend-first Internal Developer Platform.

Generates claim YAML, validates against Kyverno policies, and submits
via git. The same claims can be created by hand, by this CLI, or by
the Backstage portal — the backend doesn't care which interface you use.`,
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.PersistentFlags().StringVar(&repoRoot, "repo-root", "", "Path to the backend-first-idp repo root (auto-detected if in repo)")
	cobra.OnInitialize(initRepoRoot)
}

func initRepoRoot() {
	if repoRoot != "" {
		return
	}
	// Walk up from cwd to find the repo root (has platform-api/ directory)
	dir, err := os.Getwd()
	if err != nil {
		return
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "platform-api", "xrds")); err == nil {
			repoRoot = dir
			return
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	fmt.Fprintln(os.Stderr, "WARNING: Could not detect repo root. Use --repo-root flag.")
}
