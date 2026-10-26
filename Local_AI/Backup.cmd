@echo off
setlocal
cd /d "%~dp0"
powershell.exe -Sta -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-OrionMemory.ps1" %*
endlocal
