#!/usr/bin/env bash
# ABOUTME: YAML validation test — runs yamllint on all YAML files in the repo.
# ABOUTME: Run via 'make test-yaml' or directly with bash.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== YAML Lint Tests ==="
echo ""

# Find all YAML files, excluding .git and node_modules
mapfile -t YAML_FILES < <(find "${REPO_ROOT}" \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -type f \( -name '*.yaml' -o -name '*.yml' \) \
    | sort)

if [[ ${#YAML_FILES[@]} -eq 0 ]]; then
    echo "No YAML files found to lint."
    exit 0
fi

echo "Linting ${#YAML_FILES[@]} YAML files..."
echo ""

yamllint -c "${REPO_ROOT}/.yamllint.yml" "${YAML_FILES[@]}"

echo ""
echo "=== ALL YAML FILES PASSED ==="
