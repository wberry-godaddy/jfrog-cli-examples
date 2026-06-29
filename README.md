# jfrog-cli-examples

Runnable CI proofs of how the JFrog CLI **package alias** ("Ghost Frog") feature
behaves in practice — and where the behavior differs from what the
[`jfrog/setup-jfrog-cli`](https://github.com/jfrog/setup-jfrog-cli) action and
`jf package-alias status` lead you to expect.

Every workflow is self-contained, runs on stock GitHub-hosted runners, and needs
**no JFrog instance and no secrets**. Each job *asserts* the documented behavior,
so a green check means "reality still matches the claim". The jobs run on a
weekly schedule as a regression tracker across `jf` versions.

| Proof | Workflow |
| --- | --- |
| `status` says ACTIVE, but interception is inert | [![01](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/01-status-active-but-inert.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/01-status-active-but-inert.yml) |
| One command, three realities | [![02](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/02-three-realities.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/02-three-realities.yml) |
| Every `go` subcommand is aliased (not just `go build`) | [![03](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/03-all-subcommands-aliased.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/03-all-subcommands-aliased.yml) |
| `jf go` needs a resolver repo, with no native fallback | [![04](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/04-jf-go-needs-resolver.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/04-jf-go-needs-resolver.yml) |
| `setup-jfrog-cli` `enable-package-alias` doesn't activate it | [![05](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/05-setup-action-gap.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/05-setup-action-gap.yml) |
| Aliasing wraps every `go` call (tooling risk) | [![06](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/06-tooling-wrapped-risk.yml/badge.svg)](https://github.com/wberry-godaddy/jfrog-cli-examples/actions/workflows/06-tooling-wrapped-risk.yml) |

## TL;DR — expectation vs reality

| Expectation | Reality |
| --- | --- |
| `enable-package-alias: true` makes `go mod download` flow through JFrog. | It doesn't. Interception is gated on the `JFROG_CLI_GHOST_FROG` env var, which the action never sets. |
| `jf package-alias status` reporting "active" means `go` is intercepted. | `status` only checks config + PATH. It reports "active" while `go mod download` still fails. |
| The alias only affects `go build` (the example in the banner). | Every `go` subcommand defaults to jf-mode (`go mod`, `go test`, `go env`, `go version`, ...). |
| Once active, `go` "just works". | `go` is rewritten to `jf go`, which hard-requires a resolver repo and has no native fallback — even `go version` fails without one. |

## How the feature actually works

`jf package-alias install` creates symlinks (`go -> jf`, `npm -> jf`, ...) and
adds their directory to `PATH`. When you then run `go ...`, the `jf` binary
inspects how it was invoked and decides what to do in `DispatchIfAlias`:

```
JFROG_CLI_GHOST_FROG unset/""/"false"  ->  bypass entirely (default; "off")
JFROG_CLI_GHOST_FROG="true"            ->  rewrite `go <args>` to `jf go <args>`
JFROG_CLI_GHOST_FROG="audit"           ->  log the routing decision, run native go
```

The catch: the env var is **opt-in and off by default**. With it unset, `jf` runs
as if you typed `jf <args>` — so `go mod download` becomes `jf mod download`, and
`jf` reports `'jf mod' is not a jf command`.

### The three realities (workflow 02)

The same `go mod download`, differing only by the env var:

| `JFROG_CLI_GHOST_FROG` | What happens | Observable output |
| --- | --- | --- |
| unset | shim misfires | `'jf mod' is not a jf command` |
| `audit` | routing decision logged, native go runs | `[GHOST_FROG] [AUDIT] Would intercept 'go' (mode=jf)` then succeeds |
| `true` | rewritten to `jf go mod download` | `Transforming 'go' to 'jf go'`, then needs `jf go-config` |

## Why there's no "real download through Artifactory" job

The full happy path (`JFROG_CLI_GHOST_FROG=true` + a configured resolver repo →
`go mod download` actually served by Artifactory) needs a JFrog instance. There
is no usable public/anonymous JFrog Go proxy — JFrog's public GoCenter was
retired in 2021, and `releases.jfrog.io` only serves JFrog's own binaries.

So this repo proves the **routing decision** with `audit` mode (which logs that
`go` would be sent to `jf go` while running native `go`), and proves the
**resolver requirement** by showing `jf go` fails without one. The only missing
piece — bytes flowing from Artifactory — is exactly what a private instance adds.

## Running it yourself

```sh
# Requires jf >= 2.93.0 and go on PATH.
export JFROG_CLI_HOME_DIR="$PWD/.jfrog"
jf package-alias install --packages go
export PATH="$JFROG_CLI_HOME_DIR/package-alias/bin:$PATH"; hash -r

go mod download                                   # 'jf mod' is not a jf command
JFROG_CLI_GHOST_FROG=audit go mod download        # [AUDIT] Would intercept 'go' (mode=jf); succeeds
JFROG_CLI_GHOST_FROG=true  go mod download        # Transforming 'go' to 'jf go'; needs jf go-config
```

## Versions under test

Each workflow runs against a matrix of `jf` versions: `2.100.0`, `2.111.0`, and
`latest`. `fail-fast` is disabled so a change in any single version is visible
without masking the others.

Note: `2.100.0` is the first release that actually ships the `jf package-alias`
command, even though `setup-jfrog-cli` advertises a `2.93.0` floor for
`enable-package-alias` — the command does not exist before `2.100.0`.

## Layout

```
main.go                     trivial program (one external dep) so go has real work
scripts/assert.sh           tiny run/assert helpers shared by the workflows
.github/workflows/01..06    one proof per file (see table above)
```
