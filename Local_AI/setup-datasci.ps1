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

function Resolve-PythonLauncher {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        try {
            $ver = & py -3 --version 2>&1 | Out-String
            if ($ver -match "Python 3") { return @{ Exe = "py"; Prefix = @("-3") } }
        } catch { }
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return @{ Exe = $python.Source; Prefix = @() } }
    throw "Python 3 is missing. Run setup.ps1 first (it can install Python.Python.3.12)."
}

$launch = Resolve-PythonLauncher
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
Write-Host "Use that interpreter in Local Coder. Do not pip-install cloud SDKs into it."
