# One-time workspace bootstrap: jq, PowerShell hooks, JSON tiers, inject snapshot.
# Run from repo root: powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/onboard.ps1
$ErrorActionPreference = "Continue"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$DocsDir = ".cursor/docs"
$StatusPath = Join-Path $DocsDir "onboarding-status.json"
$HooksPath = ".cursor/hooks.json"
$MaxSnapshotBytes = 5120

$checksPassed = [System.Collections.Generic.List[string]]::new()
$checksFailed = [System.Collections.Generic.List[string]]::new()

function Write-Step([string]$Msg) { Write-Host ">> $Msg" }
function Pass([string]$Name) { $script:checksPassed.Add($Name); Write-Host "OK  $Name" -ForegroundColor Green }
function Fail([string]$Name, [string]$Detail) {
    $script:checksFailed.Add($Name)
    Write-Host "FAIL $Name" -ForegroundColor Red
    if ($Detail) { Write-Host "     $Detail" -ForegroundColor DarkRed }
}

function Write-JsonFile([string]$Path, [object]$Obj) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $json = $Obj | ConvertTo-Json -Depth 12 -Compress
    [System.IO.File]::WriteAllText((Join-Path $Root $Path), $json, $utf8)
}

# --- PowerShell ---
Write-Step "Checking PowerShell"
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Fail "powershell" "PowerShell 5.1+ required"
} else {
    Pass "powershell"
}

# --- jq ---
Write-Step "Checking jq"
$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
$jqVersion = $null

if (-not $jqCmd) {
    Write-Host "     jq not on PATH; attempting winget install (Windows)..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $winget = Start-Process -FilePath "winget" -ArgumentList @(
            "install", "jqlang.jq", "-e",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        if ($winget.ExitCode -eq 0 -or $winget.ExitCode -eq -1978335189) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
    }
    $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
}

if ($jqCmd) {
    $jqVersion = (jq --version 2>&1 | Out-String).Trim()
    Pass "jq"
} else {
    Fail "jq" "Install jq (see README.md): winget install jqlang.jq / brew install jq"
}

# --- Detect agent runtime (.agents bridge) ---
Write-Step "Detecting agent runtime"
$detection = & (Join-Path $Root ".cursor/scripts/detect-environment.ps1")
$runtimeId = $detection.RuntimeId
Pass "detect_runtime"
Write-Host "     Runtime: $runtimeId (method: $($detection.Method))"

# --- hooks.json: PowerShell only, no bare .sh ---
Write-Step "Auditing .cursor/hooks.json"
$hooksOk = $true
if (-not (Test-Path $HooksPath)) {
    Fail "hooks.json" "Missing $HooksPath"
    $hooksOk = $false
} else {
    $hooksRaw = Get-Content $HooksPath -Raw
    $hooks = $hooksRaw | ConvertFrom-Json
    $commands = @()
    foreach ($prop in $hooks.hooks.PSObject.Properties) {
        foreach ($entry in $hooks.hooks.($prop.Name)) {
            if ($entry.command) { $commands += [string]$entry.command }
        }
    }
    foreach ($cmd in $commands) {
        if ($cmd -match '\.sh' -and $cmd -notmatch '\.ps1') {
            Fail "hooks_no_sh" "Hook invokes .sh without PowerShell -File: $cmd"
            $hooksOk = $false
        }
        if ($cmd -notmatch 'powershell' -or $cmd -notmatch '\.cursor/hooks/.*\.ps1') {
            Fail "hooks_use_powershell" "Hook must use: powershell -File .cursor/hooks/<name>.ps1 - got: $cmd"
            $hooksOk = $false
        }
    }
    $hookSh = Get-ChildItem ".cursor/hooks" -Filter "*.sh" -ErrorAction SilentlyContinue
    if ($hookSh -and $hookSh.Count -gt 0) {
        Fail "no_hook_sh" "Remove .sh from .cursor/hooks/: $($hookSh.Name -join ', ')"
        $hooksOk = $false
    } else {
        Pass "no_hook_sh"
    }
    if ($hooksOk) {
        Pass "hooks.json"
        Pass "hooks_use_powershell"
        Pass "hooks_no_sh"
    }
}

