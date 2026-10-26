@echo off
setlocal
set "KIT=%~dp0"
if "%KIT:~-1%"=="\" set "KIT=%KIT:~0,-1%"

rem Prefer the Start Menu Orion.lnk so Windows taskbar uses branding\icon.ico
rem (same AppUserModelID as VSCodium). Fallback: start VSCodium.exe directly.
set "LNK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Orion\Orion.lnk"
if exist "%LNK%" (
  start "" "%LNK%"
  endlocal
  exit /b 0
)

set "CODIUM=%LOCALAPPDATA%\Programs\VSCodium\VSCodium.exe"
if not exist "%CODIUM%" set "CODIUM=%ProgramFiles%\VSCodium\VSCodium.exe"
if not exist "%CODIUM%" (
  echo VSCodium.exe not found. Run setup.ps1 first.
  exit /b 1
)
start "Orion" "%CODIUM%" --user-data-dir "%KIT%\ide-data" --extensions-dir "%KIT%\ide-extensions" --disable-telemetry --new-window --crash-reporter-directory "%KIT%\ide-data\crashes" "%KIT%\ide-data\Orion.code-workspace"
endlocal
