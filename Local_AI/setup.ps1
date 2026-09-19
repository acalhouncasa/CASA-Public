#requires -Version 5.1
<#
.SYNOPSIS
  Install Local Coder (VSCodium + Cline + local Ollama).
.DESCRIPTION
  Pulls publisher-signed apps from winget or from payload\. Does not pack
  other installers into a self-extracting EXE.
#>
param(
    [switch]$SkipDeps,
    [switch]$PullModel,
    [string]$Model = "qwen3-coder:30b",
    [switch]$NoShortcuts,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$IdeData = Join-Path $Root "ide-data"
$IdeExt = Join-Path $Root "ide-extensions"
$Templates = Join-Path $Root "templates"
$Payload = Join-Path $Root "payload"
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Transcript = Join-Path $LogDir ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $Transcript -Append | Out-Null

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Find-VSCodiumCli {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\VSCodium\bin\codium.cmd"),
        (Join-Path ${env:ProgramFiles} "VSCodium\bin\codium.cmd")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command codium -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-VSCodiumExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\VSCodium\VSCodium.exe"),
        (Join-Path ${env:ProgramFiles} "VSCodium\VSCodium.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Apply-Letterpress {
    $exe = Find-VSCodiumExe
    if (-not $exe) { return }
    $media = Join-Path (Split-Path $exe) "resources\app\out\media"
    $dark = Join-Path $Root "branding\letterpress-dark.svg"
    $light = Join-Path $Root "branding\letterpress-light.svg"
    if (-not ((Test-Path $media) -and (Test-Path $dark))) { return }
    foreach ($name in @("letterpress-dark.svg", "letterpress-hcDark.svg")) {
        $dest = Join-Path $media $name
        if (Test-Path $dest) { Copy-Item $dark $dest -Force }
    }
    foreach ($name in @("letterpress-light.svg", "letterpress-hcLight.svg")) {
        $dest = Join-Path $media $name
        if (Test-Path $dest) { Copy-Item $light $dest -Force }
    }
    $codeIcon = Join-Path $Root "branding\code-icon.svg"
    if (Test-Path $codeIcon) {
        foreach ($name in @("code-icon.svg", "vscode-icon.svg")) {
            $dest = Join-Path $media $name
            if (Test-Path $dest) { Copy-Item $codeIcon $dest -Force }
        }
    }
    Write-Host "VSCodium marks set to Local Coder brackets."
}

function Find-Ollama {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"),
        (Join-Path ${env:ProgramFiles} "Ollama\ollama.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-Python {
    foreach ($name in @("py", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        try {
            $out = & $cmd --version 2>&1 | Out-String
            if ($out -match "Python 3") { return $cmd.Source }
        } catch {
            continue
        }
    }
    return $null
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-WingetPackage([string]$Id) {
    Write-Host "winget install $Id"
    winget install -e --id $Id --scope user --accept-package-agreements --accept-source-agreements
    Refresh-Path
}

function Install-SilentPayload([string]$Pattern, [string]$WingetId) {
    $file = $null
    if (Test-Path $Payload) {
        $file = Get-ChildItem -Path $Payload -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like $Pattern } |
            Select-Object -First 1
    }
    if ($file) {
        Write-Host "Running publisher installer: $($file.Name)"
        $args = @("/VERYSILENT", "/NORESTART", "/CURRENTUSER")
        $proc = Start-Process -FilePath $file.FullName -ArgumentList $args -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "Installer failed ($($proc.ExitCode)): $($file.Name)"
        }
        Refresh-Path
        return
    }
    Install-WingetPackage $WingetId
}

Write-Step "Local Coder setup"
Write-Host "Kit:    $Root"
Write-Host "Log:    $Transcript"
Write-Host "This installer uses official VSCodium, Ollama, and Cline packages."
Write-Host "It does not disable Windows security tools."

if (-not $SkipDeps) {
    Write-Step "Ollama"
    if (Find-Ollama) {
        Write-Host "Ollama already present."
    } else {
        Install-SilentPayload -Pattern "Ollama*.exe" -WingetId "Ollama.Ollama"
    }

    Write-Step "VSCodium"
    if (Find-VSCodiumCli) {
        Write-Host "VSCodium already present."
    } else {
        Install-SilentPayload -Pattern "VSCodium*Setup*.exe" -WingetId "VSCodium.VSCodium"
    }

    if (-not (Find-Python)) {
        Write-Step "Python (needed to seed Cline settings)"
        Install-WingetPackage "Python.Python.3.12"
    }
}

[System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "127.0.0.1:11434", "User")
$env:OLLAMA_HOST = "127.0.0.1:11434"
Write-Host "OLLAMA_HOST=127.0.0.1:11434"

$codium = Find-VSCodiumCli
if (-not $codium) {
    throw "VSCodium CLI not found after install. Open a new terminal and re-run setup.ps1."
}
Write-Host "VSCodium CLI: $codium"

New-Item -ItemType Directory -Force -Path (Join-Path $IdeData "User") | Out-Null
New-Item -ItemType Directory -Force -Path $IdeExt | Out-Null
Copy-Item (Join-Path $Templates "settings.json") (Join-Path $IdeData "User\settings.json") -Force
Copy-Item (Join-Path $Templates "argv.json") (Join-Path $IdeData "argv.json") -Force
Apply-Letterpress

Write-Step "Cline extension (isolated profile)"
$vsix = $null
if (Test-Path $Payload) {
    $vsix = Get-ChildItem -Path $Payload -Filter "*.vsix" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
$clineAlready = Get-ChildItem $IdeExt -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "saoudrizwan.claude-dev-*" }
if ($clineAlready) {
    Write-Host "Cline already installed: $($clineAlready.Name)"
} else {
    $installArgs = @(
        "--user-data-dir", $IdeData,
        "--extensions-dir", $IdeExt
    )
    if ($vsix) {
        Write-Host "Installing Cline from payload: $($vsix.Name)"
        $installArgs += @("--install-extension", $vsix.FullName, "--force")
    } else {
        Write-Host "Installing Cline from Open VSX: saoudrizwan.claude-dev"
        $installArgs += @("--install-extension", "saoudrizwan.claude-dev", "--force")
    }
    & $codium @installArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Cline extension install failed (exit $LASTEXITCODE)."
    }
}

$py = Find-Python
if ($py) {
    Write-Step "Seed Cline for local Ollama"
    if ($py -like "*\py.exe") {
        & $py -3 (Join-Path $Root "seed_cline.py") $IdeData
    } else {
        & $py (Join-Path $Root "seed_cline.py") $IdeData
    }
} else {
    Write-Warning "Python not found. Open Local Coder once, then pick Ollama in Cline settings."
}

Write-Step "Python + SQL extensions (Open VSX, isolated profile)"
$localExt = @(
    "ms-python.python",
    "ms-python.debugpy",
    "charliermarsh.ruff",
    "mtxr.sqltools",
    "mtxr.sqltools-driver-sqlite",
    "ms-toolsai.jupyter"
)
$extArgs = @(
    "--user-data-dir", $IdeData,
    "--extensions-dir", $IdeExt
)
foreach ($ext in $localExt) {
    $already = Get-ChildItem $IdeExt -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$ext-*" }
    if ($already) {
        Write-Host "Already installed: $($already.Name)"
        continue
    }
    Write-Host "Installing $ext"
    & $codium ($extArgs + @("--install-extension", $ext))
}

if ($py) {
    Write-Step "Local data-science venv (pandas, SQLAlchemy, Jupyter)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "setup-datasci.ps1")
}

if ($PullModel) {
    Write-Step "Pull model $Model (large download)"
    $ollama = Find-Ollama
    if (-not $ollama) { throw "Ollama not found; cannot pull $Model" }
    & $ollama pull $Model
}

if (-not $NoShortcuts) {
    Write-Step "Shortcuts"
    $programs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Local Coder"
    New-Item -ItemType Directory -Force -Path $programs | Out-Null
    $wscript = New-Object -ComObject WScript.Shell
    $lnk = $wscript.CreateShortcut((Join-Path $programs "Local Coder.lnk"))
    $vbs = Join-Path $Root "Launch-LocalCoder.vbs"
    $lnk.TargetPath = "$env:SystemRoot\System32\wscript.exe"
    $lnk.Arguments = "`"$vbs`""
    $lnk.WorkingDirectory = $Root
    $lnk.WindowStyle = 1
    $lnk.Description = "Local Coder (on-device Ollama)"
    $ico = Join-Path $Root "branding\icon.ico"
    if (Test-Path $ico) {
        $lnk.IconLocation = "$ico,0"
    }
    $lnk.Save()
    $desk = [Environment]::GetFolderPath("Desktop")
    Copy-Item (Join-Path $programs "Local Coder.lnk") (Join-Path $desk "Local Coder.lnk") -Force
    Write-Host "Start Menu: $programs"
    Write-Host "Desktop: $(Join-Path $desk 'Local Coder.lnk')"
}

if ($Strict) {
    Write-Step "Strict team mode (commands not auto-approved)"
    $override = Join-Path $IdeData "team-overrides.json"
    '{"autoApproveCommands": false}' | Set-Content -Path $override -Encoding utf8
    $pyStrict = Find-Python
    if ($pyStrict) {
        if ($pyStrict -like "*\py.exe") {
            & $pyStrict -3 (Join-Path $Root "seed_cline.py") $IdeData
        } else {
            & $pyStrict (Join-Path $Root "seed_cline.py") $IdeData
        }
    }
}

Write-Host ""
Write-Host "Setup finished." -ForegroundColor Green
Write-Host "  Start Menu: Local Coder"
Write-Host "  Or: .\run.ps1"
Write-Host "  Verify: .\doctor.ps1"
Write-Host "  Optional admin lock: .\harden-firewall.ps1"
Write-Host "Keep Cline on Ollama. Do not put PHI in a cloud IDE or browser chat."
Stop-Transcript | Out-Null
