#!/usr/bin/env bash
# ABOUTME: Scale test — validates 100+ team claims exist and are well-formed.
# ABOUTME: Run via 'make test-scale' or directly with bash.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "=== Scale Tests ==="
echo ""

TEAMS_DIR="${REPO_ROOT}/teams"

if [[ ! -d "${TEAMS_DIR}" ]]; then
    echo "No teams/ directory found — skipping."
    echo ""
    assert "teams/ directory exists" "false"
    print_results "SCALE TESTS"
fi

# Count claim files
echo "--- Claim count ---"
mapfile -t CLAIM_FILES < <(find "${TEAMS_DIR}" -path '*/claims/*.yaml' -type f | sort)
CLAIM_COUNT=${#CLAIM_FILES[@]}
echo "  Found ${CLAIM_COUNT} claim files under teams/"
assert "At least 100 claim files" "$([[ ${CLAIM_COUNT} -ge 100 ]] && echo true || echo false)"

# Validate all claims are valid YAML
echo ""
echo "--- YAML validity ---"
YAML_FAIL=0
for f in "${CLAIM_FILES[@]}"; do
    if ! yamllint -c "${REPO_ROOT}/.yamllint.yml" "${f}" >/dev/null 2>&1; then
        rel=$(realpath --relative-to="${REPO_ROOT}" "${f}")
        echo -e "  ${RED}FAIL${NC} ${rel}"
        ((YAML_FAIL++)) || true
    fi
done
assert "All claims pass yamllint" "$([[ ${YAML_FAIL} -eq 0 ]] && echo true || echo false)"

# Validate all claims have a team field
echo ""
echo "--- Claim structure ---"
TEAM_FAIL=0
API_FAIL=0
for f in "${CLAIM_FILES[@]}"; do
    rel=$(realpath --relative-to="${REPO_ROOT}" "${f}")
    # Check team field exists
    if ! grep -q "team:" "${f}" 2>/dev/null; then
        echo -e "  ${RED}FAIL${NC} ${rel} — missing team field"
        ((TEAM_FAIL++)) || true
    fi
    # Check apiVersion references platform.kubecon.io
    if ! grep -q "platform.kubecon.io" "${f}" 2>/dev/null; then
        echo -e "  ${RED}FAIL${NC} ${rel} — missing platform.kubecon.io apiVersion"
        ((API_FAIL++)) || true
    fi
done
assert "All claims have team field" "$([[ ${TEAM_FAIL} -eq 0 ]] && echo true || echo false)"
assert "All claims reference platform.kubecon.io" "$([[ ${API_FAIL} -eq 0 ]] && echo true || echo false)"

# Count teams
echo ""
echo "--- Team count ---"
mapfile -t TEAM_DIRS < <(find "${TEAMS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
TEAM_COUNT=${#TEAM_DIRS[@]}
echo "  Found ${TEAM_COUNT} teams"
assert "At least 10 teams" "$([[ ${TEAM_COUNT} -ge 10 ]] && echo true || echo false)"

print_results "SCALE TESTS"
