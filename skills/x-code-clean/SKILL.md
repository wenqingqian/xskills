---
name: x-code-clean
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "trim comments", "dead code", "unused code"); never auto-triggered. When invoked, run three check categories over a scope given in natural language (files, directories, or a git commit range; default: uncommitted changes): comment cleanup (delete feedback-driven why-not explanations, redundant prose, and unnecessary references to other files/projects/repos; keep non-obvious what/why; also covers Python descriptive strings — docstrings and whitelisted help/description-style literals, e.g. argparse help=), style checks (imports not at module top level, with exemption flags for legitimate inner imports), and dead-code detection (module-level definitions never referenced in the repo, Python only). Report first; edit only after the user confirms.
---

# Code Cleanup

This is an **active** skill: it runs only on explicit invocation (by name or
keywords such as "clean up comments" / "trim comments" / "dead code"); never
auto-trigger it from conversation content alone. Three check categories run
over the scope, all of them, every time:

1. **Comments** — four-tier classification (below); covers comments,
   docstrings, and descriptive strings (help/description-style literals);
   any language: Python is parsed exactly (tokenize/ast), other languages
   use per-extension heuristics — treat those as candidate lists, verify
   against real files (including their doc-bearing string constructs).
2. **Style** — registered style checkers (Python only for now).
3. **Code** — dead-code candidates (Python only for now).

Output a per-item report first; only edit after the user confirms. **Read
`GUIDE.md` in this skill directory before classifying** — worked examples,
the assert-vs-example rule, edge cases, pitfalls.

## The core rule (the user's criterion)
It must NOT say **why the code is not written some other way** ("why not
alternative X") — residue of a past Q&A, noise for every future reader. A
"why not" with a concrete in-code consequence is a design note → keep; a
bare alternative-comparison is feedback-driven → delete.

## Test-instance information (models, hyper-params, parallel configs)
Comments citing concrete test instances carry no code semantics and go stale
→ delete by default. A real config restriction belongs in an `assert` (fails
loudly, cannot rot) plus at most one short pointer comment. Teaching
examples with placeholder numbers stay, written relatively ("TP member
0/1"). Details: GUIDE.md.

## References to other files / projects / repos
Judge every comment that points at another file from **this project's
standpoint**: keep it only if it creates a constraint or provenance this
project needs. **Keep (④)**: vendored/ported-code provenance ("copied from
upstream `x/y.py`, sync on update"); external spec/format contracts ("layout
follows RFC 1234 §3"); in-repo sync pointers whose target you verified
exists. **Delete (②)**: informational asides into other projects/repos the
reader cannot resolve and that constrain nothing here; in-repo references
whose target no longer exists — dangling, always delete. Verify in-repo
targets against the working tree; external refs cannot be verified — judge
necessity only. Edge cases: GUIDE.md.

## Four-tier classification
1. **① Delete** — feedback-driven "why not alternative X" explanations.
2. **② Delete** — restates the code or a sibling docstring verbatim,
   test-instance citations, unnecessary cross-file/cross-repo references.
3. **③ Trim** — over-long prose: compress to the core what/why, drop
   defensive hedges; multi-paragraph docstrings collapse to 1–2 sentences.
4. **④ Keep / fine-tune** — non-obvious what/why, interface contracts,
   binding references, section dividers, one-line purpose docstrings,
   license/copyright headers (always keep). Fix only factual errors or
   non-local assumptions.

Docstrings follow the same tiers, but keep a one-line purpose statement on
public functions/classes so the API stays readable.

Descriptive strings follow the same tiers too: Python-wise, any plain
string literal bound to a whitelisted documentation name — `help`,
`description`, `doc`, `__doc__`, `epilog`, `usage`, `title`, `comment`,
`note`/`notes`, `summary`, `about` (extractor kind `desc_string`). Two
guardrails, because strings are runtime content: functional strings
(raise/print/log messages, prompts, UI/i18n values) are always ④ keep,
even when they explain why; and every proposed desc_string edit is
annotated "changes runtime output (CLI help / docs)". Non-Python
languages have no string extraction — check their doc-bearing constructs
(cobra `Short:`/`Long:`, yargs `.describe()`, commander `.description()`)
during the read pass. Details and worked examples: GUIDE.md.

## Scope (no invocation parameters)
The skill takes **no flags**; the user states the scope in natural language:
- "these files / this directory" → `--files <f...>`
- "since commit X" → `--range <start>..HEAD` (git mode)
- nothing said → the uncommitted changes (`git status` / `git diff`);
  **state that scope at the top of the report**.

**Scope correction (critical)**: `git diff <start>..HEAD` hides lines
created by the start commit. For a file created inside the range, ask
whether to review the whole file (recommended) or only diff lines.

## Checkers (all registered checkers always run)
`checks.py` has no checker selection — everything in `scripts/checks/` runs
every time:

- `no-inner-import` (style): imports not at module top level. Legitimate
  patterns are downgraded to exemption candidates with a structural flag —
  `typing-only`, `optional-dep` (try/except ImportError with fallback),
  `lazy-activation` (actionable-error raise or lazy-contract docstring),
  `test-local` (test files; alias patch-targeted in-file),
  `circular-guard` (hoisting would close an in-repo import cycle),
  `heavy-deferral` (heavy third-party inside a CLI entry). Flagged items
  stay in the report — never hidden. Details: GUIDE.md.
- `dead-code` (code): module-level function/class/constant defined in a
  scope file but never referenced in any repo `.py`; candidates from scope
  files, references searched repo-wide. Exemption signals (`exported`,
  `decorated`, `entry-point`, `test-only`, `dynamic-ref`) are reported as
  flags, never hidden. Name-based matching can miss — verify candidates with
  your own grep. Details: GUIDE.md.

Checkers only *find*; fixes go through the report-then-confirm flow. Report
all findings — the user decides; never drop one with a plausible excuse.

## Workflow
### 1. Extract the candidate list / run checkers

```
python3 scripts/extract_comments.py --range <start>..HEAD | --files a.py ...
python3 scripts/checks.py --range <start>..HEAD | --files a.py ...
```

Extraction is best-effort — read the actual files anyway; the report must
cite real file:line and real text.

### 2. Session-context review
Usually invoked right after a task finished in this session. Before
reporting, re-check every finding against session context: what was just
built, which definitions await their caller in the next step, which
references came from the current task. A just-added function awaiting its
caller is not dead code — annotate, don't propose deletion.

### 3. Report (default, before any edit)
- State the scope first (files / range / "uncommitted changes").
- **Changes** (tiers ①–③ and checker findings): `file:line` + original text
  (abridged) + tier/checker + replacement text (verbatim for ③ trims);
  dead-code findings carry their exemption flags; no-inner-import findings
  with flags are listed as exempted (flag + reason, no hoist proposal);
  desc_string findings carry the runtime-output annotation.
- **Kept** (④): one compact line per file — line numbers + 3–6 word reason
  ("non-obvious why", "interface contract", "vendored provenance").

End with a summary count (delete N / trim N / keep N / violations M /
exempted K). Do not
edit until the user confirms. If the user explicitly says "just fix it",
skip the report step.

### 4. Apply and verify
- Edit each accepted item (`Edit` tool, exact matches from the working tree).
- Syntax gate: Python `py_compile`; Shell `bash -n`; YAML `yaml.safe_load`;
  others: skip if no toolchain, say so.
- `git diff` — self-check: only comments/findings changed, no behavior drift;
  desc_string text edits are the expected exception (they change CLI/doc
  output by design).
- Commit only when asked, e.g. `Trim feedback-driven and redundant comments in <area>`.
