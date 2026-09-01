# xskills Development Guide

Contributor guide for developing, verifying, and releasing skills in this repository.
Adapted from the proven process of the AGENTSPACE plugin repo
(`/Users/wenqingqian/Documents/mytest/AGENTSPACE`).

## Skill Classification (MUST)

Every skill in this plugin is strictly classified into one of two types. The
classification is managed in ONE file: `SKILLS.md` at the repo root (the
registry — name / type / description per skill).

| Type | Invocation | name | description |
| --- | --- | --- | --- |
| passive | Agent auto-triggers by judging the description | `x-<name>` | plain functional description |
| active | User explicitly invokes by name or keyword; never auto-triggered | `x-<name>` | `Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords; never auto-triggered.` + functional description |

Rules:
- Every skill name starts with the `x-` prefix (e.g. `x-code-clean`, `x-skills`).
- Passive skills let the agent decide via the description; active skills MUST
  carry the explicit-only prefix template in their description and MUST NOT be
  auto-triggered.
- Add/update the registry row in `SKILLS.md` for every skill before release;
  `verify-release.sh` enforces registry ↔ `skills/` sync.

## Repository Structure

```
xskills/
├── .zcode-plugin/
│   └── plugin.json       # ZCode plugin manifest (name/description/version/author)
├── marketplace.json      # Marketplace manifest (version must match plugin.json)
├── kimi.plugin.json      # Kimi plugin manifest (name/version/skills/interface)
├── SKILLS.md             # Skill registry: one file classifying all skills (passive/active)
├── skills/
│   └── <x-name>/
│       └── SKILL.md      # Skill body: YAML frontmatter (name/description) + instructions
├── DEVELOPMENT.md        # This file
├── AGENTS.md             # Project working guide
└── README.md
```

## How to Develop a Skill

1. Create a directory under `skills/`, e.g. `skills/x-my-skill/` (name starts with `x-`).
2. Create `SKILL.md` starting with YAML frontmatter containing **only** `name` and `description`:

   ```markdown
   ---
   name: x-my-skill
   description: <classification-conformant description>
   ---

   # Instructions
   ```

3. Write the description per the skill's classification (see "Skill Classification"
   above):
   - **passive**: describe what the skill does and when to trigger it — the agent
     auto-triggers via this description.
   - **active**: prefix the description with the explicit-only template
     (`Explicit-only: invoked ONLY when the user explicitly requests this skill by
     name or its keywords; never auto-triggered.`) then the functional description.
     List the known keywords (e.g. "x-skills", "list my skills") inside the
     description so explicit invocation is recognizable.
4. **Language policy (MUST)**: all content that will be committed to this repository is
   English only — no Chinese. This includes SKILL.md, README, docs, comments, commit
   messages, and JSON manifests (plugin.json / marketplace.json). (This deliberately
   deviates from the AGENTSPACE plugin's bilingual policy.)
5. **Size budget**: keep `SKILL.md` under 150 lines. Move background detail elsewhere
   (e.g. referenced docs) if it grows.
6. **Hard/soft separation**: mechanical aggregation belongs in scripts with strict,
   verbatim output templates; free-form slots are filled by agents. Never mix the two
   inside a skill's instructions.
7. **Registry sync (MUST)**: add the skill's row (name / type / description) to
   `SKILLS.md` before release; `verify-release.sh` checks registry ↔ `skills/` sync.

## How to Verify

1. **Syntax first**: `bash -n <script.sh> && echo "syntax OK"` for any shell asset;
   `python3 -m py_compile` for Python assets.
2. **Sandbox test**: create an isolated sandbox (`SB=$(mktemp -d /tmp/xs-...-XXXXXX)`),
   run the skill's flow there, verify output. Tests only touch the sandbox copy —
   the plugin repo is never modified.
3. **End-to-end**: exercise the full skill flow (trigger → action → result) once in a
   real, third-party directory outside this repo.
4. **Release gate (run before every release)**: `bash verify-release.sh` — JSON
   validity, version consistency (plugin.json ↔ kimi.plugin.json ↔
   marketplace.json ↔ CHANGELOG), no Chinese in committed content,
   `bash -n` / `py_compile`, SKILL size budget, registry ↔ `skills/` sync,
   README release history, Kimi manifest contract. Fix any issue it reports.
5. **Regression suite**: `bash self-test.sh` — runs every `tests/t[0-9]*.sh` scenario
   in an isolated sandbox (repo never modified).
6. **Dogfooding**: after release, install the plugin and invoke a skill in a real session.

## How to Release

Fixed gate sequence for every release:

1. **Scaffold the version**: `bash new-version.sh X.Y.Z` — validates the
   format and monotonic increase, bumps the version in `.zcode-plugin/plugin.json`,
   `kimi.plugin.json`, and `marketplace.json` (top-level + `plugins[0]`), and
   inserts a CHANGELOG skeleton at the top.
2. **Fill the CHANGELOG entry** at the top of `CHANGELOG.md`: one bullet per
   change. The changelog is the record of what changed and why.
3. **Add the README release-history row** (`| vX.Y.Z | date | what changed |`).
4. **Run the release gate** `bash verify-release.sh` — all checks must pass.
5. **Run the regression suite** `bash self-test.sh` — all green.
6. **Code review** — review the diff before committing.
7. **Commit + push**. Commit style: `<type> v<version> <description>`
   (e.g. `feat: v0.3.0 add x-example skill`).

### Version Discipline

- **Semantics are decided per release with the user** — there is no fixed
  minor/patch rule; ask the user which number to use when scaffolding
  (`bash new-version.sh` asks nothing, it only enforces monotonic increase).
  Current practice: new skill/capability → minor (0.2 → 0.3); fixes →
  patch (0.2.1); breaking changes or milestones → major.
- **Long-term 0.x**: this plugin stays in 0.x for the foreseeable future;
  no 1.0 target date.
- **Bump only on capability changes**: new skill, changed skill behavior, or
  manifest changes bump the version.
- **No bump for dev tooling/docs**: DEVELOPMENT.md, tests, and doc-only
  changes ship without a version bump.
- **Batch small fixes**: accumulate small fixes into ONE release — never ship
  a version per fix.
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
