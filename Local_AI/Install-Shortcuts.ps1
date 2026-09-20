#requires -Version 5.1
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Talon"
New-Item -ItemType Directory -Force -Path $programs | Out-Null
$wscript = New-Object -ComObject WScript.Shell
$ico = Join-Path $Root "branding\icon.ico"
$vbs = Join-Path $Root "Launch-LocalCoder.vbs"

function Write-Lnk([string]$Path, [string]$Target, [string]$Arguments, [string]$Description) {
    $lnk = $wscript.CreateShortcut($Path)
    $lnk.TargetPath = $Target
    $lnk.Arguments = $Arguments
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 1
    $lnk.Description = $Description
    if (Test-Path $ico) { $lnk.IconLocation = "$ico,0" }
    $lnk.Save()
}

Write-Lnk (Join-Path $programs "Talon.lnk") "$env:SystemRoot\System32\wscript.exe" "`"$vbs`"" "Talon - Local AI (on-device Ollama)"
Write-Lnk (Join-Path $programs "Talon Connect.lnk") "$env:SystemRoot\System32\cmd.exe" "/c `"$(Join-Path $Root 'Connect.cmd')`"" "Attach a local project or PHI folder"
Write-Lnk (Join-Path $programs "Talon Backup Memory.lnk") "$env:SystemRoot\System32\cmd.exe" "/c `"$(Join-Path $Root 'Backup.cmd')`"" "Zip memory to a local folder"

$desk = [Environment]::GetFolderPath("Desktop")
Copy-Item (Join-Path $programs "Talon.lnk") (Join-Path $desk "Talon.lnk") -Force
Copy-Item (Join-Path $programs "Talon Connect.lnk") (Join-Path $desk "Talon Connect.lnk") -Force
if (-not $Quiet) {
    Write-Host "Shortcuts: $programs"
    Write-Host "Desktop: Talon, Talon Connect"
    if (Test-Path $ico) { Write-Host "Icon: $ico" } else { Write-Host "No branding\icon.ico yet." }
}
