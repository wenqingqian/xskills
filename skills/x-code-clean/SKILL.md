---
name: x-code-clean
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "trim comments", "dead code", "unused code"); never auto-triggered. When invoked, run three check categories over a natural-language scope ("this commit", "the whole repo", default: uncommitted changes): comment cleanup — fanned out to parallel read-only subagents (5–10 text files each) reviewing comments, docstrings, descriptive help-style strings, and doc prose (report-only) against the four tiers, deleting feedback-driven why-not residue, date stamps, and skill/session citations; style checks (imports not at module top level, with exemption flags for legitimate inner imports); and dead-code detection (module-level definitions never referenced in the repo, Python only). Report first; edit only after the user confirms.
---

# Code Cleanup

This is an **active** skill: it runs only on explicit invocation (by name or
keywords such as "clean up comments" / "trim comments" / "dead code"); never
auto-trigger it from conversation content alone. Three check categories run
over the scope, all of them, every time:

1. **Comments** — four-tier classification (below) over every non-binary
   text file: comments, docstrings, descriptive help-style strings, doc
   prose. Parallel read-only subagents (fan-out below); no extraction script.
2. **Style** — registered style checkers (Python only for now).
3. **Code** — dead-code candidates (Python only for now).

Output a per-item report first; only edit after the user confirms. **Read
`GUIDE.md` in this skill directory before classifying** — worked examples,
the assert-vs-example rule, the subagent spawn template, pitfalls.

