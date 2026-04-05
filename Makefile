# ABOUTME: Build and test targets for the backend-first IDP v2 repo.
# ABOUTME: Primary entry point: 'make test' runs all validation suites.

.PHONY: test test-yaml test-shell test-kyverno test-xrd test-compositions \
        test-golden-path test-structure test-observability test-eso test-scale \
        lint validate clean

# Run all tests
test: test-yaml test-shell test-kyverno test-xrd test-compositions test-golden-path test-observability test-eso test-scale test-structure

# Individual test suites
test-yaml:
	@bash tests/yaml_test.sh

test-shell:
	@bash tests/shellcheck_test.sh

test-kyverno:
	@bash tests/kyverno_test.sh

test-xrd:
	@bash tests/xrd_test.sh

test-compositions:
	@bash tests/composition_test.sh

test-golden-path:
	@bash tests/golden_path_test.sh

test-observability:
	@bash tests/observability_test.sh

test-eso:
	@bash tests/eso_test.sh

test-scale:
	@bash tests/scale_test.sh

test-structure:
	@bash tests/structure_test.sh

# Lint is an alias for YAML + shell checks
lint: test-yaml test-shell

# Full validation (alias for test)
validate: test

clean:
	@echo "Nothing to clean."
