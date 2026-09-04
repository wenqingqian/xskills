# x-code-clean Classification Guide

Full standards behind `SKILL.md`: the core rule's edge cases, the
recognizable feedback-driven phrasing, the cross-file reference cases, the
dead-code caveats, and the pitfalls. Read this before classifying comments
when the case is not obvious.

## The core rule in detail

A comment may say **what this code does** and **why it is done this way**.
It must NOT say **why the code is not written some other way** ("why not
alternative X"). The second kind is almost always residue of a past Q&A —
the agent answered a user question ("why don't you use X?") and baked the
excuse into a comment. It is noise for every future reader.

### Recognizable feedback-driven phrasing (delete or trim these)

- Negations: "not a load-balancing choice", "no duplicated compute within the group"
- Defensive hedges: "kept as a safeguard", "normally unreachable"
- Alternative-comparison: "without using `retain_graph=True`", "deliberately does not implement `__getattr__`", "taking only X would silently drop Y", "which is why the advance cannot happen inside forward"
- Explaining why two functions do not share code: "each computes its side directly, kept mathematically equivalent"
- Session-directed rules: "do not duplicate these checks elsewhere", "each assert message states its own reason"
- Test-instance citations: "Example (language TP=2, vit_batch_factor=4)", "we tested with the 4b config", any model/hyper-param/parallel-layout value quoted as a fact (see the assert-vs-example rule below)

### The boundary: "why not X" that is a design note

Not every "why not X" is feedback-driven. A "why not" that carries its own
correctness/engineering reasoning with a concrete in-code consequence is a
design note → keep (tier ④). A bare alternative-comparison with no in-code
consequence is feedback-driven → delete (tier ①).

Examples that carry a specific failure mode (keep):

- "a wider group would elementwise all-reduce different vocab shards — silent embedding-gradient corruption"
- "broadcasting first would sum dp identical copies"
- "deliberately no try/except: a silent downgrade rots distributed training"

Example that just refuses an alternative (delete):

- "not a load-balancing choice"

Ask: does the sentence cite a specific failure mode of this code, or just
refuse an alternative? Specific failure mode → keep.

A comment that explains what the code needs to stay correct — e.g. "keep the
grid metadata: `_count_vision_tokens` needs it for the full macro batch" —
is legitimate why and stays.

## Test-instance information (models, hyper-params, parallel configs)

Comments citing concrete test instances — model names ("Qwen3.5"),
hyper-parameters (vit_batch_factor=4), parallel layouts ("TP=2, DP=6"),
datasets — are usually residue of development Q&A ("run this example",
"verify this config"). They carry no code semantics and go stale the moment
the config changes. Delete them by default.

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

## References to other files / projects / repos

The test is always **from this project's standpoint**: does this reference
create a constraint or provenance *this* project needs? Not "is it
interesting", not "was it true when written".

Keep (tier ④) — the reference is load-bearing here:

- Vendored/ported-code provenance: "copied from upstream
  `megatron/core/foo.py`, sync on update" — deleting it severs the sync
  obligation; nobody will know to re-check upstream.
- External spec/format contracts: "layout follows RFC 1234 §3" — the reader
  cannot interpret this file correctly without it.
- In-repo sync pointers: "must stay in sync with `a/b.py`" — but only after
  you verified `a/b.py` exists in the working tree.

Delete (tier ②) — the reference constrains nothing here:

- Informational asides into other projects/repos: "similar to the helper in
  `../other-repo/utils.py`", "the old infra repo did this differently". This
  project's readers often cannot resolve them, and nothing here breaks if
  the target changes.
- Dangling in-repo references: the target file/symbol no longer exists.
  Always delete — a reference that cannot be followed cannot be necessary.
  (If the *constraint* is still real but the target moved, fix the pointer
  instead of deleting.)

Verify every in-repo reference against the working tree before classifying
(check the file exists; if it names a symbol, grep the symbol). External
references cannot be verified — judge necessity only, and when in doubt ask
the user rather than silently keeping.

The session-context pass applies here too: a reference to a repo or file
that was part of *this session's* task (e.g. the upstream you just ported
from) is usually provenance, not an aside.

## Descriptive strings (help / description-style literals)

Comments and docstrings are not the only user-facing prose in a file.
A plain string literal bound to a documentation-carrying name is the same
kind of text with the same staleness failure modes, so it is in scope:

- Python (exact, via `extract_comments.py`): a string literal whose
  assignment target or keyword name is whitelisted — `help`,
  `description`, `doc`, `__doc__`, `epilog`, `usage`, `title`, `comment`,
  `note`, `notes`, `summary`, `about` (constant `DESC_STRING_PARAMS` in
  the extractor; extend there, never in the classifier). Reported as
  kind `desc_string`. Typical shapes: `add_argument("--x", help="...")`,
  `parser.description = "..."`, `EPILOG = """..."""` when the name itself
  is whitelisted.
- Other languages (no lexer in the extractor): check during the read
  pass. Common shapes: cobra `Short:`/`Long:`/`Example`, yargs
  `.describe()`, commander `.description()`, clap `#[doc = ""]`/`about`,
  struct tags carrying docs.

Classification is the same four tiers — help text is written for future
users exactly like a comment and goes stale the same way:

- `help="batch size; not dynamic batching — OOM in early tests"`
  → tier ①: feedback residue → `help="batch size."`
- A test-instance citation inside help ("verified with the 4b config")
  → tier ② delete, same rule as in comments.
- Over-long help/epilog prose → tier ③ compress to the factual core.

