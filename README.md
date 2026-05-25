## What this workspace is

Use this project when you want **serious agentic work** without spending days wiring rules, prompts, and project structure yourself. You get guardrails so the agent does not wander, a **written record** across chats, and **housekeeping** so the repo does not fill with half-finished edits. Setup is once per machine; you still decide what to build and what to ask. **Cursor** is the primary surface—see **Other agent tools** below for everything else. Copy `.cursor/` into another repo (**embed** mode) to reuse the same harness there.

## How to use it

**/onboarding** — Run **once** after clone: open Agent mode and send `/onboarding` (in Cursor, trust workspace hooks if prompted). The agent bootstraps the workspace and runs harness verification inside that flow—do only what it reports (install jq, reload the IDE, and so on).

**/better-prompt** — Before a real task, send your draft with `/better-prompt`. The agent uses a fixed five-point rubric (scope, done, environment, constraints, verification), surfaces only the top two gaps, and asks for testable “done” checks in chat only—it does not change files or run the task.

**/better-skill** — Before you ship a pipeline, slash command, or skill, attach the draft with `/better-skill`. The agent scores it on four fixed rubrics (subagents, validation/done, verification schemas, iterative subsets), marks what does not apply, and may say **Good to go** when nothing is missing—chat only, no file writes. Use `/better-prompt` for everyday task wording, not harness docs.

## Writing code

When you add application or test code (including stack templates under `.cursor/harness/`), agents can load the opt-in **karpathy-guidelines** skill for Karpathy-style discipline. Harness-only setup does not need it. In **embed** mode, for always-on behavior in your product repo, copy the upstream rule from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) per their [CURSOR.md](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CURSOR.md).

## Other agent tools

Slash commands are **Cursor-only** shortcuts. Elsewhere, use the same files and scripts:

1. **Bootstrap once** — Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1`; macOS/Linux: `bash .cursor/scripts/unix/onboard.sh`. Confirm `.cursor/docs/onboarding-status.json` has `"ok": true`. Set `AGENT_RUNTIME` if needed (`cursor`, `opencode`, `claude-code`, `generic`).
2. **Entry** — [`.agents/agents.md`](.agents/agents.md), [AGENTS.md](AGENTS.md), [`.agents/prompts/onboarding.md`](.agents/prompts/onboarding.md).
3. **Each session** — Read `.cursor/docs/inject-snapshot.json`; refresh with `.cursor/scripts/jq-helpers.ps1 refresh_inject` or `.cursor/scripts/unix/jq-helpers.sh refresh_inject`.
4. **Coaches** — Attach `.cursor/commands/better-prompt.md` or `better-skill.md` instead of a slash command.
5. **Rules** — Read `.cursor/rules/*.mdc` as guidance (not auto-injected without Cursor hooks). OpenCode: optional [`.agents/adaptation/opencode.json.example`](.agents/adaptation/opencode.json.example).
