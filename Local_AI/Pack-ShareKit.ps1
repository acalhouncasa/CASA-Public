#requires -Version 5.1
param(
    [switch]$DownloadPayload,
    [switch]$BuildInno
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
$Dist = Join-Path $Root "dist"
$Stage = Join-Path $Dist "LocalCoder-$Version"
$Zip = Join-Path $Dist "LocalCoder-$Version.zip"

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage "templates") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Stage "payload") | Out-Null
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

$copyFiles = @(
    "VERSION",
    "LICENSE.txt",
    "THIRD_PARTY.md",
    "README.md",
    "TEAM.md",
    "LEARN.md",
    "IT.md",
    "WELCOME.md",
    "setup.ps1",
    "run.ps1",
    "seed_cline.py",
    "setup-datasci.ps1",
    "doctor.ps1",
    "Update-LocalCoder.ps1",
    ".clinerules",
    "ruff.toml",
    "harden-firewall.ps1",
    "Sign-LocalCoder.ps1",
    "Install.cmd",
    "Check.cmd",
    "Launch-LocalCoder.vbs",
    "Start Local Coder.cmd",
    "Start Talon.cmd",
    "Uninstall-LocalCoder.ps1"
)
foreach ($name in $copyFiles) {
    Copy-Item (Join-Path $Root $name) (Join-Path $Stage $name) -Force
}
Copy-Item (Join-Path $Root "templates\*") (Join-Path $Stage "templates") -Force
Copy-Item (Join-Path $Root "payload\README.txt") (Join-Path $Stage "payload\README.txt") -Force
if (Test-Path (Join-Path $Root "branding")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "branding") | Out-Null
    Copy-Item (Join-Path $Root "branding\*") (Join-Path $Stage "branding") -Force
}
Copy-Item (Join-Path $Root "WELCOME.md") (Join-Path $Stage "WELCOME.md") -Force
if (Test-Path (Join-Path $Root "data\README.txt")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "data") | Out-Null
    Copy-Item (Join-Path $Root "data\README.txt") (Join-Path $Stage "data\README.txt") -Force
}
if (Test-Path (Join-Path $Root "examples")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "examples") | Out-Null
    Copy-Item (Join-Path $Root "examples\*") (Join-Path $Stage "examples") -Force
}
if (Test-Path (Join-Path $Root "learn")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "learn") | Out-Null
    Copy-Item (Join-Path $Root "learn\*.py") (Join-Path $Stage "learn") -Force
}
if (Test-Path (Join-Path $Root "memory\README.txt")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Stage "memory") | Out-Null
    Copy-Item (Join-Path $Root "memory\README.txt") (Join-Path $Stage "memory\README.txt") -Force
}
Copy-Item (Join-Path $Root "pack\LocalCoder.iss") (Join-Path $Stage "LocalCoder.iss") -ErrorAction SilentlyContinue
Copy-Item (Join-Path $Root "Pack-ShareKit.ps1") (Join-Path $Stage "Pack-ShareKit.ps1") -Force

if ($DownloadPayload) {
    Write-Host "Downloading official VSCodium and Ollama installers via winget..."
    $payloadDir = Join-Path $Stage "payload"
    winget download -e --id VSCodium.VSCodium -d $payloadDir --accept-package-agreements --accept-source-agreements
    winget download -e --id Ollama.Ollama -d $payloadDir --accept-package-agreements --accept-source-agreements
    Write-Host "Cline .vsix: install from Open VSX during setup, or drop a .vsix into payload\ before zipping."
}

$sums = Join-Path $Stage "SHA256SUMS.txt"
$lines = New-Object System.Collections.Generic.List[string]
Get-ChildItem $Stage -Recurse -File | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($Stage.Length + 1)
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    $lines.Add("$hash  $rel")
}
$lines -join "`n" | Set-Content -Path $sums -Encoding ascii

if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path $Stage -DestinationPath $Zip -CompressionLevel Optimal

$zipHash = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
@(
    "LocalCoder $Version share kit",
    "zip  $zipHash  $(Split-Path $Zip -Leaf)",
    "Verify: Get-FileHash .\$((Split-Path $Zip -Leaf)) -Algorithm SHA256",
    "Then: Unblock-File .\$((Split-Path $Zip -Leaf))  (only if the hash matches)",
    "Unzip and run Install.cmd"
) | Set-Content -Path (Join-Path $Dist "SHA256SUMS.txt") -Encoding ascii

Add-Content (Join-Path $Dist "SHA256SUMS.txt") "`n$zipHash  $(Split-Path $Zip -Leaf)"

if ($BuildInno) {
    $iscc = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) {
        Write-Warning "ISCC.exe not found. Zip kit is the supported share format. Unsigned EXE would also trigger SmartScreen until you Authenticode-sign it."
    } else {
        $iss = Join-Path $Root "pack\LocalCoder.iss"
        & $iscc $iss
    }
}

Write-Host ""
Write-Host "Share this (preferred): $Zip"
Write-Host "Hash: $zipHash"
Write-Host "Give coworkers IT.md with the zip. Do not email an unsigned Setup.exe and expect silence from SmartScreen."
