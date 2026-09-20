@echo off
setlocal
set "KIT=%~dp0"
if "%KIT:~-1%"=="\" set "KIT=%KIT:~0,-1%"
set "CODIUM=%LOCALAPPDATA%\Programs\VSCodium\VSCodium.exe"
if not exist "%KIT%\extensions\talon-guard-1.3.0.vsix" (
  "%KIT%\.venv\Scripts\python.exe" "%KIT%\learn\make_guard_vsix.py"
)
"%CODIUM%" --user-data-dir "%KIT%\ide-data" --extensions-dir "%KIT%\ide-extensions" --install-extension "%KIT%\extensions\talon-guard-1.3.0.vsix" --force --wait
echo EXIT:%ERRORLEVEL%
endlocal
