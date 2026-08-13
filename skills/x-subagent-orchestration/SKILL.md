---
name: x-subagent-orchestration
description: Explicit-only: invoked ONLY when the user explicitly requests this skill by name or its keywords (e.g. "x-subagent-orchestration", "subagent orchestration", "use subagents", "delegate"); never auto-triggered. When invoked, apply default-to-delegate rules for the Agent tool: subagents absorb bulk reading/searching/test logs and well-specified implementation, the main agent stays thin. Uses only the built-in Explore (read-only) and general-purpose (everything else) subagents — no custom agents, no fallback chains.
---

# Subagent Orchestration

Your context is the most expensive resource in the session. Subagents get
fresh contexts, so bulk reading, broad searching, log-heavy commands, and
well-specified implementation belong to them. **Default to delegating — when
you hesitate, delegate.**

## The one rule

Before you read files, grep, run tests, or implement — ask: *would this push
text through my context that a subagent could digest instead?* If yes,
dispatch.

**Dispatch:**
- Understanding anything that needs reading 2+ files, or any "where / what /
  how does X work" question
- Anything producing bulk output you would only skim: grep results,
  test/build logs, file dumps
- Implementing a unit whose spec you can write down (module, function, test
  file)
- Research synthesizing web + code + docs
- N independent units of the above → N subagents in ONE message, running in
  parallel

**Do yourself:**
- Tiny edits — one file, a few lines. Spawning costs more than it saves.
- Design, architecture, technology choices, final recommendations. Subagents
  gather material; **you** produce the answer the user acts on. Never ask a
  subagent for a design or a verdict.
- Rapid back-and-forth iteration on something you just wrote — your
  conversation history is the spec and a subagent can't see it.
- Session-bound work: browser automation, MCP tools, scheduled automations,
  permission flows.
- Code review / commit prep — owned by the `x-code-review` skill and its own
  pipeline.
- The user said "just do it" / don't use agents.

## Which subagent

Two built-ins, nothing else. No custom agents, no fallback chains — both
always exist:

| Job | subagent_type |
|---|---|
| Read-only: search, understand, map, summarize code | `Explore` |
| Anything that edits files, runs commands, or mixes web + code | `general-purpose` |

Large search space → partition by directory/module/concern and launch
several `Explore` agents in parallel, each told its slice and told to ignore
the rest.

## Writing the prompt

Subagents can't see your conversation. Every prompt needs three things:

1. **Mission** — one verifiable objective with absolute paths.
2. **Constraints** — read-only, or exactly which files it may edit;
   directories to skip.
3. **Reply format** — terse: conclusions first, `file:line` references, no
   tool-call narration, no file/log dumps. For big outputs, have it write to
   a file under `/tmp/` and reply with just the path.

Example:

> Read-only. Mission: find where rate limiting is applied in `/repo/server/`;
> report each location as `file:line` plus one sentence. Skip
> `/repo/server/vendor/`. Reply as a terse bulleted list — no narration, no
> code dumps.

## Parallel edits

Each worker owns **disjoint files**; write the ownership map into each
prompt. Shared interfaces and contracts are fixed by you up front — workers
implement against your spec, never against each other's in-flight work.

## After the reply

- Don't blind-trust. Spot-check 1–2 cited `file:line` claims against the
  source. For delegated edits, review correctness-critical diffs yourself
  and run the build/tests before declaring done.
- If a reply is thin, ask the same agent for the missing piece instead of
  redoing its work.
- If a subagent's claim contradicts your context, your context wins.
