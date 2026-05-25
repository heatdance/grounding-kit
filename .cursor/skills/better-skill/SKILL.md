---
name: better-skill
description: >-
  Coach pipeline, command, or skill drafts (v1 rubrics); advice only. Use with
  /better-skill before shipping agent-facing harness docs.
---

# Better skill

Slash command: [`.cursor/commands/better-skill.md`](../../commands/better-skill.md). Tier: [`.cursor/docs/l1/operator-assist.json`](../../docs/l1/operator-assist.json). Patterns: [`.cursor/docs/l2/skill-authoring-patterns.json`](../../docs/l2/skill-authoring-patterns.json).

Always-on: [`.cursor/rules/preservation.mdc`](../../rules/preservation.mdc) (shipped coach); [`.cursor/rules/communication.mdc`](../../rules/communication.mdc) (Answer tier).

## Turn type

**Conversation only.** No writes, no `log.research`, no subagents for the user’s draft.

## Artifact classifier

| Type | Signals |
|------|---------|
| pipeline | `.cursor/pipelines/`, phases, Epic/workspace, orchestration |
| command | `.cursor/commands/`, slash, run from root, On success |
| skill | `SKILL.md`, frontmatter, When to use |

User task only → redirect to `/better-prompt`.

## Four rubrics (never add a fifth)

| ID | satisfied means |
|----|-----------------|
| subagents | Slices delegated; brief + merge; no chains |
| validation_done | STOP, prerequisites, verifier or validation_log |
| verification_schema | schema_version, contracts, forbidden inputs, fresh proceed |
| iterative_subsets | No one-shot; temp/ lifecycle; subset gates |

Status each: `satisfied` | `gap` | `not_applicable` + reason.

## Output template

1. Artifact · 2. Scorecard (4 rows) · 3. Improvements (max 2, gaps only) · 4. Paste-ready addendum · 5. Good to go | Needs work.

Close with: **Coaching only — no harness doc was written.**

## Pattern inserts (gaps only)

Use [`.cursor/docs/l2/skill-authoring-patterns.json`](../../docs/l2/skill-authoring-patterns.json) — generic wording, no product-specific Jira/epic names unless draft already has them.

## Examples

See [examples.md](examples.md).

## Related

User tasks: [`.cursor/skills/better-prompt/`](../better-prompt/SKILL.md). Execution: [`.cursor/rules/delegation.mdc`](../../rules/delegation.mdc).
