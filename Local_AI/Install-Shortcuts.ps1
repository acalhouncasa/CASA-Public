#requires -Version 5.1
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Orion"
New-Item -ItemType Directory -Force -Path $programs | Out-Null
$wscript = New-Object -ComObject WScript.Shell
$ico = Join-Path $Root "branding\icon.ico"

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

# Target the .cmd files directly. cmd /c "E:\...\Local AI\Start Orion.cmd"
# splits at the space and never runs the script.
Write-Lnk (Join-Path $programs "Orion.lnk") (Join-Path $Root "Start Orion.cmd") "" "Orion - Local AI (on-device Ollama)"
Write-Lnk (Join-Path $programs "Orion Connect.lnk") (Join-Path $Root "Connect.cmd") "" "Attach a local project or PHI folder"
Write-Lnk (Join-Path $programs "Orion Backup Memory.lnk") (Join-Path $Root "Backup.cmd") "" "Zip memory to a local folder"

$desk = [Environment]::GetFolderPath("Desktop")
Copy-Item (Join-Path $programs "Orion.lnk") (Join-Path $desk "Orion.lnk") -Force
Copy-Item (Join-Path $programs "Orion Connect.lnk") (Join-Path $desk "Orion Connect.lnk") -Force
if (-not $Quiet) {
    Write-Host "Shortcuts: $programs"
    Write-Host "Desktop: Orion, Orion Connect"
    if (Test-Path $ico) { Write-Host "Icon: $ico" } else { Write-Host "No branding\icon.ico yet." }
}
