#!/usr/bin/env bash
# t06: dead-code checker — never-referenced module-level defs are reported with
#      exemption flags; referenced defs stay silent; string-literal refs flag
#      dynamic-ref; __all__ membership flags exported
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t06)" || exit 1
cd "$SB"
git init -q .
mkdir -p pkg tests

cat > pkg/dead.py <<'EOF'
"""Mixed live/dead defs."""
import os

UNUSED_OK = len(os.curdir)

class DeadClass:
    pass

EXPORTED_ORPHAN = "x"
__all__ = ["EXPORTED_ORPHAN", "used_func"]

def used_func():
    return 1

def dead_func():
    return 2

def main():
    pass
EOF

cat > pkg/user.py <<'EOF'
import pkg.dead as d

def run():
    return d.used_func()
EOF

cat > tests/test_dead.py <<'EOF'
from pkg.dead import used_func

def test_it():
    assert used_func() == 1
EOF

cat > pkg/dynamic.py <<'EOF'
CALLBACK_NAME = "dead_func"
EOF

git add -A

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --files pkg/dead.py)" \
  || fail "checks.py exited nonzero"

# dead class reported
assert_output_contains "$OUT" "class 'DeadClass' is defined but never referenced"
# dead constant reported
assert_output_contains "$OUT" "constant 'UNUSED_OK' is defined but never referenced"
# exported orphan reported with the exported flag, not hidden
assert_output_contains "$OUT" "'EXPORTED_ORPHAN' is defined but never referenced"
assert_output_contains "$OUT" "exported"
# entry point flagged
assert_output_contains "$OUT" "entry-point"
# dead_func: only a string-literal ref -> still reported, flagged dynamic-ref
assert_output_contains "$OUT" "'dead_func' is defined but never referenced"
assert_output_contains "$OUT" "dynamic-ref"
# used_func referenced from pkg/user.py and tests -> never reported
assert_output_not_contains "$OUT" "'used_func' is defined"
echo "PASS: t06"
