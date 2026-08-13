# xskills Development Guide

Contributor guide for developing, verifying, and releasing skills in this repository.
Adapted from the proven process of the AGENTSPACE plugin repo
(`/Users/wenqingqian/Documents/mytest/AGENTSPACE`).

## Repository Structure

```
xskills/
├── .zcode-plugin/
│   └── plugin.json       # Plugin manifest (name/description/version/author)
├── skills/
│   └── <skill-name>/
│       └── SKILL.md      # Skill body: YAML frontmatter (name/description) + instructions
├── DEVELOPMENT.md        # This file
├── AGENTS.md             # Project working guide
└── README.md
```

## How to Develop a Skill

1. Create a directory under `skills/`, e.g. `skills/my-skill/`.
2. Create `SKILL.md` starting with YAML frontmatter containing **only** `name` and `description`:

   ```markdown
   ---
   name: my-skill
   description: When this skill should be triggered (be specific for accurate auto-triggering)
   ---

   # Instructions
   ```

3. `description` must state the trigger conditions explicitly (e.g. "Triggered ONLY by
   explicit /my-skill; never automatic"). Clear descriptions improve auto-trigger accuracy.
4. **Language policy (MUST)**: all content that will be committed to this repository is
   English only — no Chinese. This includes SKILL.md, README, docs, comments, and commit
   messages. (This deliberately deviates from the AGENTSPACE plugin's bilingual policy.)
5. **Size budget**: keep `SKILL.md` under 120 lines. Move background detail elsewhere
   (e.g. referenced docs) if it grows.
6. **Hard/soft separation**: mechanical aggregation belongs in scripts with strict,
   verbatim output templates; free-form slots are filled by agents. Never mix the two
   inside a skill's instructions.

## How to Verify

1. **Syntax first**: `bash -n <script.sh> && echo "syntax OK"` for any shell asset.
2. **Sandbox test**: create an isolated sandbox (`SB=$(mktemp -d /tmp/xs-...-XXXXXX)`),
   run the skill's flow there, verify output. Tests only touch the sandbox copy —
   the plugin repo is never modified.
3. **End-to-end**: exercise the full skill flow (trigger → action → result) once in a
   real, third-party directory outside this repo.
4. **Release gate (run before every release)**:
   - `python3 -m json.tool` on every `.json` file (plugin.json etc.)
   - version consistency: `version` in plugin.json matches the latest CHANGELOG entry
   - `bash -n` on all `.sh` files
   - SKILL size budget (≤ 120 lines per SKILL.md)
   - README release history table updated with the new version
5. **Dogfooding**: after release, install the plugin and invoke a skill in a real session.

## How to Release

Fixed gate sequence for every release:

1. **Bump version** in `.zcode-plugin/plugin.json` (bare version, no `v` prefix).
2. **Add a CHANGELOG entry** at the top of `CHANGELOG.md` (keep this file at repo root):
   `## vX.Y.Z (YYYY-MM-DD)` + one bullet per change. The changelog is the record of
   what changed and why.
3. **Run the release gate** (verify section above) — all checks must pass.
4. **Code review** — review the diff before committing.
5. **Commit + push**. Commit style: `<type> v<version> <description>` (e.g. `feat: v0.2.0 add my-skill`).

### Version Discipline

- **Bump only on capability changes**: new skill, changed skill behavior, or manifest
  changes bump the version.
- **No bump for dev tooling/docs**: DEVELOPMENT.md, tests, and doc-only changes ship
  without a version bump.
- **Batch small fixes**: accumulate small fixes into ONE release — never ship a version
  per fix.
- **Unpushed commits roll into the next version**.

### Script Pattern Discipline (MUST, when writing shell assets)

Hard-won contracts from the AGENTSPACE repo's risk audit. New code that violates one is
a release blocker:

1. **ENVIRON, never `-v`**: pass escaped content to `awk` via environment variables —
   `awk -v` processes backslash escapes and eats the `\` of `\|`.
2. **Dual-condition matching**: delete/update rows by `name AND location`, never by
   name alone.
3. **Atomic writes**: write via tmp+mv; never `cat >`, `>`, or `>>` on a live file.
4. **Guard every `$(...)` read path**: `2>/dev/null || true` — a bare awk/grep on a
   missing file aborts the whole script under `set -euo pipefail`.
5. **Read-only commands must not write**: anything declared read-only stays read-only;
   write paths belong behind explicit gates (`--fix`) or dedicated scripts.
