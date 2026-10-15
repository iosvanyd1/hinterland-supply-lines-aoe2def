# Build and install Hinterland Supply Lines on a player's PC from this repo.
# Usually started by HinterlandSetup.cmd; safe to run again to update.
#   powershell -ExecutionPolicy Bypass -File scripts\player-setup.ps1 [-Python python] [-SkipDeploy]
param(
    [string]$Python = 'python',
    # Build only; leave the game folders untouched (for testing this script).
    [switch]$SkipDeploy
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

function Step([string]$Message) { Write-Host "`n== $Message" -ForegroundColor Cyan }
function Check([string]$What) { if ($LASTEXITCODE -ne 0) { throw "$What failed (see the messages above)." } }

if (-not $SkipDeploy -and (Get-Process -Name 'AoE2DE*' -ErrorAction SilentlyContinue)) {
    throw 'Close Age of Empires II first, then run this again.'
}

Step 'Python environment'
if (-not (Test-Path '.venv\Scripts\python.exe')) {
    & $Python -m venv .venv
    Check 'Creating the Python environment'
}
& .venv\Scripts\python.exe -m pip install --quiet --disable-pip-version-check -e .
Check 'Installing the build tool'

Step 'Finding the game'
& .venv\Scripts\python.exe -m hinterland paths
Check 'Finding the game'

Step 'Building the mod from your game files'
& .venv\Scripts\python.exe -m hinterland build
Check 'Building the mod'

if ($SkipDeploy) {
    Write-Host "`nBuilt in $repo\build (not installed: -SkipDeploy)."
} else {
    Step 'Installing into the game'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'deploy.ps1')
    Check 'Installing into the game'
}

$dat = Join-Path $repo 'build\HinterlandSupplyLines\resources\_common\dat\empires2_x2_p1.dat'
$hash = (Get-FileHash $dat).Hash
Step 'Done'
Write-Host "Data mod fingerprint: $hash"
Write-Host 'Everyone in a game must see the same fingerprint, or the game will go out of sync.'
Write-Host ''
Write-Host 'First time only, in game:'
Write-Host '  1. Mods > My Mods > Import Local Mods'
Write-Host '  2. Installed Mods: switch "Hinterland Supply Lines - Text" On, then restart the game'
Write-Host 'To play: Data Mod "Hinterland Supply Lines" in the game setup, any map.'
