#!/usr/bin/env bash
# Compute docClose JSON for inject-snapshot. Run from repository root.
set -euo pipefail

ROOT="$(cd "${1:-.}" && pwd)"
DOCS="$ROOT/.cursor/docs"
LOG="$DOCS/log.json"
INDEX="$DOCS/INDEX.json"
MANIFEST="$DOCS/manifest.json"
SESSION="$DOCS/session-state.json"
HINT="jq-helpers.ps1 set_last; unix/jq-helpers.sh set_last; append_research if Action touched .cursor/"

file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

if [[ ! -f "$LOG" ]]; then
  printf '{"pending":false,"reasons":[],"hint":"%s"}' "$HINT"
  exit 0
fi

if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    Set-Location '$ROOT'
    . '.cursor/scripts/Get-DocCloseStatus.ps1'
    (Get-DocCloseStatus -Root '$ROOT') | ConvertTo-Json -Compress
  " 2>/dev/null | tr -d '\r\n'
  exit 0
fi

reasons=()
now=$(date +%s)
log_m=$(file_mtime "$LOG")

if (( now - log_m >= 7200 )); then reasons+=("logStale"); fi

for f in "$INDEX" "$MANIFEST"; do
  [[ -f "$f" ]] || continue
  if (( $(file_mtime "$f") > log_m )); then reasons+=("tierNewer"); break; fi
done

has_edits=0
if [[ -f "$SESSION" ]] && command -v jq >/dev/null 2>&1; then
  has_edits=$(jq '(.editsThisSession // []) | length' "$SESSION" 2>/dev/null || echo 0)
fi

cursor_touched=0
if (( has_edits > 0 )); then
  cutoff=$((now - 7200))
  while IFS= read -r -d '' fp; do
    fm=$(file_mtime "$fp")
    if (( fm > cutoff && fm > log_m )); then cursor_touched=1; break; fi
  done < <(find "$ROOT/.cursor" -type f -print0 2>/dev/null || true)
  if (( cursor_touched )); then reasons+=("cursorTouched"); fi
fi

if command -v jq >/dev/null 2>&1; then
  rw=$(jq -r '
    def ts(s): (s | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601);
    . as $l |
    (if (($l.research // []) | length) == 0 and ($l.last.when // "") != "" and (ts($l.last.when) > (now - 7200))
     then "weak" else "" end),
    (if (($l.research // []) | length) > 0 and ($l.last.when // "") != ""
      and (ts($l.research[-1].when) < (ts($l.last.when) - 3600))
     then "weak" else "" end)
  ' "$LOG" 2>/dev/null || echo "")
  if [[ "$rw" == *weak* ]] && (( cursor_touched || has_edits > 0 )); then reasons+=("researchWeak"); fi

  if [[ -f "$SESSION" ]]; then
    whack=$(jq -r '
      (.attempts // []) as $a |
      if ($a | length) < 3 then ""
      else
        ($a[-3].hypothesis) as $h |
        if ([$a[-3], $a[-2], $a[-1]] | map(.hypothesis == $h) | all) then "whack" else "" end
      end
    ' "$SESSION" 2>/dev/null || echo "")
    [[ "$whack" == "whack" ]] && reasons+=("whackAMole")
  fi
fi

if command -v jq >/dev/null 2>&1; then
  jq -n --arg hint "$HINT" --argjson r "$(printf '%s\n' "${reasons[@]}" | jq -R . | jq -s .)" \
    '{ pending: ($r | length > 0), reasons: $r, hint: $hint }'
else
  pending=false
  [[ ${#reasons[@]} -gt 0 ]] && pending=true
  printf '{"pending":%s,"reasons":[],"hint":"%s"}' "$pending" "$HINT"
fi
