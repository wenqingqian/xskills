# Changelog

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
