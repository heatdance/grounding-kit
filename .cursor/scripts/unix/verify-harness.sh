#!/usr/bin/env bash
# Verify harness hygiene (Unix). Exit 0 = pass, 1 = fail.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
DOCS=".cursor/docs"
MAX_SNAPSHOT=5120
MAX_SESSIONS=10

pass=()
fail=()

ok() { pass+=("$1"); echo "OK  $1"; }
bad() { fail+=("$1"); echo "FAIL $1"; [[ -n "${2:-}" ]] && echo "     $2"; }

require_jq() {
  command -v jq >/dev/null 2>&1 || { bad "json_valid" "jq not installed"; return 1; }
}

# no_hook_sh
if find .cursor/hooks -maxdepth 1 -name '*.sh' 2>/dev/null | grep -q .; then
  bad "no_hook_sh" "remove .sh from .cursor/hooks/"
else ok "no_hook_sh"; fi

# no_duplicate_scripts
if find .cursor/scripts -maxdepth 1 -name '*.sh' 2>/dev/null | grep -q .; then
  bad "no_duplicate_scripts" "move .sh to .cursor/scripts/unix/"
else ok "no_duplicate_scripts"; fi

# hooks_json_ps1
if [[ -f .cursor/hooks.json ]]; then
  if grep -q 'powershell' .cursor/hooks.json && grep -q '\.ps1' .cursor/hooks.json \
     && ! grep -E '\.sh"' .cursor/hooks.json | grep -v '\.ps1' | grep -q '\.sh'; then
    ok "hooks_json_ps1"
  else
    bad "hooks_json_ps1" "hooks.json must use powershell + .ps1"
  fi
else bad "hooks_json_ps1" "missing hooks.json"; fi

