#!/usr/bin/env bash
# One-time workspace bootstrap (macOS/Linux). Hook smoke tests require onboard.ps1 on Windows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
DOCS=".cursor/docs"
STATUS="$DOCS/onboarding-status.json"
MAX_SNAPSHOT=5120
UNIX_DIR=".cursor/scripts/unix"

pass=()
fail=()

step() { echo ">> $*"; }
ok() { pass+=("$1"); echo "OK  $1"; }
bad() { fail+=("$1"); echo "FAIL $1"; [[ -n "${2:-}" ]] && echo "     $2"; }

# shellcheck source=digest-lib.sh
source "$UNIX_DIR/digest-lib.sh" 2>/dev/null || true

step "Checking jq"
if [[ -z "${JQ:-}" ]]; then
  if command -v jq >/dev/null 2>&1; then JQ="$(command -v jq)"; fi
fi
if [[ -n "${JQ:-}" ]]; then
  ok "jq"
  JQ_VER="$("$JQ" --version 2>&1)"
else
  bad "jq" "Install jq (see README.md): brew install jq / apt install jq"
fi

step "Detecting agent runtime"
RUNTIME="${AGENT_RUNTIME:-}"
if [[ -z "$RUNTIME" ]]; then
  if [[ -n "${CURSOR_TRACE_ID:-}" || -n "${CURSOR_SESSION_ID:-}" ]]; then RUNTIME=cursor
  elif [[ -n "${OPENCODE:-}" || -n "${OPENCODE_VERSION:-}" || -f opencode.json || -d .opencode ]]; then RUNTIME=opencode
  elif [[ -n "${CLAUDE_CODE:-}" ]]; then RUNTIME=claude-code
  else RUNTIME=generic
  fi
fi
ok "detect_runtime"
echo "     Runtime: $RUNTIME"

step "Auditing .cursor/hooks.json"
hooks_ok=true
if [[ ! -f .cursor/hooks.json ]]; then
  bad "hooks.json" "missing file"
  hooks_ok=false
