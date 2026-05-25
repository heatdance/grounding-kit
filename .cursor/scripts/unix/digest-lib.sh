#!/usr/bin/env bash
# Shared digest builder for hooks and jq-helpers. Source from repo root context.
set -euo pipefail

DOCS_DIR="${DOCS_DIR:-.cursor/docs}"
MAX_BYTES="${MAX_BYTES:-5120}"
LOG="${DOCS_DIR}/log.json"
CURRENT="${DOCS_DIR}/current.json"
L0="${DOCS_DIR}/l0.json"
INTENT="${DOCS_DIR}/l1/intent.json"
MANIFEST="${DOCS_DIR}/manifest.json"
SNAPSHOT="${DOCS_DIR}/inject-snapshot.json"
SCRIPT_DIR="$(dirname "$0")"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

resolve_jq() {
  if command -v jq >/dev/null 2>&1; then command -v jq; return 0; fi
  local candidate pwsh_jq
  for candidate in \
    "${LOCALAPPDATA}/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe" \
    "/c/Users/${USERNAME}/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then printf '%s' "$candidate"; return 0; fi
  done
  if command -v powershell.exe >/dev/null 2>&1; then
    pwsh_jq=$(powershell.exe -NoProfile -Command "(Get-Command jq -ErrorAction SilentlyContinue).Source" 2>/dev/null | tr -d '\r')
    if [[ -n "$pwsh_jq" && -f "$pwsh_jq" ]]; then printf '%s' "$pwsh_jq"; return 0; fi
  fi
  return 1
}

JQ="${JQ:-$(resolve_jq 2>/dev/null || true)}"

get_doc_close_json() {
  bash "$SCRIPT_DIR/doc-close-status.sh" "$ROOT" 2>/dev/null || \
    printf '{"pending":false,"reasons":[],"hint":"jq-helpers set_last"}'
}

build_digest_json() {
  local doc_close
  doc_close=$(get_doc_close_json)
  if [[ -n "${JQ:-}" ]]; then
    "$JQ" -n \
      --slurpfile log "$LOG" \
      --slurpfile cur "$CURRENT" \
      --slurpfile l0 "$L0" \
      --slurpfile intent "$INTENT" \
      --slurpfile manifest "$MANIFEST" \
      --argjson docClose "$doc_close" \
      '{
        v: 1,
        generated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        note: "Refreshed by inject-context hook. Read at start of every turn.",
        actionOpen: ($intent[0].actionOpen // [
          "Read inject-snapshot.json first.",
          "State interpreted intent, evidence, confidence (low = no writes).",
          "INDEX then at most one l1 and one l2; log each to research[].",
          "Clarify if ambiguous; close Action with log.last and tiers."
        ]),
        docClose: $docClose,
        last: ($log[0].last // {}),
        research: (($log[0].research // []) | if length > 5 then .[-5:] else . end),
        current: $cur[0],
        l0: {
          loadPolicy: ($l0[0].loadPolicy // ""),
          anchors: ($l0[0].anchors // [])
        },
        manifest: {
          rules: (($manifest[0].rules // []) | length),
          skills: (($manifest[0].skills // []) | length),
          hooks: (($manifest[0].hooks // []) | length),
          scripts: (($manifest[0].scripts // []) | length)
        }
      }' 2>/dev/null || build_digest_fallback
  else
    build_digest_fallback
  fi
}

build_digest_fallback() {
  local log_part cur_part
  log_part=$(head -c 2048 "$LOG" 2>/dev/null || echo '{}')
  cur_part=$(head -c 1024 "$CURRENT" 2>/dev/null || echo '{}')
  printf '{"v":1,"note":"degraded-no-jq","last":%s,"current":%s,"docClose":{"pending":false,"reasons":[]}}\n' "$log_part" "$cur_part"
}

write_snapshot() {
  local json
  json=$(build_digest_json)
  mkdir -p "$DOCS_DIR"
  printf '%s\n' "$json" > "$SNAPSHOT"
  if [[ -n "${JQ:-}" && -f "$SNAPSHOT" ]]; then
    local bytes
    bytes=$(wc -c < "$SNAPSHOT" | tr -d ' ')
    if [[ "$bytes" -gt "$MAX_BYTES" ]]; then
      local doc_close
      doc_close=$(get_doc_close_json)
      "$JQ" -n \
        --slurpfile log "$LOG" \
        --slurpfile l0 "$L0" \
        --slurpfile intent "$INTENT" \
        --argjson docClose "$doc_close" \
        '{
          v: 1,
          generated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
          note: "trimmed for size cap",
          actionOpen: ($intent[0].actionOpen // []),
          docClose: $docClose,
          last: ($log[0].last // {}),
          research: (($log[0].research // []) | .[-3:]),
          l0: { loadPolicy: ($l0[0].loadPolicy // ""), anchors: ($l0[0].anchors // []) }
        }' > "$SNAPSHOT"
    fi
  fi
}

cap_context_string() {
  local s
  s=$(printf '%s' "$1" | head -c "$MAX_BYTES")
  printf '%s' "$s"
}

emit_additional_context() {
  local json compact
  write_snapshot
  json=$(cat "$SNAPSHOT")
  compact=$(cap_context_string "$json")
  if [[ -n "${JQ:-}" ]]; then
    "$JQ" -n --arg ctx "$compact" '{ "additional_context": $ctx }'
  else
    printf '{"additional_context":%s}\n' "$(printf '%s' "$compact" | sed 's/\\/\\\\/g; s/"/\\"/g; s/.*/"&"/')"
  fi
}
