#!/usr/bin/env bash
# Test infrastructure for the xskills regression suite (dev-only, NOT deployed).
# REPO points at the plugin repo root; tests operate on /tmp sandbox copies —
# the plugin repo is never modified.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Tests import packages from $REPO — never let that materialize __pycache__
# inside the plugin repo (gate and tests must stay read-only).
export PYTHONDONTWRITEBYTECODE=1

fail() {
  echo "FAIL: $*" >&2
  echo "sandbox left at: ${SB:-<none>}" >&2
  exit 1
}

assert_ok() { "$@" || fail "command failed: $*"; }
assert_fails() { "$@" && fail "expected failure (exit 0): $*"; return 0; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"; }
assert_not_contains() { grep -Fq -- "$2" "$1" && fail "unexpected '$2' in $1"; return 0; }
assert_output_contains() { printf '%s' "$1" | grep -Fq -- "$2" || fail "expected '$2' in command output"; }
assert_output_not_contains() { printf '%s' "$1" | grep -Fq -- "$2" && fail "unexpected '$2' in command output"; return 0; }

# build_sandbox <tag>: creates /tmp/xs-test-<tag>-XXXXXX with a scratch file
# area and echoes the sandbox path. Tests copy only what they need from REPO.
build_sandbox() {
  local tag="$1"
  SB="$(mktemp -d "/tmp/xs-test-${tag}-XXXXXX")" || return 1
  echo "$SB"
}
