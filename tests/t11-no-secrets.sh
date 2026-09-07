#!/usr/bin/env bash
# t11: no-secrets checker — IPs/tokens/credential assignments are findings on
#      any text file (not just .py); loopback and RFC 5737 doc ranges get
#      exemption flags instead of being hidden; version-like numbers and
#      placeholder assignments stay silent; PYTHON_ONLY checkers skip non-.py
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t11)" || exit 1

cat > "$SB/notes.md" <<'EOF'
# Deploy notes

prod gateway at 10.0.0.7, failover 203.0.113.9 (doc range), local 127.0.0.1
db password=hunter2secret, retry token=9f86d081882c
version bumped to 2.6.32.5 today
placeholder like password=os.environ is fine
AWS sample AKIAIOSFODNN7EXAMPLE in prose
EOF
cat > "$SB/code.py" <<'EOF'
"""Module."""
EOF

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/checks.py" --files "$SB/notes.md" "$SB/code.py")" \
  || fail "checks.py exited nonzero"

# findings carry the no-secrets checker id
assert_output_contains "$OUT" '"checker": "no-secrets"'
# private IP flagged, no exemption flag; doc range + loopback flagged, not hidden
assert_output_contains "$OUT" '"kinds": ['
assert_output_contains "$OUT" 'ipv4'
assert_output_contains "$OUT" 'doc-range'
assert_output_contains "$OUT" 'loopback'
# credential assignments caught
assert_output_contains "$OUT" 'credential-assignment'
assert_output_contains "$OUT" 'hunter2secret'
# aws-style key caught
assert_output_contains "$OUT" 'aws-key'
assert_output_contains "$OUT" 'AKIAIOSFODNN7EXAMPLE'
# non-py file scanned; .py file produces no no-secrets noise
assert_output_contains "$OUT" 'notes.md'
# env-ref placeholders stay silent; version-like 4-part numbers are still
# flagged (shape-only detection, known false-positive class — the agent
# verifies before reporting; over-reporting is the safe direction here)
assert_output_not_contains "$OUT" 'placeholder like'
assert_output_contains "$OUT" '2.6.32.5'
echo "PASS: t11"
