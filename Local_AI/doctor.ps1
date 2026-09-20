#requires -Version 5.1
<#
.SYNOPSIS
  Verify Local Coder is installed and still pointed at local Ollama.
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$fail = 0
$warn = 0

function Write-Check([string]$Level, [string]$Message) {
    if ($Quiet -and $Level -eq "OK") { return }
    $color = switch ($Level) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "Gray" }
    }
    Write-Host ("[{0}] {1}" -f $Level.PadRight(4), $Message) -ForegroundColor $color
}

function Pass([string]$Message) { Write-Check "OK" $Message }
function Warn([string]$Message) { $script:warn++; Write-Check "WARN" $Message }
function Fail([string]$Message) { $script:fail++; Write-Check "FAIL" $Message }

Write-Host "Talon doctor" -ForegroundColor Cyan
Write-Host "Kit: $Root"

$versionFile = Join-Path $Root "VERSION"
if (Test-Path $versionFile) {
    Pass ("VERSION " + (Get-Content $versionFile -Raw).Trim())
} else {
    Warn "VERSION file missing"
}

$onedrive = [Environment]::GetEnvironmentVariable("OneDrive")
if ($onedrive -and $Root.StartsWith($onedrive, [System.StringComparison]::OrdinalIgnoreCase)) {
    Warn "Kit is under OneDrive. PHI in data\\ or ide-data\\ can sync off this PC."
}

$git = Join-Path $Root ".git"
if (Test-Path $git) {
    Warn "Kit is a git working copy. Do not commit ide-data, .venv, or data\\*.sqlite."
}

$codium = @(
    (Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"),
    (Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($codium) { Pass "VSCodium $codium" } else { Fail "VSCodium.exe not found. Run setup.ps1." }

$ollamaOk = $false
try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
    $ollamaOk = $true
    $names = @($tags.models | ForEach-Object { $_.name })
    Pass ("Ollama on 127.0.0.1:11434 (" + $names.Count + " model(s))")
    $defaultsPath = Join-Path $Root "templates\team-defaults.json"
    $wanted = @("qwen3-coder:30b")
    if (Test-Path $defaultsPath) {
        $cfg = Get-Content $defaultsPath -Raw | ConvertFrom-Json
        if ($cfg.preferredModels) { $wanted = @($cfg.preferredModels) }
    }
    $hit = $wanted | Where-Object { $names -contains $_ } | Select-Object -First 1
    if ($hit) { Pass "Model present: $hit" }
    else { Warn ("No preferred model installed. ollama pull " + $wanted[0]) }
} catch {
    Fail "Ollama not answering on http://127.0.0.1:11434. Start Ollama or run run.ps1."
}

$ide = Join-Path $Root "ide-data"
$ext = Join-Path $Root "ide-extensions"
if (Test-Path (Join-Path $ide "User\settings.json")) { Pass "Isolated profile ide-data\\" } else { Fail "ide-data profile missing. Run setup.ps1." }
$cline = Get-ChildItem $ext -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "saoudrizwan.claude-dev-*" }
if ($cline) { Pass "Cline $($cline.Name)" } else { Fail "Cline extension missing. Run setup.ps1." }

$providers = Join-Path $ide "cline-home\data\settings\providers.json"
if (Test-Path $providers) {
    $p = Get-Content $providers -Raw | ConvertFrom-Json
    if ($p.lastUsedProvider -eq "ollama") { Pass "Cline lastUsedProvider=ollama" }
    else { Fail "Cline lastUsedProvider is '$($p.lastUsedProvider)'. Re-run seed_cline.py." }
} else {
    Warn "Cline providers.json missing. Run: python seed_cline.py .\\ide-data"
}

$venvPy = Join-Path $Root ".venv\Scripts\python.exe"
if (Test-Path $venvPy) {
    Pass "venv $venvPy"
    & $venvPy -c "import pandas, numpy, sklearn, sqlalchemy, matplotlib" 2>$null
    if ($LASTEXITCODE -eq 0) { Pass "Python data-science imports" }
    else { Fail "venv missing pandas/sklearn/sqlalchemy. Run setup-datasci.ps1." }
} else {
    Fail "venv missing. Run setup-datasci.ps1."
}

$sqlite = Join-Path $Root "data\local.sqlite"
if (Test-Path $sqlite) { Pass "SQLite data\\local.sqlite" } else { Warn "data\\local.sqlite missing. Run setup-datasci.ps1." }

$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($smi) {
    $line = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null | Select-Object -First 1
    if ($line) { Pass "GPU $line" }
} else {
    Warn "nvidia-smi not found. 30B models need a large NVIDIA GPU."
}

$learn = Join-Path $Root "learn\talon_learn.py"
if (Test-Path $learn) { Pass "Background learner learn\\talon_learn.py" } else { Warn "talon_learn.py missing" }
$mem = Join-Path $Root "memory\INDEX.md"
if (Test-Path $mem) { Pass "memory\\INDEX.md present" } else { Warn "memory not built yet (starts with run.ps1)" }

$overrides = Join-Path $ide "team-overrides.json"
if (Test-Path $overrides) { Pass "team-overrides.json present (Strict or custom)" }

Write-Host ""
if ($fail -gt 0) {
    Write-Host "Doctor: $fail fail, $warn warn" -ForegroundColor Red
    exit 1
}
if ($warn -gt 0) {
    Write-Host "Doctor: $warn warn (still usable)" -ForegroundColor Yellow
    exit 0
}
Write-Host "Doctor: all checks passed" -ForegroundColor Green
exit 0
