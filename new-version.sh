#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Scaffold a new plugin version: bump the version markers (plugin.json +
# kimi.plugin.json + marketplace.json top-level and plugins[0]) and insert a
# CHANGELOG skeleton at the top.
#
# Usage: bash new-version.sh X.Y.Z
# After running: fill the CHANGELOG bullets, add the README release-history
# row, then run `bash verify-release.sh` as the release gate.
#
# Version semantics are decided per release with the user (see
# DEVELOPMENT.md); this tool only enforces monotonic increase and a valid
# X.Y.Z format.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NEW="${1:-}"

[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "usage: bash new-version.sh X.Y.Z" >&2
  exit 2
}

# Latest version from the CHANGELOG (BSD sed; newest-first convention).
LATEST="$(sed -n 's/^## v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$ROOT/CHANGELOG.md" | head -1 || true)"
[ -n "$LATEST" ] || {
  echo "error: no version in CHANGELOG.md (## vX.Y.Z)" >&2
  exit 1
}

# Version-aware comparison (macOS sort lacks -V; python is a gate dependency).
if ! python3 - "$LATEST" "$NEW" <<'EOF' | grep -qx newer
import sys
def v(s): return tuple(int(x) for x in s.split('.'))
print("newer" if v(sys.argv[2]) > v(sys.argv[1]) else "")
EOF
then
  echo "error: $NEW is not newer than latest v$LATEST" >&2
  exit 1
fi

# --- 1. version field bumps -------------------------------------------------
# Load + apply to all targets in memory first; only write once every target
# validated, so a missing/corrupt file cannot leave a partially-applied state.
python3 - "$NEW" "$ROOT" <<'EOF'
import json, sys
ver, root = sys.argv[1], sys.argv[2]
targets = [
    (f"{root}/.zcode-plugin/plugin.json", lambda d: d.__setitem__("version", ver)),
    (f"{root}/kimi.plugin.json", lambda d: d.__setitem__("version", ver)),
    # marketplace carries BOTH a top-level version and plugins[0].version —
    # one lambda per field would reload the unmodified file and the last
    # write wins, dropping the other field (drift caught by verify-release [1])
    (f"{root}/marketplace.json", lambda d: [d.__setitem__("version", ver), d["plugins"][0].__setitem__("version", ver)]),
]
docs, errors = [], []
for path, fn in targets:
    try:
        d = json.load(open(path))
        fn(d)
    except Exception as e:
        errors.append(f"{path}: {e}")
        continue
    docs.append((path, d))
if errors:
    for e in errors:
        print(f"error: cannot load {e}", file=sys.stderr)
    sys.exit(1)
for path, d in docs:
    open(path, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print(f"  {path}: version -> {ver}")
EOF

# --- 2. CHANGELOG skeleton at the top --------------------------------------
CL="$ROOT/CHANGELOG.md"
TODAY="$(date +%F)"
python3 - "$CL" "$NEW" "$TODAY" <<'EOF'
import sys
cl, ver, today = sys.argv[1], sys.argv[2], sys.argv[3]
block = f"## v{ver} ({today})\n\n- TODO: one bullet per change (fill before release)\n\n"
with open(cl) as f:
    content = f.read()
header = "# Changelog\n\n"
if content.startswith(header):
    content = content[len(header):]
with open(cl, "w") as f:
    f.write(header + block + content)
print(f"  CHANGELOG.md: v{ver} skeleton inserted at top")
EOF

echo ""
echo "Scaffolded v$NEW (from v$LATEST):"
echo "  - version fields bumped in plugin.json / kimi.plugin.json / marketplace.json"
echo "  - CHANGELOG.md skeleton at top (fill the bullets)"
echo ""
echo "Next:"
echo "  1. Fill CHANGELOG bullets (decide minor/patch with the user)"
echo "  2. Add the README release-history row (| v$NEW | date | what changed |)"
echo "  3. bash verify-release.sh   <- release gate"
echo "  4. Code review -> commit -> push"
