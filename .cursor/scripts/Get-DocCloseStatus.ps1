# Doc-close heuristics for inject-snapshot (no stop-hook followup_message).
function Get-DocCloseStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $Docs = Join-Path $Root ".cursor\docs"
    $Log = Join-Path $Docs "log.json"
    $Index = Join-Path $Docs "INDEX.json"
    $Manifest = Join-Path $Docs "manifest.json"
    $SessionState = Join-Path $Docs "session-state.json"
    $Hint = "jq-helpers.ps1 set_last; unix/jq-helpers.sh set_last; append_research if Action touched .cursor/"

    $reasons = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path $Log)) {
        return @{ pending = $false; reasons = @(); hint = $Hint }
    }

    $logMtime = (Get-Item $Log).LastWriteTime

    if (((Get-Date) - $logMtime).TotalMinutes -ge 120) {
        $reasons.Add("logStale")
    }

    foreach ($f in @($Index, $Manifest)) {
        if ((Test-Path $f) -and (Get-Item $f).LastWriteTime -gt $logMtime) {
            if ($reasons -notcontains "tierNewer") { $reasons.Add("tierNewer") }
        }
    }

    $hasSessionEdits = $false
    if (Test-Path $SessionState) {
        try {
            $ss = Get-Content $SessionState -Raw | ConvertFrom-Json
            if ($ss.editsThisSession -and @($ss.editsThisSession).Count -gt 0) { $hasSessionEdits = $true }
        } catch {}
    }

    $cursorTouched = $false
    if ($hasSessionEdits) {
        $cutoff = (Get-Date).AddHours(-2)
        Get-ChildItem (Join-Path $Root ".cursor") -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.LastWriteTime -gt $cutoff -and $_.LastWriteTime -gt $logMtime) {
                $script:cursorTouched = $true
            }
        }
        if ($cursorTouched) { $reasons.Add("cursorTouched") }
    }

    try {
        $log = Get-Content $Log -Raw | ConvertFrom-Json
        $rc = @($log.research).Count
        if ($cursorTouched -and $rc -eq 0) { $reasons.Add("researchWeak") }
        if ($rc -gt 0 -and $log.last -and $log.last.when) {
            $lastWhen = [datetime]::Parse($log.last.when.Replace("Z", "+00:00"))
            $resWhen = [datetime]::Parse($log.research[-1].when.Replace("Z", "+00:00"))
            if ($lastWhen -gt $resWhen.AddHours(1)) {
                if ($reasons -notcontains "researchWeak") { $reasons.Add("researchWeak") }
            }
        }
    } catch {}

    if (Test-Path $SessionState) {
        try {
            $ss = Get-Content $SessionState -Raw | ConvertFrom-Json
            if ($ss.attempts -and @($ss.attempts).Count -ge 3) {
                $lastThree = @($ss.attempts | Select-Object -Last 3)
                $hyp = $lastThree[0].hypothesis
                if (($lastThree | Where-Object { $_.hypothesis -eq $hyp }).Count -ge 3) {
                    $reasons.Add("whackAMole")
                }
            }
        } catch {}
    }

    return @{
        pending = ($reasons.Count -gt 0)
        reasons = @($reasons | Select-Object -Unique)
        hint    = $Hint
    }
}
