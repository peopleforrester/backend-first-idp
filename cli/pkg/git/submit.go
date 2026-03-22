// ABOUTME: Git operations for submitting claims — write, commit, and push.
// ABOUTME: Writes claims to teams/{team}/claims/ and commits with conventional message.
package git

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// Submit writes a claim file to the team's claims directory, commits, and pushes.
func Submit(repoRoot, team, claimName, yamlContent string) error {
	claimsDir := filepath.Join(repoRoot, "teams", team, "claims")
	if err := os.MkdirAll(claimsDir, 0o755); err != nil {
		return fmt.Errorf("creating claims directory: %w", err)
	}

	claimFile := filepath.Join(claimsDir, claimName+".yaml")
	if err := os.WriteFile(claimFile, []byte(yamlContent), 0o644); err != nil {
		return fmt.Errorf("writing claim file: %w", err)
	}

	relPath, _ := filepath.Rel(repoRoot, claimFile)
	fmt.Printf("  Wrote %s\n", relPath)

	// Git add
	if err := runGit(repoRoot, "add", claimFile); err != nil {
		return fmt.Errorf("git add: %w", err)
	}

	// Git commit
	msg := fmt.Sprintf("platform: add %s for team %s", claimName, team)
	if err := runGit(repoRoot, "commit", "-m", msg); err != nil {
		return fmt.Errorf("git commit: %w", err)
	}
	fmt.Printf("  Committed: %s\n", msg)

	// Git push
	if err := runGit(repoRoot, "push"); err != nil {
		return fmt.Errorf("git push: %w", err)
	}
	fmt.Println("  Pushed to remote.")

	return nil
}

func runGit(dir string, args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
