@echo off
setlocal
title Talon
cd /d "%~dp0"
echo Starting Talon...
echo Launcher 1.4.6 — if this window sits here, it is waiting for Ollama.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
if errorlevel 1 (
  echo.
  echo Talon did not start. Read ide-data\logs\launch.log
  echo Or run:  powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
  pause
)
endlocal
