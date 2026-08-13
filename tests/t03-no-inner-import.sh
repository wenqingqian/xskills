#!/usr/bin/env bash
# t03: checks.py no-inner-import — reports inner imports with parent, clean file is silent
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

def foo():
    return os.path
EOF

# --list works
LIST="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --list)" || fail "--list failed"
assert_output_contains "$LIST" "no-inner-import"

# direct "--<checker-id>" form is shorthand for --check <id>
OUT0="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --no-inner-import --files "$SB/inner.py")" \
  || fail "direct checker flag failed"
assert_output_contains "$OUT0" "FunctionDef 'foo'"

# inner import reported with parent
OUT="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --check no-inner-import --files "$SB/inner.py")" \
  || fail "checks.py exited nonzero"
assert_output_contains "$OUT" "FunctionDef 'foo'"
assert_output_contains "$OUT" "import 'sys' inside FunctionDef 'foo'"

# clean file: empty array
OUT2="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --check no-inner-import --files "$SB/clean.py")" \
  || fail "checks.py exited nonzero on clean file"
assert_output_contains "$OUT2" "[]"
echo "PASS: t03"
