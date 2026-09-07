#!/usr/bin/env bash
# t01: changed_lines.py — added-line sets for working-tree and range modes,
#      created/untracked files reported whole, binary files skipped
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t01)" || exit 1
PROJ="$SB/proj"
mkdir -p "$PROJ"
cd "$PROJ" || exit 1
git init -q
git config user.email t@example.com
git config user.name t

printf 'keep\nold\n' > a.py
printf '\000binary\000' > blob.png
printf 'readme text\n' > README
git add a.py blob.png README
git commit -qm base

# working-tree mode: a.py gains lines 2-3, README rewritten at line 1,
# b.py created (tracked), c.py untracked — both reviewed whole
printf 'keep\nnew1\nnew2\nold\n' > a.py
printf 'brand new file\n' > b.py
printf 'untracked\n' > c.py
printf 'readme changed\n' > README
git add a.py b.py README

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/changed_lines.py")" \
  || fail "working-tree mode exited nonzero"
python3 - "$OUT" <<'PYEOF' || fail "working-tree line sets wrong"
import json, sys
d = json.loads(sys.argv[1])
assert d["files"]["a.py"] == [2, 3], d
assert d["files"]["README"] == [1], d
assert sorted(d["whole"]) == ["b.py", "c.py"], d
assert "blob.png" not in d["files"] and "blob.png" not in d["whole"], d
PYEOF

# range mode: commit the working tree as R1, then extend a.py in R2
git commit -qm change1
R1="$(git rev-parse HEAD)"
printf 'keep\nnew1\nnew2\nold\nmore\n' > a.py
printf '\000stillbinary\000' > blob.png
git commit -aqm change2

OUT="$(python3 "$REPO/skills/x-code-clean/scripts/changed_lines.py" --range "$R1..HEAD")" \
  || fail "range mode exited nonzero"
python3 - "$OUT" <<'PYEOF' || fail "range line sets wrong"
import json, sys
d = json.loads(sys.argv[1])
assert d["files"] == {"a.py": [5]}, d
assert d["whole"] == [], d
assert "blob.png" not in d["files"], d
PYEOF

# range that created a file reports it whole
OUT="$(python3 "$REPO/skills/x-code-clean/scripts/changed_lines.py" --range base..HEAD 2>/dev/null)" \
  || OUT="$(python3 "$REPO/skills/x-code-clean/scripts/changed_lines.py" --range "$(git rev-parse HEAD~2)..HEAD")" \
  || fail "whole-range mode exited nonzero"
printf '%s' "$OUT" | grep -Fq '"b.py"' || fail "expected b.py whole in full range"
echo "PASS: t01"
