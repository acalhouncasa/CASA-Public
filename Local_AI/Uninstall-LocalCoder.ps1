#requires -Version 5.1
param(
    [switch]$RemoveDeps
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Local Coder"
if (Test-Path $programs) {
    Remove-Item $programs -Recurse -Force
    Write-Host "Removed Start Menu folder."
}

$kitDefault = Join-Path $env:LOCALAPPDATA "Programs\LocalCoder"
if ((Test-Path $kitDefault) -and ($Root -eq $kitDefault)) {
    Write-Host "This copy lives in $kitDefault. After uninstall, delete that folder in Explorer."
}

if ($RemoveDeps) {
    Write-Host "Removing VSCodium and Ollama via winget (requested)."
    winget uninstall -e --id VSCodium.VSCodium --accept-source-agreements
    winget uninstall -e --id Ollama.Ollama --accept-source-agreements
} else {
    Write-Host "Left VSCodium and Ollama installed. Pass -RemoveDeps to uninstall those too."
}

Write-Host "Firewall: Get-NetFirewallRule | Where-Object DisplayName -like 'LocalCoder *' | Remove-NetFirewallRule"