## The core rule (the user's criterion)
It must NOT say **why the code is not written some other way** ("why not
alternative X") — residue of a past Q&A, noise for every future reader. A
"why not" with a concrete in-code consequence is a design note → keep; a
bare alternative-comparison is feedback-driven → delete.

## Citation and metadata residue (② by default)
Test-instance citations (models, hyper-params, parallel configs), date
stamps ("written 2026-09-05"), and skill/session references ("per
x-grilling") are metadata residue — git blame and the commit message are
the permanent database for when and why; comment copies rot → delete by
default. Exceptions: license/copyright headers (dates are legal metadata,
④ always); a date carrying a live obligation ("compat layer can go after
2026-06", ④); a skill-cited comment with a real in-code reason — strip
the attribution, keep the reason, re-judge it (① if a bare why-not).
Config restrictions → an `assert` plus one pointer; teaching examples stay, written relatively ("TP member 0/1"). Details: GUIDE.md.

## References to other files / projects / repos
Judge every comment that points at another file from **this project's
standpoint**: keep it only if it creates a constraint or provenance this
project needs. **Keep (④)**: vendored/ported-code provenance ("copied from
upstream, sync on update"); external spec/format contracts ("layout follows
RFC 1234 §3"); verified in-repo sync pointers. **Delete (②)**: informational
asides into other projects/repos; dangling in-repo references (target gone —
always). Verify in-repo targets against the working tree. Edge cases: GUIDE.md.

## Four-tier classification
1. **① Delete** — feedback-driven "why not alternative X" explanations.
2. **② Delete** — citation/metadata residue: restates the code or a
   sibling docstring verbatim, test-instance citations, date stamps,
   skill/session references, unnecessary cross-file/cross-repo references.
3. **③ Trim** — over-long prose: compress to the core what/why, drop
   defensive hedges; multi-paragraph docstrings collapse to 1–2 sentences.
4. **④ Keep / fine-tune** — non-obvious what/why, interface contracts,
   binding references, section dividers, one-line purpose docstrings,
   license/copyright headers (always keep). Fix only factual errors or
   non-local assumptions.

Docstrings follow the same tiers, but keep a one-line purpose statement on
public functions/classes so the API stays readable.

Descriptive strings follow the same tiers: a plain string literal bound
to a whitelisted doc name — `help`/`description`/`doc`/`__doc__`/
`epilog`/`usage`/`title`/`comment`/`note(s)`/`summary`/`about` (argparse
`help=` is the canonical case). Functional strings (raise/print/log,
prompts, UI/i18n) are always ④ keep; edits to one are annotated
"changes runtime output". Doc prose is reviewed but **report-only** —
asked item by item even in "just fix it" mode. Details: GUIDE.md.

## Scope (no invocation parameters)
The skill takes **no flags**; the user states the scope in natural language:
- "this commit / since commit X" → range mode: only the lines the range
  added are reviewed, created files whole (the tree must match the range
  end — say so in the report if it has moved past).
- "the whole repo" → whole-repo mode: every non-binary text file, whole.
- nothing said → the uncommitted changes; **state that scope at the top
  of the report**.

## Comment review fan-out (subagents)
- Line sets: `python3 scripts/changed_lines.py` (working tree) or with
  `--range <start>..<end>` — added lines per modified file, created
  files listed whole. Whole-repo mode skips this step.
- Partition the scope files 5–10 per subagent by size (large code files
  fewer, small configs/docs more; default 8); spawn one parallel
  read-only `Explore` subagent per partition, no cap on count. Binary
  extensions (constant in `changed_lines.py`) are already excluded.
- Each subagent gets the self-contained template from GUIDE.md: files +
  mode + line sets, rules digest, GUIDE.md path, findings format.
  Subagents only find.
- The main agent verifies every finding (grep the cited text at
  file:line; fix or drop mismatches), applies the session-context pass,
  then reports; edits after confirmation are made by the main agent.

## Checkers (all registered checkers always run)
`checks.py` has no checker selection — everything in `scripts/checks/` runs
every time:

- `no-inner-import` (style): imports not at module top level. Legitimate
  patterns (`typing-only`, `optional-dep`, `lazy-activation`, `test-local`,
  `circular-guard`, `heavy-deferral`) are downgraded to exemption
  candidates with a flag — reported, never hidden, no hoist proposal.
- `dead-code` (code): module-level definitions never referenced in any
  repo `.py`. Exemption signals (`exported`, `decorated`, `entry-point`,
  `test-only`, `dynamic-ref`) are reported as flags, never hidden.
  Name-based matching can miss — verify candidates with your own grep.

Checkers only *find*; fixes go through the report-then-confirm flow. Report
all findings — the user decides; never drop one with a plausible excuse.

## Workflow
### 1. Scope the files / run checkers

```
python3 scripts/changed_lines.py [--range <start>..HEAD]
python3 scripts/checks.py --range <start>..HEAD | --files a.py ...
```

Then fan out the comment review (section above) and collect the findings.

### 2. Verify and re-check
Grep-verify every subagent finding against the real file before it enters
the report (the report must cite real file:line and real text). Then
re-check findings against session context: what was just built, which
definitions await their caller. A just-added function awaiting its caller
is not dead code — annotate, don't propose deletion.

### 3. Report (default, before any edit)
- State the scope first (range / whole repo / "uncommitted changes").
- **Changes** (tiers ①–③ and checker findings): `file:line` + original text
  (abridged) + tier/checker + replacement text (verbatim for ③ trims);
  dead-code and no-inner-import findings with flags are listed as exempted
  (flag + reason, no hoist proposal); descriptive-string edits carry the
  runtime-output annotation; doc-prose findings are marked report-only.
- **Kept** (④): one compact line per file — line numbers + 3–6 word reason
  ("non-obvious why", "interface contract", "vendored provenance").

End with a summary count (delete N / trim N / keep N / violations M /
exempted K). Do not edit until the user confirms. If the user explicitly
says "just fix it", skip the report for code comments and checker
findings — never for doc-prose findings (asked item by item).

### 4. Apply and verify
- Edit each accepted item (`Edit` tool, exact matches from the working tree).
- Syntax gate: Python `py_compile`; Shell `bash -n`; YAML `yaml.safe_load`;
  others: skip if no toolchain, say so.
- `git diff` — self-check: only comments/strings/doc text/findings changed,
  no behavior drift; descriptive-string edits are the expected exception.
- Commit only when asked, e.g. `Trim feedback-driven and redundant comments in <area>`.
