# Agent schema — agent workspace starter

Agents: follow this file and always-on rules under `.cursor/rules/`. Humans: read [README.md](README.md) only.

## Onboarding (once per machine)

After clone, run `/onboarding` or execute `.cursor/scripts/onboard.ps1` (Windows) / `.cursor/scripts/unix/onboard.sh` (Unix). Onboarding **detects your agent runtime** and writes [`.agents/state/environment.json`](.agents/state/environment.json) (mirror: [`.cursor/docs/environment.json`](.cursor/docs/environment.json)).

Force runtime before running onboard:

```bash
export AGENT_RUNTIME=opencode
bash .cursor/scripts/unix/onboard.sh
```

```powershell
$env:AGENT_RUNTIME = "opencode"
powershell -NoProfile -File .cursor/scripts/onboard.ps1
```

| Runtime | After onboarding |
|---------|------------------|
| **Cursor** | Reload IDE; hooks inject snapshot; read [`.cursor/hooks.json`](.cursor/hooks.json) (`powershell` + `*.ps1` only). **No `stop` hook** — check `docClose` in `inject-snapshot.json` instead of chat followups. |
| **OpenCode / other** | Read [`.agents/agents.md`](.agents/agents.md); **manually** read `inject-snapshot.json` each turn; optional [`opencode.json.example`](.agents/adaptation/opencode.json.example). |

Portable bridge: [`.agents/manifest.yaml`](.agents/manifest.yaml). Harness hygiene re-check: `.cursor/scripts/verify-harness.ps1` (also run automatically during `/onboarding`).

## Modes

| Mode | Description |
|------|-------------|
| **Workspace** | Open this repository. Writable paths: `.cursor/**` only. Root `README.md` / `AGENTS.md` only when the user explicitly asks. |
| **Embed** | Copy `.cursor/` into another repo. Same allowlist: all agent artifacts stay under `.cursor/`. |

## Action open (before first write)

1. Read [`.cursor/docs/inject-snapshot.json`](.cursor/docs/inject-snapshot.json) — use embedded **actionOpen** + `l0` anchors; if **docClose.pending**, run doc close before finishing.
2. State **interpreted intent**, tier **evidence**, **confidence** (high | medium | low). Tier detail: [`.cursor/docs/l1/intent.json`](.cursor/docs/l1/intent.json).
3. **Low** → Blocking + Questions only; no file writes until the user answers.
4. Progressive research + `log.research[]`; clarify if tiers leave ambiguity.

Optional helper: `.cursor/scripts/action-open.ps1` or `unix/action-open.sh` (prints checklist).

## Turn classification

Every user message:

1. Read `inject-snapshot.json` first (refreshed on Cursor each prompt; manual on other runtimes).
2. Classify **Conversation** vs **Action**.
   - **Conversation** — no durable file changes; do not update tiers, `log.json`, or `current.json`.
   - **Action** — any create/edit/delete under the allowlist; requires research + doc close below.

## Research before Action (progressive, logged)

Before the first write tool on an Action turn:

1. Use injected `l0` + `INDEX.json` anchors (jq or Read).
2. Log each step to `log.research[]` via `.cursor/scripts/jq-helpers.ps1 append_research` (Windows) or `.cursor/scripts/unix/jq-helpers.sh` (Unix).
3. If L0 insufficient → read **one** `l1/<id>.json`; log `result: deeper` or `answered`.
4. If still insufficient → read **one** `l2/<id>.json`; log again.
5. Do **not** load all of `l1/` or `l2/` in one turn unless the user says `more detail`.

Humans audit: `jq '.research[-10:]' .cursor/docs/log.json` (see README).

## Action close (mandatory)

After Action work:

