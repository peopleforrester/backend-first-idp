# ABOUTME: Build and test targets for the backend-first IDP repo.
# ABOUTME: Primary entry point: 'make test' runs all validation suites.

.PHONY: test test-yaml test-shell test-opa test-structure test-xrd test-compositions test-golden-path lint clean

# Run all tests
test: test-yaml test-shell test-opa test-xrd test-compositions test-golden-path test-structure

# Individual test suites
test-yaml:
	@bash tests/yaml_test.sh

test-shell:
	@bash tests/shellcheck_test.sh

test-opa:
	@bash tests/opa_test.sh

test-xrd:
	@bash tests/xrd_test.sh

test-compositions:
	@bash tests/composition_test.sh

test-golden-path:
	@bash tests/golden_path_test.sh

test-structure:
	@bash tests/structure_test.sh

# Lint is an alias for YAML + shell checks
lint: test-yaml test-shell

# Full validation (same as test, explicit name)
validate:
	@bash tests/validate.sh

clean:
	@echo "Nothing to clean."
