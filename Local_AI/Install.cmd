@echo off
setlocal
cd /d "%~dp0"
echo Local Coder installer
echo This runs setup.ps1. It installs VSCodium and Ollama from official sources.
echo It does not turn off Windows Defender or SmartScreen.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
pause
endlocal
