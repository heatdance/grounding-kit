# Verify harness hygiene. Run from repo root.
# Exit 0 = pass, 1 = fail
$ErrorActionPreference = "Continue"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$DocsDir = ".cursor/docs"
$MaxSnapshot = 5120
$MaxSessions = 10
$ExpectedBetterPromptVersion = 1
$ExpectedBetterSkillVersion = 1
$BannedNamePattern = '-v2\.json$|-copy\.json$|-old\.json$|-backup\.json$|-new\.json$'

$passed = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

function Pass([string]$n) { $script:passed.Add($n); Write-Host "OK  $n" -ForegroundColor Green }
function Fail([string]$n, [string]$d) {
    $script:failed.Add($n)
    Write-Host "FAIL $n" -ForegroundColor Red
    if ($d) { Write-Host "     $d" -ForegroundColor DarkRed }
}

function Write-StatusJson {
    $statusPath = Join-Path $DocsDir "onboarding-status.json"
    $existing = @{ v = 1 }
    if (Test-Path $statusPath) {
        try { $existing = Get-Content $statusPath -Raw | ConvertFrom-Json } catch {}
    }
    $verify = @{
        ok           = ($script:failed.Count -eq 0)
        when         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        checksPassed = @($script:passed)
        checksFailed = @($script:failed)
    }
    $out = @{
        v      = 1
        ok     = if ($existing.ok -and $verify.ok) { $true } else { $verify.ok }
        when   = $verify.when
        verify = $verify
    }
    if ($existing.jq) { $out.jq = $existing.jq }
    if ($existing.hooks) { $out.hooks = $existing.hooks }
    if ($null -ne $existing.snapshotBytes) { $out.snapshotBytes = $existing.snapshotBytes }
    if ($existing.checksPassed) { $out.checksPassed = $existing.checksPassed }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $Root $statusPath), ($out | ConvertTo-Json -Depth 8 -Compress), $utf8)
}

# no_hook_sh
$hookSh = Get-ChildItem ".cursor/hooks" -Filter "*.sh" -ErrorAction SilentlyContinue
if ($hookSh -and $hookSh.Count -gt 0) {
    Fail "no_hook_sh" ($hookSh.Name -join ", ")
} else { Pass "no_hook_sh" }

# no_duplicate_scripts (no .sh in scripts root)
$rootSh = Get-ChildItem ".cursor/scripts" -Filter "*.sh" -File -ErrorAction SilentlyContinue
if ($rootSh -and $rootSh.Count -gt 0) {
    Fail "no_duplicate_scripts" ($rootSh.Name -join ", ")
} else { Pass "no_duplicate_scripts" }

# hooks_json_ps1
if (Test-Path ".cursor/hooks.json") {
    $hooks = Get-Content ".cursor/hooks.json" -Raw | ConvertFrom-Json
    $ok = $true
    foreach ($prop in $hooks.hooks.PSObject.Properties) {
        foreach ($entry in $hooks.hooks.($prop.Name)) {
            $c = [string]$entry.command
            if ($c -match '\.sh' -and $c -notmatch '\.ps1') { $ok = $false; Fail "hooks_json_ps1" $c }
            if ($c -notmatch 'powershell' -or $c -notmatch '\.ps1') { $ok = $false; Fail "hooks_json_ps1" $c }
        }
    }
    if ($ok) { Pass "hooks_json_ps1" }
} else { Fail "hooks_json_ps1" "missing hooks.json" }

# manifest_drift
$manifestPath = Join-Path $DocsDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Fail "manifest_drift" "missing manifest.json"
} else {
    $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $manifestOk = $true
    foreach ($h in (Get-ChildItem ".cursor/hooks" -Filter "*.ps1" -File)) {
        if ($m.hooks -notcontains $h.Name) {
            Fail "manifest_drift" "hooks/$($h.Name) not in manifest.hooks"
            $manifestOk = $false
        }
    }
    foreach ($s in (Get-ChildItem ".cursor/scripts" -Filter "*.ps1" -File)) {
        if ($m.scripts -notcontains $s.Name) {
            Fail "manifest_drift" "scripts/$($s.Name) not in manifest.scripts"
            $manifestOk = $false
        }
    }
    foreach ($r in (Get-ChildItem ".cursor/rules" -Filter "*.mdc" -File)) {
        if ($m.rules -notcontains $r.Name) {
            Fail "manifest_drift" "rules/$($r.Name) not in manifest.rules"
            $manifestOk = $false
        }
    }
    if ($manifestOk) { Pass "manifest_drift" }
}

