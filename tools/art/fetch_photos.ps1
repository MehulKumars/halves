# Downloads the background photos listed in tools/art/photos.json (Wikimedia Commons, CC0 / CC BY /
# CC BY-SA) into tools/art/src/photos/, which git ignores. Run once on a new machine before
# tools/art/process_photos.gd; the baked game images themselves are in git.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$src = Join-Path $root "src"
$dir = Join-Path $src "photos"
New-Item -ItemType Directory -Force $dir | Out-Null
# Sources are tool input, not game assets: keep Godot from importing them.
if (-not (Test-Path (Join-Path $src ".gdignore"))) { New-Item -ItemType File (Join-Path $src ".gdignore") | Out-Null }
$list = Get-Content (Join-Path $root "photos.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($p in $list.photos) {
    $out = Join-Path $dir ("{0}.jpg" -f $p.id)
    if (Test-Path $out) { Write-Host "   have $($p.id)"; continue }
    # Wikimedia asks for a User-Agent that names the project (robot policy) and a gentle pace.
    Invoke-WebRequest -Uri $p.url -OutFile $out -UserAgent "HalvesGame/1.0 (https://github.com/MehulKumars/halves)"
    Write-Host "   got $($p.id): $($p.title) ($($p.author), $($p.license))"
    Start-Sleep -Seconds 2
}
