---
name: x-code-clean
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "trim comments", "dead code", "unused code", "secrets"); never auto-triggered. When invoked, run three check categories over a natural-language scope ("this commit", "the whole repo", default: uncommitted changes): comment/text cleanup — a hard extraction pass (extract_comments.py enumerates every comment, docstring, and descriptive help-style string) plus a soft subagent fan-out (5–10 text files each, at most 5 concurrent) classifying them against the four tiers, deleting feedback-driven why-not residue, restatements and duplicates, experiment souvenirs, process narration, and secrets (whole-line delete); style checks (imports not at module top level, with exemption flags for legitimate inner imports); dead-code detection (module-level definitions never referenced in the repo, Python only). Report first; edit only after the user confirms.
---

# Code Cleanup

This is an **active** skill: it runs only on explicit invocation (by name or
keywords such as "clean up comments" / "trim comments" / "dead code" /
"secrets"); never auto-trigger it from conversation content alone. Three
check categories run over the scope, all of them, every time:

1. **Comments & text** — four-tier classification (below) over every
   non-binary text file: comments, docstrings, descriptive help-style
   strings, doc prose. Dual review: hard extraction enumerates every
   candidate; a soft subagent fan-out classifies and sweeps (below).
2. **Style** — registered style checkers (Python only for now).
3. **Code** — dead-code candidates (Python only for now).

Output a per-item report first; only edit after the user confirms. **Read
`GUIDE.md` before classifying** — worked examples, the example keep rule,
the secrets rule, the spawn template, pitfalls.

## The core rule (the user's criterion)
It must NOT say **why the code is not written some other way** — past-Q&A
residue, noise for every future reader. A why-not with a concrete in-code
consequence is a design note → keep; a bare alternative-comparison deletes.

## Secrets (hard checker + soft pass)
Secret-shaped values — IPs, tokens, credentials — get a dual pass: the
`no-secrets` checker (high-precision patterns; loopback/doc-range hits
come back as flags, never hidden) plus the subagents' sweep for
unstructured ones (internal hostnames, topology). A comment/doc-line hit
→ **delete the whole line**; code/functional-string hits are report-only.
Details: GUIDE.md.

## Citation and metadata residue (② by default)
Test-instance citations (models, hyper-params, parallel configs), date
stamps, skill/session references — git blame and the commit message are
the permanent database; comment copies rot → delete by default.
Exceptions: GUIDE.md.

## Examples: the two-condition keep rule
An example survives only as: ① a pitfall/warning whose hazard is intrinsic
to this code (a kernel that really does materialize a huge intermediate)
and cannot be asserted — the note is a property of the code, not a memory;
② a macro example — a mapping/algorithm/structure above one experiment's
scope, numbers as relative placeholders. Everything else deletes: results,
measured numbers, configs cited as facts (②); assertable limits → `assert`.
Worked cases: GUIDE.md.

## References to other files / projects / repos
Judge from **this project's standpoint**: keep only a reference creating
a constraint or provenance this project needs (④ vendored provenance, spec
contracts, verified sync pointers); asides and dangling refs delete (②).

## Four-tier classification
1. **① Delete** — feedback-driven "why not alternative X" explanations.
2. **② Delete** — restatements and residue: code narration, signature
   mirrors, level duplicates (one canonical location), assert/raise
   preambles, experiment souvenirs, process/history narration, TOC
   docstrings, maintenance imperatives, secrets (whole-line delete),
   dead or background cross-refs.
3. **③ Trim** — public docstrings to a purpose line + non-obvious
   semantics; design notes to constraint + consequence; examples to one
   macro mapping.
4. **④ Keep / fine-tune** — non-obvious what/why, interface contracts,
   binding references, section dividers, one-line purpose docstrings,
   license headers (always keep). Fix only factual errors.

Docstrings follow the same tiers, but keep a one-line purpose statement on
public functions/classes. Descriptive strings — plain literals bound to a
whitelisted doc name (whitelist in GUIDE.md) — follow the same tiers.
Functional strings (raise/print/log, prompts, UI/i18n) are always ④ keep;
edits to one are annotated "changes runtime output". Doc prose is
**report-only** — asked item by item even in "just fix it" mode.

