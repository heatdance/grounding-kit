# Print Action-open checklist; optionally stub log.research.
# Usage: action-open.ps1 [-Anchor workspace] [-StubResearch]
param(
    [string]$Anchor = "intent",
    [switch]$StubResearch
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
$IntentPath = ".cursor/docs/l1/intent.json"

Write-Host "=== Action open ===" -ForegroundColor Cyan
if (Test-Path $IntentPath) {
    $intent = Get-Content $IntentPath -Raw | ConvertFrom-Json
    foreach ($step in $intent.actionOpen) { Write-Host "  - $step" }
} else {
    Write-Host "  - Read inject-snapshot.json"
    Write-Host "  - Intent + evidence + confidence (low = no writes)"
    Write-Host "  - INDEX -> one l1 -> one l2; log research[]"
}
Write-Host ""
Write-Host "Anchor hint: $Anchor (see INDEX.json)" -ForegroundColor DarkGray

if ($StubResearch -and (Get-Command jq -ErrorAction SilentlyContinue)) {
    & (Join-Path $PSScriptRoot "jq-helpers.ps1") append_research L1 $Anchor "answered" "action-open"
    Write-Host "OK: appended research stub for $Anchor" -ForegroundColor Green
}
