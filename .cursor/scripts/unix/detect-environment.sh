#!/usr/bin/env bash
# Print detected runtime id (stdout). Used by onboard.sh and adapt-environment.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

if [[ -n "${AGENT_RUNTIME:-}" ]]; then
  printf '%s\n' "${AGENT_RUNTIME}"
  exit 0
fi

if [[ -n "${CURSOR_TRACE_ID:-}" || -n "${CURSOR_SESSION_ID:-}" || -n "${CURSOR_AGENT:-}" ]]; then
  printf '%s\n' "cursor"
  exit 0
fi

if [[ -n "${OPENCODE:-}" || -n "${OPENCODE_VERSION:-}" || -f opencode.json || -d .opencode ]]; then
  printf '%s\n' "opencode"
  exit 0
fi

if [[ -n "${CLAUDE_CODE:-}" ]]; then
  printf '%s\n' "claude-code"
  exit 0
fi

printf '%s\n' "generic"
