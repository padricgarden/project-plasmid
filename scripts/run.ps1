# Launch the game. Usage: .\scripts\run.ps1 [-Seconds N]
#
# -Seconds runs it for a fixed time and exits, which is how a scripted check confirms the
# main scene actually renders. Without it the game runs until you close the window.
param([int]$Seconds = 0)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "project-plasmid"
$godot = Join-Path $root "Godot\Godot_v4.7.2-stable_win64_console.exe"

if (-not (Test-Path $godot)) {
    Write-Error "Godot not found at $godot. See CLAUDE.md > Engine."
}

if ($Seconds -le 0) {
    & $godot --path $project
    exit $LASTEXITCODE
}

$proc = Start-Process -FilePath $godot -ArgumentList @("--path", $project) `
    -PassThru -NoNewWindow -RedirectStandardError (Join-Path $env:TEMP "plasmid_run_err.txt")
if (-not $proc.WaitForExit($Seconds * 1000)) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Write-Host "ran for $Seconds s, then stopped" -ForegroundColor DarkGray
}
Get-Content (Join-Path $env:TEMP "plasmid_run_err.txt") -ErrorAction SilentlyContinue
