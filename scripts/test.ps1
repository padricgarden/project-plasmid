# Run the headless GDScript test suite. Usage: .\scripts\test.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root "Godot\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    Write-Error "Godot editor not found at $godot. See CLAUDE.md > Engine."
}
& $godot --headless --path (Join-Path $root "project-plasmid") --script res://tests/run_tests.gd
exit $LASTEXITCODE
