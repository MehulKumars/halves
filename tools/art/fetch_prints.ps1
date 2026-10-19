# Downloads the chapter prints listed in tools/art/prints.json (public-domain scans on Wikimedia
# Commons) into tools/art/src/, which git ignores. Run once on a new machine before
# tools/art/process_prints.gd; the baked game images themselves are in git.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$src = Join-Path $root "src"
New-Item -ItemType Directory -Force $src | Out-Null
# Sources are tool input, not game assets: keep Godot from importing them.
if (-not (Test-Path (Join-Path $src ".gdignore"))) { New-Item -ItemType File (Join-Path $src ".gdignore") | Out-Null }
$list = Get-Content (Join-Path $root "prints.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($p in $list.prints) {
    $out = Join-Path $src ("{0}.jpg" -f $p.id)
    if (Test-Path $out) { Write-Host "   have $($p.id)"; continue }
    Invoke-WebRequest -Uri $p.url -OutFile $out -UserAgent "HalvesGameAssetFetch/1.0 (https://github.com/MehulKumars/halves)"
    Write-Host "   got $($p.id): $($p.title) ($($p.collection), $($p.licence))"
    Start-Sleep -Milliseconds 500
}
