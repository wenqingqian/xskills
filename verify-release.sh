#!/usr/bin/env bash
# Dev tool — repo root only, NOT part of the deployed plugin.
# Release gate. Read-only. Checks (exit 0 = release-ready):
#   [0] JSON validity
#   [1] version consistency (plugin.json <-> marketplace.json <-> CHANGELOG)
#   [2] no Chinese in committed content (user rule)
#   [3] script syntax (bash -n on .sh, py_compile on .py)
#   [4] SKILL size budget (<=120 lines per SKILL.md)
#   [5] registry <-> skills/ sync + name prefix + classification contract
#   [6] README release history coverage
# Usage: bash verify-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
issues=0

echo "== xskills verify-release: $ROOT =="

# --- [0] JSON validity ------------------------------------------------------
echo "[0] JSON validity"
JSON_FILES=( "$ROOT/.zcode-plugin/plugin.json" "$ROOT/marketplace.json" )
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
MKTP_VER="$(python3 -c "import json,sys; d=json.load(open('$ROOT/marketplace.json')); print(d['version'])" 2>/dev/null || echo missing)"
MKTP_P0_VER="$(python3 -c "import json,sys; d=json.load(open('$ROOT/marketplace.json')); print(d['plugins'][0]['version'])" 2>/dev/null || echo missing)"
for name in "$PLUGIN_VER" "$MKTP_VER" "$MKTP_P0_VER"; do
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
while IFS= read -r f; do
  if ! python3 -c "import sys; sys.exit(1 if any('\u4e00' <= c <= '\u9fff' for c in open(sys.argv[1], encoding='utf-8').read()) else 0)" "$f" 2>/dev/null; then
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
