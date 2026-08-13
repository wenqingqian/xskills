---
name: x-code-clean
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-clean", "clean up comments", "review comments", "trim comments"); never auto-triggered. When invoked, review and clean up code comments (both `#` and `"""docstrings"""`) and code-style violations (e.g. imports not at module top level) in files or a git commit range, in any language. Removes feedback-driven "why not written some other way" explanations, trims redundant/over-explanatory prose, keeps only non-obvious what/why, and checks import placement.
---

# Code Cleanup

This is an **active** skill: it runs only when the user explicitly invokes
it (by name or keywords such as "clean up comments" / "trim comments");
never auto-trigger it from conversation content alone. Review every comment
in scope and improve it: delete the ones that don't carry information, trim
the ones that over-explain, keep the ones that state non-obvious facts. Run
the requested style checkers on the same scope. Output a per-item report
first; only edit after the user confirms.

Works on any language: Python is parsed exactly (tokenize/ast); other
languages use per-extension comment-marker heuristics — treat those results
as candidate lists and verify against the real files.

**Read `GUIDE.md` in this skill directory before classifying** — it carries
worked examples, the assert-vs-example rule, and the pitfalls.

## The core rule (the user's criterion)

A comment may say **what this code does** and **why it is done this way**.
It must NOT say **why the code is not written some other way** ("why not
alternative X") — residue of a past Q&A, noise for every future reader. A
"why not" with a concrete in-code consequence is a design note → keep; a
bare alternative-comparison is feedback-driven → delete.

## Test-instance information (models, hyper-params, parallel configs)

Comments citing concrete test instances (model names, hyper-parameters,
parallel layouts, datasets) carry no code semantics and go stale — delete by
default. If the code genuinely only works under a specific config, express
the restriction with an `assert` (fails loudly, cannot rot) and keep at most
one short comment pointing at it. Teaching examples with placeholder numbers
are different: keep them, written relatively ("TP member 0/1"), never "under
config X".

## Four-tier classification

1. **① Delete** — feedback-driven "why not alternative X" explanations.
2. **② Delete** — redundant comments that restate the code or a sibling
   docstring verbatim, and test-instance citations.
3. **③ Trim** — over-long prose: compress to the core what/why, drop
   defensive hedges and repeated clauses. Multi-paragraph docstrings usually
   collapse to 1–2 sentences.
4. **④ Keep / fine-tune** — non-obvious what/why, interface contracts (what
   a hook must guarantee), section dividers, one-line purpose docstrings,
   license/copyright headers (always keep). Fix only factual errors or
   non-local assumptions.

Docstrings follow the same tiers, with one difference: keep a one-line
purpose statement on public functions/classes so the API stays readable.

## Style checkers (optional, on request)

Run the registered checkers when the user asks for style checks beyond
comments (e.g. "imports must be at the top", "--no-inner-import"):

```
python3 scripts/checks.py --list                          # available checkers
python3 scripts/checks.py --check no-inner-import --files a.py b.py
python3 scripts/checks.py --check no-inner-import --range <start>..HEAD
```

Findings are JSON: `{checker, file, line, column, text, message, parent...}`.
Checkers only *find*; fixes go through the same report-then-confirm flow.
Report all findings — the user decides (a `if TYPE_CHECKING:` import may be
acceptable); never drop a finding with a plausible excuse.

## Workflow

### 1. Define scope

- **Git-range mode**: `git log --oneline <start>..HEAD` (verify linear, no
  merges) + `git diff --stat <start>..HEAD` for the file list.
- **File mode**: the user-specified files/directories.
- **Scope correction (critical)**: `git diff <start>..HEAD` only shows lines
  modified *after* the start commit — comments created by the start commit
  are invisible. For a file created inside the range, ask the user whether
  to review its whole content (recommended) or only the diff lines.
### 2. Extract the candidate list / run checkers

```
python3 scripts/extract_comments.py --range <start>..HEAD        # git mode
python3 scripts/extract_comments.py --files a.py b.sh conf.yml   # file mode
python3 scripts/checks.py --check no-inner-import --files ...    # style check
```

Output: JSON items `{file, line, line_end, kind, text}` with
kind ∈ `full_comment` / `inline_comment` / `docstring` (docstring only for
Python). Best-effort — treat it as a candidate list and read the actual
files anyway; non-Python extraction is heuristic (verify against the working
tree). Then classify each item — the report must cite real file:line and
real text.

### 3. Report (default, before any edit)

- For **changes** (tiers ①–③ and checker findings): `file:line` + original
  text (abridged) + tier/checker + replacement text (verbatim for tier ③
  trims).
- For **kept** items (tier ④): one compact line per file listing line
  numbers and a 3–6 word reason ("non-obvious why", "interface contract",
  "section divider").

End with a summary count (delete N / trim N / keep N / findings M). Do not
edit until the user confirms. If the user explicitly says "just fix it",
skip the report step.

### 4. Apply and verify

- Edit each accepted item (`Edit` tool, exact matches from the working tree).
- Syntax gate per language: Python `python3 -m py_compile`; Shell `bash -n`;
  YAML `python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))"`;
  C/C++/others: skip if no toolchain, say so.
- `git diff` — self-check that only comments/findings changed (no behavior
  drift).
- Commit only when asked, e.g. `Trim feedback-driven and redundant comments in <area>`.
