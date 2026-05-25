# Onboarding

Run **once** after you clone the repo: open Agent mode and send `/onboarding`. The agent bootstraps and verifies the workspace; you only do what it reports (for example trust hooks in Cursor, install jq, or reload the IDE).

Portable spec: [`.agents/manifest.yaml`](../../.agents/manifest.yaml) and [`.agents/prompts/onboarding.md`](../../.agents/prompts/onboarding.md).

## Run (from repository root)

One-time bootstrap after cloning. Works for **Cursor**, **OpenCode**, **Claude Code**, and other agentic tools. Do not skip terminal steps.



**Windows (hook smoke for Cursor; environment adapt for all):**



```powershell

powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1

```



**macOS / Linux:**



```bash

bash .cursor/scripts/unix/onboard.sh

```

Unix reference: [`.cursor/scripts/unix/README.md`](../scripts/unix/README.md).

**Force runtime** when auto-detect is wrong:

```bash

export AGENT_RUNTIME=opencode   # cursor | opencode | claude-code | generic

bash .cursor/scripts/unix/onboard.sh

```

```powershell

$env:AGENT_RUNTIME = "opencode"

powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1

```



## Rules



- Do **not** open or double-click `.cursor/hooks/*.sh` in Explorer or the editor. Hooks must run via **PowerShell** per `.cursor/hooks.json` (Cursor only).

- Do **not** change `hooks.json` to invoke bare `.sh` files.

- `.cursor/hooks/` must contain only `*.ps1` (no orphan `.sh`).



## On success



1. Read `.cursor/docs/onboarding-status.json` and confirm `"ok": true`.

2. Read `.agents/state/environment.json` for **runtime-specific** operator steps.

3. **Cursor:** reload IDE; new Agent chat; hooks inject snapshot.

4. **OpenCode / other:** read `.agents/agents.md` and `AGENTS.md`; refresh `inject-snapshot.json` manually each turn if hooks are unavailable.

5. Optional OpenCode: merge [`.agents/adaptation/opencode.json.example`](../../.agents/adaptation/opencode.json.example) into `opencode.json`.



## On failure



1. Read `onboarding-status.json` → `checksFailed`.

2. If jq is missing, tell the user how to install it for their OS (winget, brew, or package manager) and re-run `/onboarding` after install.

3. Re-run `.cursor/scripts/verify-harness.ps1` (Windows) to see hygiene failures.

4. Do **not** claim the workspace is ready until onboarding exits 0 and `"ok": true`.



## Re-run when



- First clone on a machine

- After installing jq

- Switching primary agent tool (set `AGENT_RUNTIME` and re-run)

- If hooks were reverted to `.sh`, duplicate scripts reappeared, or snapshot/harness behaves incorrectly



After cleaning duplicate files in an Action, report deleted paths in `log.last` and re-run verify.

