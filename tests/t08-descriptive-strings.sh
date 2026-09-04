#!/usr/bin/env bash
# t08: extract_comments.py desc_string — plain string literals bound to a
#      whitelisted documentation name are extracted; functional strings
#      (error messages, prefixed literals, dict values, non-whitelisted
#      names) are not
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t08)" || exit 1
cat > "$SB/sample.py" <<'EOF'
"""Module docstring."""

import argparse

EPILOG = """multi-line epilog prose"""


def build():
    parser = argparse.ArgumentParser(description="Do the thing.")
    parser.add_argument("--batch", help="batch size; not dynamic batching - OOM in early tests")
    parser.add_argument("--path", help=r"raw prefix is not extracted")
    parser.add_argument("--mode", help=f"interpolation makes it functional")
    parser.epilog = "attribute assignment"
    raise SystemExit("error message is functional prose")
    return parser


USAGE_TEXT = "not whitelisted"
NOTES = {"help": "dict values are out of scope"}
ABOUT: str = "annotated assignment is not matched"
EOF

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/extract_comments.py" --files "$SB/sample.py")" \
  || fail "extract_comments.py exited nonzero"

# whitelisted names in all three binding shapes are extracted
assert_output_contains "$OUT" '"kind": "desc_string"'
assert_output_contains "$OUT" "Do the thing."
assert_output_contains "$OUT" "batch size; not dynamic batching"
assert_output_contains "$OUT" "attribute assignment"
assert_output_contains "$OUT" "multi-line epilog prose"

# docstring extraction unchanged
assert_output_contains "$OUT" '"kind": "docstring"'
assert_output_contains "$OUT" "Module docstring"

# functional / out-of-scope strings stay out
assert_output_not_contains "$OUT" "raw prefix is not extracted"
assert_output_not_contains "$OUT" "interpolation makes it functional"
assert_output_not_contains "$OUT" "error message is functional prose"
assert_output_not_contains "$OUT" "not whitelisted"
assert_output_not_contains "$OUT" "dict values are out of scope"
assert_output_not_contains "$OUT" "annotated assignment is not matched"

# exactly four desc_string items: EPILOG, description=, help=, .epilog =
COUNT="$(printf '%s' "$OUT" | grep -Fc '"kind": "desc_string"')"
[ "$COUNT" -eq 4 ] || fail "expected 4 desc_string items, got $COUNT"
echo "PASS: t08"
