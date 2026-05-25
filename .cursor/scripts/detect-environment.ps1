# Detect agent runtime for multi-tool onboarding.
# Returns object: @{ RuntimeId; Signals; Method; Override }
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Continue"
$RuntimesDir = Join-Path $Root ".agents/runtimes"

function Test-RuntimeProfile {
    param([string]$ProfilePath)
    if (-not (Test-Path $ProfilePath)) { return $null }
    Get-Content $ProfilePath -Raw | ConvertFrom-Json
}

function Test-DetectSignals {
    param($Profile)
    $signals = [System.Collections.Generic.List[string]]::new()
    if ($Profile.detect.env) {
        foreach ($name in $Profile.detect.env) {
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if (Test-Path "Env:$name") {
                $val = [Environment]::GetEnvironmentVariable($name)
                if ($val) { $signals.Add("env:$name") }
            }
        }
    }
    if ($Profile.detect.paths) {
        foreach ($rel in $Profile.detect.paths) {
            $p = Join-Path $Root $rel
            if (Test-Path $p) { $signals.Add("path:$rel") }
        }
    }
    return $signals
}

$override = [Environment]::GetEnvironmentVariable("AGENT_RUNTIME")
if ($override) {
    $override = $override.Trim().ToLowerInvariant()
    return @{
        RuntimeId = $override
        Method    = "override"
        Override  = $override
        Signals   = @("AGENT_RUNTIME=$override")
    }
}

$order = @("cursor", "opencode", "claude-code")
$best = @{ RuntimeId = "generic"; Method = "fallback"; Signals = @() }

foreach ($id in $order) {
    $profilePath = Join-Path $RuntimesDir "$id.json"
    $profile = Test-RuntimeProfile $profilePath
    if (-not $profile) { continue }
    $signals = Test-DetectSignals $profile
    if ($signals.Count -gt 0) {
        return @{
            RuntimeId = $id
            Method    = "detect"
            Override  = $null
            Signals   = @($signals)
        }
    }
}

return $best
