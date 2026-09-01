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
