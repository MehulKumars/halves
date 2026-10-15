# Claude Code PostToolUse hook: after Claude edits or writes a .gd file, compile it inside
# this project and send real errors back to Claude (exit 2 = stderr is shown to Claude).
# Skipped silently: non-.gd files, files outside this project, addons/, and a missing Godot.
# Registered in .claude/settings.json. Test by hand:
#   '{"tool_input":{"file_path":"core/events.gd"}}' | powershell -NoProfile -File tools/hooks/gd_check.ps1

# "Continue", not "SilentlyContinue": in Windows PowerShell 5.1, SilentlyContinue drops a
# native program's stderr even with 2>&1, and Godot prints script errors to stderr.
$ErrorActionPreference = "Continue"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
# Set GD_CHECK_DEBUG=1 to print why the hook skipped a file.
function Debug-Note([string]$Text) { if ($env:GD_CHECK_DEBUG) { [Console]::Error.WriteLine("gd_check: $Text") } }

$raw = [Console]::In.ReadToEnd()
try { $payload = $raw | ConvertFrom-Json } catch { Debug-Note "stdin is not JSON: $raw"; exit 0 }
$file = $payload.tool_input.file_path
if (-not $file) { $file = $payload.tool_response.filePath }
if (-not $file -or $file -notmatch '\.gd$') { exit 0 }

if (-not [IO.Path]::IsPathRooted($file)) { $file = Join-Path $project $file }
$full = [IO.Path]::GetFullPath($file)
if (-not $full.StartsWith($project, [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
$res = "res://" + $full.Substring($project.Length).TrimStart('\', '/').Replace('\', '/')
if ($res -like "res://addons/*") { exit 0 }

# Find Godot: the GODOT environment variable, else PATH (re-read from the registry,
# because an editor started before Godot was installed has a stale PATH).
$godot = $env:GODOT
if (-not $godot) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}
if (-not $godot) { Debug-Note "godot not found on PATH and GODOT is not set"; exit 0 }
Debug-Note "checking $res with $godot"

$out = & $godot --headless --path $project -s tools/hooks/check_script.gd -- $res 2>&1 | ForEach-Object { "$_" }
Debug-Note "godot printed $($out.Count) lines"
if ($env:GD_CHECK_DEBUG) { $out | ForEach-Object { Debug-Note "  | $_" } }
$errorPattern = 'SCRIPT ERROR|Parse Error|Compile Error|check_script: FAILED'
if ($out | Where-Object { $_ -match $errorPattern }) {
    [Console]::Error.WriteLine("Godot 4.7 found errors after editing $res :")
    $out | Where-Object { $_ -match "$errorPattern|at: GDScript" } | Select-Object -First 20 |
        ForEach-Object { [Console]::Error.WriteLine("  $_") }
    [Console]::Error.WriteLine("Fix these before continuing. See CLAUDE.md for Godot 4 rules.")
    exit 2
}
exit 0