# --- JSON validate ---
Write-Step "Validating tier JSON"
$jsonFiles = @(
    "$DocsDir/log.json",
    "$DocsDir/current.json",
    "$DocsDir/l0.json",
    "$DocsDir/INDEX.json",
    "$DocsDir/l1/workspace.json",
    "$DocsDir/l2/structure.json",
    "$DocsDir/manifest.json",
    "$DocsDir/l1/runtimes.json",
    "$DocsDir/l1/intent.json"
)
$jsonOk = $true
if ($jqCmd) {
    foreach ($f in $jsonFiles) {
        if (-not (Test-Path $f)) {
            Fail "json_valid" "Missing $f"
            $jsonOk = $false
            continue
        }
        jq empty $f 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Fail "json_valid" "Invalid JSON: $f"
            $jsonOk = $false
        }
    }
    if ($jsonOk) { Pass "json_valid" }
} else {
    Fail "json_valid" "jq required for validation"
}

# --- Refresh inject snapshot ---
Write-Step "Refreshing inject-snapshot.json"
$snapshotBytes = 0
try {
    . (Join-Path $Root ".cursor/scripts/digest-lib.ps1")
    Update-InjectSnapshot
    $snapPath = Join-Path $Root "$DocsDir/inject-snapshot.json"
    if (Test-Path $snapPath) {
        $snapshotBytes = (Get-Item $snapPath).Length
        if ($snapshotBytes -le $MaxSnapshotBytes) {
            Pass "snapshot_refresh"
            Pass "snapshot_size"
        } else {
            Fail "snapshot_size" "$snapshotBytes bytes (max $MaxSnapshotBytes)"
        }
    } else {
        Fail "snapshot_refresh" "inject-snapshot.json not created"
    }
} catch {
    Fail "snapshot_refresh" $_.Exception.Message
}

# --- Hook smoke tests (Cursor only) ---
if ($runtimeId -ne "cursor") {
    Write-Step "Hook smoke skipped (runtime: $runtimeId)"
    Pass "hook_smoke_skipped"
} elseif ($jqCmd) {
Write-Step "Smoke-testing hooks (PowerShell)"
    $injectPs1 = Join-Path $Root ".cursor/hooks/inject-context.ps1"
    $guardPs1 = Join-Path $Root ".cursor/hooks/guard-paths.ps1"

    $sessionIn = '{"hook_event_name":"sessionStart"}'
    $sessionOut = $sessionIn | powershell -NoProfile -ExecutionPolicy Bypass -File $injectPs1 2>&1 | Out-String
    try {
        $sessionJson = $sessionOut.Trim() | ConvertFrom-Json
        if ($sessionJson.additional_context -and ($sessionJson.additional_context -is [string])) {
            Pass "inject_sessionStart"
        } else {
            Fail "inject_sessionStart" "additional_context missing or not a string"
        }
    } catch {
        Fail "inject_sessionStart" "Invalid JSON output: $($sessionOut.Substring(0, [Math]::Min(200, $sessionOut.Length)))"
    }

    $snapBefore = (Get-Item (Join-Path $Root "$DocsDir/inject-snapshot.json")).LastWriteTimeUtc
    Start-Sleep -Milliseconds 200
    $promptIn = '{"hook_event_name":"beforeSubmitPrompt"}'
    $promptOut = $promptIn | powershell -NoProfile -ExecutionPolicy Bypass -File $injectPs1 2>&1 | Out-String
    try {
        $promptJson = $promptOut.Trim() | ConvertFrom-Json
        if ($promptJson.continue -eq $true) {
            Pass "inject_beforeSubmitPrompt"
        } else {
            Fail "inject_beforeSubmitPrompt" "Expected continue: true"
        }
    } catch {
        Fail "inject_beforeSubmitPrompt" "Invalid JSON: $promptOut"
    }
    $snapAfter = (Get-Item (Join-Path $Root "$DocsDir/inject-snapshot.json")).LastWriteTimeUtc
    if ($snapAfter -ge $snapBefore) {
        Pass "inject_snapshot_touched"
    } else {
        Fail "inject_snapshot_touched" "inject-snapshot.json was not refreshed on beforeSubmitPrompt"
    }

    $guardIn = '{"file_path":"C:/temp/forbidden.txt"}'
    $guardOut = $guardIn | powershell -NoProfile -ExecutionPolicy Bypass -File $guardPs1 2>&1 | Out-String
    try {
        $guardJson = $guardOut.Trim() | ConvertFrom-Json
        if ($guardJson.agent_message) {
            Pass "guard_paths"
        } else {
            Fail "guard_paths" "Expected agent_message for path outside .cursor/"
        }
    } catch {
        Fail "guard_paths" "Invalid JSON: $guardOut"
    }
} else {
    Fail "inject_sessionStart" "jq required for prior steps"
    Fail "inject_beforeSubmitPrompt" "skipped"
    Fail "guard_paths" "skipped"
}

