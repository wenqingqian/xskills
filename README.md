# xskills

A repository that manages personal [ZCode](https://z.ai) skills and packages them into a ZCode plugin for unified management. Every skill is strictly classified as **passive** (the agent auto-triggers it via the description) or **active** (explicit invocation only).

## Skill Classification

Every skill is registered in one file — [`SKILLS.md`](SKILLS.md) — with its name, type, and description:

| Type | Invocation | Description format |
| --- | --- | --- |
| passive | Agent auto-triggers by judging the description | `x-<name>`: plain functional description |
| active | User explicitly invokes by name or keyword; never auto-triggered | `x-<name>`: `Explicit-only:` prefix template + functional description |

All skill names start with the `x-` prefix.

## Directory Layout

```
xskills/
├── .zcode-plugin/
│   └── plugin.json       # Plugin manifest (name/description/version/author)
├── marketplace.json      # Marketplace manifest (version must match plugin.json)
├── SKILLS.md             # Skill registry: one file classifying all skills (passive/active)
├── skills/
│   ├── x-code-clean/     # active — comment cleanup + style checkers (explicit invocation only)
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── extract_comments.py
│   │       ├── checks.py
│   │       └── checks/   # checker registry (add a checker = 1 file + 1 registration line)
│   └── x-skills/         # active — workbench: list this plugin's skills
│       └── SKILL.md
├── DEVELOPMENT.md        # Contributor guide: classification / develop / verify / release
├── AGENTS.md             # Project working guide (AGENTSPACE entry notes)
├── CHANGELOG.md          # Release history per version
└── README.md
```

## Available Skills

| name | type | description |
| --- | --- | --- |
| x-code-clean | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments"); never auto-triggered. Review and clean up code comments and code-style violations (e.g. imports not at module top level) in files or a git commit range, any language; report-then-confirm workflow |
| x-skills | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-skills", "list my skills"); never auto-triggered. Workbench: list the skills belonging to xskills with a short description of each |

## Development Process

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full process: skill classification
(passive/active), how to develop skills (structure, frontmatter, language policy),
how to verify (`verify-release.sh` gate + `self-test.sh` regression suite), and how
to release (version discipline, changelog, commit style).

## How to Register as a ZCode Plugin

1. Push this repository to its remote (`origin`).
2. Add the repository as a plugin marketplace in ZCode (the manifest lives at
   `marketplace.json`; the plugin itself is served from `./`).
3. Install the `xskills` plugin from that marketplace. Once registered, all skills
   under `skills/` can be invoked in sessions:
   - passive skills auto-trigger via their descriptions;
   - active skills (e.g. `x-skills`) run only when explicitly invoked.

## Release History

| Version | Date | What changed |
| --- | --- | --- |
| v0.1.1 | 2026-08-13 | x-code-clean reclassified from passive to active (explicit invocation only, Explicit-only: description prefix); registry/README/t04 updated accordingly |
| v0.1.0 | 2026-08-13 | Initial release: skill classification system (passive/active, single registry file SKILLS.md), x-code-clean skill (comment cleanup + no-inner-import checker), x-skills workbench skill, plugin + marketplace manifests, verify-release gate + self-test suite |

## AGENTSPACE

Experiment and iteration state for this project is managed by `AGENTSPACE/` (NOT under git management; ignored by `.gitignore`). When the work involves experiments, code changes, project iterations, or status queries/changes, read `AGENTSPACE/AGENTS.md` first and follow its rules.
