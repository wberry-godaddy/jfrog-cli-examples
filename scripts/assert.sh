#!/usr/bin/env bash
#
# Shared helpers for the proof workflows in .github/workflows/.
#
# Design goal: keep each workflow step short and make the *expectation* explicit.
# A green job means "observed reality matched the documented claim".
#
# Source this file from a `run:` step:
#   source "${GITHUB_WORKSPACE}/scripts/assert.sh"

# Directory where `jf package-alias install` creates the tool symlinks.
# Mirrors jfrog-cli's GetAliasBinDir(): $JFROG_CLI_HOME_DIR/package-alias/bin
# (falling back to $HOME/.jfrog when JFROG_CLI_HOME_DIR is unset).
ALIAS_BIN="${JFROG_CLI_HOME_DIR:-${HOME}/.jfrog}/package-alias/bin"

# Put the alias directory first on PATH so that `go` resolves to the jf shim.
enable_alias_on_path() {
  export PATH="${ALIAS_BIN}:${PATH}"
  hash -r 2>/dev/null || true
  echo "alias dir on PATH: ${ALIAS_BIN}"
  echo "go now resolves to: $(command -v go)"
}

# run_go <mode> <go-args...>
#   mode=unset -> JFROG_CLI_GHOST_FROG unset (Ghost Frog interception OFF)
#   mode=audit -> JFROG_CLI_GHOST_FROG=audit (log the routing decision, run native go)
#   mode=true  -> JFROG_CLI_GHOST_FROG=true  (intercept: rewrite to `jf go ...`)
# Captures output in RUN_OUT and exit code in RUN_CODE (never aborts the step).
run_go() {
  local mode="$1"; shift
  if [ "${mode}" = "unset" ]; then
    unset JFROG_CLI_GHOST_FROG
  else
    export JFROG_CLI_GHOST_FROG="${mode}"
  fi
  echo "::group::JFROG_CLI_GHOST_FROG=${mode} :: go $*"
  set +e
  RUN_OUT="$(go "$@" 2>&1)"
  RUN_CODE=$?
  set -e
  printf '%s\n' "${RUN_OUT}"
  echo "--> exit ${RUN_CODE}"
  echo "::endgroup::"
}

assert_contains() { # <haystack> <needle> <message>
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "PASS: $3"
  else
    echo "FAIL: $3"
    echo "      expected output to contain: $2"
    exit 1
  fi
}

assert_zero() { # <code> <message>
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2 (exit 0)"
  else
    echo "FAIL: $2 (got exit $1, expected 0)"
    exit 1
  fi
}

assert_nonzero() { # <code> <message>
  if [ "$1" -ne 0 ]; then
    echo "PASS: $2 (exit $1)"
  else
    echo "FAIL: $2 (expected a non-zero exit, got 0)"
    exit 1
  fi
}
