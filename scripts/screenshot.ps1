# Render the game to a PNG so UI work can be looked at, not just asserted about.
# Usage: .\scripts\screenshot.ps1 -Out C:\path\shot.png [-Scene res://...] [-Select 5]
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Scene = "res://src/ui/plasmid_editor.tscn",
    [int]$Select = -1,
    [switch]$Commit,
    [int]$Tab = -1
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "project-plasmid"
$godot = Join-Path $root "Godot\Godot_v4.7.2-stable_win64_console.exe"

if (-not (Test-Path $godot)) {
    Write-Error "Godot not found at $godot. See CLAUDE.md > Engine."
}

# No --headless: capturing a viewport needs a real rendering device.
& $godot --path $project --script res://tools/screenshot.gd -- `
    "--out=$Out" "--scene=$Scene" "--select=$Select" "--commit=$($Commit.IsPresent.ToString().ToLower())" "--tab=$Tab"
exit $LASTEXITCODE
