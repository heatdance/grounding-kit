---
name: agent-intent
description: >-
  Intent gate, tier-grounded research, clarify-before-implement, and anti
  whack-a-mole. Use on Action turns, when scope is ambiguous, after failed fixes,
  or when the user asks how agents should interpret requests.
---

# Agent intent

Always-on rules: [intent.mdc](../../rules/intent.mdc), [communication.mdc](../../rules/communication.mdc) (clarify layout), [documentation.mdc](../../rules/documentation.mdc).

## Action open checklist

1. Read `inject-snapshot.json` (+ `environment.json` if non-Cursor).
2. Write interpreted intent + evidence + confidence (chat).
3. `append_research` for each tier read.
4. If **low** confidence → Blocking + Questions only; stop.
5. If **medium** → prefer Questions; proceed only when harm is low and scope is explicit.

## Clarify template (chat)

```
Blocking: …

Questions:
1. …
2. …

Context: …
```

## Bad vs good

**Bad:** User says "fix onboarding" → agent edits random scripts without reading `l1/workspace.json` or `l1/runtimes.json`.

**Good:** Research `workspace` + `runtimes` anchors, state intent ("align Unix docs with onboard adapt"), then edit.

**Bad:** Second identical retry after test failure.

**Good:** Log `blocked`, explain wrong assumption, offer options; wait for user after third literal retry.

**Bad:** Long paragraph mixing rationale, three questions, and a partial implementation plan.

**Good:** Three labeled blocks; numbered questions under Questions only.

## Audit research trail (operators)

```bash
jq '.research[-10:]' .cursor/docs/log.json
jq '.last' .cursor/docs/log.json
jq -r '.anchors.intent.path' .cursor/docs/INDEX.json
```

Windows: `.cursor/scripts/query-log.ps1 research-recent`
