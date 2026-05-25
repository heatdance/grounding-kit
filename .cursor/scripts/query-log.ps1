param([string]$Cmd = "last")
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Log = Join-Path $Root ".cursor\docs\log.json"
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Get-Content $Log -TotalCount 80
    exit 0
}
switch ($Cmd) {
    "last" { jq '.last' $Log }
    "research" { jq '.research' $Log }
    "research-recent" { jq '.research[-10:]' $Log }
    "digest" { jq '{ last, research: .research[-5:] }' $Log }
    default { Write-Error "Usage: query-log.ps1 last|research|research-recent|digest" }
}
