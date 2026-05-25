# Agent entry (portable)

This repository uses a **dual-layer** layout:

| Layer | Role |
|-------|------|
| **`.agents/`** | Cross-runtime bridge (this file, manifest, runtime profiles, onboarding state) |
| **`.cursor/`** | Canonical harness (rules, skills, tiered JSON docs, hooks for Cursor) |
| **`AGENTS.md`** | Full agent schema (tiers, Action close, jq commands) |

## First step every session

1. Read [`.cursor/docs/inject-snapshot.json`](../.cursor/docs/inject-snapshot.json) — includes **actionOpen** checklist and tier anchors.
2. Read [`.agents/state/environment.json`](state/environment.json) if present (onboarding output).
3. On **Action**: interpreted intent + evidence + confidence (**low** = no writes until user answers). See [`.cursor/docs/l1/intent.json`](../.cursor/docs/l1/intent.json).
4. Follow [AGENTS.md](../AGENTS.md) for Conversation vs Action and doc sync.

If `environment.json` is missing, run **onboarding** (below).

## Onboarding (`/onboarding`)

Onboarding detects your runtime and adapts the workspace:

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1
```

```bash
# macOS / Linux / Git Bash
bash .cursor/scripts/unix/onboard.sh
```

Force a runtime when auto-detect is wrong:

```bash
export AGENT_RUNTIME=opencode
bash .cursor/scripts/unix/onboard.sh
```

```powershell
$env:AGENT_RUNTIME = "opencode"
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1
```

Unix helpers: [`.cursor/scripts/unix/README.md`](../.cursor/scripts/unix/README.md).

Profiles live in [`.agents/runtimes/`](runtimes/). Schema: [`.agents/schemas/environment.schema.json`](schemas/environment.schema.json).

## Writable paths

Same as AGENTS.md: **`.cursor/**`**, plus **`.agents/state/**`** for machine-local onboarding output. Root `README.md` / `AGENTS.md` only when the user asks.

## Non-Cursor runtimes

- **No hooks** — refresh snapshot manually: `jq-helpers.ps1 refresh_inject` or `unix/jq-helpers.sh refresh_inject`.
- **Rules** — read `.cursor/rules/*.mdc` as markdown guidance (not auto-injected).
- **OpenCode** — see [`.agents/adaptation/opencode.json.example`](adaptation/opencode.json.example).

Spec manifest: [`.agents/manifest.yaml`](manifest.yaml).
