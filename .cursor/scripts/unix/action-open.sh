#!/usr/bin/env bash
# Print Action-open checklist; optionally stub log.research.
# Usage: action-open.sh [anchor] [--stub]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
ANCHOR="${1:-intent}"
STUB=false
[[ "${2:-}" == "--stub" ]] && STUB=true

INTENT=".cursor/docs/l1/intent.json"
echo "=== Action open ==="
if [[ -f "$INTENT" ]] && command -v jq >/dev/null 2>&1; then
  jq -r '.actionOpen[] | "  - \(.)"' "$INTENT"
else
  echo "  - Read inject-snapshot.json"
  echo "  - Intent + evidence + confidence (low = no writes)"
  echo "  - INDEX -> one l1 -> one l2; log research[]"
fi
echo ""
echo "Anchor hint: $ANCHOR (see INDEX.json)"

if $STUB && command -v jq >/dev/null 2>&1; then
  "$(dirname "$0")/jq-helpers.sh" append_research L1 "$ANCHOR" answered action-open
  echo "OK: appended research stub for $ANCHOR"
fi
