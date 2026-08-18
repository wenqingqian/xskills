#!/usr/bin/env bash
# t05: new-version.sh — format/downgrade rejection + marker sync on a sandbox copy
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

SB="$(build_sandbox t05)" || exit 1
mkdir -p "$SB/repo"
(cd "$REPO" && tar -cf - \
  --exclude=.git --exclude=AGENTSPACE --exclude=__pycache__ --exclude='*.pyc' .) \
  | (cd "$SB/repo" && tar -xf -)
cd "$SB/repo" || exit 1

# invalid format -> exit 2
bash new-version.sh abc >/dev/null 2>&1 && fail "invalid format should fail" || true

# downgrade -> exit 1
bash new-version.sh 0.1.0 >/dev/null 2>&1 && fail "downgrade should fail" || true

# normal bump -> all markers synced (compute a version newer than the repo's
# current latest so this test survives future releases)
NEXT="$(python3 - <<'EOF'
import re
m = re.search(r"^## v(\d+)\.(\d+)\.\d+", open("CHANGELOG.md").read(), re.M)
maj, mid = (int(x) for x in m.group(1, 2))
print(f"{maj}.{mid+1}.0")
EOF
)"
[ -n "$NEXT" ] || fail "could not compute next version"
assert_ok bash new-version.sh "$NEXT"
python3 - "$SB/repo" "$NEXT" <<'EOF'
import json, sys
r, ver = sys.argv[1], sys.argv[2]
assert json.load(open(f"{r}/.zcode-plugin/plugin.json"))["version"] == ver
assert json.load(open(f"{r}/kimi.plugin.json"))["version"] == ver, "kimi marker unsynced"
m = json.load(open(f"{r}/marketplace.json"))
assert m["version"] == ver and m["plugins"][0]["version"] == ver, "marketplace markers unsynced"
print("markers OK")
EOF
head -6 "$SB/repo/CHANGELOG.md" | grep -Fq "## v$NEXT" || fail "CHANGELOG skeleton missing"

rm -rf "$SB"
echo "PASS: t05"
