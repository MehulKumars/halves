# Renders every screen of the UI kit to build/snapshots/*.png (see tools/snapshots.gd).
# Opens a game window for a while; it cannot run headless.
#   powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1                       # project style, 4 sizes
#   powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Styles all -Sizes 720x1600
#   powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Only "main_menu,pause" -Inset "0,64,0,32"
param(
    [string]$Godot = "godot",
    [string]$Sizes = "",
    [string]$Styles = "",
    [string]$Inset = "0,0,0,0",
    [string]$Only = "",
    [string]$Out = "build/snapshots"
)
$ErrorActionPreference = "Continue"
$project = Split-Path -Parent $PSScriptRoot
$userArgs = @("--inset", $Inset, "--out", $Out)
if ($Sizes) { $userArgs += @("--sizes", $Sizes) }
if ($Styles) { $userArgs += @("--styles", $Styles) }
if ($Only) { $userArgs += @("--only", $Only) }
$output = & $Godot --path $project -s tools/snapshots.gd -- @userArgs 2>&1 | ForEach-Object { "$_" }
$output | Where-Object { $_ -match "snapshot|ERROR|SCRIPT ERROR|WARNING" } | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { Write-Host "Snapshots failed (exit $LASTEXITCODE)"; exit 1 }
