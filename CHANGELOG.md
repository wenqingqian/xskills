# Changelog

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
