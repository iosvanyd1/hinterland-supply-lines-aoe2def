# Lint + tests + build. Run before every commit.
$ErrorActionPreference = 'Stop'
$py = Join-Path (Split-Path $PSScriptRoot -Parent) '.venv\Scripts\python.exe'
& $py -m hinterland lint;   if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $py -m pytest -q;         if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $py -m hinterland build;  if ($LASTEXITCODE) { exit $LASTEXITCODE }
