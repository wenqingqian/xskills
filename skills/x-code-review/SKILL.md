---
name: x-code-review
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-code-review", "review the code", "review this diff", "do a code review"); never auto-triggered. When invoked, conduct a multi-axis code review (correctness, readability, architecture, security, performance) of uncommitted changes or a git range using the dedicated code-review subagent cluster (major + sub-N + merger + executor pipeline), then apply approved fixes. Skip when changes are trivially small or the code just passed a review.
---

# Code Review and Quality

Multi-dimensional code review with quality gates. Every change gets reviewed
before merge — no exceptions. Five axes: correctness, readability,
architecture, security, performance. **Full standards and the report
template live in `GUIDE.md` in this skill directory — read it before
reviewing.** Approval standard: approve a change when it definitely improves
overall code health, even if it isn't perfect.

## When to Use

- **Before every commit** — user asks to commit or for a review; before
  merging a PR; after a feature; when another agent produced code to
  evaluate; after a bug fix.
- **Skip** (use good judgment): very small changes (single-line fix, typo,
  minor rename); code that just passed a full review with only trivially
  small follow-ups.

## The Five-Axis Review

1. **Correctness** — matches spec; edge cases; error paths; tests pass and
   test the right things; off-by-one, races, state inconsistencies.
2. **Readability & Simplicity** — clear names; straightforward flow; no
   unnecessary complexity or dead code; fewer lines where possible; comments
   have contextual coherence; repeated conditionals signal a missing
   model/dispatcher; a conditional on an unrelated flow is a design smell.
3. **Architecture** — follows existing patterns; clean module boundaries; no
   duplication; refactor reduces complexity, not just relocates it; no
   feature logic leaking into shared modules; type boundaries explicit.
4. **Security** — no secrets in code/logs/VC; assertions constrain boundary
   conditions; no silent errors (caught-but-ignored failures rot code).
5. **Performance** — only in hot paths, data-intensive ops, or user-facing
   interactions; otherwise skip.

When you flag a structural problem, propose the move — not just the problem
(replace conditional chains with a dispatcher; collapse duplicate branches;
reuse the canonical helper).

## Multi-Model Review Pattern (MUST)

**You MUST use the dedicated code-review subagent cluster** (`code-reviewer-*`
types) — reviewing yourself when it is available is a **process violation**;
if unavailable, fall back to a built-in subagent with you applying changes.

### Your Role as Orchestrator (Strict Data Pipeline)

**You are the router, not the reader** — with one exception: you MUST read
any document the merger's reply references before approving.

1. Create `REVIEW_DIR="/tmp/code-review-$(date +%s)"`, mkdir; detect
   available sub-N agents dynamically (skip any N that doesn't exist).
2. Launch major + all subs in parallel with: code context (diff or files),
   output file path, **review scope whitelist**, planning-space exclusion.
3. Collect file paths from replies — **MUST NOT read the review reports**.
4. Forward paths to the merger; read its referenced documents, then
   approve/reject; launch the executor.

**Hard rules:** MUST NOT read `review_major.md` / `review_sub_N.md` (context
is reserved for routing); MUST read the merger-referenced documents
(`review_final.md` etc.) before deciding — the summary alone is deciding
blind; absolute paths; parse replies exactly; forward raw paths as
`[review-major: /abs, review-sub-1: /abs, ...]`.

### Subagent Roles

- **code-reviewer-major**: primary reviewer, writes `review_major.md`.
- **code-reviewer-sub-N**: supplementary opinions, each writes
  `review_sub_N.md`; launch all that exist, in parallel.
- **code-reviewer-merger**: reads major + subs, writes `review_final.md`.
- **code-reviewer-executor**: does not judge — implements faithfully.
- Cluster requires at minimum `code-reviewer-major`; if merger/executor
  missing, major takes over their responsibilities.

### Review Scope Whitelist

**Included**: source (`.py .cpp .c .h .hpp .java .rs .go .js .ts .tsx .jsx
.swift .kt .scala .rb .php .sh .bash .zsh .fish`), build/test (`Makefile`,
`CMakeLists.txt`, `BUILD*`, `Dockerfile`).

**Excluded**: anything matched by `.gitignore`; config (`.yaml .yml .toml
.ini .cfg .conf`); docs (`.md .txt .log .rst .tex`); data (`.json .xml .csv
.sql`); generated (`*.generated.*`, `node_modules/`, `venv/`, `__pycache__/`,
`.git/`); if `skill planning` is active, its `{planning_space}`.

### Pipeline Flow

```
0: check cluster availability (MUST gate)   1: mkdir REVIEW_DIR
2: detect sub-N agents                      3: launch major + subs (context
   + output path + whitelist)               4: collect paths — MUST NOT read
5: forward to merger [review-major: …, review-sub-1: …]
6: merger replies; READ its referenced docs before deciding
7: approve → executor ("Approved. Implement: <review_final.md>"); 8: verify
Cluster unavailable → built-in subagent review + you implement.
```

## Review Process

1. **Check subagent availability** (mandatory gate, before any review work).
2. **Understand the context** — what does the change accomplish, what spec
   does it implement, what behavior change is expected?
3. **Review the tests first** — they reveal intent and coverage.
4. **Review the implementation** with the five axes.
5. **Categorize findings**: *(no prefix)* Required, **Critical:** blocks
   merge, **Nit:** optional, **Optional:/Consider:** suggestion, **FYI**
   informational. Lead with what matters.
6. **Verify the verification** — what tests ran, did the build pass, manual
   testing, before/after comparison?

## The Review Report

Report structure: Overview; Review Checklist (context, correctness,
readability, architecture, security, performance, verification);
Findings Summary (severity × count); Verdict; Details by severity.
Template: `GUIDE.md`.