else
  if grep -E '\.sh"' .cursor/hooks.json 2>/dev/null | grep -v '\.ps1' | grep -q '\.sh'; then
    bad "hooks_no_sh" "hooks.json must not invoke bare .sh (use PowerShell -File .ps1 on Windows)"
    hooks_ok=false
  fi
  if ! grep -q 'powershell' .cursor/hooks.json || ! grep -q '\.ps1' .cursor/hooks.json; then
    bad "hooks_use_powershell" "hooks.json should use powershell -File .cursor/hooks/*.ps1"
    hooks_ok=false
  fi
  hook_sh_count=$(find .cursor/hooks -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${hook_sh_count:-0}" -gt 0 ]]; then
    bad "no_hook_sh" "Remove .sh files from .cursor/hooks/"
    hooks_ok=false
  fi
  if $hooks_ok; then
    ok "hooks.json"
    ok "hooks_use_powershell"
    ok "hooks_no_sh"
    ok "no_hook_sh"
  fi
fi

step "Validating tier JSON"
json_ok=true
for f in \
  "$DOCS/log.json" \
  "$DOCS/current.json" \
  "$DOCS/l0.json" \
  "$DOCS/INDEX.json" \
  "$DOCS/manifest.json" \
  "$DOCS/environment.json" \
  "$DOCS/l1/workspace.json" \
  "$DOCS/l1/runtimes.json" \
  "$DOCS/l1/intent.json" \
  "$DOCS/l2/structure.json"; do
  if [[ -z "${JQ:-}" ]]; then json_ok=false; break; fi
  if ! "$JQ" empty "$f" 2>/dev/null; then
    bad "json_valid" "invalid: $f"
    json_ok=false
  fi
done
if $json_ok && [[ -n "${JQ:-}" ]]; then ok "json_valid"; fi

step "Refreshing inject-snapshot.json"
bytes=0
if [[ -f "$UNIX_DIR/digest-lib.sh" ]]; then
  # shellcheck source=digest-lib.sh
  source "$UNIX_DIR/digest-lib.sh"
  write_snapshot || true
fi
if [[ -f "$DOCS/inject-snapshot.json" ]]; then
  bytes=$(wc -c < "$DOCS/inject-snapshot.json" | tr -d ' ')
  if [[ "$bytes" -le "$MAX_SNAPSHOT" ]]; then
    ok "snapshot_refresh"
    ok "snapshot_size"
  else
    bad "snapshot_size" "$bytes bytes (max $MAX_SNAPSHOT)"
  fi
else
  bad "snapshot_refresh" "missing inject-snapshot.json"
fi

step "Hook smoke (skipped on Unix)"
echo "     Full hook smoke runs on Windows via onboard.ps1"
echo "     Ensure .cursor/hooks.json uses PowerShell -File *.ps1 when using Cursor on Windows"

# Adapt before verify (environment.json required by verify)
if [[ ${#fail[@]} -eq 0 ]]; then
  step "Adapting repository for runtime: $RUNTIME"
  export AGENT_RUNTIME="$RUNTIME"
  export ONBOARD_OK=true
  if bash "$UNIX_DIR/adapt-environment.sh" "$RUNTIME"; then
    ok "adapt_environment"
  else
    bad "adapt_environment" "adapt-environment.sh failed"
  fi
fi

if [[ ${#fail[@]} -eq 0 ]]; then
  step "Running verify-harness.sh"
  if bash "$UNIX_DIR/verify-harness.sh"; then
    ok "verify_harness"
  else
    bad "verify_harness" "verify-harness.sh failed"
  fi
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OK=true
[[ ${#fail[@]} -gt 0 ]] && OK=false

if [[ ${#pass[@]} -gt 0 ]]; then
  checks_passed_json=$(printf '%s\n' "${pass[@]}" | "$JQ" -R . | "$JQ" -s .)
else
  checks_passed_json='[]'
fi
if [[ ${#fail[@]} -gt 0 ]]; then
  checks_failed_json=$(printf '%s\n' "${fail[@]}" | "$JQ" -R . | "$JQ" -s .)
else
  checks_failed_json='[]'
fi

if [[ -n "${JQ:-}" ]]; then
  if $OK; then ok_json=true; else ok_json=false; fi
  "$JQ" -n \
    --arg when "$WHEN" \
    --argjson ok "$ok_json" \
    --arg jqver "${JQ_VER:-}" \
    --argjson passed "$checks_passed_json" \
    --argjson failed "$checks_failed_json" \
    --argjson snap "${bytes:-0}" \
    '{
      v: 1,
      ok: $ok,
      when: $when,
      jq: { installed: true, version: $jqver },
      hooks: { usePowerShell: true, noShInHooksJson: true, note: "smoke tests on Windows only" },
      snapshotBytes: ($snap | tonumber),
      checksPassed: $passed,
      checksFailed: $failed
    }' > "$STATUS"
fi

if $OK && [[ -n "${JQ:-}" ]]; then
  WHEN="$WHEN" "$JQ" \
    --arg when "$WHEN" \
    --arg what "Onboarding completed" \
    --arg why "Bootstrap jq and doc harness (Unix entry)" \
    --arg mode "action" \
    '.last = {when: $when, what: $what, why: $why, mode: $mode, paths: [".cursor/scripts/unix/onboard.sh"]}' \
    "$DOCS/log.json" > "$DOCS/log.json.tmp" && mv "$DOCS/log.json.tmp" "$DOCS/log.json"
  case "$RUNTIME" in
    cursor) RESUME="Onboarding complete (Unix). For hook smoke run onboard.ps1 on Windows; reload Cursor." ;;
    opencode) RESUME="Onboarding complete (OpenCode). Read .agents/agents.md each session." ;;
    *) RESUME="Onboarding complete ($RUNTIME). Read .agents/state/environment.json for steps." ;;
  esac
  "$JQ" -n \
    --arg resume "$RESUME" \
    --arg next "Read inject-snapshot.json each turn; see .agents/state/environment.json" \
    '{resume: $resume, next: $next, anchors: ["workspace","structure","runtimes"]}' \
    > "$DOCS/current.json"
  write_snapshot 2>/dev/null || true
  echo ""
  echo "OK: onboarding complete"
  echo "     Runtime: $RUNTIME"
  echo "     Status: $STATUS"
  echo "     Environment: .agents/state/environment.json"
  exit 0
fi

echo ""
echo "ONBOARDING FAILED"
echo "     Failed: ${fail[*]}"
exit 1
