# Better skill

Coach a draft **pipeline**, **slash command**, or **skill** before you rely on it for agent work. **Advice only** — the agent does not write or run the harness doc.

Skill: [`.cursor/skills/better-skill/SKILL.md`](../skills/better-skill/SKILL.md). Tier: [`.cursor/docs/l1/operator-assist.json`](../docs/l1/operator-assist.json) (`betterSkill.version`). Patterns: [`.cursor/docs/l2/skill-authoring-patterns.json`](../docs/l2/skill-authoring-patterns.json).

## When to use

- You are authoring or reviewing `.cursor/pipelines/`, `.cursor/commands/`, or `.cursor/skills/*/SKILL.md`.
- You want agentic-facing docs with clear done checks, verification, and orchestration — not a one-shot prompt.

**Misroute:** Operator **task** text only (e.g. “fix login test”) → use [`/better-prompt`](better-prompt.md), not this command.

## Agent instructions

1. Classify this turn as **Conversation** ([`documentation.mdc`](../rules/documentation.mdc)): no `append_research`, no `set_last`, no file edits.
2. Read the draft from the message and any `@` attachments. Do **not** run verifiers, edit files, or spawn subagents for the draft.
3. **Classify artifact:** `pipeline` | `command` | `skill` (path and structure).
4. Score the draft against the **four fixed rubrics** below. Each rubric: `satisfied` | `gap` | `not_applicable` (short reason required for n/a).
5. **Never add a fifth rubric.** Do not recommend Jira, epic workspaces, or `*_verify.py` unless the draft already uses them.
6. Apply the output template unless **minimal mode** applies.
7. End with: **Coaching only — no harness doc was written.**

### Four rubrics (fixed)

| ID | What it checks |
|----|----------------|
| **subagents** | Heavy slices use separate Task/subprocess passes with a written brief; orchestrator merges; cap parallel work; no subagent chains. |
| **validation_done** | Phases or the run end with observable done: verifier script, exit code, `validation_log`, or explicit STOP/prerequisite tables. |
| **verification_schema** | Durable outputs use schema_version + contracts; forbidden inputs; fresh-run tokens (`proceed` = new run); anti whack-a-mole (log blocked assumptions). |
| **iterative_subsets** | Large work split (phases, `map_only`, per-slice temp files, delete `temp/` before complete); MUST NOT one-shot materialize + emit. |

### Applicability (default)

| Artifact | Typical |
|----------|---------|
| **pipeline** | All four often apply |
| **command** | `validation_done` strong; `subagents` / `iterative_subsets` often n/a |
| **skill** | Light `validation_done`; `subagents` / `iterative_subsets` usually n/a unless orchestration skill |

### Hallucination guards

- Do **not** invent repo paths, verifiers, or epic folders unless the draft or `@` file names them.
- Do **not** paste a full subprocess table into a one-screen skill.
- If all applicable rubrics are **satisfied**, verdict is **Good to go** (no filler improvements).

### Minimal mode

Single-screen **command** or **skill** with explicit On success / On failure and a script or path: one-sentence intent, one check, **Ready to send**, disclaimer.

### Output template (~200 words)

1. **Artifact** — type + one-sentence purpose.
2. **Rubric scorecard** — four rows (status + ≤12 words evidence).
3. **Improvements** — only `gap` rubrics; **max 2** bullets.
4. **Paste-ready addendum** — optional sections to add to the doc (for a *future* edit; do not apply).
5. **Verdict** — **Good to go** or **Needs work** + one next step.

## Shipped behavior

Versioned in `operator-assist.json`. No learning loops or auto-edits unless the operator entrusts a harness behavior change ([`preservation.mdc`](../rules/preservation.mdc)).
