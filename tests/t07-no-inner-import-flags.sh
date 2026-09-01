#!/usr/bin/env bash
# t07: no-inner-import exemption flags — the six structural signals
#      downgrade findings to exemption candidates (no hoist proposal),
#      while an unflagged inner import stays a hoist proposal
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t07)" || exit 1
PROJ="$SB/proj"
mkdir -p "$PROJ/tests"

# circular-guard: lib_a top-level imports lib_b, so hoisting lib_b's
# function-level import of lib_a back to top level would close a cycle
cat > "$PROJ/lib_a.py" <<'EOF'
import lib_b

def run():
    return lib_b.helper()
EOF
cat > "$PROJ/lib_b.py" <<'EOF'
def helper():
    import lib_a
    return lib_a.run()
EOF
# heavy-deferral: heavy third-party inside a CLI entry function
cat > "$PROJ/entry.py" <<'EOF'
def main():
    from transformers import AutoTokenizer
    return AutoTokenizer
EOF
# optional-dep: try/except ImportError with a silent fallback
cat > "$PROJ/probe.py" <<'EOF'
try:
    import triton
except ImportError:
    triton = None
EOF
# lazy-activation (b): gated branch + lazy contract in the module docstring
cat > "$PROJ/gated.py" <<'EOF'
"""Engine extras: stock runs must not require the engine dependency."""

def start(cfg):
    if cfg.use_engine:
        from sga.runtime import build_engine
        return build_engine()
    return None
EOF
# lazy-activation (a): ImportError converted to an actionable error
cat > "$PROJ/failfast.py" <<'EOF'
try:
    from modelopt.torch import add_modelopt_args
except ImportError:
    raise RuntimeError("pip install modelopt to use this training path")
EOF
# typing-only: module-level TYPE_CHECKING guard
cat > "$PROJ/types.py" <<'EOF'
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import schemas
EOF
# test-local: test file + alias used as an in-file patch target
cat > "$PROJ/tests/test_engine.py" <<'EOF'
from unittest import mock

def test_engine():
    import sga.engine as engine_mod
    with mock.patch("engine_mod.build_engine"):
        assert engine_mod is not None
EOF
# violation: plain inner import, no signal
cat > "$PROJ/bad.py" <<'EOF'
import os

def foo():
    import sys
    return sys.path
EOF

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" \
  --files "$PROJ"/*.py "$PROJ/tests/test_engine.py")" \
  || fail "checks.py exited nonzero"

assert_output_contains "$OUT" "exemption candidate (flags: circular-guard)"
assert_output_contains "$OUT" "exemption candidate (flags: heavy-deferral)"
assert_output_contains "$OUT" "exemption candidate (flags: optional-dep)"
assert_output_contains "$OUT" "exemption candidate (flags: lazy-activation)"
assert_output_contains "$OUT" "exemption candidate (flags: typing-only)"
assert_output_contains "$OUT" "exemption candidate (flags: test-local)"
assert_output_contains "$OUT" "inside FunctionDef 'foo'; move to module top level"

# exactly one hoist proposal: flagged findings must not carry one
VIOL="$(printf '%s' "$OUT" | grep -Fc 'move to module top level')"
[ "$VIOL" -eq 1 ] || fail "expected exactly 1 hoist proposal, got $VIOL"

# flagged findings appear in the same output (never hidden):
# one per fixture file (both lazy-activation shapes count separately)
FLAGGED="$(printf '%s' "$OUT" | grep -Fc 'exemption candidate')"
[ "$FLAGGED" -eq 7 ] || fail "expected 7 exemption candidates, got $FLAGGED"
echo "PASS: t07"