1. Update `log.json` — `last` WWW (`what`, `when`, `why`, `mode`, `paths` including **deleted** paths); `jq-helpers.ps1 set_last` then `rotate_log`.
2. Overwrite `current.json` — `resume`, `next`, `anchors` (≤15 lines total).
3. Patch `INDEX.json` and every touched `l1`/`l2` JSON (overwrite in place; no `*-v2.json`).
4. Update [`.cursor/docs/manifest.json`](.cursor/docs/manifest.json) if hooks, scripts, rules, skills, or commands changed.
5. Validate: `jq empty` on edited JSON; optional `verify-harness.ps1`.
6. Work-tier chat line: `Mode: Action — updated: … deleted: …`

## Allowlist and naming

| Artifact | Path |
|----------|------|
| Rules | `.cursor/rules/*.mdc` |
| Skills | `.cursor/skills/<name>/SKILL.md` |
| L0 | `.cursor/docs/l0.json` |
| L1 topics | `.cursor/docs/l1/<kebab-case>.json` |
| L2 detail | `.cursor/docs/l2/<kebab-case>.json` |
| Log / current / index | `.cursor/docs/log.json`, `current.json`, `INDEX.json` |
| Sessions (cold) | `.cursor/docs/sessions/YYYY-MM-DD-slug.json` |
| Harness templates | `.cursor/harness/<stack>/` |

**Banned:** new dirs/files at repo root; duplicate topic files; speculative doc forks.

## Injected context

- **Cursor:** hooks run via **PowerShell** (`.cursor/hooks.json` → `*.ps1`). **sessionStart** adds `additional_context`; **beforeSubmitPrompt** refreshes `inject-snapshot.json` (includes **docClose** heuristics; no **stop** hook).
- **Non-Cursor:** no hooks — read [`.cursor/docs/inject-snapshot.json`](.cursor/docs/inject-snapshot.json) every turn; refresh with `jq-helpers.ps1 refresh_inject` or `unix/jq-helpers.sh refresh_inject` when stale.
- Read [`.agents/state/environment.json`](.agents/state/environment.json) for capability flags (`capabilities.injectSnapshot`, etc.).

Do not reload the full tier tree; use anchors and at most two extra JSON files per Action.

## Canonical jq (run from repo root)

**Unix / macOS / Linux:**

```bash
jq -r '.anchors.workspace.path' .cursor/docs/INDEX.json
jq '.anchors' .cursor/docs/l0.json
jq '{ last, research: .research[-5:] }' .cursor/docs/log.json
jq '.capabilities' .agents/state/environment.json

.cursor/scripts/unix/jq-helpers.sh append_research L0 workspace answered jq
.cursor/scripts/unix/jq-helpers.sh set_last "What" "Why" action ".cursor/docs/log.json"
.cursor/scripts/unix/jq-helpers.sh rotate_log
.cursor/scripts/unix/jq-helpers.sh refresh_inject

jq empty .cursor/docs/log.json
```

**Windows (PowerShell):**

```powershell
powershell -NoProfile -File .cursor/scripts/jq-helpers.ps1 append_research L0 workspace answered jq
powershell -NoProfile -File .cursor/scripts/jq-helpers.ps1 set_last "What" "Why" action ".cursor/docs/log.json"
```

Unix script reference: [`.cursor/scripts/unix/README.md`](.cursor/scripts/unix/README.md).

## Tier map

| Tier | File(s) | Role |
|------|---------|------|
| L0 | `l0.json` | Manifest, load policy, anchor list |
| L1 | `l1/*.json` | Topic summaries |
| L2 | `l2/*.json` | Depth / structure / harness detail |
| Sessions | `sessions/*.json` | Optional full handoffs (not injected) |

## Multi-runtime bridge

- Portable entry: [`.agents/agents.md`](.agents/agents.md) — use when the tool does not load `.cursor/rules` automatically.
- L1 detail: [`.cursor/docs/l1/runtimes.json`](.cursor/docs/l1/runtimes.json)
- Profiles: [`.agents/runtimes/`](.agents/runtimes/) — detection signals and operator steps per tool.

