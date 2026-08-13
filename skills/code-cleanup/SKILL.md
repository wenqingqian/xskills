---
name: code-cleanup
description: Review and clean up code comments (both `#` and `"""docstrings"""`) and code-style violations (e.g. imports not at module top level) in files or a git commit range, in any language. Removes feedback-driven "why not written some other way" explanations, trims redundant/over-explanatory prose, keeps only non-obvious what/why, and checks import placement. Trigger whenever the user asks to clean up/review/improve comments or docstrings, check import placement/standards (e.g. --no-inner-import, "imports must be at the top"), "review all comments", "trim comments", "clean up docstrings", or reviews comments/standards in commits starting from some point — even if they don't say "skill".
---

# Code Cleanup

Review every comment in scope and improve it: delete the ones that don't
carry information, trim the ones that over-explain, keep the ones that state
non-obvious facts. Run the requested style checkers on the same scope.
Output a per-item report first; only edit after the user confirms.

Works on any language: Python is parsed exactly (tokenize/ast); other
languages use per-extension comment-marker heuristics — treat those results
as candidate lists and verify against the real files.

## The core rule (the user's criterion)

A comment may say **what this code does** and **why it is done this way**.
It must NOT say **why the code is not written some other way** ("why not
alternative X"). The second kind is almost always residue of a past
Q&A — the agent answered a user question ("why don't you use X?") and
baked the excuse into a comment. It is noise for every future reader.

Recognizable feedback-driven phrasing (delete or trim these):

- Negations: "not a load-balancing choice", "no duplicated compute within the group"
- Defensive hedges: "kept as a safeguard", "normally unreachable"
- Alternative-comparison: "without using `retain_graph=True`", "deliberately does not implement `__getattr__`", "taking only X would silently drop Y", "which is why the advance cannot happen inside forward"
- Explaining why two functions do not share code: "each computes its side directly, kept mathematically equivalent"
- Session-directed rules: "do not duplicate these checks elsewhere", "each assert message states its own reason"
- Test-instance citations: "Example (language TP=2, vit_batch_factor=4)", "we tested with the 4b config", any model/hyper-param/parallel-layout value quoted as a fact (see the assert-vs-example rule below)

A comment that explains what the code needs to stay correct — e.g. "keep the
grid metadata: `_count_vision_tokens` needs it for the full macro batch" —
is legitimate why and stays.

Boundary: not every "why not X" is feedback-driven. A "why not" that carries
its own correctness/engineering reasoning with a concrete in-code consequence
("a wider group would elementwise all-reduce different vocab shards — silent
embedding-gradient corruption", "broadcasting first would sum dp identical
copies", "deliberately no try/except: a silent downgrade rots distributed
training") is a design note → keep (tier ④). A bare alternative-comparison
with no in-code consequence ("not a load-balancing choice") is
feedback-driven → delete (tier ①). Ask: does the sentence cite a specific
failure mode of this code, or just refuse an alternative? Specific failure
mode → keep.

## Test-instance information (models, hyper-params, parallel configs)

Comments citing concrete test instances — model names ("Qwen3.5"), hyper-
parameters (vit_batch_factor=4), parallel layouts ("TP=2, DP=6"), datasets —
are usually residue of development Q&A ("run this example", "verify this
config"). They carry no code semantics and go stale the moment the config
changes. Delete them by default.

If the code genuinely only works under a specific config, express the
restriction with an `assert` — it executes, fails loudly, and cannot rot —
and keep at most one short comment pointing at the constraint. A comment
that merely *claims* a restriction is the worst option: unenforced and
stale. (Check that the assert exists before deleting a config-citing
comment; if the restriction is real but unasserted, the fix is to add the
assert, not to keep the comment.)

Teaching examples that demonstrate a mapping or algorithm are different:
their numbers are placeholders, not test instances. Keep them, but write
them relatively ("TP member 0/1") rather than absolutely ("rank 2/rank 3"),
and never frame them as "under config X".

## Four-tier classification

1. **① Delete** — feedback-driven "why not alternative X" explanations.
2. **② Delete** — redundant comments that restate the code or a sibling
   docstring verbatim, and test-instance citations (model names,
   hyper-params, parallel configs — see the section above).
3. **③ Trim** — descriptive but over-long prose: compress to the core
   what/why, drop defensive hedges and repeated clauses. Multi-paragraph
   docstrings usually collapse to 1–2 sentences.
4. **④ Keep / fine-tune** — non-obvious what/why, interface contracts
   (what a hook must guarantee), section dividers, one-line purpose
   docstrings, and license/copyright file headers (always keep).
   Fix only factual errors or references that depend on
   non-local assumptions (e.g. an example citing hard-coded ranks when the
   actual value depends on a config).

Docstrings follow the same tiers, with one difference: keep a one-line
purpose statement on public functions/classes so the API stays readable.
Delete only the explanatory prose inside them.

## Style checkers (optional, on request)

The user may ask for style checks beyond comments (e.g. "imports must be at
the top", "--no-inner-import"). Run the registered checkers:

```
python3 scripts/checks.py --list                          # available checkers
python3 scripts/checks.py --check no-inner-import --files a.py b.py
python3 scripts/checks.py --check no-inner-import --range <start>..HEAD
```

Findings are JSON: `{checker, file, line, column, text, message, parent...}`.
Checkers only *find*; the fix goes through the same report-then-confirm
flow as comments. Checker-specific judgment notes:

- `no-inner-import`: reports every import not at module top level, with the
  enclosing construct in `parent` (`FunctionDef 'foo'`, `If`, `Try`, ...).
  Report them all; the user decides — a `if TYPE_CHECKING:` import may be
  acceptable, a function-body lazy import may have a deliberate reason, but
  the user's stated rule ("all imports at the top") is the default
  contract. Do not silently drop findings with a plausible excuse.

Adding a checker: drop a module in `scripts/checks/` defining `CHECKER_ID`
and `run(path, src) -> list[dict]`, register it in `scripts/checks/__init__.py`.
The CLI picks it up automatically.

## Workflow

### 1. Define scope

- **Git-range mode**: `git log --oneline <start>..HEAD` (verify linear,
  no merges to report) and `git diff --stat <start>..HEAD` for the file list.
- **File mode**: the user-specified files/directories.
- **Scope correction (critical)**: `git diff <start>..HEAD` only contains
  lines that were *modified after* the start commit. Comments created by the
  start commit itself and never touched since are invisible to the diff.
  Check `git log --oneline --diff-filter=A <start>..HEAD -- <file>`; if a
  file was created inside the range, ask the user whether to review its
  whole current content (recommended — the file's comments all came from the
  range) or only the lines the diff shows. In file mode no correction is
  needed.

### 2. Extract the candidate list / run checkers

```
python3 scripts/extract_comments.py --range <start>..HEAD        # git mode
python3 scripts/extract_comments.py --files a.py b.sh conf.yml   # file mode
python3 scripts/checks.py --check no-inner-import --files ...    # style check
```

Output: JSON items `{file, line, line_end, kind, text}` with
kind ∈ `full_comment` / `inline_comment` / `docstring` (docstring only for
Python). The script is best-effort (see its header); treat it as a candidate
list and read the actual files anyway. Non-Python extraction is heuristic —
always verify against the working tree. If a language's markers are not
covered, fall back to `git diff` + grep + reading the files.

Then read every file in scope in full, and classify each candidate item
against the four tiers — the report must cite real file:line and real text,
so verification against the working tree is mandatory.

### 3. Report (default, before any edit)

Deliver a per-item report:

- For **changes** (tiers ①–③ and checker findings): `file:line` + original
  text (abridged) + tier/checker + replacement text (verbatim for tier ③
  trims).
- For **kept** items (tier ④): one compact line per file listing
  line numbers and a 3–6 word reason ("non-obvious why", "interface
  contract", "section divider").

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
- Commit only when asked (or when the user's flow expects it); match the
  repo's message style, e.g. `Trim feedback-driven and redundant comments in <area>`.

## Pitfalls

- Do not "improve" tier-④ comments just to look busy — a good review
  changes little. Keeping ~90% unchanged is the healthy outcome.
- Long docstrings are not automatically bad: file-format contracts (e.g.
  checkpoint layout), WARNING/caveat blocks, and design notes with real
  invariants stay. Only the defensive/alternative-comparison prose goes.
- When in doubt between trim and delete, trim to the factual core — the
  user's rule forbids why-not-alternative, not factual why.
- Style checkers report, they do not judge: never drop a finding because
  you can imagine a justification. The report lists it; the user decides.
