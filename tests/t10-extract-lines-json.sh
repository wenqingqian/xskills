#!/usr/bin/env bash
# t10: extract_comments.py --lines-json composes with changed_lines.py —
#      modified files report only items intersecting the added-line set,
#      created files report whole (via "whole"), out-of-scope files are
#      skipped, and an explicitly empty payload scopes the run to nothing
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SK="$REPO/skills/x-code-clean/scripts"
SB="$(build_sandbox t10)" || exit 1
cd "$SB"
git init -q .
git config user.email t@t; git config user.name t

cat > base.py <<'EOF'
"""Base module."""

def keep():
    return 1  # untouched inline
EOF
git add -A && git commit -qm base

# modify base.py (new comment on line 4) and create new.py (created whole)
cat > base.py <<'EOF'
"""Base module."""

def keep():
    return 1  # untouched inline

# added full comment
def extra():
    return 2  # added inline
EOF
cat > new.py <<'EOF'
"""Fresh module."""
# fresh comment
EOF
echo "untouched" > other.txt

SCOPE="$(python3 "$SK/changed_lines.py")" || fail "changed_lines.py exited nonzero"

OUT="$(printf '%s' "$SCOPE" | python3 "$SK/extract_comments.py" --files base.py new.py other.txt --lines-json -)" \
  || fail "extract_comments.py exited nonzero"

# base.py: only items intersecting added lines (docstring/old inline excluded)
assert_output_contains "$OUT" "# added full comment"
assert_output_contains "$OUT" "# added inline"
assert_output_not_contains "$OUT" "untouched inline"
assert_output_not_contains "$OUT" "Base module"
# new.py: created file reports whole
assert_output_contains "$OUT" "Fresh module"
assert_output_contains "$OUT" "# fresh comment"
# other.txt: not in the scope payload -> skipped entirely
assert_output_not_contains "$OUT" "untouched"

# an explicitly empty payload scopes the run to nothing (no whole-file fallback)
EMPTY_OUT="$(printf '{"files": {}, "whole": []}' | \
  python3 "$SK/extract_comments.py" --files base.py --lines-json -)" \
  || fail "extract_comments.py (empty payload) exited nonzero"
assert_output_not_contains "$EMPTY_OUT" "added full comment"
assert_output_not_contains "$EMPTY_OUT" "Fresh module"
echo "PASS: t10"
