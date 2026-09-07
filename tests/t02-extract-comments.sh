#!/usr/bin/env bash
# t02: extract_comments.py file mode — Python docstring/full/inline comments
#      (restored in v0.10.0; was t01 before the v0.9.0 deletion)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t02)" || exit 1
cat > "$SB/sample.py" <<'EOF'
"""Module docstring."""

def foo():
    # full comment
    x = 1  # inline comment
    return x
EOF

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/extract_comments.py" --files "$SB/sample.py")" \
  || fail "extract_comments.py exited nonzero"
assert_output_contains "$OUT" '"kind": "docstring"'
assert_output_contains "$OUT" '"kind": "full_comment"'
assert_output_contains "$OUT" '"kind": "inline_comment"'
assert_output_contains "$OUT" "Module docstring"
assert_output_contains "$OUT" "# inline comment"
echo "PASS: t02"
