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

$codium = Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"
if (-not (Test-Path $codium)) {
    $codium = Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe"
}
$ws = Join-Path $Root "ide-data\Orion.code-workspace"
$argsCodium = @(
    "--user-data-dir `"$Root\ide-data`""
    "--extensions-dir `"$Root\ide-extensions`""
    "--disable-telemetry"
    "--new-window"
    "--crash-reporter-directory `"$Root\ide-data\crashes`""
    "`"$ws`""
) -join " "

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

# Main Orion shortcut must target VSCodium.exe (not Start Orion.cmd) so the
# taskbar can use branding\icon.ico via AppUserModelID VSCodium.VSCodium.
$orionLnk = Join-Path $programs "Orion.lnk"
if (Test-Path $codium) {
    Write-Lnk $orionLnk $codium $argsCodium "Orion - Local AI (on-device Ollama)"
    $setAppId = Join-Path $Root "tools\Set-LnkAppUserModelId.ps1"
    if (Test-Path $setAppId) {
        try {
            & $setAppId -ShortcutPath $orionLnk -AppUserModelId "VSCodium.VSCodium"
        } catch {
            Write-Host "WARN: could not set AppUserModelID ($(#requires -Version 5.1
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Orion"
New-Item -ItemType Directory -Force -Path $programs | Out-Null
$wscript = New-Object -ComObject WScript.Shell
$ico = Join-Path $Root "branding\icon.ico"

$codium = Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"
if (-not (Test-Path $codium)) {
    $codium = Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe"
}
$ws = Join-Path $Root "ide-data\Orion.code-workspace"
$argsCodium = @(
    "--user-data-dir `"$Root\ide-data`""
    "--extensions-dir `"$Root\ide-extensions`""
    "--disable-telemetry"
    "--new-window"
    "--crash-reporter-directory `"$Root\ide-data\crashes`""
    "`"$ws`""
) -join " "

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

# Main Orion shortcut must target VSCodium.exe (not Start Orion.cmd) so the
# taskbar can use branding\icon.ico via AppUserModelID VSCodium.VSCodium.
$orionLnk = Join-Path $programs "Orion.lnk"
if (Test-Path $codium) {
    Write-Lnk $orionLnk $codium $argsCodium "Orion - Local AI (on-device Ollama)"
    $setAppId = Join-Path $Root "tools\Set-LnkAppUserModelId.ps1"
    if (Test-Path $setAppId) {
        & $setAppId -ShortcutPath $orionLnk -AppUserModelId "VSCodium.VSCodium"
    }
} else {
    Write-Lnk $orionLnk (Join-Path $Root "Start Orion.cmd") "" "Orion - Local AI (on-device Ollama)"
}

Write-Lnk (Join-Path $programs "Orion Connect.lnk") (Join-Path $Root "Connect.cmd") "" "Attach a local project or PHI folder"
Write-Lnk (Join-Path $programs "Orion Backup Memory.lnk") (Join-Path $Root "Backup.cmd") "" "Zip memory to a local folder"
# Starter that waits for Ollama then launches via Orion.lnk
Write-Lnk (Join-Path $programs "Orion (with Ollama check).lnk") (Join-Path $Root "Start Orion.cmd") "" "Start Ollama if needed, then Orion"

$desk = [Environment]::GetFolderPath("Desktop")
Copy-Item $orionLnk (Join-Path $desk "Orion.lnk") -Force
Copy-Item (Join-Path $programs "Orion Connect.lnk") (Join-Path $desk "Orion Connect.lnk") -Force

# Start menu / taskbar tile art (unsigned XML + PNGs already applied by apply_win32_icons).
$manifest = Join-Path (Split-Path $codium) "VSCodium.VisualElementsManifest.xml"
if ((Test-Path $manifest) -and (Test-Path $codium)) {
    $xml = Get-Content $manifest -Raw
    if ($xml -notmatch 'ShortDisplayName="Orion"') {
        $xml2 = $xml -replace 'ShortDisplayName="[^"]*"', 'ShortDisplayName="Orion"'
        Set-Content -Path $manifest -Value $xml2 -Encoding UTF8
    }
}

if (-not $Quiet) {
    Write-Host "Shortcuts: $programs"
    Write-Host "Desktop: Orion, Orion Connect"
    if (Test-Path $ico) { Write-Host "Icon: $ico" } else { Write-Host "No branding\icon.ico yet." }
}
.Exception.Message))"
        }
    }
} else {
    Write-Lnk $orionLnk (Join-Path $Root "Start Orion.cmd") "" "Orion - Local AI (on-device Ollama)"
}

Write-Lnk (Join-Path $programs "Orion Connect.lnk") (Join-Path $Root "Connect.cmd") "" "Attach a local project or PHI folder"
Write-Lnk (Join-Path $programs "Orion Backup Memory.lnk") (Join-Path $Root "Backup.cmd") "" "Zip memory to a local folder"
# Starter that waits for Ollama then launches via Orion.lnk
Write-Lnk (Join-Path $programs "Orion (with Ollama check).lnk") (Join-Path $Root "Start Orion.cmd") "" "Start Ollama if needed, then Orion"

$desk = [Environment]::GetFolderPath("Desktop")
Copy-Item $orionLnk (Join-Path $desk "Orion.lnk") -Force
Copy-Item (Join-Path $programs "Orion Connect.lnk") (Join-Path $desk "Orion Connect.lnk") -Force

# Start menu / taskbar tile art (unsigned XML + PNGs already applied by apply_win32_icons).
$manifest = Join-Path (Split-Path $codium) "VSCodium.VisualElementsManifest.xml"
if ((Test-Path $manifest) -and (Test-Path $codium)) {
    $xml = Get-Content $manifest -Raw
    if ($xml -notmatch 'ShortDisplayName="Orion"') {
        $xml2 = $xml -replace 'ShortDisplayName="[^"]*"', 'ShortDisplayName="Orion"'
        Set-Content -Path $manifest -Value $xml2 -Encoding UTF8
    }
}

if (-not $Quiet) {
    Write-Host "Shortcuts: $programs"
    Write-Host "Desktop: Orion, Orion Connect"
    if (Test-Path $ico) { Write-Host "Icon: $ico" } else { Write-Host "No branding\icon.ico yet." }
}

