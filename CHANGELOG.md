# Changelog

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
