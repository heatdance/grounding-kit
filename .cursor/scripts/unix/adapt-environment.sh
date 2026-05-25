#!/usr/bin/env bash
# Write .agents/state/environment.json and .cursor/docs/environment.json (Unix-native).
# Usage: adapt-environment.sh [runtime_id]   (default: detect-environment.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
UNIX_DIR="$(dirname "$0")"
DOCS=".cursor/docs"
STATE_DIR=".agents/state"
ONBOARD_OK="${ONBOARD_OK:-true}"

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for adapt-environment.sh" >&2
    exit 1
  fi
}

require_jq

RUNTIME="${1:-}"
if [[ -z "$RUNTIME" ]]; then
  RUNTIME="$("$UNIX_DIR/detect-environment.sh")"
fi

PROFILE=".agents/runtimes/${RUNTIME}.json"
if [[ ! -f "$PROFILE" ]]; then
  RUNTIME=generic
  PROFILE=".agents/runtimes/generic.json"
fi

WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$STATE_DIR"

METHOD=detect
if [[ -n "${AGENT_RUNTIME:-}" ]]; then
  METHOD=override
fi

if [[ "${ONBOARD_OK}" == "true" ]]; then OB_JSON=true; else OB_JSON=false; fi

# Build environment JSON from runtime profile + onboarding flags
jq -n \
  --arg when "$WHEN" \
  --arg runtime "$RUNTIME" \
  --arg method "$METHOD" \
  --argjson profile "$(cat "$PROFILE")" \
  --argjson onboardOk "$OB_JSON" \
  --arg statusPath ".cursor/docs/onboarding-status.json" \
  '{
    v: 1,
    runtime: $runtime,
    label: $profile.label,
    detectedAt: $when,
    detection: {
      method: $method,
      signals: [],
      override: (if $method == "override" then $runtime else null end)
    },
    capabilities: $profile.capabilities,
    entryPoints: $profile.entryPoints,
    onboarding: {
      ok: $onboardOk,
      statusPath: $statusPath,
      operatorSteps: $profile.operatorSteps
    },
    adaptation: {
      notesPath: (".agents/state/adaptation-" + $runtime + ".md"),
      exampleConfig: ($profile.adaptation.exampleConfig // null)
    }
  }' > "$STATE_DIR/environment.json"

cp "$STATE_DIR/environment.json" "$DOCS/environment.json"

# Human-readable notes
NOTES="$STATE_DIR/adaptation-${RUNTIME}.md"
{
  echo "# Adaptation notes ($RUNTIME)"
  echo ""
  echo "Generated: $WHEN"
  echo ""
  echo "## Operator steps"
  jq -r '.operatorSteps[] | "- \(.)"' "$PROFILE"
  echo ""
  ex="$(jq -r '.adaptation.exampleConfig // empty' "$PROFILE")"
  if [[ -n "$ex" ]]; then
    echo "Example config: $ex"
  fi
} > "$NOTES"

echo "OK: adapted for runtime $RUNTIME"
echo "     $STATE_DIR/environment.json"
