# xskills

## Project Overview

Manages personal ZCode skills and packages them into a ZCode plugin for unified management. For now, the only requirement is that this repository can be registered as a ZCode plugin and its skills can be invoked. Hooks / MCP / marketplace publishing are out of scope for now.

## Runtime Environment

No special environment required: this is a pure skill/plugin repository (markdown + JSON manifest), no container, conda, or GPU dependencies. See AGENTSPACE/tests.md for details.

## Key Repositories

- `xskills` (this repository, /Users/wenqingqian/Documents/mytest/xskills): the only code repository; the carrier of personal ZCode skills and the plugin manifest.
  - Planned layout: `skills/<skill-name>/SKILL.md` (skill body) + `.zcode-plugin/plugin.json` (plugin manifest)
  - Reference template: `~/.zcode/cli/plugins/cache/zcode-plugins-official/example-plugin/0.2.0/`
  - Currently an empty repository, no code yet

## AGENTSPACE

Experiment and iteration state for this project is managed by `AGENTSPACE/` (NOT under git management; ignored by the host .gitignore): plan (task plans), iterations (code change iterations), utils (reusable tools), tests (environment & tests), notes (knowledge).

### When to read AGENTSPACE/AGENTS.md

When the conversation involves this project's experiments, code changes, project iterations, or status queries/changes → read `AGENTSPACE/AGENTS.md` first and follow its rules (it guides you to the entry files such as tests.md and iterations.md).

### When not to read it

For questions unrelated to this project, casual chat, or pure queries without state changes, when the user has not explicitly asked to use AGENTSPACE.

### Hard rules

- AGENTSPACE initialization happens only through the explicit `/agentspace-init` command, never automatically
- AGENTSPACE index/entry state (plan.md, iterations.md, the two index.md files) can only be modified by scripts under `AGENTSPACE/scripts/`
- Do not read plugin development data: `skills/agentspace-update/versions/`, `DEVELOPMENT.md`, `marketplace.json`, etc. are unrelated to this project and out of AGENTSPACE's scope
