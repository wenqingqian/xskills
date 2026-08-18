#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Release gate. Read-only. Checks (exit 0 = release-ready):
#   [0] JSON validity
#   [1] version consistency (plugin.json <-> kimi.plugin.json <->
#       marketplace.json <-> CHANGELOG)
#   [2] no Chinese in committed content (user rule)
#   [3] script syntax (bash -n on .sh, py_compile on .py)
#   [4] SKILL size budget (<=120 lines per SKILL.md)
#   [5] registry <-> skills/ sync + name prefix + classification contract
#   [6] README release history coverage
#   [7] Kimi manifest contract (name/skills/interface/key whitelist)
# Usage: bash verify-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
issues=0

echo "== xskills verify-release: $ROOT =="

# --- [0] JSON validity ------------------------------------------------------
echo "[0] JSON validity"
JSON_FILES=( "$ROOT/.zcode-plugin/plugin.json" "$ROOT/kimi.plugin.json" "$ROOT/marketplace.json" )
for f in "${JSON_FILES[@]}"; do
  if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
    echo "  [issue] invalid JSON: ${f#$ROOT/}"
    issues=$((issues+1))
  fi
done

# --- [1] version consistency ------------------------------------------------
echo "[1] version consistency"
# BSD grep has no -P; sed is portable here.
LATEST="$(sed -n 's/^## v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$ROOT/CHANGELOG.md" | head -1 || true)"
if [ -z "$LATEST" ]; then
  echo "  [issue] no version in CHANGELOG.md (## vX.Y.Z)"
  issues=$((issues+1))
  LATEST="?"
fi
PLUGIN_VER="$(python3 -c "import json,sys; print(json.load(open('$ROOT/.zcode-plugin/plugin.json'))['version'])" 2>/dev/null || echo missing)"
KIMI_VER="$(python3 -c "import json,sys; print(json.load(open('$ROOT/kimi.plugin.json'))['version'])" 2>/dev/null || echo missing)"
MKTP_VER="$(python3 -c "import json,sys; d=json.load(open('$ROOT/marketplace.json')); print(d['version'])" 2>/dev/null || echo missing)"
MKTP_P0_VER="$(python3 -c "import json,sys; d=json.load(open('$ROOT/marketplace.json')); print(d['plugins'][0]['version'])" 2>/dev/null || echo missing)"
for name in "$PLUGIN_VER" "$KIMI_VER" "$MKTP_VER" "$MKTP_P0_VER"; do
  if [ "$name" != "$LATEST" ]; then
    echo "  [issue] version mismatch: expected v$LATEST, got '$name'"
    issues=$((issues+1))
  fi
done

# --- [2] no Chinese in committed content (user rule) ------------------------
echo "[2] no Chinese in committed content"
# scan files that will be committed (everything tracked/untracked except AGENTSPACE/ and .git)
# python3 is already a gate dependency; BSD grep has no -P (a silent no-op), so
# use python3 for the scan and fail loudly if it is unavailable.
# Binary files (not decodable as UTF-8 text) are not "content" and pass.
while IFS= read -r f; do
  if ! python3 -c "import sys
try:
    text = open(sys.argv[1], encoding='utf-8').read()
except UnicodeDecodeError:
    sys.exit(0)  # binary file, not text content
sys.exit(1 if any('\u4e00' <= c <= '\u9fff' for c in text) else 0)" "$f" 2>/dev/null; then
    echo "  [issue] Chinese found in: ${f#$ROOT/}"
    issues=$((issues+1))
  fi
done < <(find "$ROOT" -type f \
  -not -path "$ROOT/.git/*" \
  -not -path "$ROOT/AGENTSPACE/*" \
  -not -path "*/__pycache__/*" \
  -not -name "*.pyc")

# --- [3] script syntax ------------------------------------------------------
echo "[3] script syntax"
count=0
while IFS= read -r f; do
  count=$((count+1))
  case "$f" in
    *.sh) bash -n "$f" 2>/dev/null || { echo "  [issue] bash -n failed: ${f#$ROOT/}"; issues=$((issues+1)); } ;;
    # compile() in memory — py_compile writes __pycache__ into the repo,
    # violating this gate's read-only contract.
    *.py) python3 -c "import sys; compile(open(sys.argv[1],'rb').read(), sys.argv[1], 'exec')" "$f" 2>/dev/null \
            || { echo "  [issue] python syntax failed: ${f#$ROOT/}"; issues=$((issues+1)); } ;;
  esac
done < <(find "$ROOT" \( -name '*.sh' -o -name '*.py' \) \
  -not -path "$ROOT/.git/*" -not -path "$ROOT/AGENTSPACE/*" -not -path "*/__pycache__/*")
echo "  checked $count scripts"

# --- [4] SKILL size budget --------------------------------------------------
echo "[4] SKILL size budget (<=120 lines)"
while IFS= read -r f; do
  n=$(wc -l < "$f" | tr -d ' ' 2>/dev/null || true)
  if [ "${n:-0}" -gt 120 ]; then
    echo "  [issue] ${f#$ROOT/}: $n lines > 120 budget"
    issues=$((issues+1))
  fi
done < <(find "$ROOT/skills" -name 'SKILL.md' -not -path "*/__pycache__/*")

# --- [5] registry <-> skills/ sync + classification contract ----------------
echo "[5] registry <-> skills/ sync"
REG="$ROOT/SKILLS.md"
[ -f "$REG" ] || { echo "  [issue] SKILLS.md registry missing"; issues=$((issues+1)); REG=/dev/null; }

