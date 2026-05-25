# Doc harness jq utilities. Run from repository root.
# Usage: .cursor/scripts/jq-helpers.ps1 append_research|set_last|rotate_log|refresh_inject
param(
    [Parameter(Position = 0)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
$DocsDir = ".cursor/docs"
$LogPath = Join-Path $DocsDir "log.json"

. (Join-Path $PSScriptRoot "digest-lib.ps1")

function Require-Jq {
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Error "jq is required. Install jq - see README.md."
        exit 1
    }
}

function Write-JsonUtf8([string]$Path, [string]$Json) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $Root $Path), $Json, $utf8)
}

switch ($Command) {
    "append_research" {
        Require-Jq
        $tier = $Rest[0]; $anchor = $Rest[1]; $result = $Rest[2]; $via = if ($Rest.Count -gt 3) { $Rest[3] } else { "jq" }
        $when = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $tmp = New-TemporaryFile
        jq --arg when $when --arg tier $tier --arg anchor $anchor --arg via $via --arg result $result `
            '.research += [{when: $when, tier: $tier, anchor: $anchor, via: $via, result: $result}]' `
            $LogPath | Set-Content -Path $tmp.FullName -Encoding utf8 -NoNewline
        if ($LASTEXITCODE -eq 0) { Move-Item -Force $tmp.FullName $LogPath }
        & $PSCommandPath rotate_log
    }
    "set_last" {
        $what = $Rest[0]; $why = $Rest[1]; $mode = if ($Rest.Count -gt 2) { $Rest[2] } else { "action" }
        $paths = @()
        if ($Rest.Count -gt 3) { $paths = $Rest[3..($Rest.Count - 1)] }
        $when = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $log = Get-Content $LogPath -Raw | ConvertFrom-Json
        $log.last = @{
            when  = $when
            what  = $what
            why   = $why
            mode  = $mode
            paths = @($paths)
        }
        Write-JsonUtf8 $LogPath ($log | ConvertTo-Json -Depth 12 -Compress)
    }
    "rotate_log" {
        Require-Jq
        $log = Get-Content $LogPath -Raw | ConvertFrom-Json
        if ($log.research -and $log.research.Count -gt 20) {
            $log.research = @($log.research | Select-Object -Last 20)
        }
        $hist = @()
        if ($log.history) { $hist = @($log.history) }
        if ($log.last) { $hist += $log.last }
        if ($hist.Count -gt 10) { $log.history = @($hist | Select-Object -Last 10) } else { $log.history = $hist }
        Write-JsonUtf8 $LogPath ($log | ConvertTo-Json -Depth 12 -Compress)
    }
    "refresh_inject" {
        Update-InjectSnapshot
        Write-Host "Updated .cursor/docs/inject-snapshot.json"
    }
    default {
        Write-Host "Usage: jq-helpers.ps1 append_research|set_last|rotate_log|refresh_inject"
        exit 1
    }
}
