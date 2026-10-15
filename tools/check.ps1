# The "done" check. Run from the project root:  powershell -ExecutionPolicy Bypass -File tools/check.ps1
# 1. imports assets, 2. boots the game headless for ~300 frames, 3. runs every GUT test.
# Exits 1 and prints the problem if any step reports a script error or a failing test.
param(
    [string]$Godot = "godot",
    [int]$Frames = 300
)

$ErrorActionPreference = "Continue"
$project = Split-Path -Parent $PSScriptRoot
$failed = $false

function Invoke-Step([string]$Name, [string[]]$GodotArgs, [string]$FailPattern) {
    Write-Host "== $Name"
    $output = & $Godot @GodotArgs 2>&1 | ForEach-Object { "$_" }
    $problems = $output | Select-String -Pattern $FailPattern
    if ($LASTEXITCODE -ne 0 -or $problems) {
        $output | Select-Object -Last 40 | ForEach-Object { Write-Host "   $_" }
        Write-Host "!! $Name FAILED" -ForegroundColor Red
        return $false
    }
    Write-Host "   ok"
    return $true
}

$errors = "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error|ERROR: .*(script|res://)"

# Warm-up import: on a fresh clone the first import can report script errors before Godot
# has built its class-name cache, so its output is not judged. Real script errors still
# show up in the boot and test steps below.
Write-Host "== import (warm-up)"
& $Godot --headless --path $project --import 2>&1 | Out-Null
Write-Host "   done"
if (-not (Invoke-Step "boot $Frames frames" @("--headless", "--path", $project, "--quit-after", "$Frames") $errors)) { $failed = $true }
if (-not (Invoke-Step "GUT tests" @("--headless", "--path", $project, "-s", "addons/gut/gut_cmdln.gd", "-gexit") "$errors|\[Failed\]|Failing Tests")) { $failed = $true }

if ($failed) { Write-Host "CHECK FAILED" -ForegroundColor Red; exit 1 }
Write-Host "CHECK PASSED" -ForegroundColor Green
exit 0