# index_orphans + banned names
$indexPath = Join-Path $DocsDir "INDEX.json"
if (Test-Path $indexPath) {
    $index = Get-Content $indexPath -Raw | ConvertFrom-Json
    $anchorPaths = @()
    foreach ($p in $index.anchors.PSObject.Properties) {
        $anchorPaths += $index.anchors.($p.Name).path -replace '\\', '/'
    }
    $indexOk = $true
    foreach ($f in (Get-ChildItem "$DocsDir/l1" -Filter "*.json" -File -ErrorAction SilentlyContinue)) {
        $rel = "l1/$($f.Name)"
        if ($f.Name -match $BannedNamePattern) {
            Fail "index_orphans" "banned filename: $rel"
            $indexOk = $false
        }
        if ($anchorPaths -notcontains $rel) {
            Fail "index_orphans" "$rel not in INDEX.json"
            $indexOk = $false
        }
    }
    foreach ($f in (Get-ChildItem "$DocsDir/l2" -Filter "*.json" -File -ErrorAction SilentlyContinue)) {
        $rel = "l2/$($f.Name)"
        if ($f.Name -match $BannedNamePattern) {
            Fail "index_orphans" "banned filename: $rel"
            $indexOk = $false
        }
        if ($anchorPaths -notcontains $rel) {
            Fail "index_orphans" "$rel not in INDEX.json"
            $indexOk = $false
        }
    }
    if ($indexOk) { Pass "index_orphans" }
} else { Fail "index_orphans" "missing INDEX.json" }

