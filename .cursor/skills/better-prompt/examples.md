# Better-prompt examples (max 5; replace in place)

## Vague — full mode

**Draft:** fix the app

**Coach shape:**

- Intent: restore or improve unspecified application behavior without target or symptom.
- Done: named test command exits 0; named file or API behavior matches stated expectation; operator can reproduce steps.
- Worth adding (top 2 rubric gaps): scope — which app or repo path? verification — what command proves fixed?
- Addendum (no invented paths): “Fix [symptom] in [area you name]. Done when [test/command] passes. Out of scope: [list].”

## Tight — minimal mode

**Draft:** run verify-harness.ps1 and fix any manifest_drift FAIL lines; re-run until exit 0

**Coach shape:** Ready to send.

## Harness-shaped — full mode

**Draft:** fix onboarding

**Coach shape:**

- Intent: align onboarding without naming runtime or last failure.
- Done: onboard script exits 0; status JSON `"ok": true`; operator steps match detected runtime.
- Worth adding: environment — which runtime? verification — what failed last run?