Two guardrails, because unlike comments a string is runtime content:

- **Functional strings are never prose.** `raise`/`print`/log messages,
  prompts, UI and i18n values are ④ keep — always, even when they
  explain why. Their audience is the running program's user, not the
  code reader, and editing them changes behavior. Only whitelisted names
  (and the obvious doc-bearing constructs above) enter classification.
- **Report the blast radius.** Every proposed desc_string edit is
  annotated "changes runtime output (CLI help / docs)"; the user
  confirms with that in view.

Extractor limits (best-effort by design; the read pass is the net):
values wrapped in parentheses or moved to the next line, implicit
concatenation (`"a" "b"` captures only the first part), and prefixed
literals (`f""`/`b""`/`r""` — interpolated/byte content is functional
anyway) are not auto-extracted; dict values (`{"help": "..."}`) and
non-whitelisted names are out of scope on purpose. Annotated
assignments (`usage: str = "..."`) are not matched either.

## Dead-code findings (the `dead-code` checker)

The checker is name-based: a same-named symbol anywhere in the repo masks a
dead definition (false negative), and dynamic consumption hides real uses
(false positive). Both directions are absorbed by process, not by the
script:

- Every finding is a **candidate**. Before putting it in the report, verify
  with your own grep: search the identifier across the repo (including
  strings, configs, CLI entry tables, docs that generate calls).
- Exemption flags mean "probably alive, user decides": `exported` (in
  `__all__` — public API), `decorated` (registration-style decorators such
  as pytest fixtures / CLI commands consume invisibly), `entry-point`
  (`main`), `test-only` (only tests reference it — maybe production code
  lost its caller, maybe a test helper), `dynamic-ref` (name appears in a
  string literal — getattr/registry lookup).
- Unflagged findings are the strong candidates; still verify once.
- Deleting a dead function can orphan its private helpers (they were
  referenced only by it). After applying deletions, re-run `checks.py` once
  to catch the cascade.
- Only Python is supported. Do not hand-roll dead-code analysis for other
  languages; say the category does not cover them.

## Inner-import findings (the `no-inner-import` checker)

The checker reports every import that is not at module top level, then
downgrades the legitimate patterns to **exemption candidates**: they stay
in the report (flags, never hidden), carry their flag, and get no hoist
proposal — the user still decides. Unflagged findings are violations.

The six structural signals and their real-code shapes:

- `optional-dep` — probing for a dependency that may be absent:
  `try: from modelopt.torch import ...` / `except ImportError:` with a
  silent fallback (set to None, log, pass). The handler does NOT raise.
- `lazy-activation` — two shapes: (a) `except ImportError:` that raises
  an actionable error (`raise RuntimeError("pip install pkg[extra]")`) —
  the feature is opt-in and fails with instructions when absent; (b) a
  lazy-contract keyword ("lazy", "on demand", "optional dep",
  "deferred import", "not require") in the module or enclosing
  docstring — e.g. a gated `from sga.runtime import build_engine` in a
  module whose docstring says "stock runs must not require it". The
  keyword match is a heuristic; read the actual contract before
  accepting the exemption.
- `test-local` — the file is a test (`tests/`, `test_*.py`,
  `conftest.py`), where function-level imports are idiom, or the import
  alias is a patch target (`import sga.engine as engine_mod` +
  `mock.patch("engine_mod.build_engine")` — detected via the alias
  appearing in a string literal of the same file).
- `circular-guard` — hoisting would close an import cycle: the in-repo
  target module (transitively, module-level imports only) imports the
  current module back. Typical shape: a callback/re-entry boundary —
  `runtime.py` importing the host framework inside a function because
  the framework calls back into this package via
  `extra_args_provider`-style hooks; a top-level import would deadlock
  the interpreter at startup.
- `heavy-deferral` — a heavy third-party package (torch / transformers /
  triton family; the list is a constant in the checker, extend it there)
  imported inside a CLI entry (`main`/`cli` function, `__main__.py`, or
  the `if __name__ == "__main__"` guard) to keep startup fast.
- `typing-only` — inside a module-level `if TYPE_CHECKING:` block;
  never executes at runtime.

What the checker cannot decide (verify before reporting):

- External-target cycles: `circular-guard` resolves only in-repo
  targets. A function-level import of an external framework at a
  callback boundary is a circular-guard suspect — annotate it as such
  instead of proposing a hoist; confirm by checking whether the
  framework imports this package back (docs, plugin contract, or the
  callback wiring in this repo).
- Docstring semantics: a keyword hit is not a contract. If the
  docstring does not actually declare laziness, drop the flag in your
  report and treat the finding as a violation.
- The alias-in-string signal can fire on unrelated prose mentioning
  `alias.` — check the string is a patch target.
- Signals compose (a heavy import inside try/except gets several
  flags); all of them are shown, in checker order.

Never invent an exemption the checker did not signal — same discipline
as dead-code: the report lists it, the user decides.

## Pitfalls

- Do not "improve" tier-④ comments just to look busy — a good review changes
  little. Keeping ~90% unchanged is the healthy outcome.
- Long docstrings are not automatically bad: file-format contracts (e.g.
  checkpoint layout), WARNING/caveat blocks, and design notes with real
  invariants stay. Only the defensive/alternative-comparison prose goes.
- When in doubt between trim and delete, trim to the factual core — the
  user's rule forbids why-not-alternative, not factual why.
- Checkers report, they do not judge: never drop a finding because you
  can imagine a justification. The report lists it; the user decides.
