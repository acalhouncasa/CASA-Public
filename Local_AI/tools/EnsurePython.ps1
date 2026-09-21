<#
.SYNOPSIS
    Find Python 3, or install it with winget, for the Talon kit.

.DESCRIPTION
    Shared by setup.ps1 and setup-datasci.ps1. Looks on PATH, then in the
    usual Windows install folders. If nothing is found, installs
    Python.Python.3.12 with winget (user scope) and searches again.

.NOTES
    Author:      Alan Calhoun, Senior Data Analyst, CASA-Trinity
    Created:     2026-09-21
    Last Modified: 2026-09-21
    AI Assistant: Talon
    License:     UNLICENSED
#>

function Refresh-TalonPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
    $apps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    if (Test-Path $apps) {
        $env:Path = $apps + ";" + $env:Path
    }
}

function Get-TalonPythonCandidates {
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($name in @("py", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch "WindowsApps")) {
            $hits.Add($cmd.Source)
        }
    }
    $globs = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python*\python.exe"),
        (Join-Path ${env:ProgramFiles} "Python*\python.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Python*\python.exe")
    )
    foreach ($pattern in $globs) {
        if (-not $pattern) { continue }
        Get-Item $pattern -ErrorAction SilentlyContinue | ForEach-Object { $hits.Add($_.FullName) }
    }
    return @($hits | Select-Object -Unique)
}

function Test-TalonPython3([string]$Exe) {
    if (-not $Exe -or -not (Test-Path $Exe)) { return $false }
    try {
        if ($Exe -like "*\py.exe") {
            $out = & $Exe -3 --version 2>&1 | Out-String
        } else {
            $out = & $Exe --version 2>&1 | Out-String
        }
        return ($out -match "Python 3")
    } catch {
        return $false
    }
}

function Find-TalonPython {
    Refresh-TalonPath
    foreach ($exe in Get-TalonPythonCandidates) {
        if (Test-TalonPython3 $exe) { return $exe }
    }
    return $null
}

function Get-TalonPythonLauncher {
    $exe = Find-TalonPython
    if (-not $exe) { return $null }
    if ($exe -like "*\py.exe") {
        return @{ Exe = $exe; Prefix = @("-3") }
    }
    return @{ Exe = $exe; Prefix = @() }
}

function Install-TalonPythonIfMissing {
    $existing = Find-TalonPython
    if ($existing) {
        Write-Host "Python already present: $existing"
        return $existing
    }
    Write-Host "Python 3 was not found. Installing Python.Python.3.12 with winget..."
    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (-not (Test-Path $winget)) {
        $wg = Get-Command winget -ErrorAction SilentlyContinue
        if ($wg) { $winget = $wg.Source }
    }
    if (-not $winget -or -not (Test-Path $winget)) {
        throw @"
Python 3 is missing and winget is not available.
Install Python 3.12 from https://www.python.org/downloads/windows/
Check "Add python.exe to PATH", then run setup.ps1 again.
Or see INSTALL.md section 8.
"@
    }
    & $winget install -e --id Python.Python.3.12 --scope user --accept-package-agreements --accept-source-agreements
    Refresh-TalonPath
    Start-Sleep -Seconds 2
    $again = Find-TalonPython
    if ($again) {
        Write-Host "Python installed: $again"
        return $again
    }
    throw @"
winget finished but Python 3 is still not on PATH.
Close this window, open a new PowerShell, and run:
  py -3 --version
  .\setup-datasci.ps1
If py is missing, install Python 3.12 from https://www.python.org/downloads/windows/
and check "Add python.exe to PATH". Details: INSTALL.md section 8.
"@
}
