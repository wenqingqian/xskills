#!/usr/bin/env bash
# t03: checks.py — every registered checker always runs (no selection flags);
#      inner import reported with parent; def-free clean file is silent;
#      a scope flag is mandatory
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t03)" || exit 1
cat > "$SB/inner.py" <<'EOF'
import os

def foo():
    import sys
    return sys.path
EOF
cat > "$SB/clean.py" <<'EOF'
import os

print(os.path)
EOF

# no scope flags -> error
OUT_ERR="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" 2>&1 || true)"
assert_output_contains "$OUT_ERR" "provide --range or --files"

# removed checker-selection flags are gone
OUT_GONE="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --check no-inner-import --files "$SB/inner.py" 2>&1 || true)"
assert_output_contains "$OUT_GONE" "unrecognized arguments"

# inner import reported with parent, no selection needed
OUT="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --files "$SB/inner.py")" \
  || fail "checks.py exited nonzero"
assert_output_contains "$OUT" "no-inner-import"
assert_output_contains "$OUT" "import 'sys' inside FunctionDef 'foo'"

# dead-code runs too, unasked: foo is defined but never referenced
assert_output_contains "$OUT" "dead-code"

# clean file (no defs, no inner imports): empty array
OUT2="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --files "$SB/clean.py")" \
  || fail "checks.py exited nonzero on clean file"
assert_output_contains "$OUT2" "[]"
echo "PASS: t03"
