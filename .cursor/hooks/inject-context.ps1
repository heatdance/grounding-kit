# sessionStart / beforeSubmitPrompt — refresh inject-snapshot; additional_context on sessionStart only.
# Invoked from hooks.json via: powershell -File .cursor/hooks/inject-context.ps1
$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $Root ".cursor\scripts\digest-lib.ps1")

$inputJson = [Console]::In.ReadToEnd()
$event = "sessionStart"
try {
    $obj = $inputJson | ConvertFrom-Json
    if ($obj.hook_event_name) { $event = $obj.hook_event_name }
} catch {}

Update-InjectSnapshot

if ($event -eq "sessionStart") {
    $ctx = [string](Get-InjectSnapshotText -MaxBytes 5120)
    $out = @{ additional_context = $ctx }
    $out | ConvertTo-Json -Compress
} else {
    @{ continue = $true } | ConvertTo-Json -Compress
}
