---
name: karpathy-guidelines
description: >-
  Karpathy-inspired coding discipline: clarify assumptions, simplify,
  surgical diffs, verifiable done. Use when writing, reviewing, or refactoring
  application or test code — not for harness-only tier/doc Actions.
license: MIT
---

# Karpathy guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876). Upstream: [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills). Tier: [`.cursor/docs/l2/karpathy-guidelines.json`](../../docs/l2/karpathy-guidelines.json).

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Harness scope (this workspace)

**Use when:**

- Writing or reviewing **application or test code** (including under [`.cursor/harness/`](../../harness/) when you add stack templates).
- **Embed mode:** after copying `.cursor/` into a product repo, while implementing features or tests there.

**Do not use when:**

- Editing harness tier JSON, rules, hooks, or manifest-only Actions — follow [`intent.mdc`](../../rules/intent.mdc) and tier research instead.
- Conversation coaches (`/better-prompt`, `/better-skill`) — those are advice-only turns.
- Weakening shipped core per [`preservation.mdc`](../../rules/preservation.mdc).

This skill does **not** replace intent gates, doc close, or preservation.

## Relation to harness tools

| Tool | Role |
|------|------|
| **karpathy-guidelines** (this skill) | Code execution discipline |
| `/better-prompt` | Coach operator task wording |
| `/better-skill` | Coach pipeline/command/skill docs |
| `preservation.mdc` | Frozen shipped harness behavior |

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — do not pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — do not delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Always-on in a product repo (embed)

This skill is **opt-in** here. For always-on behavior in your application repo, copy upstream [`.cursor/rules/karpathy-guidelines.mdc`](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/.cursor/rules/karpathy-guidelines.mdc) per [CURSOR.md](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CURSOR.md).
