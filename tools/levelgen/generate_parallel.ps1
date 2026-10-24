# Bakes every Halves level and pool with several Godot processes at once, then merges the parts.
# Used before a release or after changing the plan, masks or generator (docs/HALVES.md sections 4, 4b).
# Each range only depends on its own seeds, so the result is the same as one process would give.
# (v3) Small ranges go through a queue, last ranges first (the biggest boards), so no process idles.
param(
    [string]$Godot = "C:\Users\lordi\GameDev\Tools\bin\godot.cmd",
    [int]$Processes = 4,
    [int]$Chunk = 10,
    [string[]]$Kinds = @("levels", "daily", "zen", "rush")
)

$ErrorActionPreference = "Stop"
# "-Kinds daily,zen,rush" arrives as one string when the script is run with -File.
$Kinds = $Kinds | ForEach-Object { $_ -split "," } | Where-Object { $_ }
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sizes = @{ "levels" = 300; "daily" = 400; "zen" = 150; "rush" = 150 }
$logs = Join-Path $project "build\levelgen"
New-Item -ItemType Directory -Force $logs | Out-Null
$started = Get-Date

foreach ($kind in $Kinds) {
    $total = $sizes[$kind]
    $ranges = @()
    for ($from = 1; $from -le $total; $from += $Chunk) {
        $ranges += , @($from, [math]::Min($total, $from + $Chunk - 1))
    }
    [array]::Reverse($ranges)
    $queue = New-Object System.Collections.Queue
    foreach ($r in $ranges) { $queue.Enqueue($r) }
    $running = @()
    $failed = $false
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($running.Count -lt $Processes -and $queue.Count -gt 0) {
            $r = $queue.Dequeue()
            $gargs = @("--headless", "--path", $project, "-s", "tools/levelgen/generate_halves.gd", "--")
            if ($kind -ne "levels") { $gargs += @("--pool", $kind) }
            $gargs += @("--range", "$($r[0])-$($r[1])")
            $log = Join-Path $logs "gen_${kind}_$($r[0]).log"
            $p = Start-Process -FilePath $Godot -ArgumentList $gargs -NoNewWindow -PassThru `
                -RedirectStandardOutput $log -RedirectStandardError "$log.err"
            $null = $p.Handle
            $running += $p
        }
        Start-Sleep -Milliseconds 500
        $done = @($running | Where-Object { $_.HasExited })
        foreach ($p in $done) {
            if ($p.ExitCode -ne 0) { $failed = $true }
        }
        $running = @($running | Where-Object { -not $_.HasExited })
    }
    if ($failed) {
        Write-Host "!! $kind generation failed; see $logs\gen_${kind}_*.log" -ForegroundColor Red
        exit 1
    }
    & $Godot --headless --path $project -s tools/levelgen/generate_halves.gd -- --merge $kind 2>&1 |
        Where-Object { $_ -notmatch "^Godot Engine" } | ForEach-Object { Write-Host "   $_" }
    Write-Host ("== $kind done ({0:N1} min so far)" -f ((Get-Date) - $started).TotalMinutes)
}
