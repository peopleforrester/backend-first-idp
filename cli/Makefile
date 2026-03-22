# ABOUTME: Build and test targets for the platform CLI.
# ABOUTME: Primary entry points: 'make build' and 'make test'.

.PHONY: build test lint clean

BINARY=platform
GO=go

build:
	$(GO) build -o $(BINARY) .

test:
	$(GO) test ./... -v

lint:
	$(GO) vet ./...

clean:
	rm -f $(BINARY)
