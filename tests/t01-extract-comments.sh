#!/usr/bin/env bash
# t01: extract_comments.py file mode — Python docstring/full/inline comments
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t01)" || exit 1
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
echo "PASS: t01"
