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
├── kimi.plugin.json      # Kimi plugin manifest (name/version/skills/interface)
├── SKILLS.md             # Skill registry: one file classifying all skills (passive/active)
├── skills/
│   ├── x-better-commit/  # active — commit message title + body rules (draft / rewrite)
│   │   └── SKILL.md
│   ├── x-code-clean/     # active — comment cleanup + style + dead-code checkers (explicit invocation only)
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── extract_comments.py
│   │       ├── checks.py
│   │       └── checks/   # checker registry (add a checker = 1 file + 1 registration line)
│   ├── x-code-review/    # active — multi-axis review via subagent cluster (SKILL.md + GUIDE.md)
│   ├── x-grilling/       # active — relentless plan/decision stress-test interview
│   ├── x-skills/         # active — workbench: list this plugin's skills
│   │   └── SKILL.md
│   └── x-subagent-orchestration/  # active — default-to-delegate subagent rules
│       └── SKILL.md
├── DEVELOPMENT.md        # Contributor guide: classification / develop / verify / release
├── new-version.sh         # Dev tool: scaffold a version (bump markers + CHANGELOG skeleton)
├── verify-release.sh      # Dev tool: release gate [0]-[7]
├── self-test.sh           # Dev tool: regression suite runner
├── tests/                 # Regression scenarios (t01-t04, sandbox-isolated)
├── AGENTS.md             # Project working guide (AGENTSPACE entry notes)
├── CHANGELOG.md          # Release history per version
└── README.md
```

## Available Skills

| name | type | description | usage |
| --- | --- | --- | --- |
| x-better-commit | active | Explicit-only: draft or rewrite a git commit message (title + body) from the staged diff or an existing commit — type-prefixed imperative title, optional why-over-how body — then commit or amend | `x-better-commit`; `x-better-commit --amend`; `x-better-commit <rev>` |
| x-code-clean | active | Explicit-only: three check categories over a natural-language scope (default uncommitted changes): comment cleanup (feedback-driven why-not, redundant prose, unnecessary cross-file/repo references), style checks (imports not at module top level), dead-code detection (never-referenced module-level defs, Python only); report-then-confirm | `x-code-clean [scope in natural language]` |
| x-code-review | active | Explicit-only: multi-axis code review of uncommitted changes using the code-review subagent cluster (major + sub-N + merger + executor), then apply approved fixes | `x-code-review`; `x-code-review --range <start>..HEAD` |
| x-grilling | active | Explicit-only: interview the user relentlessly about a plan, decision, or idea until a shared understanding is reached | `x-grilling <topic>` |
| x-skills | active | Explicit-only: workbench listing this plugin's skills with descriptions and usage | `x-skills`; `x-skills --usage <name>` |
| x-subagent-orchestration | active | Explicit-only: default-to-delegate rules for the Agent tool (bulk reading/search/tests to subagents); built-in Explore / general-purpose only | `x-subagent-orchestration` |

## Development Process

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full process: skill classification
(passive/active), how to develop skills (structure, frontmatter, language policy),
how to verify (`verify-release.sh` gate + `self-test.sh` regression suite), and how
to release (version discipline, changelog, commit style).

## How to Register as a Plugin

### ZCode

1. Push this repository to its remote (`origin`).
2. Add the repository as a plugin marketplace in ZCode (the manifest lives at
   `marketplace.json`; the plugin itself is served from `./`).
3. Install the `xskills` plugin from that marketplace. Once registered, all skills
   under `skills/` can be invoked in sessions:
   - passive skills auto-trigger via their descriptions;
   - active skills (e.g. `x-skills`) run only when explicitly invoked.

### Kimi

Kimi publishes no marketplace listing; the plugin installs directly from the
manifest at the repo root (`kimi.plugin.json`). Install it locally via Kimi's
`/plugins` with a zip of this repository or its GitHub URL, then the skills
under `skills/` become invocable the same way (passive auto-trigger / active
explicit-only).

## Release History

| Version | Date | What changed |
| --- | --- | --- |
| v0.5.0 | 2026-09-01 | x-code-clean rework: natural-language scope (invocation flags removed, default uncommitted changes), new comment rule for cross-file/cross-repo references (keep constraint/provenance, delete asides and dangling pointers), new Python-only dead-code checker with exemption flags, session-context review step; SKILL size budget raised to 150; t03 rewritten, t06 added |
| v0.4.0 | 2026-08-27 | New active skill x-better-commit: commit title rules + optional body rules with three modes (commit staged work, --amend last unpushed commit, improve any commit's message in place); registry and README updated |
| v0.3.0 | 2026-08-19 | Kimi plugin support: new kimi.plugin.json manifest (name/version/skills/interface); new-version.sh syncs all three manifests; verify gate gains the Kimi contract check; t05/t04 updated |
| v0.2.0 | 2026-08-13 | Three new active skills localized from local agent skills (x-code-review via subagent cluster, x-grilling, x-subagent-orchestration); x-skills workbench lists name/type/description/usage per skill with `--usage <name>` support; registry gained a usage column |
| v0.1.1 | 2026-08-13 | x-code-clean reclassified from passive to active (explicit invocation only, Explicit-only: description prefix); registry/README/t04 updated accordingly |
| v0.1.0 | 2026-08-13 | Initial release: skill classification system (passive/active, single registry file SKILLS.md), x-code-clean skill (comment cleanup + no-inner-import checker), x-skills workbench skill, plugin + marketplace manifests, verify-release gate + self-test suite |

## AGENTSPACE

Experiment and iteration state for this project is managed by `AGENTSPACE/` (NOT under git management; ignored by `.gitignore`). When the work involves experiments, code changes, project iterations, or status queries/changes, read `AGENTSPACE/AGENTS.md` first and follow its rules.
