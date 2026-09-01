# xskills Skill Registry

Single source of truth for classifying every skill in this plugin into one of
two strict categories:

| Type | Invocation | description format |
| --- | --- | --- |
| passive | Agent auto-triggers by judging the description | `x-<name>`: plain functional description |
| active | User explicitly invokes by name or keyword; never auto-triggered | `x-<name>`: description starts with the explicit-only prefix template |

Active-only prefix template (must prefix the description of every active skill):

```
Explicit-only: invoked ONLY when the user explicitly requests this skill by name
or its keywords; never auto-triggered.
```

## Skills

| name | type | description | usage |
| --- | --- | --- | --- |
| x-better-commit | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-better-commit", "better commit", "improve the commit message", "write a commit message"); never auto-triggered. Draft or rewrite a git commit message — title and body — from the staged diff or an existing commit per the title rules (type prefix, imperative mood, specific, <=50/72 chars, one coherent purpose) and the body rules (optional by default; when written: why over how, wrapped at 72, footer refs), then commit or amend | `x-better-commit`; `x-better-commit --amend`; `x-better-commit <rev>` |
| x-code-clean | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "trim comments", "dead code", "unused code"); never auto-triggered. Three check categories over a natural-language scope (files/directories or a git commit range; default uncommitted changes): comment cleanup (feedback-driven why-not explanations, redundant prose, unnecessary references to other files/projects/repos), style checks (imports not at module top level), dead-code detection (module-level defs never referenced in the repo, Python only); report-then-confirm workflow | `x-code-clean [scope in natural language]`; no flags — scope defaults to uncommitted changes |
| x-code-review | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-review", "review the code", "review this diff"); never auto-triggered. Multi-axis code review of uncommitted changes using the code-review subagent cluster (major + sub-N + merger + executor), then apply approved fixes | `x-code-review`; `x-code-review --range <start>..HEAD` |
| x-grilling | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-grilling", "grill me", "stress-test my thinking"); never auto-triggered. Interview the user relentlessly about a plan, decision, or idea until a shared understanding is reached | `x-grilling <topic>` |
| x-skills | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-skills", "list my skills"); never auto-triggered. Workbench: list the skills belonging to xskills with a short description of each | `x-skills`; `x-skills --usage <name>` |
| x-subagent-orchestration | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-subagent-orchestration", "use subagents", "delegate"); never auto-triggered. Default-to-delegate rules for the Agent tool; uses only built-in Explore / general-purpose subagents | `x-subagent-orchestration` |

## Adding a Skill

1. Create `skills/<x-name>/SKILL.md` with frontmatter `name` + `description`.
2. Every skill name starts with the `x-` prefix.
3. Classify it here (one row): passive if the agent may auto-trigger it via the
   description; active if it must only run on explicit user invocation — active
   descriptions carry the explicit-only prefix template above.
4. Register the row in this file before release; `verify-release.sh` checks that
   the registry and the `skills/` directory stay in sync.