# json_valid
if (Get-Command jq -ErrorAction SilentlyContinue) {
    $jsonOk = $true
    $files = @(
        "$DocsDir/log.json", "$DocsDir/current.json", "$DocsDir/l0.json",
        "$DocsDir/INDEX.json", "$DocsDir/manifest.json", "$DocsDir/environment.json", "$DocsDir/inject-snapshot.json"
    )
    Get-ChildItem "$DocsDir/l1" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { $files += $_.FullName.Replace("$Root\", "").Replace("\", "/") }
    Get-ChildItem "$DocsDir/l2" -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { $files += $_.FullName.Replace("$Root\", "").Replace("\", "/") }
    foreach ($f in $files) {
        if (-not (Test-Path $f)) { continue }
        jq empty $f 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "json_valid" "invalid: $f"
            $jsonOk = $false
        }
    }
    if ($jsonOk) { Pass "json_valid" }
} else { Fail "json_valid" "jq not installed" }

# snapshot_size
$snap = Join-Path $DocsDir "inject-snapshot.json"
if (Test-Path $snap) {
    $len = (Get-Item $snap).Length
    if ($len -le $MaxSnapshot) { Pass "snapshot_size" } else { Fail "snapshot_size" "$len bytes (max $MaxSnapshot)" }
} else { Fail "snapshot_size" "missing inject-snapshot.json" }

# snapshot_doc_close
if (Test-Path $snap) {
    try {
        $snapObj = Get-Content $snap -Raw | ConvertFrom-Json
        $pending = $snapObj.docClose.pending
        if ($snapObj.docClose -and ($pending -is [bool])) { Pass "snapshot_doc_close" }
        else { Fail "snapshot_doc_close" "inject-snapshot.json missing docClose.pending boolean" }
    } catch { Fail "snapshot_doc_close" "could not parse inject-snapshot.json" }
} else { Fail "snapshot_doc_close" "missing inject-snapshot.json" }

# sessions_cap
$sess = Get-ChildItem "$DocsDir/sessions" -Filter "*.json" -File -ErrorAction SilentlyContinue
if ($sess -and $sess.Count -gt $MaxSessions) {
    Fail "sessions_cap" "$($sess.Count) files (max $MaxSessions)"
} else { Pass "sessions_cap" }

# intent_rule_present
if (Test-Path "$DocsDir/manifest.json") {
    try {
        $m = Get-Content "$DocsDir/manifest.json" -Raw | ConvertFrom-Json
        if ($m.rules -contains "intent.mdc") { Pass "intent_rule_present" } else { Fail "intent_rule_present" "intent.mdc not in manifest.rules" }
    } catch { Fail "intent_rule_present" "invalid manifest.json" }
} else { Fail "intent_rule_present" "missing manifest.json" }

# index_intent
if (Test-Path "$DocsDir/INDEX.json") {
    $intentPath = jq -r '.anchors.intent.path // empty' "$DocsDir/INDEX.json" 2>$null
    if ($intentPath -eq "l1/intent.json" -and (Test-Path "$DocsDir/l1/intent.json")) {
        Pass "index_intent"
    } else {
        Fail "index_intent" "INDEX anchor intent -> l1/intent.json missing or wrong"
    }
} else { Fail "index_intent" "missing INDEX.json" }

# preservation_rule_present
if (Test-Path "$DocsDir/manifest.json") {
    try {
        $m = Get-Content "$DocsDir/manifest.json" -Raw | ConvertFrom-Json
        if ($m.rules -contains "preservation.mdc") { Pass "preservation_rule_present" }
        else { Fail "preservation_rule_present" "preservation.mdc not in manifest.rules" }
    } catch { Fail "preservation_rule_present" "invalid manifest.json" }
} else { Fail "preservation_rule_present" "missing manifest.json" }

# index_preservation
if (Test-Path "$DocsDir/INDEX.json") {
    $presPath = jq -r '.anchors.preservation.path // empty' "$DocsDir/INDEX.json" 2>$null
    if ($presPath -eq "l1/preservation.json" -and (Test-Path "$DocsDir/l1/preservation.json")) {
        Pass "index_preservation"
    } else {
        Fail "index_preservation" "INDEX anchor preservation -> l1/preservation.json missing or wrong"
    }
} else { Fail "index_preservation" "missing INDEX.json" }

# better_prompt_version
$bpOk = $false
if (-not (Test-Path "$DocsDir/manifest.json") -or -not (Test-Path "$DocsDir/l1/operator-assist.json")) {
    Fail "better_prompt_version" "manifest or operator-assist.json missing"
} elseif (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Fail "better_prompt_version" "jq not installed"
} else {
    $mv = jq -r '.betterPromptVersion // empty' "$DocsDir/manifest.json" 2>$null
    $tv = jq -r '.betterPrompt.version // empty' "$DocsDir/l1/operator-assist.json" 2>$null
    if ($mv -eq "$ExpectedBetterPromptVersion" -and $tv -eq "$ExpectedBetterPromptVersion") { $bpOk = $true }
    else { Fail "better_prompt_version" "manifest=$mv tier=$tv expected $ExpectedBetterPromptVersion" }
}
if ($bpOk) { Pass "better_prompt_version" }

# better_prompt_golden_valid
$goldenPath = "$DocsDir/l2/better-prompt-golden.json"
if (Test-Path $goldenPath) {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        jq empty $goldenPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "better_prompt_golden_valid" "invalid JSON"
        } else {
            $gOk = $true
            $ev = jq -r '.expectCoachVersion // empty' $goldenPath 2>$null
            $cc = jq -r '(.cases | length) // 0' $goldenPath 2>$null
            $gp = ""
            try {
                $idx = Get-Content (Join-Path $DocsDir "INDEX.json") -Raw | ConvertFrom-Json
                $gp = [string]$idx.anchors.'better-prompt-golden'.path
            } catch { $gp = "" }
            if ($ev -ne "$ExpectedBetterPromptVersion") {
                Fail "better_prompt_golden_valid" "expectCoachVersion=$ev"
                $gOk = $false
            }
            if ([int]$cc -lt 1) {
                Fail "better_prompt_golden_valid" "cases empty"
                $gOk = $false
            }
            if ($gp -ne "l2/better-prompt-golden.json") {
                Fail "better_prompt_golden_valid" "INDEX anchor missing or wrong (got '$gp')"
                $gOk = $false
            }
            if ($gOk) { Pass "better_prompt_golden_valid" }
        }
    } else { Fail "better_prompt_golden_valid" "jq not installed" }
} else { Fail "better_prompt_golden_valid" "missing l2/better-prompt-golden.json" }

# better_skill_version
$bsOk = $false
if (-not (Test-Path "$DocsDir/manifest.json") -or -not (Test-Path "$DocsDir/l1/operator-assist.json")) {
    Fail "better_skill_version" "manifest or operator-assist.json missing"
} elseif (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Fail "better_skill_version" "jq not installed"
} else {
    $mv = jq -r '.betterSkillVersion // empty' "$DocsDir/manifest.json" 2>$null
    $tv = jq -r '.betterSkill.version // empty' "$DocsDir/l1/operator-assist.json" 2>$null
    if ($mv -eq "$ExpectedBetterSkillVersion" -and $tv -eq "$ExpectedBetterSkillVersion") { $bsOk = $true }
    else { Fail "better_skill_version" "manifest=$mv tier=$tv expected $ExpectedBetterSkillVersion" }
}
if ($bsOk) { Pass "better_skill_version" }

# better_skill_golden_valid
$bsGoldenPath = "$DocsDir/l2/better-skill-golden.json"
if (Test-Path $bsGoldenPath) {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        jq empty $bsGoldenPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "better_skill_golden_valid" "invalid JSON"
        } else {
            $bsgOk = $true
            $ev = jq -r '.expectCoachVersion // empty' $bsGoldenPath 2>$null
            $cc = jq -r '(.cases | length) // 0' $bsGoldenPath 2>$null
            $gp = ""
            try {
                $idx = Get-Content (Join-Path $DocsDir "INDEX.json") -Raw | ConvertFrom-Json
                $gp = [string]$idx.anchors.'better-skill-golden'.path
            } catch { $gp = "" }
            if ($ev -ne "$ExpectedBetterSkillVersion") {
                Fail "better_skill_golden_valid" "expectCoachVersion=$ev"
                $bsgOk = $false
            }
            if ([int]$cc -lt 1) {
                Fail "better_skill_golden_valid" "cases empty"
                $bsgOk = $false
            }
            if ($gp -ne "l2/better-skill-golden.json") {
                Fail "better_skill_golden_valid" "INDEX anchor missing or wrong (got '$gp')"
                $bsgOk = $false
            }
            if ($bsgOk) { Pass "better_skill_golden_valid" }
        }
    } else { Fail "better_skill_golden_valid" "jq not installed" }
} else { Fail "better_skill_golden_valid" "missing l2/better-skill-golden.json" }

