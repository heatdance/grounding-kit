#!/usr/bin/env bash
# Doc harness jq utilities. Run from repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
DOCS=".cursor/docs"
LOG="$DOCS/log.json"
SCRIPT_DIR="$(dirname "$0")"
# shellcheck source=digest-lib.sh
source "$SCRIPT_DIR/digest-lib.sh" 2>/dev/null || true
[[ -z "${JQ:-}" ]] && [[ -f "$SCRIPT_DIR/digest-lib.sh" ]] && source "$SCRIPT_DIR/digest-lib.sh"

require_jq() {
  if [[ -z "${JQ:-}" ]]; then
    # shellcheck source=digest-lib.sh
    source "$SCRIPT_DIR/digest-lib.sh"
  fi
  [[ -n "${JQ:-}" ]] || {
    echo "jq is required for this command. Install jq — see README.md." >&2
    exit 1
  }
}

cmd="${1:-}"
shift || true

case "$cmd" in
  append_research)
    require_jq
    tier="${1:?tier}"; anchor="${2:?anchor}"; result="${3:?result}"; via="${4:-jq}"
    when="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    tmp=$(mktemp)
    "$JQ" --arg when "$when" --arg tier "$tier" --arg anchor "$anchor" --arg via "$via" --arg result "$result" \
      '.research += [{when: $when, tier: $tier, anchor: $anchor, via: $via, result: $result}]' \
      "$LOG" > "$tmp" && mv "$tmp" "$LOG"
    "$SCRIPT_DIR/jq-helpers.sh" rotate_log
    ;;
  set_last)
    require_jq
    what="${1:?what}"; why="${2:?why}"; mode="${3:-action}"
    shift 3 || true
    if [[ $# -gt 0 ]]; then
      paths_json=$(printf '%s\n' "$@" | "$JQ" -R . | "$JQ" -s .)
    else
      paths_json='[]'
    fi
    when="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    tmp=$(mktemp)
    "$JQ" --arg when "$when" --arg what "$what" --arg why "$why" --arg mode "$mode" --argjson paths "$paths_json" \
      '.last = {when: $when, what: $what, why: $why, mode: $mode, paths: $paths}' \
      "$LOG" > "$tmp" && mv "$tmp" "$LOG"
    ;;
  rotate_log)
    require_jq
    tmp=$(mktemp)
    "$JQ" '.research = ((.research // []) | if length > 20 then .[-20:] else . end)
      | .history = ((.history // []) + [(.last // {})] | if length > 10 then .[-10:] else . end)' \
      "$LOG" > "$tmp" && mv "$tmp" "$LOG"
    ;;
  refresh_inject)
    write_snapshot
    echo "Updated $SNAPSHOT"
    ;;
  *)
    echo "Usage: jq-helpers.sh append_research|set_last|rotate_log|refresh_inject" >&2
    exit 1
    ;;
esac
