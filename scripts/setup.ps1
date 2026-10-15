# One-time setup on Windows 11. Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
param(
    [string]$XsCheckVersion = 'v0.2.30'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

# Python env (uv: https://docs.astral.sh/uv/)
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw 'uv not found. Install: winget install --id=astral-sh.uv -e   (then reopen the terminal)'
}
uv venv .venv
uv pip install -p .venv -e '.[dev]'

# xs-check linter
$bin = Join-Path $repo 'tools\bin'
New-Item -ItemType Directory -Force $bin | Out-Null
$url = "https://github.com/Divy1211/xs-check/releases/download/$XsCheckVersion/xs-check.exe"
Invoke-WebRequest -Uri $url -OutFile (Join-Path $bin 'xs-check.exe')

# Local paths config
$local = Join-Path $repo 'config\paths.local.toml'
if (-not (Test-Path $local)) {
    Copy-Item (Join-Path $repo 'config\paths.example.toml') $local
    Write-Host "Created $local - check install_dir / profile_dir."
}

& .venv\Scripts\python.exe -m hinterland paths
Write-Host 'Setup done. Next: .venv\Scripts\python.exe -m hinterland build ; scripts\deploy.ps1'