# every skills/<dir>/SKILL.md: frontmatter name must be x-<dir> and be in registry
while IFS= read -r f; do
  dir="$(basename "$(dirname "$f")")"
  name="$(awk '/^name:/{sub(/^name:[ \t]*/,""); print; exit}' "$f" 2>/dev/null || true)"
  case "$name" in
    x-*) ;;
    *) echo "  [issue] $dir: frontmatter name '$name' lacks x- prefix"; issues=$((issues+1)) ;;
  esac
  if [ "$name" != "$dir" ]; then
    echo "  [issue] $dir: frontmatter name '$name' != directory name"
    issues=$((issues+1))
  fi
  if [ -f "$REG" ] && ! grep -Fq "| $name |" "$REG"; then
    echo "  [issue] $dir: '$name' not registered in SKILLS.md"
    issues=$((issues+1))
  fi
  # classification contract: active rows must carry Explicit-only in description,
  # passive rows must NOT carry it; registry type must be a valid value.
  # ENVIRON instead of -v: -v processes backslash escapes (repo script discipline).
  desc="$(awk '/^description:/{sub(/^description:[ \t]*/,""); print; exit}' "$f" 2>/dev/null || true)"
  type="$(n="$name" awk '$1=="|" && $2==ENVIRON["n"] {print $4}' "$REG" 2>/dev/null | tr -d ' ')"
  case "$type" in
    passive|active) ;;
    "") echo "  [issue] $dir: no type found in SKILLS.md registry"; issues=$((issues+1)); type="invalid" ;;
    *) echo "  [issue] $dir: registry type '$type' invalid (passive|active)"; issues=$((issues+1)); type="invalid" ;;
  esac
  case "$desc" in
    Explicit-only:*)
      if [ "$type" != "active" ]; then
        echo "  [issue] $dir: passive skill description must NOT carry 'Explicit-only:' prefix"
        issues=$((issues+1))
      fi ;;
    *)
      if [ "$type" = "active" ]; then
        echo "  [issue] $dir: active skill description lacks 'Explicit-only:' prefix"
        issues=$((issues+1))
      fi ;;
  esac
done < <(find "$ROOT/skills" -name 'SKILL.md' -not -path "*/__pycache__/*")

# every registry row must have a matching skills/<x-name>/SKILL.md
if [ -f "$REG" ]; then
  while IFS='|' read -r _ name type rest; do
    name="$(echo "$name" | tr -d ' ')"
    [ -n "$name" ] || continue
    case "$name" in
      x-*) ;;
      *) echo "  [issue] registry row '$name' lacks x- prefix"; issues=$((issues+1)); continue ;;
    esac
    if [ ! -f "$ROOT/skills/$name/SKILL.md" ]; then
      echo "  [issue] registry row '$name' has no skills/$name/SKILL.md"
      issues=$((issues+1))
    fi
  done < <(grep '^| x-' "$REG")
fi

# --- [6] README release history coverage ------------------------------------
echo "[6] README release history"
if [ "$LATEST" != "?" ]; then
  if ! grep -Fq "| v$LATEST |" "$ROOT/README.md"; then
    echo "  [issue] README.md missing release history row for v$LATEST"
    issues=$((issues+1))
  fi
fi

# --- [7] Kimi manifest contract ----------------------------------------------
# Portable release-gate subset of the Kimi plugin schema (kimi.plugin.json —
# name required, [a-z0-9][a-z0-9_-]{0,63}). Kimi installs via /plugins install
# (local/zip/GitHub); there is no Kimi marketplace manifest to check.
echo "[7] Kimi manifest contract"
KIMI_OUT="$(python3 - "$ROOT/kimi.plugin.json" <<'EOF' 2>&1
import json, re, sys
path = sys.argv[1]
issues = []
try:
    kimi = json.load(open(path))
except Exception as e:
    print(f"  [issue] kimi.plugin.json unreadable: {e}")
    sys.exit(0)
allowed_top = {
    "name", "version", "description", "keywords", "author", "homepage",
    "license", "interface", "skills", "agents", "commands", "mcpServers",
    "hooks", "sessionStart", "systemPrompt", "systemPromptPath",
}
if not isinstance(kimi, dict):
    issues.append("kimi.plugin.json root must be an object")
else:
    unknown = sorted(set(kimi) - allowed_top)
    if unknown:
        issues.append(f"unsupported top-level fields: {', '.join(unknown)}")
    for field in ("name", "version", "description"):
        if not isinstance(kimi.get(field), str) or not kimi[field].strip():
            issues.append(f"required non-empty field: {field}")
    name = kimi.get("name", "")
    if name != "xskills":
        issues.append(f"plugin name must be xskills, got {name!r}")
    elif not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", name):
        issues.append(f"plugin name violates [a-z0-9][a-z0-9_-]{{0,63}}: {name!r}")
    skills_path = str(kimi.get("skills", "")).rstrip("/")
    if skills_path not in ("skills", "./skills"):
        issues.append(f"skills path must resolve to skills, got {kimi.get('skills')!r}")
    interface = kimi.get("interface")
    required_interface = (
        "displayName", "shortDescription", "longDescription", "developerName", "websiteURL",
    )
    if not isinstance(interface, dict):
        issues.append("interface object is required")
    else:
        for field in required_interface:
            if not isinstance(interface.get(field), str) or not interface[field].strip():
                issues.append(f"required non-empty interface.{field}")
for msg in issues:
    print(f"  [issue] {msg}")
EOF
)"
if [ -n "$KIMI_OUT" ]; then
  echo "$KIMI_OUT"
  issues=$((issues+1))
fi

# --- summary ----------------------------------------------------------------
dirty=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)
echo ""
if [ "$issues" -eq 0 ]; then
  echo "[pass] release-ready (v$LATEST)"
  [ "${dirty:-0}" -gt 0 ] && echo "[note] working tree has $dirty uncommitted change(s) — commit after passing"
  exit 0
else
  echo "[fail] $issues issue(s) — fix before release"
  exit 1
fi