# skill_authoring_patterns_valid
$patPath = "$DocsDir/l2/skill-authoring-patterns.json"
if (Test-Path $patPath) {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        jq empty $patPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "skill_authoring_patterns_valid" "invalid JSON"
        } else {
            $rk = @("subagents", "validation_done", "verification_schema", "iterative_subsets")
            $patOk = $true
            foreach ($k in $rk) {
                $has = jq -r --arg k $k '.rubrics[$k].pattern // empty' $patPath 2>$null
                if (-not $has) { $patOk = $false; Fail "skill_authoring_patterns_valid" "missing rubric $k" }
            }
            if ($patOk) { Pass "skill_authoring_patterns_valid" }
        }
    } else { Fail "skill_authoring_patterns_valid" "jq not installed" }
} else { Fail "skill_authoring_patterns_valid" "missing l2/skill-authoring-patterns.json" }

# karpathy_skill_present
$kgSkillPath = ".cursor/skills/karpathy-guidelines/SKILL.md"
if (Test-Path "$DocsDir/manifest.json") {
    try {
        $m = Get-Content "$DocsDir/manifest.json" -Raw | ConvertFrom-Json
        if ($m.skills -contains "karpathy-guidelines" -and (Test-Path $kgSkillPath)) {
            Pass "karpathy_skill_present"
        } else {
            Fail "karpathy_skill_present" "karpathy-guidelines missing from manifest.skills or SKILL.md"
        }
    } catch { Fail "karpathy_skill_present" "invalid manifest.json" }
} else { Fail "karpathy_skill_present" "missing manifest.json" }