## Scope (no invocation parameters)
The skill takes **no flags**; the user states the scope in natural language:
"this commit / since commit X" → range mode (only added lines reviewed,
created files whole; say so if the tree moved past the range end); "the
whole repo" → every non-binary text file, whole; nothing said → the
uncommitted changes — **state that scope at the top of the report**.

## Comment review fan-out (dual: extraction + subagents)
- Line sets: `python3 scripts/changed_lines.py` (working tree, or
  `--range <start>..<end>`) — added lines per modified file, created files
  whole; whole-repo mode skips this step.
- Hard extraction: `python3 scripts/extract_comments.py --files <scope
  files> --lines-json -` (pipe the changed_lines JSON; whole-repo mode
  omits the flag) — every comment/docstring/desc-string enumerated.
- Partition the scope files 5–10 per `Explore` subagent by size (default
  8; partition count may exceed the cap). Spawn **at most 5 subagents at
  once**, in parallel; queue the rest and spawn the next partition each
  time a running one finishes. Each gets the GUIDE.md spawn template
  (files + mode + extracted item list + rules digest), classifies **every**
  listed item — the coverage floor, not the ceiling — and sweeps for what
  extraction cannot see (doc prose, unstructured secrets).
- The main agent grep-verifies every finding, applies the session-context
  pass, reports; edits after confirmation are the main agent's.

## Checkers (all registered checkers always run)
`checks.py` has no checker selection — everything in `scripts/checks/` runs
every time; checkers only *find* — report all findings, the user decides,
never drop one with a plausible excuse:

- `no-inner-import` (style, Python): imports not at module top level;
  legitimate patterns (six structural signals, GUIDE.md) downgrade to
  exemption candidates with a flag — reported, never hidden, no hoist.
- `dead-code` (code, Python): module-level definitions never referenced in
  any repo `.py`; exemption signals (`exported`, `decorated`, `entry-point`,
  `test-only`, `dynamic-ref`) reported as flags; verify with your own grep.
- `no-secrets` (text, every non-binary file): secret-shaped values;
  exemption flags (`loopback`, `doc-range`) stay in the report; version-
  like noise is dropped at verification, accounted for in the summary.

## Workflow
### 1. Scope the files / run checkers

```
python3 scripts/changed_lines.py [--range <start>..HEAD]
python3 scripts/checks.py --range <start>..HEAD | --files a.py ...
python3 scripts/extract_comments.py --files <scope files> [--lines-json -]
```

### 2. Verify and re-check
Grep-verify every finding against the real file (cite real file:line +
real text); then re-check against session context — a just-added function
awaiting its caller is not dead code; annotate, don't propose deletion.

### 3. Report (default, before any edit)
- State the scope first (range / whole repo / "uncommitted changes").
- **Changes** (tiers ①–③ and checker findings): `file:line` + original
  text (abridged) + tier/checker + replacement (verbatim for ③); flagged
  checker findings listed as exempted; secrets hits state "whole line
  deleted"; descriptive-string edits carry "changes runtime output";
  doc-prose findings are report-only.
- **Kept** (④): one compact line per file — line numbers + 3–6 word reason
  ("non-obvious why", "interface contract", "vendored provenance").

End with a summary count (delete N / trim N / keep N / violations M /
exempted K). Do not edit until the user confirms. "Just fix it" skips the
report for code comments and checker findings — never for doc prose.

### 4. Apply and verify
- Edit each accepted item (`Edit` tool, exact matches from the working tree).
- Syntax gate: `py_compile` / `bash -n` / `yaml.safe_load`; skip others if no toolchain, say so.
- `git diff` self-check: only comments/strings/doc text changed, no
  behavior drift (descriptive-string edits are the expected exception).
- Commit only when asked, e.g. `Trim feedback-driven and redundant comments in <area>`.
