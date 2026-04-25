#!/usr/bin/env bash
# ABOUTME: Shared test library — common boilerplate for all test scripts.
# ABOUTME: Provides assert(), assert_file_exists(), assert_dir_exists(), print_results(), colors.

# Sourced by test scripts — do not execute directly.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
PASS=0
FAIL=0

# Colors (disable if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'
else
    GREEN='' RED='' NC=''
fi

assert() {
    local description="$1"
    local result
    result="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    if [[ "${result}" == "true" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description}"
        ((FAIL++)) || true
    fi
}

assert_file_exists() {
    local file="$1"
    local description="${2:-$file}"
    if [[ -f "${REPO_ROOT}/${file}" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — file not found: ${file}"
        ((FAIL++)) || true
    fi
}

assert_dir_exists() {
    local dir="$1"
    local description="${2:-$dir}"
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — directory not found: ${dir}"
        ((FAIL++)) || true
    fi
}

assert_equal_files() {
    # Compare two files byte-for-byte. Used to enforce single-source-of-truth
    # invariants between a canonical file and an inlined copy.
    local a="$1"
    local b="$2"
    local description="${3:-${a} == ${b}}"
    if diff -q "${REPO_ROOT}/${a}" "${REPO_ROOT}/${b}" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — files differ"
        ((FAIL++)) || true
    fi
}

assert_yaml_contains() {
    # Assert that a YAML file contains an arbitrary literal string.
    # Whitespace-tolerant grep with -F (fixed string).
    local file="$1"
    local needle="$2"
    local description="${3:-${file} contains [${needle}]}"
    if grep -F -q -- "${needle}" "${REPO_ROOT}/${file}"; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — not found in ${file}"
        ((FAIL++)) || true
    fi
}

assert_yaml_not_contains() {
    local file="$1"
    local needle="$2"
    local description="${3:-${file} does not contain [${needle}]}"
    if grep -F -q -- "${needle}" "${REPO_ROOT}/${file}"; then
        echo -e "  ${RED}FAIL${NC} ${description} — unexpectedly found in ${file}"
        ((FAIL++)) || true
    else
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    fi
}

assert_team_allowlist_matches_teams_yaml() {
    # The default-deny-unlisted-teams Kyverno rule enumerates the team allowlist
    # in cluster-policies/region-enforcement.yaml. The source of truth for which
    # teams exist is scripts/teams.yaml. Assert the two sets are equal.
    local description="default-deny-unlisted-teams allowlist matches scripts/teams.yaml"
    local result
    result="$(REPO_ROOT="${REPO_ROOT}" python3 - <<'PY'
import sys, yaml, os
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
teams_yaml = yaml.safe_load((repo / "scripts/teams.yaml").read_text())
teams_set = set(teams_yaml.get("teams", {}).keys())

policy_docs = list(yaml.safe_load_all(
    (repo / "policies/kyverno/cluster-policies/region-enforcement.yaml").read_text()
))
policy = policy_docs[0]
allowlist = None
for rule in policy["spec"]["rules"]:
    if rule["name"] == "default-deny-unlisted-teams":
        for cond in rule["preconditions"]["all"]:
            if cond.get("operator") == "AnyNotIn":
                allowlist = set(cond["value"])
                break
        break

if allowlist is None:
    print("MISSING_RULE")
    sys.exit(0)

missing_in_policy = teams_set - allowlist
extra_in_policy = allowlist - teams_set
if not missing_in_policy and not extra_in_policy:
    print("OK")
else:
    print(f"DRIFT missing_in_policy={sorted(missing_in_policy)} extra_in_policy={sorted(extra_in_policy)}")
PY
)"
    if [[ "${result}" == "OK" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — ${result}"
        ((FAIL++)) || true
    fi
}

assert_drift_configmap_matches_canonical() {
    # The drift-check CronJob ConfigMap embeds an inline copy of
    # platform-api/drift-detection/scripts/check-drift.sh. They MUST match.
    local cronjob_yaml="platform-api/drift-detection/drift-check-cronjob.yaml"
    local canonical="platform-api/drift-detection/scripts/check-drift.sh"
    local description="drift ConfigMap matches canonical script"

    local extracted
    extracted="$(python3 - "${REPO_ROOT}/${cronjob_yaml}" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    docs = list(yaml.safe_load_all(f))
for doc in docs:
    if doc and doc.get("kind") == "ConfigMap" and doc.get("metadata", {}).get("name") == "drift-check-script":
        sys.stdout.write(doc["data"]["check-drift.sh"])
        break
PY
)"
    local canonical_content
    canonical_content="$(cat "${REPO_ROOT}/${canonical}")"

    if [[ "${extracted}" == "${canonical_content}" ]]; then
        echo -e "  ${GREEN}PASS${NC} ${description}"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} ${description} — ConfigMap drifted from ${canonical}"
        ((FAIL++)) || true
    fi
}

print_results() {
    local suite_name="${1:-TESTS}"
    echo ""
    echo "=== Results ==="
    echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}"
    echo ""

    if [[ ${FAIL} -gt 0 ]]; then
        echo -e "${RED}${suite_name} FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}ALL ${suite_name} PASSED${NC}"
        exit 0
    fi
}
