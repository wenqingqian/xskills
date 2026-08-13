# xskills

A repository that manages personal [ZCode](https://z.ai) skills and packages them into a ZCode plugin for unified management. For now, the only requirement is that this repository can be registered as a ZCode plugin and its skills can be invoked.

## Directory Layout

```
xskills/
├── .zcode-plugin/
│   └── plugin.json       # Plugin manifest (name/description/version/author)
├── skills/
│   └── <skill-name>/
│       └── SKILL.md      # Skill body: YAML frontmatter (name/description) + instructions
├── AGENTS.md             # Project working guide (AGENTSPACE entry notes)
├── AGENTSPACE/           # Experiment & iteration workspace (gitignored, NOT under git)
└── README.md
```

Reference template: `~/.zcode/cli/plugins/cache/zcode-plugins-official/example-plugin/0.2.0/`

## How to Add a Skill

1. Create a directory under `skills/`, e.g. `skills/my-skill/`;
2. Create `SKILL.md` inside it, starting with YAML frontmatter:

   ```markdown
   ---
   name: my-skill
   description: When this skill should be triggered (be specific for accurate auto-triggering)
   ---

   # Instructions
   ```

3. Write a clear `description` covering the trigger scenarios — the more specific, the more accurate the auto-triggering.

## How to Register as a ZCode Plugin

Register this repository as a ZCode plugin (the manifest lives at `.zcode-plugin/plugin.json`). Once registered, all skills under `skills/` can be invoked in sessions.

## AGENTSPACE

Experiment and iteration state for this project is managed by `AGENTSPACE/` (NOT under git management; ignored by `.gitignore`). When the work involves experiments, code changes, project iterations, or status queries/changes, read `AGENTSPACE/AGENTS.md` first and follow its rules.
