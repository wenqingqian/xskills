# Changelog

## v0.6.0 (2026-09-01)

- `x-better-commit` title rules hardened after real-world misses:
  - Zero-context reader principle: the title and body are written for
    someone who knows only the repository; session-local shorthand
    (review-finding IDs like "R1-R8", "review leftovers", "pre-surgery")
    is banned everywhere. Public issue numbers remain the only allowed
    outside reference and live in the body footer.
  - Type prefix unconditionally mandatory: the old "follow the repo's
    existing vocabulary" escape hatch let agents drop `feat:` in repos
    with non-conventional logs. Repo convention may now adjust only the
    type set and scope usage.
  - One outcome, judged by grammar position rather than symbol: no
    separator may join two verb-bearing clauses, and deliverable
    enumeration in the title is banned outright. Remediation order:
    umbrella rewrite first, dominant-change-plus-body second, and never
    splitting an already-made commit (split advice only while drafting).
  - Meta-narration banned: file counts ("7 files"), "part N/M", and
    "pre-/post-*" sequence markers no longer appear in titles.

## v0.5.0 (2026-09-01)

- x-code-clean rework — now three check categories over one scope: comment
  cleanup, style checks, and the new dead-code detection.
- Invocation parameters removed: the skill takes no flags; the user states
  the scope in natural language (files/directories or "since commit X") and
  the agent maps it onto `--files`/`--range`; default is the uncommitted
  changes, stated at the top of the report. `checks.py` dropped
  `--check`/`--all`/`--list` and always runs every registered checker.
- Comment cleanup gains a cross-file/cross-repo reference rule: keep only
  references that create a constraint or provenance this project needs
  (vendored-code provenance, external spec contracts, verified in-repo sync
  pointers); delete informational asides into other projects/repos;
  dangling in-repo references are always deleted. GUIDE.md carries the
  worked cases.
- New `dead-code` checker (Python only): module-level functions/classes/
  constants defined in scope files but never referenced in any repo `.py`;
  candidates from scope files, references searched repo-wide; exemption
  signals (`exported`, `decorated`, `entry-point`, `test-only`,
  `dynamic-ref`) are reported as flags, never hidden.
- New workflow step "session-context review": findings are re-checked
  against what this session just built (e.g. a function awaiting its caller
  is not dead code) before the report.
- verify-release.sh SKILL.md size budget raised from 120 to 150 lines;
  DEVELOPMENT.md synced.
- Tests: t03 rewritten for the flagless checks.py; new t06 covers the
  dead-code checker.

## v0.4.0 (2026-08-27)

- New active skill `x-better-commit`: draft or rewrite a git commit
  message — title and body — from the staged diff or an existing commit.
  Carries the title rules (type prefix, imperative mood, specific and
  diff-grounded, <=50/72 chars, one coherent purpose — tightly coupled
  changes may share a commit) and the body rules (optional by default:
  only non-obvious changes get a body; when written — why before what,
  wrapped at 72, behavior over narration, concrete numbers, footer
  refs), plus a final check that refuses to rewrite published history
  and a worked example.
- Three modes: `x-better-commit` commits staged work, `--amend` rewrites
  the last unpushed commit, `<rev>` prints an improved message without
  touching history.
- SKILLS.md registry and README (layout + skills table) updated for the
  new skill.

## v0.3.0 (2026-08-19)

- Kimi plugin support: new `kimi.plugin.json` manifest at the repo root
  (name / version / description / author / homepage / license / keywords /
  skills / interface) so the plugin can be installed via Kimi's `/plugins
  install` (zip or GitHub URL); Kimi publishes no marketplace listing, so no
  additional marketplace file.
- `new-version.sh` now syncs the version across all three manifests
  (`.zcode-plugin/plugin.json`, `kimi.plugin.json`, `marketplace.json`
  top-level and `plugins[0]`).
- `verify-release.sh` gained a Kimi manifest contract check: name must equal
  `xskills` and match `[a-z0-9][a-z0-9_-]{0,63}`, skills path must resolve to
  `skills`, required `interface` metadata must be present, and top-level keys
  must stay within the Kimi schema whitelist.
- Tests updated: t05 asserts the kimi marker sync after a `new-version.sh`
  bump; t04 adds a negative case for a Kimi contract violation.

## v0.2.0 (2026-08-13)

- Three new skills, localized from the local agent skills (all active,
  `Explicit-only:` descriptions, English-only content):
  - `x-code-review`: multi-axis code review (correctness/readability/
    architecture/security/performance) of uncommitted changes via the
    dedicated code-review subagent cluster (major + sub-N + merger +
    executor); full standards + report template in its GUIDE.md.
  - `x-grilling`: relentless one-question-at-a-time interview to stress-test
    a plan, decision, or idea until shared understanding.
  - `x-subagent-orchestration`: default-to-delegate rules for the Agent tool
    (bulk reading/search/tests/implementations to built-in Explore /
    general-purpose subagents).
- `x-skills` workbench enhanced: registry gained a `usage` column; the skill
  now lists name / type / description / usage per skill, and supports
  `x-skills --usage <name>` for one skill's invocation parameters.
- SKILLS.md registry and README updated for all five skills.

## v0.1.1 (2026-08-13)

- `x-code-clean` reclassified from passive to **active** (explicit invocation
  only): description now carries the `Explicit-only:` prefix; registry and
  README updated; t04 negative test now constructs a temporary passive skill
  in the sandbox to exercise the passive-with-prefix contract.

## v0.1.0 (2026-08-13)

- Initial release.
- Skill classification system: every skill strictly classified as passive
  (agent auto-triggers via description) or active (explicit invocation only),
  managed in a single registry file `SKILLS.md`; all skill names use the `x-`
  prefix; active skills carry the `Explicit-only:` description prefix template.
- `x-code-clean` (passive): review and clean up code comments (multi-language
  extraction via `extract_comments.py`) and code-style violations via the
  extensible checker registry (`checks.py` + `checks/`, first checker
  `no-inner-import`); report-then-confirm workflow.
- `x-skills` (active): workbench skill that lists the plugin's skills with a
  short description of each, read from the registry.
- Plugin + marketplace manifests (`.zcode-plugin/plugin.json`,
  `marketplace.json`), DEVELOPMENT.md contributor guide, verify-release gate
  and self-test regression suite.
