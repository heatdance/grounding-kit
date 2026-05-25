# Onboarding (any agent runtime)

Execute onboarding from the **repository root**. Do not skip terminal steps.

## 1. Detect or accept runtime

- Read `.agents/runtimes/*.json` and `.agents/manifest.yaml`.
- If the operator set `AGENT_RUNTIME`, use that value (`cursor`, `opencode`, `claude-code`, `generic`).
- Otherwise let the onboard script auto-detect.

## 2. Run the bootstrap script

| OS | Command |
|----|---------|
| Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1` |
| Unix | `bash .cursor/scripts/unix/onboard.sh` |

Unix details: `.cursor/scripts/unix/README.md` (jq-helpers, detect/adapt, `AGENT_RUNTIME`).

## 3. Confirm outputs

| File | Purpose |
|------|---------|
| `.cursor/docs/onboarding-status.json` | Pass/fail checks (`ok: true`) |
| `.agents/state/environment.json` | Runtime profile + operator steps |
| `.cursor/docs/environment.json` | Mirror for tier docs / agents |

## 4. Tell the operator

- **Cursor:** reload IDE; new Agent chat; hooks inject snapshot.
- **OpenCode / other:** read `environment.json` → `onboarding.operatorSteps`; no hook reload.
- **Failure:** read `checksFailed` in onboarding-status; run `verify-harness.ps1` on Windows.

## 5. Agent duties after onboarding

Read `inject-snapshot.json` every turn. On Action close, update `log.json`, `current.json`, tiers, and `manifest.json` if harness files changed (see `hygiene.mdc`).
