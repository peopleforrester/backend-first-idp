// ABOUTME: Kyverno CLI wrapper for local policy validation.
// ABOUTME: Runs 'kyverno apply' against repo policies without needing a cluster.
package claim

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ValidateFile runs kyverno apply against the repo's cluster policies.
func ValidateFile(repoRoot string, claimFile string) (string, error) {
	policyDir := filepath.Join(repoRoot, "policies", "kyverno", "cluster-policies")

	if _, err := os.Stat(policyDir); os.IsNotExist(err) {
		return "", fmt.Errorf("policy directory not found: %s", policyDir)
	}

	// Find all policy files
	entries, err := os.ReadDir(policyDir)
	if err != nil {
		return "", fmt.Errorf("reading policy directory: %w", err)
	}

	var policyFiles []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".yaml") {
			policyFiles = append(policyFiles, filepath.Join(policyDir, e.Name()))
		}
	}

	if len(policyFiles) == 0 {
		return "", fmt.Errorf("no policy files found in %s", policyDir)
	}

	args := append(policyFiles, "--resource", claimFile)
	args = append([]string{"apply"}, args...)

	cmd := exec.Command("kyverno", args...)
	output, err := cmd.CombinedOutput()

	return string(output), err
}

// ValidateYAML writes YAML to a temp file, validates, then cleans up.
func ValidateYAML(repoRoot string, yamlContent string) (string, error) {
	tmpFile, err := os.CreateTemp("", "platform-claim-*.yaml")
	if err != nil {
		return "", fmt.Errorf("creating temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(yamlContent); err != nil {
		return "", fmt.Errorf("writing temp file: %w", err)
	}
	tmpFile.Close()

	return ValidateFile(repoRoot, tmpFile.Name())
}
