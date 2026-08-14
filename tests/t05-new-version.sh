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

# normal bump -> all markers synced
assert_ok bash new-version.sh 0.3.0
python3 - "$SB/repo" <<'EOF'
import json, sys
r = sys.argv[1]
assert json.load(open(f"{r}/.zcode-plugin/plugin.json"))["version"] == "0.3.0"
m = json.load(open(f"{r}/marketplace.json"))
assert m["version"] == "0.3.0" and m["plugins"][0]["version"] == "0.3.0", "marketplace markers unsynced"
print("markers OK")
EOF
head -6 "$SB/repo/CHANGELOG.md" | grep -q "## v0.3.0" || fail "CHANGELOG skeleton missing"

rm -rf "$SB"
echo "PASS: t05"