# manifest_drift (hooks, root ps1, rules)
if [[ -f "$DOCS/manifest.json" ]]; then
  m_ok=true
  for f in .cursor/hooks/*.ps1; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f")
    jq -e --arg n "$b" '.hooks | index($n)' "$DOCS/manifest.json" >/dev/null 2>&1 || { bad "manifest_drift" "hooks/$b"; m_ok=false; }
  done
  for f in .cursor/scripts/*.ps1; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f")
    jq -e --arg n "$b" '.scripts | index($n)' "$DOCS/manifest.json" >/dev/null 2>&1 || { bad "manifest_drift" "scripts/$b"; m_ok=false; }
  done
  for f in .cursor/rules/*.mdc; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f")
    jq -e --arg n "$b" '.rules | index($n)' "$DOCS/manifest.json" >/dev/null 2>&1 || { bad "manifest_drift" "rules/$b"; m_ok=false; }
  done
  $m_ok && ok "manifest_drift"
else bad "manifest_drift" "missing manifest.json"; fi

# index_orphans
if [[ -f "$DOCS/INDEX.json" ]] && require_jq; then
  i_ok=true
  for f in "$DOCS"/l1/*.json "$DOCS"/l2/*.json; do
    [[ -f "$f" ]] || continue
    rel=${f#"$DOCS/"}
    if echo "$f" | grep -qE '-v2\.json$|-copy\.json$|-old\.json$|-backup\.json$|-new\.json$'; then
      bad "index_orphans" "banned name $rel"; i_ok=false; continue
    fi
    jq -e --arg p "$rel" '.anchors | to_entries[] | .value.path == $p' "$DOCS/INDEX.json" >/dev/null 2>&1 \
      || { bad "index_orphans" "$rel not in INDEX"; i_ok=false; }
  done
  $i_ok && ok "index_orphans"
else bad "index_orphans" "missing INDEX or jq"; fi

# json_valid
if require_jq; then
  j_ok=true
  for f in "$DOCS/log.json" "$DOCS/current.json" "$DOCS/l0.json" "$DOCS/INDEX.json" \
    "$DOCS/manifest.json" "$DOCS/environment.json" "$DOCS/inject-snapshot.json"; do
    [[ -f "$f" ]] || continue
    jq empty "$f" 2>/dev/null || { bad "json_valid" "$f"; j_ok=false; }
  done
  for f in "$DOCS"/l1/*.json "$DOCS"/l2/*.json; do
    [[ -f "$f" ]] || continue
    jq empty "$f" 2>/dev/null || { bad "json_valid" "$f"; j_ok=false; }
  done
  $j_ok && ok "json_valid"
fi

# snapshot_size
if [[ -f "$DOCS/inject-snapshot.json" ]]; then
  bytes=$(wc -c < "$DOCS/inject-snapshot.json" | tr -d ' ')
  if [[ "$bytes" -le "$MAX_SNAPSHOT" ]]; then ok "snapshot_size"; else bad "snapshot_size" "$bytes bytes"; fi
else bad "snapshot_size" "missing inject-snapshot.json"; fi

# snapshot_doc_close
if [[ -f "$DOCS/inject-snapshot.json" ]] && require_jq; then
  if jq -e '.docClose | type == "object" and (.pending | type) == "boolean"' "$DOCS/inject-snapshot.json" >/dev/null 2>&1; then
    ok "snapshot_doc_close"
  else
    bad "snapshot_doc_close" "inject-snapshot.json missing docClose.pending boolean"
  fi
elif [[ ! -f "$DOCS/inject-snapshot.json" ]]; then
  bad "snapshot_doc_close" "missing inject-snapshot.json"
fi

# sessions_cap
count=$(find "$DOCS/sessions" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${count:-0}" -le "$MAX_SESSIONS" ]]; then ok "sessions_cap"; else bad "sessions_cap" "$count files"; fi

# intent_rule_present
if [[ -f "$DOCS/manifest.json" ]] && jq -e '.rules | index("intent.mdc")' "$DOCS/manifest.json" >/dev/null 2>&1; then
  ok "intent_rule_present"
else
  bad "intent_rule_present" "intent.mdc not in manifest.rules"
fi

# index_intent
if [[ -f "$DOCS/INDEX.json" && -f "$DOCS/l1/intent.json" ]]; then
  ip=$(jq -r '.anchors.intent.path // empty' "$DOCS/INDEX.json")
  if [[ "$ip" == "l1/intent.json" ]]; then ok "index_intent"; else bad "index_intent" "wrong anchor path"; fi
else
  bad "index_intent" "INDEX or l1/intent.json missing"
fi

EXPECTED_BP_VERSION=1

# preservation_rule_present
if [[ -f "$DOCS/manifest.json" ]] && jq -e '.rules | index("preservation.mdc")' "$DOCS/manifest.json" >/dev/null 2>&1; then
  ok "preservation_rule_present"
else
  bad "preservation_rule_present" "preservation.mdc not in manifest.rules"
fi

# index_preservation
if [[ -f "$DOCS/INDEX.json" && -f "$DOCS/l1/preservation.json" ]]; then
  pp=$(jq -r '.anchors.preservation.path // empty' "$DOCS/INDEX.json")
  if [[ "$pp" == "l1/preservation.json" ]]; then ok "index_preservation"; else bad "index_preservation" "wrong anchor path"; fi
else
  bad "index_preservation" "INDEX or l1/preservation.json missing"
fi

# better_prompt_version
if require_jq && [[ -f "$DOCS/manifest.json" && -f "$DOCS/l1/operator-assist.json" ]]; then
  mv=$(jq -r '.betterPromptVersion // empty' "$DOCS/manifest.json")
  tv=$(jq -r '.betterPrompt.version // empty' "$DOCS/l1/operator-assist.json")
  if [[ "$mv" == "$EXPECTED_BP_VERSION" && "$tv" == "$EXPECTED_BP_VERSION" ]]; then
    ok "better_prompt_version"
  else
    bad "better_prompt_version" "manifest=$mv tier=$tv expected $EXPECTED_BP_VERSION"
  fi
fi

# better_prompt_golden_valid
if [[ -f "$DOCS/l2/better-prompt-golden.json" ]] && require_jq; then
  if jq empty "$DOCS/l2/better-prompt-golden.json" >/dev/null 2>&1; then
    ev=$(jq -r '.expectCoachVersion // empty' "$DOCS/l2/better-prompt-golden.json")
    cc=$(jq -r '(.cases | length) // 0' "$DOCS/l2/better-prompt-golden.json")
    gp=$(jq -r '.anchors."better-prompt-golden".path // empty' "$DOCS/INDEX.json")
    if [[ "$ev" == "$EXPECTED_BP_VERSION" && "$cc" -ge 1 && "$gp" == "l2/better-prompt-golden.json" ]]; then
      ok "better_prompt_golden_valid"
    else
      bad "better_prompt_golden_valid" "version/cases/INDEX mismatch"
    fi
  else
    bad "better_prompt_golden_valid" "invalid JSON"
  fi
else
  bad "better_prompt_golden_valid" "missing golden or jq"
fi

EXPECTED_BS_VERSION=1

# better_skill_version
if require_jq && [[ -f "$DOCS/manifest.json" && -f "$DOCS/l1/operator-assist.json" ]]; then
  mv=$(jq -r '.betterSkillVersion // empty' "$DOCS/manifest.json")
  tv=$(jq -r '.betterSkill.version // empty' "$DOCS/l1/operator-assist.json")
  if [[ "$mv" == "$EXPECTED_BS_VERSION" && "$tv" == "$EXPECTED_BS_VERSION" ]]; then
    ok "better_skill_version"
  else
    bad "better_skill_version" "manifest=$mv tier=$tv expected $EXPECTED_BS_VERSION"
  fi
fi

# better_skill_golden_valid
if [[ -f "$DOCS/l2/better-skill-golden.json" ]] && require_jq; then
  if jq empty "$DOCS/l2/better-skill-golden.json" >/dev/null 2>&1; then
    ev=$(jq -r '.expectCoachVersion // empty' "$DOCS/l2/better-skill-golden.json")
    cc=$(jq -r '(.cases | length) // 0' "$DOCS/l2/better-skill-golden.json")
    gp=$(jq -r '.anchors."better-skill-golden".path // empty' "$DOCS/INDEX.json")
    if [[ "$ev" == "$EXPECTED_BS_VERSION" && "$cc" -ge 1 && "$gp" == "l2/better-skill-golden.json" ]]; then
      ok "better_skill_golden_valid"
    else
      bad "better_skill_golden_valid" "version/cases/INDEX mismatch"
    fi
  else
    bad "better_skill_golden_valid" "invalid JSON"
  fi
else
  bad "better_skill_golden_valid" "missing golden or jq"
fi

# skill_authoring_patterns_valid
if [[ -f "$DOCS/l2/skill-authoring-patterns.json" ]] && require_jq; then
  if jq empty "$DOCS/l2/skill-authoring-patterns.json" >/dev/null 2>&1; then
    n=$(jq -r '[.rubrics.subagents.pattern,.rubrics.validation_done.pattern,.rubrics.verification_schema.pattern,.rubrics.iterative_subsets.pattern] | map(select(length>0)) | length' "$DOCS/l2/skill-authoring-patterns.json")
    if [[ "$n" == "4" ]]; then ok "skill_authoring_patterns_valid"; else bad "skill_authoring_patterns_valid" "rubrics incomplete"; fi
  else
    bad "skill_authoring_patterns_valid" "invalid JSON"
  fi
else
  bad "skill_authoring_patterns_valid" "missing patterns or jq"
fi

# karpathy_skill_present
if [[ -f "$DOCS/manifest.json" ]] && [[ -f ".cursor/skills/karpathy-guidelines/SKILL.md" ]] && require_jq; then
  if jq -e '.skills | index("karpathy-guidelines")' "$DOCS/manifest.json" >/dev/null 2>&1; then
    ok "karpathy_skill_present"
  else
    bad "karpathy_skill_present" "karpathy-guidelines missing from manifest.skills"
  fi
else
  bad "karpathy_skill_present" "missing manifest, SKILL.md, or jq"
fi

# karpathy_guidelines_tier_valid
if [[ -f "$DOCS/l2/karpathy-guidelines.json" ]] && require_jq; then
  if jq empty "$DOCS/l2/karpathy-guidelines.json" >/dev/null 2>&1; then
    v=$(jq -r '.v // empty' "$DOCS/l2/karpathy-guidelines.json")
    gp=$(jq -r '.anchors["karpathy-guidelines"].path // empty' "$DOCS/INDEX.json")
    if [[ "$v" == "1" && "$gp" == "l2/karpathy-guidelines.json" ]]; then
      ok "karpathy_guidelines_tier_valid"
    else
      bad "karpathy_guidelines_tier_valid" "v=$v INDEX=$gp"
    fi
  else
    bad "karpathy_guidelines_tier_valid" "invalid JSON"
  fi
else
  bad "karpathy_guidelines_tier_valid" "missing tier or jq"
fi

# distribution_baseline_valid
if [[ -f "$DOCS/l2/distribution-baseline.json" ]] && require_jq; then
  if jq empty "$DOCS/l2/distribution-baseline.json" >/dev/null 2>&1; then
    v=$(jq -r '.v // empty' "$DOCS/l2/distribution-baseline.json")
    gp=$(jq -r '.anchors["distribution-baseline"].path // empty' "$DOCS/INDEX.json")
    if [[ "$v" == "1" && "$gp" == "l2/distribution-baseline.json" ]] && \
       jq -e '.onboardingStatus.ok == false' "$DOCS/l2/distribution-baseline.json" >/dev/null 2>&1; then
      ok "distribution_baseline_valid"
    else
      bad "distribution_baseline_valid" "v=$v INDEX=$gp onboardingStatus"
    fi
  else
    bad "distribution_baseline_valid" "invalid JSON"
  fi
else
  bad "distribution_baseline_valid" "missing tier or jq"
fi

# research_recent
if require_jq && [[ -f "$DOCS/log.json" ]]; then
  st=$(jq -r '
    def ts(s): (s | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601);
    . as $l | ($l.last.when // "") as $lw |
    if $lw == "" then "ok"
    elif (ts($lw) < (now - 86400)) then "ok"
    else
      (($l.research // []) | length) as $n |
      if $n == 0 then "fail_empty"
      else if (ts($l.research[-1].when) >= (ts($lw) - 3600)) then "ok" else "fail_stale" end
    end
  ' "$DOCS/log.json" 2>/dev/null || echo "err")
  case "$st" in
    ok) ok "research_recent" ;;
    fail_empty) bad "research_recent" "recent log.last but research[] empty" ;;
    fail_stale) bad "research_recent" "newest research older than last Action" ;;
    *) bad "research_recent" "could not evaluate log.json" ;;
  esac
fi

# agents_bridge
[[ -f .agents/manifest.yaml ]] && ok "agents_manifest" || bad "agents_manifest" "missing .agents/manifest.yaml"
if [[ -f .agents/state/environment.json && -f "$DOCS/environment.json" ]] && require_jq; then
  a=$(jq -r '.runtime' .agents/state/environment.json)
  b=$(jq -r '.runtime' "$DOCS/environment.json")
  if [[ "$a" == "$b" ]]; then ok "agents_environment"; else bad "agents_environment" "runtime mismatch"; fi
else bad "agents_environment" "run onboarding first"; fi

echo ""
if [[ ${#fail[@]} -eq 0 ]]; then
  echo "OK: verify-harness passed (unix)"
  exit 0
fi
echo "VERIFY FAILED: ${fail[*]}"
exit 1
