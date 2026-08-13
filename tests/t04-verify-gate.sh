#!/usr/bin/env bash
# t04: verify-release gate — positive + negative (mutation) tests on a sandbox copy
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

# Copy the repo (without .git / AGENTSPACE / pycache) into a sandbox; all
# mutations happen on the copy — the plugin repo is never modified.
SB="$(build_sandbox t04)" || exit 1
mkdir -p "$SB/repo"
(cd "$REPO" && tar -cf - \
  --exclude=.git --exclude=AGENTSPACE --exclude=__pycache__ --exclude='*.pyc' .) \
  | (cd "$SB/repo" && tar -xf -)

gate() { bash "$SB/repo/verify-release.sh" 2>&1; }

# --- positive: pristine copy passes -----------------------------------------
OUT="$(gate)" || fail "pristine copy should pass:
$OUT"
assert_output_contains "$OUT" "[pass] release-ready"

# --- negative 1: active skill without Explicit-only prefix fails ------------
sed -i '' 's/^description: Explicit-only:/description:/' \
  "$SB/repo/skills/x-skills/SKILL.md"
OUT="$(gate)" || true
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "x-skills: active skill description lacks 'Explicit-only:' prefix"
sed -i '' 's/^description:/description: Explicit-only:/' \
  "$SB/repo/skills/x-skills/SKILL.md"

# --- negative 2: version mismatch (plugin.json only) fails -------------------
python3 - "$SB/repo" <<'EOF'
import json, sys
p = sys.argv[1] + "/.zcode-plugin/plugin.json"
d = json.load(open(p)); d["version"] = "9.9.9"
open(p, "w").write(json.dumps(d, indent=2) + "\n")
EOF
OUT="$(gate)" || true
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "version mismatch"
python3 - "$SB/repo" <<'EOF'
import json, sys
p = sys.argv[1] + "/.zcode-plugin/plugin.json"
d = json.load(open(p)); d["version"] = "0.1.0"
open(p, "w").write(json.dumps(d, indent=2) + "\n")
EOF

# --- negative 3: Chinese content fails ---------------------------------------
# generate the Chinese content via \u escapes so this test file itself stays
# ASCII (the gate scans all committed content, including tests)
python3 -c "open('$SB/repo/scratch-cn.txt','w').write('\u4e2d\u6587\u6d4b\u8bd5\n')"
OUT="$(gate)" || true
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "Chinese found in: scratch-cn.txt"
rm -f "$SB/repo/scratch-cn.txt"

# --- negative 4: registry row without matching dir fails ---------------------
printf '| x-ghost | passive | ghost skill |\n' >> "$SB/repo/SKILLS.md"
OUT="$(gate)" || true
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "registry row 'x-ghost' has no skills/x-ghost/SKILL.md"
sed -i '' '/| x-ghost |/d' "$SB/repo/SKILLS.md"

# --- negative 5: passive skill carrying Explicit-only prefix fails -----------
# no real passive skill exists in the plugin; construct a temporary one in the
# sandbox copy to exercise the contract
mkdir -p "$SB/repo/skills/x-tmp-passive"
printf '%s\n' '---' 'name: x-tmp-passive' 'description: temporary passive skill' '---' '' '# Tmp' \
  > "$SB/repo/skills/x-tmp-passive/SKILL.md"
printf '| x-tmp-passive | passive | temporary |\n' >> "$SB/repo/SKILLS.md"
sed -i '' 's/^description:/description: Explicit-only: /' \
  "$SB/repo/skills/x-tmp-passive/SKILL.md"
OUT="$(gate)" || true
assert_output_contains "$OUT" "[fail]"
assert_output_contains "$OUT" "x-tmp-passive: passive skill description must NOT carry 'Explicit-only:' prefix"
rm -rf "$SB/repo/skills/x-tmp-passive"
sed -i '' '/| x-tmp-passive |/d' "$SB/repo/SKILLS.md"

rm -rf "$SB"
echo "PASS: t04"
