# x-code-clean Classification Guide

Full standards behind `SKILL.md`: the core rule's edge cases, the
recognizable feedback-driven phrasing, the cross-file reference cases, the
subagent spawn template, the descriptive-string whitelist, the dead-code
caveats, and the pitfalls. Read this before classifying comments when the
case is not obvious.

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
- Test-instance citations: "Example (language TP=2, vit_batch_factor=4)", "we tested with the 4b config", any model/hyper-param/parallel-layout value quoted as a fact (see the example keep rule below)

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

## Examples: the two-condition keep rule

An example in a comment survives only in one of two shapes; everything
else — and every doubt — deletes (②). The sharper question behind the
rule: is the example a property of this code, or a souvenir of a run?

### Keep ① — pitfall/warning notes with an intrinsic hazard

A warning ("may OOM here", "must be contiguous or the kernel reads
garbage") stays only when **this code** actually carries the hazard —
readable in the code itself: this kernel materializes a full-vocab
intermediate, this path recurses without a base-case guard — and an
`assert` (or any executable guard) does not fit. The note is then a
property of the code, not a memory: it stays true for as long as the
code does.

A warning whose only evidence is a past run deletes outright.
"TP=2 + 4b measured OOM here" is an experiment citation wearing a
warning's clothes — the observation does not make the code dangerous,
the config drifts, and no future reader can re-run yesterday's
experiment. An OOM note earns its place only on a kernel/function whose
memory footprint genuinely is a problem; everywhere else it is exactly
the over-commenting this skill removes.

### Keep ② — macro examples

A kept example lives above one experiment's scope: it demonstrates a
mapping, algorithm, or structure (index math, a layout, a protocol
exchange) to aid understanding; its numbers are placeholders written
relatively ("TP member 0/1", not "rank 2/rank 3"); it never frames
itself as "under config X". The moment the example is confined to one
experiment or run, it is a test-instance citation, not teaching
material → delete.

### Absolute counter-examples (delete by default)

Specific experiment results and experimental data: measured numbers
("3.2 s/iter"), benchmark figures, single-run observations, loss
values, configs cited as facts ("we tested with the 4b config"). These
are ② residue — stale the moment the config moves.

### The assert-first rule (unchanged)

If the code genuinely only works under a specific config, express the
restriction with an `assert` — it executes, fails loudly, and cannot
rot — and keep at most one short pointer comment. A comment that merely
*claims* a restriction is the worst option: unenforced and stale.
(Check that the assert exists before deleting a config-citing comment;
if the restriction is real but unasserted, the fix is to add the
assert, not to keep the comment.)

## Secrets and sensitive values (hard checker + soft pass)

Secret-shaped text gets a dual pass. The **hard** side is the
`no-secrets` checker: high-precision patterns (IPv4/IPv6, AWS/GitHub/
Slack/Google/OpenAI token shapes, private-key headers, bearer tokens,
`password=/token:` assignments with literal-looking values) over every
non-binary text file. The **soft** side is the subagent sweep for what
no regex catches: internal hostnames (`db-prod-3.internal`), IPv6 short
forms, topology descriptions, usernames, "ask admin X for the password"
asides.

Verdict per hit:

- Comment or doc line → delete the whole line. No redact-and-keep: a
  line that carried a secret is not trusted to keep, and the sentence
  around it is usually residue anyway. A multi-line docstring loses the
  carrying sentence/lines (a ③-style edit, syntax-gated after).
- Descriptive string → remove the carrying line, annotated "changes
  runtime output" like any string edit.
- Code line (functional string, config value) → report-only flag:
  removal can change behavior, and this skill does not refactor code.

Exemptions are reported as flags, never hidden: `loopback` (127.0.0.0/8,
0.0.0.0) and `doc-range` (RFC 5737 192.0.2.0/24 / 198.51.100.0/24 /
203.0.113.0/24, RFC 3849 2001:db8::/32, broadcast 255.255.255.255).

Known noise, handled at verification: the checker is shape-only, so any
4-octet number is IP-shaped — a version number ("bumped to 2.6.32.5")
is the classic false positive. Verify the line's context; drop proven
version strings and account for the drop in the report summary
("dropped N known-noise hits") so nothing disappears silently.

Two duties travel with the report: state that deleting working-tree
text does not scrub git history (an already-pushed secret needs history
rotation outside this skill), and note that for a live credential
deletion is not remediation — the credential needs rotating.

## Dates and process/skill citations

Git blame answers "when was this written / who last touched it" permanently
and accurately; the commit message answers "why" (that is what x-better-
commit's body rules are for). A comment copy of either does not stay
current and reads as noise, so both go by ②:

- Date stamps — "created 2026-09-05", "updated last week", "2025 version" —
  delete. They imply the code has not changed since, which is usually
  false.
- Skill/session references — "modified per x-grilling", "applied the
  code-review suggestion", "based on this morning's agent session" —
  delete. Future readers cannot resolve which conversation that was; the
  process history lives in git blame and the commit body.

Exceptions (keep, ④):

- License/copyright headers with dates — legal metadata, always kept.
- A date bound to a live obligation: "this compat shim can be removed
  after 2026-06" — a constraint with a failure mode (premature removal
  breaks readers of old data), not metadata.
- Strip-the-attribution: "per x-grilling: no try/except here — a silent
  downgrade rots distributed training" → delete the attribution, keep
  "no try/except here — a silent downgrade rots distributed training",
  and re-judge that sentence on its own merits (concrete in-code
  consequence → stays as a design note; bare "we don't use X" → ①).

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
kind of text with the same staleness failure modes, so it is in scope.
Found by reading — the whitelist convention is:

- `help`, `description`, `doc`, `__doc__`, `epilog`, `usage`, `title`,
  `comment`, `note`/`notes`, `summary`, `about`. Typical shapes:
  `add_argument("--x", help="...")`, `parser.description = "..."`,
  module-level `EPILOG = """..."""`.
- Other languages, same idea: cobra `Short:`/`Long:`/`Example`, yargs
  `.describe()`, commander `.description()`, clap `#[doc = ""]`/`about`,
  struct tags carrying docs.

Classification is the same four tiers — help text is written for future
users exactly like a comment and goes stale the same way:

- `help="batch size; not dynamic batching — OOM in early tests"`
  → tier ①: feedback residue → `help="batch size."`
- A test-instance citation inside help ("verified with the 4b config")
  → tier ② delete, same rule as in comments.
- Over-long help/epilog prose → tier ③ compress to the factual core.

Two guardrails, because unlike a comment a string is runtime content:

- **Functional strings are never prose.** `raise`/`print`/log messages,
  prompts, UI and i18n values are ④ keep — always, even when they
  explain why. Their audience is the running program's user, not the
  code reader.
- **Report the blast radius.** Every proposed edit is annotated
  "changes runtime output (CLI help / docs)"; the user confirms with
  that in view.

Non-whitelisted names, dict values (`{"help": "..."}`), and interpolated
(f-string) content are out of scope on purpose. When in doubt, judge by
role: is this string user-facing documentation, or program behavior?

## Comment review fan-out (the subagent template)

The comments category is a dual review: extraction guarantees coverage,
subagents judge.

- Hard: run `changed_lines.py` (range/uncommitted modes), then
  `extract_comments.py --files <scope files> --lines-json -` (pipe the
  JSON in; whole-repo mode omits the flag). Every comment, docstring,
  and descriptive string in scope is now enumerated.
- Soft: partition the scope files 5–10 per subagent by size (default 8;
  large code files fewer, small configs/docs more), spawn one parallel
  read-only `Explore` subagent per partition, and give each a
  self-contained prompt of this shape:

> Review these files for a comment-cleanup pass: <file list>.
> Scope: <whole file | ONLY the listed lines> <line sets from
> `changed_lines.py`, range/working-tree modes only>.
> The extraction pass already enumerated the comment candidates in your
> files (JSON below). Classify EVERY listed item — the list is the
> coverage floor; you may not skip entries — and additionally sweep the
> files for text extraction cannot see (doc prose, comment-like
> constructs it misses) and for unstructured secrets (internal
> hostnames, topology, usernames; structured IPs/tokens are the
> checker's job — still report anything you see).
> First read <skill-dir>/GUIDE.md, then classify:
> - Four tiers: ① why-not residue → delete; ② citation/metadata residue
>   (test-instance values, date stamps, skill/session references,
>   cross-file asides, dangling pointers) → delete; ③ over-long prose →
>   compress to the factual core; ④ non-obvious what/why, interface
>   contracts, provenance, dividers, license headers → keep.
> - Secrets: a hit in a comment → propose deleting the whole line; in a
>   descriptive string → the carrying line, annotated "changes runtime
>   output"; on a code line → report-only. Loopback/doc-range addresses
>   are reported with their flags, never hidden.
> - Examples: kept only as pitfall notes (hazard intrinsic to this code,
>   assert unsuitable) or macro examples (above one experiment's scope,
>   relative placeholder numbers). Experiment results/data delete.
> - Descriptive strings: a plain string bound to help/description/doc/
>   \_\_doc\_\_/epilog/usage/title/comment/note/notes/summary/about gets
>   the same tiers; raise/print/log messages and prompts are functional —
>   never propose touching them.
> - Doc prose (md/rst body text) is report-only: list findings, never
>   present them as ready-to-apply.
>
> Report ONLY: per finding — file, line, tier, original text (abridged),
> proposed replacement (verbatim compression for ③); then one
> kept-summary line per file. No edits. "Clean" is a valid per-file
> result.

Subagents only find. Before a finding enters the report, the main agent
greps the cited text at the cited location — a subagent's file:line is a
claim, not a fact; fix or drop mismatches. The session-context review
(what was just built, what awaits its caller) stays with the main agent;
subagents cannot do it.

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
- The extraction list is the coverage floor: classifying every listed item
  is mandatory, and the soft sweep may add findings but never subtract
  items. An item you judge fine still belongs in the kept summary.
- Secret findings on code lines stay report-only — do not edit functional
  strings or configs to "help"; removal can change behavior, the user
  decides. And deletion is not remediation: flag live credentials for
  rotation and say that git history is not scrubbed.
- Long docstrings are not automatically bad: file-format contracts (e.g.
  checkpoint layout), WARNING/caveat blocks, and design notes with real
  invariants stay. Only the defensive/alternative-comparison prose goes.
- When in doubt between trim and delete, trim to the factual core — the
  user's rule forbids why-not-alternative, not factual why.
- A subagent finding is a claim until verified: no unverified file:line
  reaches the report, ever.
- Doc-prose findings stay advisory even when everything else is
  pre-approved: docs are edited item by item, with explicit approval.
- Checkers report, they do not judge: never drop a finding because you
  can imagine a justification. The report lists it; the user decides.
