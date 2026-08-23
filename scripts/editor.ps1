# Open the project in the Godot editor. Usage: .\scripts\editor.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root "Godot\Godot_v4.7.2-stable_win64.exe"
if (-not (Test-Path $godot)) {
    Write-Error "Godot editor not found at $godot. See CLAUDE.md > Engine."
}
& $godot --editor --path (Join-Path $root "project-plasmid")
