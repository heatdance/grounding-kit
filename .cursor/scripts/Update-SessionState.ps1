# Append edit path to session-state.json. Dot-source from guard-paths.ps1.
function Update-SessionState {
    param(
        [string]$Path,
        [string]$Hypothesis = "",
        [string]$Root = (Get-Location).Path
    )
$StatePath = Join-Path $Root ".cursor/docs/session-state.json"
$when = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$state = @{
    v                 = 1
    lastConfidence    = $null
    lastIntentSummary = $null
    attempts          = @()
    editsThisSession  = @()
}
if (Test-Path $StatePath) {
    try { $state = Get-Content $StatePath -Raw | ConvertFrom-Json } catch {}
}

$edits = [System.Collections.Generic.List[string]]::new()
if ($state.editsThisSession) { $edits.AddRange(@($state.editsThisSession)) }
$norm = $Path -replace '\\', '/'
if ($edits -notcontains $norm) { $edits.Add($norm) }

$attempts = [System.Collections.Generic.List[object]]::new()
if ($state.attempts) { $attempts.AddRange(@($state.attempts)) }
if ($Hypothesis) {
    $attempts.Add(@{ when = $when; hypothesis = $Hypothesis; path = $norm })
    if ($attempts.Count -gt 10) {
        $attempts = [System.Collections.Generic.List[object]]::new()
        $attempts.AddRange(@($state.attempts | Select-Object -Last 9))
        $attempts.Add(@{ when = $when; hypothesis = $Hypothesis; path = $norm })
    }
}

$out = @{
    v                 = 1
    lastConfidence    = $state.lastConfidence
    lastIntentSummary = $state.lastIntentSummary
    attempts          = @($attempts)
    editsThisSession  = @($edits | Select-Object -Last 50)
}
$utf8 = New-Object System.Text.UTF8Encoding $false
$json = $out | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText((Join-Path $Root $StatePath), $json, $utf8)
}
