# Block VSCodium and this isolated profile from the public internet.
# Localhost (Ollama on 127.0.0.1) stays allowed.
# Run from an elevated PowerShell.

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-VSCodium {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"),
        (Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    throw "VSCodium.exe not found. Run setup.ps1 first."
}

$exe = Find-VSCodium
$rulePrefix = "LocalCoder"

Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "$rulePrefix *" } |
    Remove-NetFirewallRule

# Allow loopback, then block everything else for this binary.
New-NetFirewallRule `
    -DisplayName "$rulePrefix VSCodium allow localhost" `
    -Direction Outbound `
    -Program $exe `
    -Action Allow `
    -RemoteAddress @("127.0.0.1", "::1") `
    -Protocol Any | Out-Null

New-NetFirewallRule `
    -DisplayName "$rulePrefix VSCodium block Internet" `
    -Direction Outbound `
    -Program $exe `
    -Action Block `
    -RemoteAddress Internet `
    -Protocol Any | Out-Null

Write-Host "Firewall rules installed for: $exe"
Write-Host "VSCodium may still reach 127.0.0.1 (Ollama). Public internet is blocked."
Write-Host "To remove later: Get-NetFirewallRule | ? DisplayName -like 'LocalCoder *' | Remove-NetFirewallRule"
Write-Host ""
Write-Host "Note: Windows 'block Internet' + 'allow localhost' can still be order-sensitive."
Write-Host "After launching Local Coder, confirm Resource Monitor shows no VSCodium connections except 127.0.0.1."
