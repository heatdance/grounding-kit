# Write environment profile after detection. Dot-source from onboard.ps1
param(
    [hashtable]$Detection,
    [bool]$OnboardingOk = $false,
    [string]$StatusPath = ".cursor/docs/onboarding-status.json",
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
if (-not $Detection) {
    $Detection = & (Join-Path $Root ".cursor/scripts/detect-environment.ps1")
}
$runtimeId = $Detection.RuntimeId
$profilePath = Join-Path $Root ".agents/runtimes/$runtimeId.json"
if (-not (Test-Path $profilePath)) {
    $runtimeId = "generic"
    $profilePath = Join-Path $Root ".agents/runtimes/generic.json"
}
$profile = Get-Content $profilePath -Raw | ConvertFrom-Json
$when = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$notesRel = ".agents/state/adaptation-$runtimeId.md"
$notesPath = Join-Path $Root $notesRel
$notesDir = Split-Path $notesPath -Parent
if (-not (Test-Path $notesDir)) { New-Item -ItemType Directory -Path $notesDir -Force | Out-Null }

$exampleLine = ""
if ($profile.adaptation.exampleConfig) {
    $exampleLine = "Example config: $($profile.adaptation.exampleConfig)"
}

$notes = @"
# Adaptation notes ($runtimeId)

Generated: $when

## Capabilities

- Hooks: $($profile.capabilities.hooks)
- Inject snapshot: $($profile.capabilities.injectSnapshot)
- Slash commands: $($profile.capabilities.slashCommands)

## Operator steps

$($profile.operatorSteps | ForEach-Object { "- $_" } | Out-String)

$exampleLine

## Detection

- Method: $($Detection.Method)
- Signals: $($Detection.Signals -join ', ')
"@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($notesPath, $notes.TrimEnd(), $utf8)

$envObj = @{
    v            = 1
    runtime      = $runtimeId
    label        = $profile.label
    detectedAt   = $when
    detection    = @{
        method  = $Detection.Method
        signals = @($Detection.Signals)
        override = $Detection.Override
    }
    capabilities = @{
        hooks           = [bool]$profile.capabilities.hooks
        injectSnapshot  = [string]$profile.capabilities.injectSnapshot
        slashCommands   = [bool]$profile.capabilities.slashCommands
        pathGuard       = [bool]$profile.capabilities.pathGuard
    }
    entryPoints  = @{
        primary  = $profile.entryPoints.primary
        rules    = @($profile.entryPoints.rules)
        snapshot = $profile.entryPoints.snapshot
        skills   = $profile.entryPoints.skills
    }
    onboarding   = @{
        ok             = $OnboardingOk
        statusPath     = $StatusPath
        operatorSteps  = @($profile.operatorSteps)
    }
    adaptation   = @{
        notesPath     = $notesRel
        exampleConfig = $profile.adaptation.exampleConfig
    }
}

function Write-JsonUtf8([string]$RelPath, [object]$Obj) {
    $full = Join-Path $Root $RelPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $Obj | ConvertTo-Json -Depth 10 -Compress
    [System.IO.File]::WriteAllText($full, $json, $utf8)
}

Write-JsonUtf8 ".agents/state/environment.json" $envObj
Write-JsonUtf8 ".cursor/docs/environment.json" $envObj

return $envObj
