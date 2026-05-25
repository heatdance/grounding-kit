---
name: better-prompt
description: >-
  Coach a draft task prompt (v1 rubric); advice only, no execution. Use with
  /better-prompt for scope, done criteria, and a paste-ready addendum.
---

# Better prompt

Slash command: [`.cursor/commands/better-prompt.md`](../../commands/better-prompt.md). Tier: [`.cursor/docs/l1/operator-assist.json`](../../docs/l1/operator-assist.json). Golden cases: [`.cursor/docs/l2/better-prompt-golden.json`](../../docs/l2/better-prompt-golden.json).

Always-on: [`.cursor/rules/communication.mdc`](../../rules/communication.mdc) (Answer tier for coaching chat); [`.cursor/rules/preservation.mdc`](../../rules/preservation.mdc) (do not mutate shipped coach without entrust).

## Turn type

**Conversation only.** No file writes, no `log.research`, no subagents for the user’s task.

## Rubric (fixed; pick top 2 gaps only)

| Gap | Ask when missing |
|-----|------------------|
| scope | What is in / out of the task? |
| done | What observable signal means finished? |
| environment | OS, runtime, branch, credentials, or tool? |
| constraints | Must-nots, style, time, or compatibility limits? |
| verification | What command or check proves success? |

## Full output template

1. **Interpreted intent** — one sentence.
2. **Suggested done** — 2–4 bullets; each must cite command, path, or exit code (no vague “works”).
3. **Worth adding** — up to **2** numbered questions from the rubric (impact order).
4. **Paste-ready addendum** — for a *future* message only; no invented paths.
5. **Next step** — send as-is, merge addendum, or re-run `/better-prompt`.

Close with: **Coaching only — your task was not started.**

## Minimal mode

Tight draft (path + verb, harness slash command, pure Q&A): intent + one done bullet + **Ready to send** + disclaimer.

## Examples (in SKILL — see also examples.md)

**Vague:** “fix the app” → full mode; top gaps likely scope + done + verification.

**Tight:** “run verify-harness.ps1 and fix manifest_drift FAIL lines; re-run until exit 0” → minimal mode.

More: [examples.md](examples.md) (max 5; replace in place per hygiene).

## Related

Execution path: [`.cursor/rules/delegation.mdc`](../../rules/delegation.mdc).
