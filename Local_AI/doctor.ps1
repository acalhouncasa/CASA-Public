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
    Fail "venv missing. Run setup-datasci.ps1. If py -3 --version fails, see INSTALL.md section 8 to install Python."
}

$settingsPath = Join-Path $ide "User\settings.json"
$wsPath = Join-Path $ide "Talon.code-workspace"
$interpOk = $false
foreach ($cfgPath in @($settingsPath, $wsPath)) {
    if (-not (Test-Path $cfgPath)) { continue }
    $raw = Get-Content $cfgPath -Raw -ErrorAction SilentlyContinue
    if ($raw -and $raw -like "*__LOCALCODER_PYTHON__*") {
        Fail "Python path placeholder still in $(Split-Path $cfgPath -Leaf). Run setup-datasci.ps1."
        continue
    }
    if ($raw -and ($raw -like "*python.defaultInterpreterPath*") -and ($raw -like "*.venv*python.exe*")) {
        $interpOk = $true
    }
}
if ($interpOk) { Pass "Python interpreter pinned to kit .venv" }
else { Fail "Python interpreter is not pinned. Run setup-datasci.ps1 (INSTALL.md section 8)." }
if (Test-Path $settingsPath) {
    $sraw = Get-Content $settingsPath -Raw
    if ($sraw -match '"python.useEnvironmentsExtension"\s*:\s*false') { Pass "Python Environments picker is off" }
    else { Warn "python.useEnvironmentsExtension is not false. Re-run setup-datasci.ps1." }
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
$ingest = Join-Path $Root "learn\ingest_path.py"
if (Test-Path $ingest) { Pass "Path ingest learn\\ingest_path.py" } else { Warn "ingest_path.py missing" }
$mem = Join-Path $Root "memory\INDEX.md"
if (Test-Path $mem) { Pass "memory\\INDEX.md present" } else { Warn "memory not built yet (starts with run.ps1)" }

$sources = Join-Path $ide "sources.json"
if (Test-Path $sources) {
    $src = Get-Content $sources -Raw -Encoding utf8 | ConvertFrom-Json
    $nFold = @($src.folders).Count
    $nDb = @($src.databases).Count
    Pass "Connected sources: $nFold folder(s), $nDb database(s)"
} else {
    Warn "No PHI folder connected. Run Connect.cmd"
}

$overrides = Join-Path $ide "team-overrides.json"
if (Test-Path $overrides) { Pass "team-overrides.json present (Strict or custom)" }

$ico = Join-Path $Root "branding\icon.ico"
if (Test-Path $ico) { Pass "Talon icon branding\\icon.ico" } else { Warn "branding\\icon.ico missing. Shortcuts will look like a script." }

$menuPatch = Join-Path $Root "learn\patch_vscodium_menus.py"
if ((Test-Path $menuPatch) -and (Test-Path $venvPy)) {
    & $venvPy $menuPatch --check
    if ($LASTEXITCODE -eq 0) { Pass "File menu Open Folder is patched off" }
    else { Fail "File menu still has Open Folder. Close Talon and run: python learn\patch_vscodium_menus.py" }
}
$guard = Join-Path $Root "extensions\talon.talon-guard-1.3.0\extension.js"
if (Test-Path $guard) { Pass "Talon Guard extension present" } else { Warn "Talon Guard missing. File → Open Folder is not locked off." }
$guardPkg = Join-Path $Root "extensions\talon.talon-guard-1.3.0\package.json"
if (Test-Path $guardPkg) {
    $bytes = [System.IO.File]::ReadAllBytes($guardPkg)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Warn "Guard package.json has a UTF-8 BOM. VSCodium will mark Talon Guard invalid."
    } else {
        Pass "Guard package.json has no UTF-8 BOM"
    }
}
$ollamaPage = Join-Path $Root "extensions\talon.talon-guard-1.3.0\ollama-down.html"
$guardJs = Get-Content $guard -Raw -ErrorAction SilentlyContinue
if ((Test-Path $ollamaPage) -and $guardJs -match "lockClineToOllama" -and $guardJs -match "enforceOllamaGate" -and $guardJs -match "spawnIngest") {
    Pass "Ollama wait page, Cline provider lock, and path ingest"
} else {
    Warn "Ollama wait page, Cline provider lock, or path ingest missing from Guard"
}

$backup = Join-Path $Root "Backup-TalonMemory.ps1"
if (Test-Path $backup) { Pass "Memory backup script present" } else { Warn "Backup-TalonMemory.ps1 missing" }

$starters = @(
    (Join-Path $Root ".cline\workflows\ingest-this-path.md"),
    (Join-Path $Root ".cline\workflows\map-this-folder.md"),
    (Join-Path $Root ".cline\workflows\list-sql-tables.md"),
    (Join-Path $Root ".cline\workflows\read-memory-index.md")
)
if ($starters | Where-Object { -not (Test-Path $_) }) {
    Warn "One or more Cline starters missing under .cline\\workflows"
} else {
    Pass "Cline starters (ingest / map / SQL / memory)"
}

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
