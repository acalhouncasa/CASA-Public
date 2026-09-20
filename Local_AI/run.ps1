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

$guardSrc = Join-Path $Root "extensions\talon.talon-guard-1.3.0"
$guardDst = Join-Path $IdeExt "talon.talon-guard-1.3.0"
if (Test-Path $guardSrc) {
    if (Test-Path $guardDst) { Remove-Item $guardDst -Recurse -Force }
    Copy-Item $guardSrc $guardDst -Recurse -Force
}

$settingsDest = Join-Path $IdeData "User\settings.json"
Copy-Item (Join-Path $Root "templates\settings.json") $settingsDest -Force
$venvPy = Join-Path $Root ".venv\Scripts\python.exe"
$sqlite = Join-Path $Root "data\local.sqlite"
$settingsText = Get-Content $settingsDest -Raw -Encoding utf8
$settingsText = $settingsText.Replace("__LOCALCODER_PYTHON__", ($venvPy -replace "\\", "/"))
$settingsText = $settingsText.Replace("__LOCALCODER_SQLITE__", ($sqlite -replace "\\", "/"))
Set-Content -Path $settingsDest -Value $settingsText -Encoding utf8
$apply = Join-Path $Root "learn\apply_sources.py"
if (Test-Path $apply) {
    python $apply $Root | Out-Null
}
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
$env:TALON_KIT = $Root
# Cline's current bundle stores provider/onboarding in CLINE_DIR, not VS Code settings.
$env:CLINE_DIR = Join-Path $IdeData "cline-home"

$kbSrc = Join-Path $Root "templates\keybindings.json"
$kbDest = Join-Path $IdeData "User\keybindings.json"
if (Test-Path $kbSrc) {
    Copy-Item $kbSrc $kbDest -Force
}

$mediaRoot = Split-Path $codium
$media = Join-Path $mediaRoot "resources\app\out\media"
$dark = Join-Path $Root "branding\letterpress-dark.svg"
if ((Test-Path $media) -and (Test-Path $dark)) {
    try {
        Copy-Item $dark (Join-Path $media "letterpress-dark.svg") -Force -ErrorAction Stop
        Copy-Item $dark (Join-Path $media "letterpress-hcDark.svg") -Force -ErrorAction SilentlyContinue
        $light = Join-Path $Root "branding\letterpress-light.svg"
        if (Test-Path $light) {
            Copy-Item $light (Join-Path $media "letterpress-light.svg") -Force -ErrorAction SilentlyContinue
            Copy-Item $light (Join-Path $media "letterpress-hcLight.svg") -Force -ErrorAction SilentlyContinue
        }
        $codeIcon = Join-Path $Root "branding\code-icon.svg"
        if (Test-Path $codeIcon) {
            Copy-Item $codeIcon (Join-Path $media "code-icon.svg") -Force -ErrorAction SilentlyContinue
            Copy-Item $codeIcon (Join-Path $media "vscode-icon.svg") -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "Could not refresh VSCodium marks (editor may be open)."
    }
}

$warmPy = Join-Path $Root "learn\warmup.py"
$warmExe = Join-Path $Root ".venv\Scripts\pythonw.exe"
if (-not (Test-Path $warmExe)) { $warmExe = Join-Path $Root ".venv\Scripts\python.exe" }
if ((Test-Path $warmPy) -and (Test-Path $warmExe)) {
    Start-Process -FilePath $warmExe -ArgumentList @("`"$warmPy`"") -WindowStyle Hidden
    Write-Host "Warming the local model in the background..."
}

$wsFile = Join-Path $IdeData "Talon.code-workspace"
$openTarget = $Workspace
if (Test-Path $wsFile) { $openTarget = $wsFile }

Get-CimInstance Win32_Process -Filter "Name = 'VSCodium.exe'" | ForEach-Object {
    $cl = [string]$_.CommandLine
    if ($cl -and ($cl.ToLower().Contains("local ai") -or $cl -match 'work\\Local')) {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2

# Launch goes through Open-Talon.cmd so "Local AI" stays one path.
# Do not pass USAGE.md as a launch file.
$learnPy = Join-Path $Root "learn\talon_learn.py"
$venvPy = Join-Path $Root ".venv\Scripts\pythonw.exe"
if (-not (Test-Path $venvPy)) { $venvPy = Join-Path $Root ".venv\Scripts\python.exe" }
$learnArgs = @("`"$learnPy`"", "--watch", "--kit", "`"$Root`"", "--workspace", "`"$Workspace`"")
$sourcesFile = Join-Path $IdeData "sources.json"
if (Test-Path $sourcesFile) {
    $src = Get-Content $sourcesFile -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($folder in @($src.folders)) {
        if ($folder.path) { $learnArgs += @("--workspace", "`"$($folder.path)`"") }
    }
}
if ((Test-Path $learnPy) -and (Test-Path $venvPy)) {
    Start-Process -FilePath $venvPy -ArgumentList $learnArgs -WindowStyle Hidden
}

Write-Host "Opening Talon - Local AI (VSCodium + Cline + Ollama)..."
Write-Host "Workspace: $openTarget"
if (-not (Test-Path $sourcesFile)) {
    Write-Host "No PHI folder connected yet. Run Connect.cmd to attach a local folder or database."
}
Write-Host "Background learner is mapping data and lessons on this PC only."
Write-Host "GitHub remotes and GitHub login are blocked in this window."
cmd.exe /c "`"$Root\Open-Talon.cmd`""
