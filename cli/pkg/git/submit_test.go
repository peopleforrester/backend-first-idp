// ABOUTME: Tests for git submit operations — branch safety check.
// ABOUTME: Uses temporary git repos to verify CheckBranch rejects main.
package git

import (
	"os"
	"os/exec"
	"testing"
)

func TestCheckBranch_RejectsMain(t *testing.T) {
	dir := setupTempRepo(t, "main")
	err := CheckBranch(dir)
	if err == nil {
		t.Fatal("expected error when on main branch")
	}
	if err.Error() != "refusing to push to main. Switch to staging or a feature branch first" {
		t.Errorf("unexpected error message: %v", err)
	}
}

func TestCheckBranch_AcceptsStaging(t *testing.T) {
	dir := setupTempRepo(t, "staging")
	if err := CheckBranch(dir); err != nil {
		t.Fatalf("staging branch should be accepted, got: %v", err)
	}
}

func TestCheckBranch_AcceptsFeatureBranch(t *testing.T) {
	dir := setupTempRepo(t, "feat/add-cdn-claim")
	if err := CheckBranch(dir); err != nil {
		t.Fatalf("feature branch should be accepted, got: %v", err)
	}
}

func TestCheckBranch_InvalidRepo(t *testing.T) {
	dir := t.TempDir()
	err := CheckBranch(dir)
	if err == nil {
		t.Fatal("expected error for non-git directory")
	}
}

// setupTempRepo creates a temporary git repo on the given branch.
func setupTempRepo(t *testing.T, branch string) string {
	t.Helper()
	dir := t.TempDir()

	cmds := [][]string{
		{"git", "init", "-b", branch},
		{"git", "config", "user.email", "test@test.com"},
		{"git", "config", "user.name", "Test"},
	}
	for _, args := range cmds {
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("setup command %v failed: %v\n%s", args, err, out)
		}
	}

	// Create initial commit so HEAD exists
	f, _ := os.CreateTemp(dir, "init")
	f.Close()
	cmd := exec.Command("git", "add", ".")
	cmd.Dir = dir
	cmd.Run()
	cmd = exec.Command("git", "commit", "-m", "init", "--allow-empty")
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("initial commit failed: %v\n%s", err, out)
	}

	return dir
}
