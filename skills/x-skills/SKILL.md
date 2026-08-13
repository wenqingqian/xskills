---
name: x-skills
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-skills", "list my skills", "show skills", "what skills do I have"); never auto-triggered. When invoked, list the skills belonging to the xskills plugin with a short description of each.
---

# x-skills Workbench

List the skills belonging to this plugin (xskills) with a short description of
each, so the user can see what is available and how each one is invoked.

## When to invoke

This is an **active** skill: it runs only when the user explicitly asks for it
(by name or by keywords such as "list skills" / "show my skills"). Never
auto-trigger it based on the conversation content alone.

## Steps

1. Read `SKILLS.md` at the plugin root (the registry — single source of truth
   for the skill list and their classification).
2. Present the skills in a table:

   | name | type | description |
   | --- | --- | --- |

   For each row from the registry, explain briefly:
   - `passive`: the agent auto-triggers it when the description matches the
     user's request — no need to name the skill.
   - `active`: the user must invoke it explicitly (by name or keyword); it is
     never auto-triggered.

3. If the registry mentions a skill whose `skills/` directory is missing (or
   vice versa), report the drift — do not silently present a stale list.

## Notes

- Answer in the user's language.
- The registry file lives at the plugin root (`SKILLS.md`), not inside the
  skill directory; read it from the plugin's installed location.
