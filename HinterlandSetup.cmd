@echo off
rem Hinterland Supply Lines: install or update the mod on a player's PC.
rem Double-click to run. Needs Git and Python 3.11+ (offers to install them).
rem Downloads the repo into %USERPROFILE%\HinterlandSupplyLines, builds the mod
rem from your own game files and installs it. Close Age of Empires II first.
setlocal EnableExtensions
title Hinterland Supply Lines setup
set "REPO_URL=https://github.com/iosvanyd1/hinterland-supply-lines-aoe2def.git"
set "BRANCH=claude/scaffold-research"
set "TARGET=%USERPROFILE%\HinterlandSupplyLines"

where git >nul 2>nul
if errorlevel 1 (
    call :install "Git" Git.Git
    goto :end
)

rem "python" may be the Microsoft Store placeholder, so check that it really runs.
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
if errorlevel 1 (
    call :install "Python 3.12" Python.Python.3.12
    goto :end
)

if exist "%TARGET%\.git" (
    echo Updating %TARGET% ...
    git -C "%TARGET%" fetch origin || goto :fail
    git -C "%TARGET%" checkout "%BRANCH%" || goto :fail
    git -C "%TARGET%" pull --ff-only origin "%BRANCH%" || goto :fail
) else (
    echo Downloading the mod into %TARGET% ...
    git clone -b "%BRANCH%" "%REPO_URL%" "%TARGET%" || goto :fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\player-setup.ps1" || goto :fail
goto :end

:install
echo.
echo %~1 is missing or too old.
choice /M "Install %~1 now with winget"
if errorlevel 2 (
    echo Install %~1 yourself, then run HinterlandSetup.cmd again.
    exit /b 1
)
winget install --id %~2 -e --source winget
echo.
echo When the install has finished, close this window and run HinterlandSetup.cmd again.
exit /b 0

:fail
echo.
echo Setup did not finish. Read the messages above, fix the problem, and run it again.

:end
echo.
pause
