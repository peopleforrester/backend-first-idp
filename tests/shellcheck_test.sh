#!/usr/bin/env bash
# ABOUTME: Shellcheck test — validates all shell scripts in the repo.
# ABOUTME: Run via 'make test-shell' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "=== Shellcheck Tests ==="
echo ""

# Find all .sh files, excluding .git
mapfile -t SHELL_FILES < <(find "${REPO_ROOT}" \
    -not -path '*/.git/*' \
    -type f -name '*.sh' \
    | sort)

if [[ ${#SHELL_FILES[@]} -eq 0 ]]; then
    echo "No shell scripts found — skipping."
    exit 0
fi

echo "Checking ${#SHELL_FILES[@]} shell scripts..."
echo ""

SHELL_FAIL=0
for f in "${SHELL_FILES[@]}"; do
    REL=$(realpath --relative-to="${REPO_ROOT}" "${f}")
    if shellcheck -x "${f}"; then
        echo "  PASS ${REL}"
    else
        echo "  FAIL ${REL}"
        SHELL_FAIL=1
    fi
done

echo ""
if [[ ${SHELL_FAIL} -ne 0 ]]; then
    echo "SHELLCHECK TESTS FAILED"
    exit 1
else
    echo "=== ALL SHELLCHECK TESTS PASSED ==="
fi
