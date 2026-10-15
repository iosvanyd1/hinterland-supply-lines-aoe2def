# Copy (or junction) build\<ModName> into the local mods folder.
#   scripts\deploy.ps1               # copy
#   scripts\deploy.ps1 -Mode Link    # junction: rebuilds show up without redeploying
#   scripts\deploy.ps1 -ModName HinterlandSupplyLinesDev   # after `build --dev`
param(
    [ValidateSet('Copy', 'Link')] [string]$Mode = 'Copy',
    [string]$ModName = 'HinterlandSupplyLines',
    [string]$SteamId,
    # Retired (kept so old commands still run): used to copy XS + RMS into the profile.
    [switch]$AlsoProfile
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$src = Join-Path $repo "build\$ModName"
$base = Join-Path $env:USERPROFILE 'Games\Age of Empires 2 DE'

if (-not $SteamId) {
    $ids = @(Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^\d+$' -and $_.Name -ne '0' -and (Test-Path (Join-Path $_.FullName 'mods')) })
    if ($ids.Count -ne 1) { throw "Found $($ids.Count) profiles in $base; pass -SteamId <number>" }
    $SteamId = $ids[0].Name
}
$profileDir = Join-Path $base $SteamId
$dest = Join-Path $profileDir "mods\local\$ModName"

if (-not (Test-Path $src)) { throw "Build output missing: $src. Run: .venv\Scripts\python.exe -m hinterland build" }
if (-not (Test-Path (Join-Path $src 'resources\_common\dat\empires2_x2_p1.dat'))) {
    Write-Warning 'Build has no .dat (built with --no-dat?). Only XS/RMS will change in game; the Supply Cart will be missing.'
}
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
    # Retired: the XS now ships inside the mod as Effects.xs, and a profile copy of
    # Effects.xs would override the game's own in every game, with or without the mod.
    Write-Host '-AlsoProfile is no longer needed; nothing copied to the profile.'
}
Write-Host "Deployed $ModName -> $dest ($Mode)"

# Strings-only companion mod: the game loads modded strings at startup from
# enabled mods only, and a data mod is enabled later in the lobby.
$textSrc = Join-Path $repo "build\$ModName-Text"
$textDest = Join-Path $profileDir "mods\local\$ModName-Text"
if (Test-Path $textSrc) {
    if (Test-Path $textDest) {
        $item = Get-Item $textDest -Force
        if ($item.LinkType) { $item.Delete() } else { Remove-Item $textDest -Recurse -Force }
    }
    if ($Mode -eq 'Link') {
        New-Item -ItemType Junction -Path $textDest -Target $textSrc | Out-Null
    } else {
        Copy-Item $textSrc $textDest -Recurse
    }
    Write-Host "Deployed $ModName-Text -> $textDest ($Mode). Turn it On in Mods > Installed Mods."
}
Write-Host 'In game: Mods > My Mods > Import Local Mods (first time). Pick the mod in the lobby "Data Mod" dropdown.'