# karpathy_guidelines_tier_valid
$kgTierPath = "$DocsDir/l2/karpathy-guidelines.json"
if (Test-Path $kgTierPath) {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        jq empty $kgTierPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "karpathy_guidelines_tier_valid" "invalid JSON"
        } else {
            $kgOk = $true
            $kv = jq -r '.v // empty' $kgTierPath 2>$null
            $gp = ""
            try {
                $idx = Get-Content (Join-Path $DocsDir "INDEX.json") -Raw | ConvertFrom-Json
                $gp = [string]$idx.anchors.'karpathy-guidelines'.path
            } catch { $gp = "" }
            if ($kv -ne "1") {
                Fail "karpathy_guidelines_tier_valid" "v=$kv expected 1"
                $kgOk = $false
            }
            if ($gp -ne "l2/karpathy-guidelines.json") {
                Fail "karpathy_guidelines_tier_valid" "INDEX anchor wrong (got '$gp')"
                $kgOk = $false
            }
            if ($kgOk) { Pass "karpathy_guidelines_tier_valid" }
        }
    } else { Fail "karpathy_guidelines_tier_valid" "jq not installed" }
} else { Fail "karpathy_guidelines_tier_valid" "missing l2/karpathy-guidelines.json" }

# distribution_baseline_valid
$dbPath = "$DocsDir/l2/distribution-baseline.json"
if (Test-Path $dbPath) {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        jq empty $dbPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "distribution_baseline_valid" "invalid JSON"
        } else {
            $dbOk = $true
            $dv = jq -r '.v // empty' $dbPath 2>$null
            $gp = ""
            try {
                $idx = Get-Content (Join-Path $DocsDir "INDEX.json") -Raw | ConvertFrom-Json
                $gp = [string]$idx.anchors.'distribution-baseline'.path
            } catch { $gp = "" }
            if ($dv -ne "1") { Fail "distribution_baseline_valid" "v=$dv expected 1"; $dbOk = $false }
            if ($gp -ne "l2/distribution-baseline.json") { Fail "distribution_baseline_valid" "INDEX anchor wrong"; $dbOk = $false }
            $obOk = jq -e '.onboardingStatus.ok == false' $dbPath 2>$null
            if ($LASTEXITCODE -ne 0) { Fail "distribution_baseline_valid" "onboardingStatus.ok must be false"; $dbOk = $false }
            if ($dbOk) { Pass "distribution_baseline_valid" }
        }
    } else { Fail "distribution_baseline_valid" "jq not installed" }
} else { Fail "distribution_baseline_valid" "missing l2/distribution-baseline.json" }

# research_recent (when log.last is recent, research trail must be recent too)
$logPath = Join-Path $Root "$DocsDir/log.json"
if (Test-Path $logPath) {
    try {
        $log = Get-Content $logPath -Raw | ConvertFrom-Json
        $status = "ok"
        if ($log.last -and $log.last.when) {
            $lastWhen = [datetime]::Parse($log.last.when.Replace("Z", "+00:00"))
            if ($lastWhen -gt (Get-Date).ToUniversalTime().AddHours(-24)) {
                $research = @($log.research)
                if ($research.Count -eq 0) {
                    $status = "fail_empty"
                } else {
                    $resWhen = [datetime]::Parse($research[-1].when.Replace("Z", "+00:00"))
                    if ($resWhen -lt $lastWhen.AddHours(-1)) { $status = "fail_stale" }
                }
            }
        }
        switch ($status) {
            "ok" { Pass "research_recent" }
            "fail_empty" { Fail "research_recent" "recent log.last but research[] empty" }
            "fail_stale" { Fail "research_recent" "newest research older than last Action" }
            default { Fail "research_recent" "unknown" }
        }
    } catch { Fail "research_recent" "could not parse log.json" }
} else { Fail "research_recent" "missing log.json" }

# agents_bridge
if (Test-Path ".agents/manifest.yaml") { Pass "agents_manifest" } else { Fail "agents_manifest" "missing .agents/manifest.yaml" }
$envState = ".agents/state/environment.json"
$envMirror = "$DocsDir/environment.json"
if ((Test-Path $envState) -and (Test-Path $envMirror)) {
    try {
        $a = Get-Content $envState -Raw | ConvertFrom-Json
        $b = Get-Content $envMirror -Raw | ConvertFrom-Json
        if ($a.runtime -eq $b.runtime) { Pass "agents_environment" } else { Fail "agents_environment" "runtime mismatch state vs docs" }
    } catch {
        Fail "agents_environment" "invalid environment JSON"
    }
} else {
    Fail "agents_environment" "run onboarding to create environment.json (state + docs mirror)"
}

Write-StatusJson

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "OK: verify-harness passed" -ForegroundColor Green
    exit 0
}
Write-Host "VERIFY FAILED: $($failed -join ', ')" -ForegroundColor Red
exit 1
