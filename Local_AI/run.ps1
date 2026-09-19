# Launch the isolated local coding IDE. Inference stays on Ollama/localhost.
param(
    [string]$Workspace = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$IdeData = Join-Path $Root "ide-data"
$IdeExt = Join-Path $Root "ide-extensions"

function Find-VSCodium {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"),
        (Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command codium -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$codium = Find-VSCodium
if (-not $codium) {
    throw "VSCodium is missing. Run .\setup.ps1 first."
}
if (-not (Test-Path (Join-Path $IdeData "User\settings.json"))) {
    throw "Isolated profile is missing. Run .\setup.ps1 first."
}

try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
} catch {
    Write-Host "Starting Ollama..."
    $ollama = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
    if (Test-Path $ollama) {
        Start-Process $ollama -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3
    } else {
        throw "Ollama is not running and was not found. Start Ollama, then retry."
    }
}

$lastFile = Join-Path $IdeData "last-workspace.txt"
if (-not $Workspace) {
    if ((Test-Path $lastFile)) {
        $Workspace = (Get-Content $lastFile -Raw).Trim()
    }
    if (-not $Workspace -or -not (Test-Path $Workspace)) {
        $Workspace = $Root
    }
}
Set-Content -Path $lastFile -Value $Workspace -Encoding utf8

if (-not (Test-Path $Workspace)) {
    throw "Workspace folder not found: $Workspace"
}

$settingsDest = Join-Path $IdeData "User\settings.json"
Copy-Item (Join-Path $Root "templates\settings.json") $settingsDest -Force
$venvPy = Join-Path $Root ".venv\Scripts\python.exe"
$sqlite = Join-Path $Root "data\local.sqlite"
$settingsText = Get-Content $settingsDest -Raw -Encoding utf8
$settingsText = $settingsText.Replace("__LOCALCODER_PYTHON__", ($venvPy -replace "\\", "/"))
$settingsText = $settingsText.Replace("__LOCALCODER_SQLITE__", ($sqlite -replace "\\", "/"))
Set-Content -Path $settingsDest -Value $settingsText -Encoding utf8
python (Join-Path $Root "seed_cline.py") $IdeData | Out-Null

$venvScripts = Join-Path $Root ".venv\Scripts"
if (Test-Path $venvScripts) {
    $env:Path = "$venvScripts;$env:Path"
    $env:VIRTUAL_ENV = Join-Path $Root ".venv"
    $env:PYTHONNOUSERSITE = "1"
}

# GitHub and gh.exe must fail inside this window only (does not change your user gitconfig).
$env:GIT_CONFIG_COUNT = "6"
$env:GIT_CONFIG_KEY_0 = "url.localcoder-blocked://gh-https/.insteadof"
$env:GIT_CONFIG_VALUE_0 = "https://github.com/"
$env:GIT_CONFIG_KEY_1 = "url.localcoder-blocked://gh-ssh/.insteadof"
$env:GIT_CONFIG_VALUE_1 = "git@github.com:"
$env:GIT_CONFIG_KEY_2 = "url.localcoder-blocked://gh-ssh2/.insteadof"
$env:GIT_CONFIG_VALUE_2 = "ssh://git@github.com/"
$env:GIT_CONFIG_KEY_3 = "url.localcoder-blocked://gist-https/.insteadof"
$env:GIT_CONFIG_VALUE_3 = "https://gist.github.com/"
$env:GIT_CONFIG_KEY_4 = "url.localcoder-blocked://gist-ssh/.insteadof"
$env:GIT_CONFIG_VALUE_4 = "git@gist.github.com:"
$env:GIT_CONFIG_KEY_5 = "url.prevent-gh-http/.insteadof"
$env:GIT_CONFIG_VALUE_5 = "http://github.com/"
$env:GH_TOKEN = ""
$env:GITHUB_TOKEN = ""
$env:GH_ENTERPRISE_TOKEN = ""
$env:OLLAMA_HOST = "127.0.0.1:11434"
$env:OLLAMA_ORIGINS = "http://127.0.0.1"
# Cline's current bundle stores provider/onboarding in CLINE_DIR, not VS Code settings.
$env:CLINE_DIR = Join-Path $IdeData "cline-home"

# Quote paths so "Local AI" is not split into two argv tokens.
$launchArgs = @(
    "--user-data-dir=`"$IdeData`"",
    "--extensions-dir=`"$IdeExt`"",
    "--disable-telemetry",
    "--crash-reporter-directory=`"$(Join-Path $IdeData 'crashes')`"",
    "`"$Workspace`""
)
Write-Host "Opening Local Coder (VSCodium + Cline + Ollama)..."
Write-Host "Workspace: $Workspace"
Write-Host "GitHub remotes and GitHub login are blocked in this window."
Start-Process -FilePath $codium -ArgumentList $launchArgs
