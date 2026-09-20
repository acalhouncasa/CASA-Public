@echo off
setlocal
set "KIT=%~dp0"
if "%KIT:~-1%"=="\" set "KIT=%KIT:~0,-1%"
set "CODIUM=%LOCALAPPDATA%\Programs\VSCodium\VSCodium.exe"
if not exist "%CODIUM%" set "CODIUM=%ProgramFiles%\VSCodium\VSCodium.exe"
if not exist "%CODIUM%" (
  echo VSCodium.exe not found. Run setup.ps1 first.
  exit /b 1
)
start "Talon" "%CODIUM%" --user-data-dir "%KIT%\ide-data" --extensions-dir "%KIT%\ide-extensions" --disable-telemetry --new-window --crash-reporter-directory "%KIT%\ide-data\crashes" "%KIT%\ide-data\Talon.code-workspace"
endlocal
