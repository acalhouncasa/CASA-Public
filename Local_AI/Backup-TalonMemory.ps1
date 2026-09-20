#requires -Version 5.1
<#
.SYNOPSIS
  Zip memory\ to a local folder you pick. Never OneDrive / Desktop / Downloads.
#>
param(
    [string]$Destination = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root "tools\LocalPaths.ps1")

$memory = Join-Path $Root "memory"
if (-not (Test-Path $memory)) {
    throw "No memory folder yet. Launch Talon once so the learner can create it."
}

if (-not $Destination) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Local folder for a Talon memory zip (USB or agency disk, not OneDrive)"
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
    $Destination = $dialog.SelectedPath
}

if (-not (Confirm-TalonLocalPath $Destination "write a PHI backup to")) {
    throw "Backup cancelled. Pick a local disk that does not sync."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zip = Join-Path $Destination "Talon-memory-$stamp.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $memory "*") -DestinationPath $zip -Force
Write-Host "Wrote $zip" -ForegroundColor Green
Write-Host "Treat this zip as PHI. Do not email it or put it on OneDrive."