## Harness hygiene

- Canonical file list: [`.cursor/docs/manifest.json`](.cursor/docs/manifest.json)
- Always-on: [`.cursor/rules/hygiene.mdc`](.cursor/rules/hygiene.mdc) — overwrite tiers, retire duplicates, sync docs in the same Action

## Intent and clarify-before-implement

- `.cursor/rules/intent.mdc` — interpret intent, tier evidence, confidence gates (**low** = no writes until user answers)
- `.cursor/rules/communication.mdc` — **Blocking** / **Questions** / **Context** layout for clarifications
- `.cursor/skills/agent-intent/` — checklist and bad/good examples

## Operator assist

- `/better-prompt` — Conversation-only prompt coaching (v1 rubric: top 2 gaps, testable done bullets); see [`.cursor/commands/better-prompt.md`](.cursor/commands/better-prompt.md).
- `/better-skill` — Conversation-only harness-doc coaching (pipelines, commands, skills; four fixed rubrics, Good to go allowed); see [`.cursor/commands/better-skill.md`](.cursor/commands/better-skill.md).
- Tier: [`.cursor/docs/l1/operator-assist.json`](.cursor/docs/l1/operator-assist.json). Golden: [`.cursor/docs/l2/better-skill-golden.json`](.cursor/docs/l2/better-skill-golden.json).
- `.cursor/rules/delegation.mdc` — read-only subagent exploration when scope is wide; parent keeps edits and verification.

## Optional skills (not shipped core)

- **karpathy-guidelines** — Opt-in coding discipline for application/test code and harness stack templates; see [`.cursor/skills/karpathy-guidelines/SKILL.md`](.cursor/skills/karpathy-guidelines/SKILL.md) and [`.cursor/docs/l2/karpathy-guidelines.json`](.cursor/docs/l2/karpathy-guidelines.json). Not in preservation shipped-core lists. For always-on in an embed target repo, copy upstream [`.cursor/rules/karpathy-guidelines.mdc`](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/.cursor/rules/karpathy-guidelines.mdc) per [CURSOR.md](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CURSOR.md).

## Shipped core (preservation)

- Always-on rules, hook/inject protocol, manifest canonical lists, and slash-command **behavior** are frozen by default — see [`.cursor/rules/preservation.mdc`](.cursor/rules/preservation.mdc) and [`.cursor/docs/l1/preservation.json`](.cursor/docs/l1/preservation.json).
- Task work and doc sync are fine; weakening gates, auto-learning coaches, or ad-hoc rule edits require explicit operator entrust (e.g. “change harness behavior”).
- Maintainer regression: [`.cursor/docs/l2/better-prompt-golden.json`](.cursor/docs/l2/better-prompt-golden.json), [`.cursor/docs/l2/better-skill-golden.json`](.cursor/docs/l2/better-skill-golden.json); `verify-harness` checks coach versions and golden JSON.

## Related rules and skills

- `.cursor/rules/communication.mdc` — chat voice and human-facing prose (README, command intros)
- `.cursor/rules/structure.mdc` — path allowlist
- `.cursor/rules/documentation.mdc` — turn class + doc duty
- `.cursor/rules/hygiene.mdc` — delete/retire + manifest sync
- `.cursor/rules/intent.mdc` — grounding and anti whack-a-mole
- `.cursor/rules/delegation.mdc` — explore-wide / edit-narrow subagent use
- `.cursor/rules/preservation.mdc` — shipped core scope guard
- `.cursor/skills/doc-maintenance/` — jq patch recipes
- `.cursor/skills/agent-intent/` — intent gate on Action turns
- `.cursor/skills/better-prompt/` — `/better-prompt` coaching template
- `.cursor/skills/better-skill/` — `/better-skill` harness-doc coaching template
- `.cursor/skills/karpathy-guidelines/` — opt-in Karpathy coding guidelines for app/test code
