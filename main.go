// Command jfrog-cli-examples is a trivial program whose only purpose is to give
// the CI workflows in this repository something real to compile and resolve.
//
// The workflows under .github/workflows exercise plain `go` commands (e.g.
// `go mod download`, `go build`) while the JFrog CLI "package alias" (Ghost
// Frog) is installed, in order to demonstrate the gap between what the feature
// appears to do and what it actually does. See README.md for the full story.
package main

import (
	"fmt"

	"github.com/google/uuid"
)

func main() {
	fmt.Println("hello from jfrog-cli-examples", uuid.NewString())
}
