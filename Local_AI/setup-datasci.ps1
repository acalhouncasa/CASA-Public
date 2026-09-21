#requires -Version 5.1
<#
.SYNOPSIS
  Create the Local Coder Python venv (pandas, SQLAlchemy, Jupyter, ruff).
.DESCRIPTION
  Inference stays on Ollama. This only installs Python packages into .venv.
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Venv = Join-Path $Root ".venv"
$Req = Join-Path $Root "templates\requirements-datasci.txt"
$DataDir = Join-Path $Root "data"

. (Join-Path $Root "tools\EnsurePython.ps1")
Install-TalonPythonIfMissing | Out-Null
$launch = Get-TalonPythonLauncher
if (-not $launch) {
    throw "Python 3 is missing. See INSTALL.md section 8."
}
Write-Host "Python launcher: $($launch.Exe) $($launch.Prefix -join ' ')"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

$venvPy = Join-Path $Venv "Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Write-Host "Creating $Venv"
    & $launch.Exe @($launch.Prefix + @("-m", "venv", $Venv))
    if ($LASTEXITCODE -ne 0) { throw "venv create failed." }
}

Write-Host "Installing local data-science packages (PyPI only)..."
& $venvPy -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed." }
& $venvPy -m pip install --no-input -r $Req
if ($LASTEXITCODE -ne 0) { throw "pip install failed." }

$sqlite = Join-Path $DataDir "local.sqlite"
if (-not (Test-Path $sqlite)) {
    & $venvPy -c "import sqlite3; sqlite3.connect(r'$sqlite').close()"
    Write-Host "Created $sqlite"
}

$demo = Join-Path $Root "examples\load_demo.py"
if (Test-Path $demo) {
    Write-Host "Loading synthetic demo table (not PHI)..."
    & $venvPy $demo $sqlite
}

Write-Host "Data science venv ready: $venvPy"
$apply = Join-Path $Root "learn\apply_sources.py"
if (Test-Path $apply) {
    Write-Host "Binding Talon to $venvPy"
    & $venvPy $apply $Root
}
Write-Host "Use that interpreter in Talon. Do not pip-install cloud SDKs into it."
