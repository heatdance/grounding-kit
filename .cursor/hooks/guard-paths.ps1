$ErrorActionPreference = "Continue"
$inputJson = [Console]::In.ReadToEnd()
$path = ""
$hookEvent = ""
try {
    $o = $inputJson | ConvertFrom-Json
    if ($o.file_path) { $path = $o.file_path }
    elseif ($o.path) { $path = $o.path }
    if ($o.hook_event_name) { $hookEvent = $o.hook_event_name }
} catch {}

if (-not $path) { "{}"; exit 0 }

$norm = $path -replace '\\', '/'
$leaf = Split-Path -Leaf $norm

# Hygiene: no shell hooks, no banned doc filenames
if ($norm -match '/\.cursor/hooks/.*\.sh$' -or $norm -like '.cursor/hooks/*.sh') {
    $msg = "Hygiene: do not add .sh under .cursor/hooks/ - use *.ps1 only (see hygiene.mdc)."
    @{ agent_message = $msg } | ConvertTo-Json -Compress
    exit 0
}
if ($norm -match '/\.cursor/docs/.*(-v2|-copy|-old|-backup|-new)\.json$') {
    $msg = "Hygiene: banned filename pattern under .cursor/docs/ - overwrite in place (see hygiene.mdc)."
    @{ agent_message = $msg } | ConvertTo-Json -Compress
    exit 0
}

$allow = $norm -match '/\.cursor/' -or $norm -like '.cursor/*' `
    -or $norm -match '/\.agents/' -or $norm -like '.agents/*' `
    -or $leaf -in @('README.md','AGENTS.md')

if ($allow) {
    if ($norm -match '/\.cursor/' -or $norm -like '.cursor/*') {
        try {
            $gRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
            . (Join-Path $gRoot ".cursor/scripts/Update-SessionState.ps1")
            Update-SessionState -Path $norm -Root $gRoot.Path
        } catch {}
    }
    "{}"; exit 0
}

$msg = "Structure rule: do not write outside .cursor/ (blocked path: $path)."
@{ agent_message = $msg } | ConvertTo-Json -Compress
