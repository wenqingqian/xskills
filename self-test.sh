#!/usr/bin/env bash
# Regression suite entry (dev-only, NOT part of the deployed plugin).
# Runs every tests/t[0-9]*.sh scenario in an isolated /tmp sandbox.
# Usage: bash self-test.sh
# NOTE: -e is intentionally omitted — the runner must execute every test and
# collect all results; a single failing test must not abort the run.
set -uo pipefail

cd "$(dirname "$0")"
log="$(mktemp "/tmp/xs-self-test.XXXXXX")" || exit 1
pass=0; fail=0; failed=()

for t in tests/t[0-9]*.sh; do
  printf '== %s\n' "$t"
  if bash "$t" >"$log" 2>&1; then
    echo "   PASS"
    pass=$((pass+1))
  else
    echo "   FAIL  (log kept: $log)"
    tail -n 15 "$log" | sed 's/^/     /'
    fail=$((fail+1))
    failed+=("$t")
  fi
done

[ "$fail" -eq 0 ] && rm -f "$log"

echo ""
echo "self-test: $pass passed, $fail failed"
[ "${#failed[@]}" -gt 0 ] && { printf 'failed: %s\n' "${failed[@]}"; echo "log kept: $log"; }
[ "$fail" -eq 0 ]
