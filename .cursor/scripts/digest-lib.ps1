# PowerShell digest helpers for hooks (degraded without jq).
$script:DocsDir = ".cursor/docs"
$script:LogPath = Join-Path $script:DocsDir "log.json"
$script:CurrentPath = Join-Path $script:DocsDir "current.json"
$script:L0Path = Join-Path $script:DocsDir "l0.json"
$script:IntentPath = Join-Path $script:DocsDir "l1/intent.json"
$script:ManifestPath = Join-Path $script:DocsDir "manifest.json"
$script:SnapshotPath = Join-Path $script:DocsDir "inject-snapshot.json"
$script:MaxSnapshotBytes = 5120

. (Join-Path $PSScriptRoot "Get-DocCloseStatus.ps1")

function Get-ActionOpenSteps {
    if (Test-Path $script:IntentPath) {
        try {
            $intent = Get-Content $script:IntentPath -Raw | ConvertFrom-Json
            if ($intent.actionOpen) { return @($intent.actionOpen) }
        } catch {}
    }
    return @(
        "Read inject-snapshot.json first.",
        "State interpreted intent, evidence, confidence (low = no writes).",
        "INDEX then at most one l1 and one l2; log each to research[].",
        "Clarify if ambiguous; close Action with log.last and tiers."
    )
}

function Get-ManifestCounts {
    $counts = @{ rules = 0; skills = 0; hooks = 0; scripts = 0 }
    if (Test-Path $script:ManifestPath) {
        try {
            $m = Get-Content $script:ManifestPath -Raw | ConvertFrom-Json
            if ($m.rules) { $counts.rules = @($m.rules).Count }
            if ($m.skills) { $counts.skills = @($m.skills).Count }
            if ($m.hooks) { $counts.hooks = @($m.hooks).Count }
            if ($m.scripts) { $counts.scripts = @($m.scripts).Count }
        } catch {}
    }
    return $counts
}

function Write-SnapshotUtf8([string]$Json) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $script:SnapshotPath), $Json, $utf8NoBom)
}

function Update-InjectSnapshot {
    $root = (Get-Location).Path
    $payload = @{
        v          = 1
        generated  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        note       = "Refreshed by inject-context hook. Read at start of every turn."
        actionOpen = Get-ActionOpenSteps
        docClose   = Get-DocCloseStatus -Root $root
    }
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        $last = jq '{ last, research: .research[-5:] }' $script:LogPath 2>$null
        $cur = Get-Content $script:CurrentPath -Raw -ErrorAction SilentlyContinue
        $l0 = jq '{ loadPolicy, anchors }' $script:L0Path 2>$null
        if ($last) {
            $lastObj = $last | ConvertFrom-Json
            $payload.last = $lastObj.last
            $payload.research = $lastObj.research
        }
        if ($cur) { $payload.current = $cur | ConvertFrom-Json }
        if ($l0) { $payload.l0 = $l0 | ConvertFrom-Json }
        $payload.manifest = Get-ManifestCounts
    } else {
        $payload.note = "degraded-no-jq"
        $payload.last = (Get-Content $script:LogPath -TotalCount 30 -ErrorAction SilentlyContinue) -join "`n"
    }
    $json = $payload | ConvertTo-Json -Depth 12 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    if ($bytes.Length -gt $script:MaxSnapshotBytes) {
        $trim = @{
            v          = 1
            generated  = $payload.generated
            note       = $payload.note
            actionOpen = $payload.actionOpen
            docClose   = $payload.docClose
        }
        if ($payload.l0) { $trim.l0 = $payload.l0 }
        if ($payload.last) { $trim.last = $payload.last }
        if ($payload.research) { $trim.research = $payload.research }
        if ($payload.manifest) { $trim.manifest = $payload.manifest }
        $json = $trim | ConvertTo-Json -Depth 12 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        if ($bytes.Length -gt $script:MaxSnapshotBytes) {
            $json = ($trim | ConvertTo-Json -Depth 8 -Compress)
        }
    }
    Write-SnapshotUtf8 $json
}

function Get-InjectSnapshotText {
    param([int]$MaxBytes = 5120)
    Update-InjectSnapshot
    $fullPath = Join-Path (Get-Location) $script:SnapshotPath
    if (-not (Test-Path $fullPath)) { return "{}" }
    $text = [System.IO.File]::ReadAllText($fullPath)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    if ($bytes.Length -le $MaxBytes) { return $text }
    [System.Text.Encoding]::UTF8.GetString($bytes, 0, $MaxBytes)
}
