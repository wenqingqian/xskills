#!/usr/bin/env bash
# t02: extract_comments.py heuristic mode — shell/yaml markers + block comments
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t02)" || exit 1
cat > "$SB/sample.sh" <<'EOF'
#!/usr/bin/env bash
# full shell comment
echo hi  # inline shell comment
EOF
cat > "$SB/sample.c" <<'EOF'
/* block
   comment */
int main() { return 0; } // trailing
EOF

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/extract_comments.py" --files "$SB/sample.sh" "$SB/sample.c")" \
  || fail "extract_comments.py exited nonzero"
assert_output_contains "$OUT" "# full shell comment"
assert_output_contains "$OUT" "# inline shell comment"
assert_output_contains "$OUT" "/* block"
assert_output_contains "$OUT" "comment */"
# line-marker extraction must work in block-pair languages too (regression:
# the // loop was unreachable when block_pairs is set)
assert_output_contains "$OUT" "// trailing"
echo "PASS: t02"
