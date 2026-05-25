---
name: doc-maintenance
description: >-
  Maintains tiered JSON documentation under .cursor/docs/ — log WWW, research
  trail, INDEX/l1/l2 patches via jq. Use on Action turns, when updating docs,
  log.json, current.json, or when the user asks about documentation harness.
---

# Doc maintenance

Rules: [documentation.mdc](../../rules/documentation.mdc), [hygiene.mdc](../../rules/hygiene.mdc). Schema: [AGENTS.md](../../../AGENTS.md). Canonical file list: `.cursor/docs/manifest.json`.

## Artifact → tier

| Change | Update |
|--------|--------|
| New/changed rule | `.cursor/rules/<name>.mdc` + `manifest.json` + `l2/structure.json` if conventions change |
| New/changed skill | `.cursor/skills/<name>/` + `manifest.json` + optional `l1/<topic>.json` |
| New hook/script | Listed path in `manifest.json`; no orphan `.sh` in hooks |
| Topic knowledge | `.cursor/docs/l1/<kebab-case>.json` + `INDEX.json` anchor |
| Deep detail | `.cursor/docs/l2/<kebab-case>.json` + `INDEX.json` |
| Retire feature | Delete file, remove `INDEX` anchor, update `manifest.json` if listed |
| Session handoff (cold) | `.cursor/docs/sessions/YYYY-MM-DD-slug.json` |
| Every Action close | `log.json`, `current.json` |

## jq-helpers (repo root)

**Windows (canonical):**

```powershell
.cursor/scripts/jq-helpers.ps1 append_research L1 workspace answered jq
.cursor/scripts/jq-helpers.ps1 set_last "Added doc rule" "Harness hygiene" action ".cursor/rules/hygiene.mdc"
.cursor/scripts/jq-helpers.ps1 rotate_log
.cursor/scripts/jq-helpers.ps1 refresh_inject
```

**Unix (macOS / Linux / Git Bash):**

```bash
.cursor/scripts/unix/jq-helpers.sh append_research L1 workspace answered jq
.cursor/scripts/unix/jq-helpers.sh set_last "Added doc rule" "Harness hygiene" action ".cursor/rules/hygiene.mdc"
.cursor/scripts/unix/jq-helpers.sh rotate_log
.cursor/scripts/unix/jq-helpers.sh refresh_inject
```

Onboarding and environment adapt: [`.cursor/scripts/unix/README.md`](../../scripts/unix/README.md).

## Patch INDEX anchor (example)

```bash
jq '.anchors["my-topic"] = {"tier":"L1","path":"l1/my-topic.json","summary":"One line"}' \
  .cursor/docs/INDEX.json > .cursor/docs/INDEX.json.tmp && \
  mv .cursor/docs/INDEX.json.tmp .cursor/docs/INDEX.json
```

## Bad vs good

**Bad:** Action that edits files but leaves `log.research` empty and `log.last.when` stale.

**Good:** Two `research` entries (L0 answered, L1 deeper), then writes, then `set_last` + `current.json` + `rotate_log`.

**Bad:** Create `topic-v2.json` instead of overwriting `topic.json`.

**Good:** Edit `l1/topic.json` in place; remove obsolete anchor from `INDEX.json`.

**Bad:** Add `hooks/foo.sh` or leave duplicate `scripts/foo.sh` + `foo.ps1` in `scripts/` root.

**Good:** Only `hooks/*.ps1`; Unix scripts under `scripts/unix/`; update `manifest.json` in the same Action.

**Bad:** Read every file in `l1/` and `l2/` before a one-line fix.

**Good:** Injected snapshot + `l0.json` + one `l1` file when needed.

## Audit grounding (operators)

After an Action, `log.research[]` should show tier steps; `last.when` should be recent.

```bash
jq '.research[-10:]' .cursor/docs/log.json
jq '.last' .cursor/docs/log.json
```

```powershell
.cursor/scripts/query-log.ps1 research-recent
```

If research is empty but files under `.cursor/` changed, the agent skipped the intent ritual — see `l1/intent.json`.

## Validate

```powershell
.cursor/scripts/verify-harness.ps1
bash .cursor/scripts/unix/verify-harness.sh
jq empty .cursor/docs/log.json
jq empty .cursor/docs/INDEX.json
```
