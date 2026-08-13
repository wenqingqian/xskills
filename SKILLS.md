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

| name | type | description |
| --- | --- | --- |
| x-code-clean | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "trim comments"); never auto-triggered. Review and clean up code comments and code-style violations (e.g. imports not at module top level) in files or a git commit range, any language; report-then-confirm workflow |
| x-skills | active | Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-skills", "list my skills"); never auto-triggered. Workbench: list the skills belonging to xskills with a short description of each |

## Adding a Skill

1. Create `skills/<x-name>/SKILL.md` with frontmatter `name` + `description`.
2. Every skill name starts with the `x-` prefix.
3. Classify it here (one row): passive if the agent may auto-trigger it via the
   description; active if it must only run on explicit user invocation — active
   descriptions carry the explicit-only prefix template above.
4. Register the row in this file before release; `verify-release.sh` checks that
   the registry and the `skills/` directory stay in sync.
