# Bakes every Halves level and pool with several Godot processes at once, then merges the parts.
# Used before a release or after changing the plan, masks or generator (docs/HALVES.md section 4).
# Each range only depends on its own seeds, so the result is the same as one process would give.
param(
    [string]$Godot = "C:\Users\lordi\GameDev\Tools\bin\godot.cmd",
    [int]$Processes = 4,
    [string[]]$Kinds = @("levels", "daily", "zen", "rush")
)

$ErrorActionPreference = "Stop"
# "-Kinds daily,zen,rush" arrives as one string when the script is run with -File.
$Kinds = $Kinds | ForEach-Object { $_ -split "," } | Where-Object { $_ }
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sizes = @{ "levels" = 100; "daily" = 400; "zen" = 120; "rush" = 150 }
$logs = Join-Path $project "build\levelgen"
New-Item -ItemType Directory -Force $logs | Out-Null

foreach ($kind in $Kinds) {
    $total = $sizes[$kind]
    $chunk = [math]::Ceiling($total / $Processes)
    $jobs = @()
    for ($p = 0; $p -lt $Processes; $p++) {
        $from = $p * $chunk + 1
        $to = [math]::Min($total, ($p + 1) * $chunk)
        if ($from -gt $to) { continue }
        $gargs = @("--headless", "--path", $project, "-s", "tools/levelgen/generate_halves.gd", "--")
        if ($kind -ne "levels") { $gargs += @("--pool", $kind) }
        $gargs += @("--range", "$from-$to")
        $log = Join-Path $logs "gen_${kind}_$from.log"
        $jobs += Start-Process -FilePath $Godot -ArgumentList $gargs -NoNewWindow -PassThru `
            -RedirectStandardOutput $log -RedirectStandardError "$log.err"
        $null = $jobs[-1].Handle
    }
    $jobs | Wait-Process
    $bad = $jobs | Where-Object { $_.ExitCode -ne 0 }
    if ($bad) {
        Write-Host "!! $kind generation failed; see $logs\gen_${kind}_*.log" -ForegroundColor Red
        exit 1
    }
    & $Godot --headless --path $project -s tools/levelgen/generate_halves.gd -- --merge $kind 2>&1 |
        Where-Object { $_ -match "wrote|error|FAILED" } | ForEach-Object { Write-Host "   $_" }
    Write-Host "== $kind done"
}
