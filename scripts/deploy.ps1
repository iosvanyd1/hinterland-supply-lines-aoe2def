# Copy (or junction) build\<ModName> into the local mods folder.
#   scripts\deploy.ps1               # copy
#   scripts\deploy.ps1 -Mode Link    # junction: rebuilds show up without redeploying
param(
    [ValidateSet('Copy', 'Link')] [string]$Mode = 'Copy',
    [string]$ModName = 'HinterlandSupplyLines',
    [string]$SteamId,
    # Also copy XS + RMS into the profile resources folders. Use if the game does
    # not list the map from inside the mod (unverified, TECHNICAL_UNKNOWNS.md U11),
    # and for scenario-editor testing with Script Filename = HinterlandSupplyLines.
    [switch]$AlsoProfile
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$src = Join-Path $repo "build\$ModName"
$base = Join-Path $env:USERPROFILE 'Games\Age of Empires 2 DE'

if (-not $SteamId) {
    $ids = @(Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^\d+$' -and (Test-Path (Join-Path $_.FullName 'mods')) })
    if ($ids.Count -ne 1) { throw "Found $($ids.Count) profiles in $base; pass -SteamId <number>" }
    $SteamId = $ids[0].Name
}
$profileDir = Join-Path $base $SteamId
$dest = Join-Path $profileDir "mods\local\$ModName"

if (-not (Test-Path $src)) { throw "Build output missing: $src. Run: .venv\Scripts\python.exe -m hinterland build" }
if (Get-Process -Name 'AoE2DE*' -ErrorAction SilentlyContinue) {
    Write-Warning 'AoE2 DE is running. Close it first; the game locks mod files and only reads them at startup.'
}

if (Test-Path $dest) {
    $item = Get-Item $dest -Force
    if ($item.LinkType) { $item.Delete() } else { Remove-Item $dest -Recurse -Force }
}
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
if ($Mode -eq 'Link') {
    New-Item -ItemType Junction -Path $dest -Target $src | Out-Null   # no admin needed
} else {
    Copy-Item $src $dest -Recurse
}
if ($AlsoProfile) {
    $common = Join-Path $profileDir 'resources\_common'
    foreach ($sub in 'xs', 'random-map-scripts') {
        $to = Join-Path $common $sub
        New-Item -ItemType Directory -Force $to | Out-Null
        Copy-Item (Join-Path $src "resources\_common\$sub\*") $to -Recurse -Force
    }
    Write-Host "Also copied XS + RMS into $common"
}
Write-Host "Deployed $ModName -> $dest ($Mode)"
Write-Host 'In game: Mods > My Mods > Import Local Mods (first time). Pick the mod in the lobby "Data Mod" dropdown.'
