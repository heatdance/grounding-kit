# Unix scripts (macOS / Linux / Git Bash)

Run all commands from the **repository root**.

## Onboarding (once per machine)

```bash
bash .cursor/scripts/unix/onboard.sh
```

Force runtime when auto-detect is wrong:

```bash
export AGENT_RUNTIME=opencode   # cursor | opencode | claude-code | generic
bash .cursor/scripts/unix/onboard.sh
```

**Outputs**

| File | Purpose |
|------|---------|
| `.cursor/docs/onboarding-status.json` | Pass/fail checks |
| `.agents/state/environment.json` | Runtime profile and operator steps |
| `.cursor/docs/environment.json` | Mirror for tier docs |

**Limits on Unix**

- Hook smoke tests run only on Windows (`onboard.ps1`). Unix onboarding still validates JSON, refreshes the inject snapshot, and adapts the repo for your runtime.
```bash
bash .cursor/scripts/unix/verify-harness.sh
```

Windows/PowerShell equivalent: `.cursor/scripts/verify-harness.ps1`.

## Environment detection and adapt (without full onboard)

```bash
bash .cursor/scripts/unix/detect-environment.sh
export AGENT_RUNTIME=generic
ONBOARD_OK=true bash .cursor/scripts/unix/adapt-environment.sh
```

`adapt-environment.sh` falls back to PowerShell `adapt-environment.ps1` only if you do not use this script — `onboard.sh` prefers the bash adapt path.

## Doc harness helpers (jq)

```bash
.cursor/scripts/unix/jq-helpers.sh append_research L1 workspace answered jq
.cursor/scripts/unix/jq-helpers.sh set_last "What changed" "Why" action ".cursor/docs/log.json"
.cursor/scripts/unix/jq-helpers.sh rotate_log
.cursor/scripts/unix/jq-helpers.sh refresh_inject
```

Requires `jq` on PATH (`brew install jq`, `apt install jq`, etc.).

## Action open checklist

```bash
bash .cursor/scripts/unix/action-open.sh intent
bash .cursor/scripts/unix/action-open.sh workspace --stub
```

## Audit log

```bash
jq '.research[-10:]' .cursor/docs/log.json
jq '.last' .cursor/docs/log.json
jq '.capabilities' .agents/state/environment.json
```

## Portable entry (any agent tool)

Read [`.agents/agents.md`](../../../.agents/agents.md) and [AGENTS.md](../../../AGENTS.md). Non-Cursor tools must **read** `.cursor/docs/inject-snapshot.json` each turn (hooks do not run).
