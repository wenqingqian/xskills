# x-code-review Full Standards

Companion to `SKILL.md`: the detailed five-axis questions, the report
checklist template, and the structural-remedy / change-description standards
that the skill references. Read this before reviewing when the case is not
obvious.

## Code Context

The code to review comes in two forms:

1. **Specific files or diffs** — you have the exact code changes to review.
2. **A git repository** — review uncommitted changes (staged and/or
   unstaged). Use `git diff` (unstaged) and `git diff --cached` (staged) to
   capture the changes; pass the diff output to the subagents as the code
   context; apply the Review Scope Whitelist; let subagents know they are
   reviewing a diff against a git working tree.

## The Five-Axis Review — Detailed Questions

### 1. Correctness

- Does it match the spec or task requirements?
- Are edge cases handled (null, empty, boundary values)?
- Are error paths handled (not just the happy path)?
- Does it pass all tests? Are the tests actually testing the right things?
- Are there off-by-one errors, race conditions, or state inconsistencies?

### 2. Readability & Simplicity

- Are names descriptive and consistent with project conventions? (No
  `temp`, `data`, `result` without context)
- Is the control flow straightforward (avoid nested ternaries, deep
  callbacks)?
- Is the code organized logically (related code grouped, clear module
  boundaries)?
- Are there any "clever" tricks that should be simplified?
- Could this be done in fewer lines? (1000 lines where 100 suffice is a
  failure)
- Are abstractions earning their complexity? (Don't generalize until the
  third use case)
- Are there dead code artifacts: no-op variables (`_unused`),
  backwards-compat shims, or `// removed` comments?
- Is a new conditional bolted onto an unrelated flow? That's a design smell,
  not a nit — push the logic into its own helper, state, or policy.
- Do repeated conditionals on the same shape appear? They signal a missing
  model or dispatcher. A "temporary" branch is usually permanent debt.
- Comments must have contextual coherence — they should flow naturally with
  the surrounding logic, not jot down whatever came to mind during the
  change. No filler text. Each comment must make sense to a reader who
  encounters it in context.

### 3. Architecture

- Does it follow existing patterns or introduce a new one? If new, is it
  justified?
- Does it maintain clean module boundaries?
- Is there code duplication that should be shared?
- Are dependencies flowing in the right direction (no circular
  dependencies)?
- Is the abstraction level appropriate (not over-engineered, not too
  coupled)?
- Does this refactor reduce complexity or just relocate it? Count the
  concepts a reader must hold to follow the change. If a "cleaner" version
  leaves that count unchanged, it isn't cleaner — prefer the restructuring
  that makes whole branches, modes, or layers disappear over one that
  re-centralizes the same logic. Prefer deleting an abstraction to polishing
  it.
- Is feature-specific logic leaking into a shared or general-purpose module?
  Keep logic in its owning layer; reuse the existing canonical helper
  instead of a near-duplicate.
- Are type boundaries explicit? Question gratuitous `any`/`unknown`/
  optional/casts and silent fallbacks that paper over an unclear invariant.

### 4. Security

- Are secrets kept out of code, logs, and version control?
- Are there sufficient assertions constraining boundary conditions? Missing
  assertions on preconditions, postconditions, or invariants can hide bugs.
- Are there possible silent errors — failures that are caught but ignored,
  or errors logged without ever being surfaced? Silent errors rot the
  codebase because nobody notices until data is corrupted.

### 5. Performance

Performance impact is **not a mandatory check** in every review. Whether to
assess performance depends on the goals and scope of the change. If the
change is in a hot path, a data-intensive operation, or a user-facing
interaction, evaluate performance. Otherwise, it can be skipped.

## Structural Remedies

When you flag a structural problem, propose the move — not just the problem:

- **Replace a chain of conditionals** with a typed model or an explicit
  dispatcher.
- **Collapse duplicate branches** into a single clearer flow.
- **Reuse the canonical helper** instead of a bespoke near-duplicate.

Prefer the remedy that removes moving pieces over one that spreads the same
complexity around.

## Change Descriptions

Every change needs a description that stands alone in version control
history.

- **First line:** short, imperative, standalone. "Delete the FizzBuzz RPC"
  not "Deleting the FizzBuzz RPC." Must be informative enough that someone
  searching history can understand the change without reading the diff.
- **Body:** what is changing and why. Include context, decisions, and
  reasoning not visible in the code itself. Link to bug numbers, benchmark
  results, or design docs where relevant. Acknowledge approach shortcomings
  when they exist.
- **Anti-patterns:** "Fix bug," "Fix build," "Add patch," "Moving code from
  A to B," "Phase 1," "Add convenience functions."

## Review Report Template

Produce the report in exactly this format:

```markdown
# Review

## Overview

[Brief summary of what was reviewed and the overall assessment.]

## Review Checklist: [Change title]

### Context
- [ ] I understand what this change does and why
- [ ] Subagent cluster availability checked and correctly used (or unavailable with documented reason)

### Correctness
- [ ] Change matches spec/task requirements
- [ ] Edge cases handled
- [ ] Error paths handled
- [ ] Tests cover the change adequately

### Readability
- [ ] Names are clear and consistent
- [ ] Logic is straightforward
- [ ] No unnecessary complexity
- [ ] No dead code
- [ ] No incomprehensible, excessive, or inappropriate comments
- [ ] Comments have contextual coherence

### Architecture
- [ ] Follows existing patterns
- [ ] No unnecessary coupling or dependencies
- [ ] Appropriate abstraction level
- [ ] Refactors reduce complexity rather than relocate it
- [ ] File stays within a healthy size

### Security
- [ ] No secrets in code, logs, or version control
- [ ] Boundary conditions have sufficient assertions
- [ ] No silent errors (errors caught but ignored or buried)

### Performance
- [ ] No performance concern, or performance impact is out of scope for this change

### Verification
- [ ] Tests pass

### Findings Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | | |
| Required | | |
| Optional/Nit | | |
| FYI | | |

### Verdict
- [ ] **Approve** — Ready to merge
- [ ] **Request changes** — Issues must be addressed

## Review Details

[Detailed findings with file paths and line numbers, ordered by severity.]
```