# --- Adapt environment (before verify so agents_environment check passes) ---
$preVerifyOk = ($checksFailed.Count -eq 0)
Write-Step "Adapting repository for runtime: $runtimeId"
$envProfile = & (Join-Path $Root ".cursor/scripts/adapt-environment.ps1") -Detection $detection -OnboardingOk $preVerifyOk -StatusPath $StatusPath -Root $Root
Pass "adapt_environment"

# --- verify-harness ---
Write-Step "Running verify-harness.ps1"
$verifyScript = Join-Path $Root ".cursor/scripts/verify-harness.ps1"
if (Test-Path $verifyScript) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verifyScript
    if ($LASTEXITCODE -ne 0) {
        Fail "verify_harness" "verify-harness.ps1 failed (see output above)"
    } else {
        Pass "verify_harness"
    }
} else {
    Fail "verify_harness" "Missing $verifyScript"
}

# --- Persist status ---
$ok = ($checksFailed.Count -eq 0)
$when = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$status = @{
    v             = 1
    ok            = $ok
    when          = $when
    runtime       = $runtimeId
    jq            = @{
        installed = [bool]$jqCmd
        version   = $jqVersion
    }
    hooks         = @{
        usePowerShell  = $hooksOk
        noShInHooksJson = ($checksPassed -contains "hooks_no_sh") -or ($checksPassed -contains "hooks.json")
    }
    environment   = @{
        statePath = ".agents/state/environment.json"
        runtime   = $runtimeId
    }
    snapshotBytes = $snapshotBytes
    checksPassed  = @($checksPassed)
    checksFailed  = @($checksFailed)
}

Write-JsonFile $StatusPath $status

if ($ok -and $jqCmd) {
    Write-Step "Updating log.json and current.json"
    $logPath = Join-Path $Root "$DocsDir/log.json"
    $log = Get-Content $logPath -Raw | ConvertFrom-Json
    $log.last = @{
        when  = $when
        what  = "Onboarding completed"
        why   = "Bootstrap jq, PowerShell hooks, and doc harness for agent workspace starter"
        mode  = "action"
        paths = @(".cursor/scripts/onboard.ps1")
    }
    Write-JsonFile "$DocsDir/log.json" $log
    jq empty $logPath 2>&1 | Out-Null

    $resume = switch ($runtimeId) {
        "cursor" { "Onboarding complete (Cursor). Reload Cursor, then start a new Agent chat." }
        "opencode" { "Onboarding complete (OpenCode). Read .agents/agents.md and inject-snapshot.json each turn." }
        default { "Onboarding complete ($runtimeId). Read .agents/state/environment.json for operator steps." }
    }
    $current = @{
        resume  = $resume
        next    = "Read inject-snapshot.json; classify Conversation vs Action. Runtime profile: .agents/state/environment.json"
        anchors = @("workspace", "structure", "runtimes")
    }
    Write-JsonFile "$DocsDir/current.json" $current

    . (Join-Path $Root ".cursor/scripts/digest-lib.ps1")
    Update-InjectSnapshot
}

Write-Host ""
if ($ok) {
    Write-Host "OK: onboarding complete" -ForegroundColor Green
    Write-Host "     Runtime: $runtimeId"
    Write-Host "     Status: $StatusPath"
    Write-Host "     Environment: .agents/state/environment.json"
    if ($runtimeId -eq "cursor") {
        Write-Host "     Reload Cursor, then start a new Agent chat."
    } else {
        Write-Host "     Follow operator steps in environment.json (no Cursor hook reload)."
    }
    exit 0
} else {
    Write-Host "ONBOARDING FAILED" -ForegroundColor Red
    Write-Host "     Failed checks: $($checksFailed -join ', ')"
    Write-Host "     See README.md (Tooling) and re-run after fixing."
    exit 1
}
