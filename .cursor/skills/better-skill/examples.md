# Better-skill examples (max 5; replace in place)

## Pipeline stub — Needs work

**Draft:** Short pipeline with “generate coverage” and no phases, no verifier, no temp/ lifecycle.

**Scorecard (illustrative):**

- subagents: gap — no per-slice orchestration
- validation_done: gap — no STOP or verifier exit 0
- verification_schema: gap — no schema_version on output
- iterative_subsets: gap — one-shot emit implied

**Improvements (max 2):** Add phased orchestration + delete `temp/` before complete; add verifier or `validation_log` gate before finish.

## Tight command — minimal / Ready to send

**Draft:** Run `verify-harness.ps1` from repo root; on FAIL fix manifest drift; re-run until exit 0. On success / On failure sections present.

**Scorecard:**

- subagents: not_applicable — single command, no fan-out
- validation_done: satisfied — exit 0 named
- verification_schema: not_applicable — no durable pipeline JSON
- iterative_subsets: not_applicable — atomic command

**Verdict:** Ready to send.

## Orchestration pipeline — Good to go

**Draft:** Phases 0–N, prerequisite table, MUST NOT one-shot, `{EpicDir}temp/` deleted before complete, subprocess per heavy slice, `*_verify.py` exit 0 in final phase.

**Scorecard:** all applicable rubrics satisfied.

**Verdict:** Good to go.
