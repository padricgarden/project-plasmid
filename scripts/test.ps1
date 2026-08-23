# Run the headless GDScript test suite. Usage: .\scripts\test.ps1 [-Rescan]
#
# Godot resolves `class_name` types through .godot/global_script_class_cache.cfg, and
# `--headless --script` does NOT scan the filesystem to build it. A run started against
# a missing or stale cache fails with "Could not find type X in the current scope".
# So: do a headless editor pass first (~2s) whenever a source file is newer than the
# cache, then run the suite.
param([switch]$Rescan)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "project-plasmid"
$godot = Join-Path $root "Godot\Godot_v4.7.2-stable_win64_console.exe"
$cache = Join-Path $project ".godot\global_script_class_cache.cfg"

if (-not (Test-Path $godot)) {
    Write-Error "Godot editor not found at $godot. See CLAUDE.md > Engine."
}

$stale = $Rescan -or -not (Test-Path $cache)
if (-not $stale) {
    $cacheTime = (Get-Item $cache).LastWriteTimeUtc
    $newest = Get-ChildItem -Path (Join-Path $project "src"), (Join-Path $project "tests") `
        -Filter *.gd -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($newest -and $newest.LastWriteTimeUtc -gt $cacheTime) { $stale = $true }
}

if ($stale) {
    Write-Host "Rebuilding script class cache..." -ForegroundColor DarkGray
    & $godot --headless --editor --quit --path $project | Out-Null
}

& $godot --headless --path $project --script res://tests/run_tests.gd
exit $LASTEXITCODE
