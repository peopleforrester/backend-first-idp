// ABOUTME: Entry point for the platform CLI — thin interface over the backend-first IDP.
// ABOUTME: Wraps claim generation, Kyverno validation, and git submission into commands.
package main

import (
	"os"

	"github.com/peopleforrester/backend-first-idp/cli/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
