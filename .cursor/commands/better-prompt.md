# Better prompt

Coach a draft task prompt before you send it for real work. **Advice only** — the agent does not execute your task, edit files, or spawn subagents for it.

Skill: [`.cursor/skills/better-prompt/SKILL.md`](../skills/better-prompt/SKILL.md). Tier: [`.cursor/docs/l1/operator-assist.json`](../docs/l1/operator-assist.json) (`betterPrompt.version`).

## When to use

- You are unsure what to include (scope, done criteria, paths).
- The task is multi-step or vague (“fix the app”, “improve harness”).
- You want a paste-ready addendum for a **later** message, not auto-run work.

Skip for `/onboarding` when the draft is only re-running setup you already know, unless you want a quick sanity check.

## Agent instructions

1. Classify this turn as **Conversation** ([`documentation.mdc`](../rules/documentation.mdc)): no `append_research`, no `set_last`, no edits under `.cursor/docs/` or repo files.
2. Read the operator’s draft task from the message (and any `@` files already attached in chat). Do **not** run tests, tools on the repo, or Task/subagents for that task.
3. Score the draft against the **rubric** (fixed gaps: scope, done, environment, constraints, verification). Surface only the **top 2** missing gaps in “Worth adding” — not all five.
4. Apply the output template below unless **minimal mode** applies.
5. End with: **Coaching only — your task was not started.**

### Quality rules (full mode)

- **Suggested done:** each bullet must name a **command**, **file/path**, or **exit code**. Do not use “works correctly”, “looks good”, “properly”, or similar.
- **Paste-ready addendum:** do not invent repo paths unless the operator named a path in the draft or attached a file with `@`.

### Minimal mode (already tight draft)

Use when **any** of:

- Single file path + clear verb (fix typo, rename, run one command).
- Operator invoked another harness slash command with explicit steps.
- Pure question with no implementation ask.

**Minimal output:** Interpreted intent (one sentence) · one suggested done bullet · **Ready to send** · coaching disclaimer.

### Full template (~150–250 words)

1. **Interpreted intent** — one sentence.
2. **Suggested done** — 2–4 verifiable bullets (commands, files, exit codes).
3. **Worth adding** — up to **2** numbered optional questions from the rubric (highest impact first).
4. **Paste-ready addendum** — short block the operator may copy into their *next* message (do not submit it for them).
5. **Next step** — one line: send as-is, merge the addendum, or refine and re-run `/better-prompt`.

## On success

Operator has actionable coaching and optional copy-paste text; no harness or project changes occurred in this turn.

## On misuse

If the operator expected implementation, remind them to send a normal prompt (without `/better-prompt`) after coaching.

## Shipped behavior

Coach contract is **versioned** in `operator-assist.json`. Do not add learning loops, corpus growth, or auto-edits to this command unless the operator explicitly entrusts a harness behavior change (see [`preservation.mdc`](../rules/preservation.mdc)).
