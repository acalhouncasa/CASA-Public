@echo off
setlocal
cd /d "%~dp0"
powershell.exe -Sta -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-TalonMemory.ps1" %*
endlocal
