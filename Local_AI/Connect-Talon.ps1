#requires -Version 5.1
<#
.SYNOPSIS
  Attach a local PHI folder and/or database, then open Talon.
#>
param(
    [string]$Folder = "",
    [string]$Sqlite = "",
    [string]$SqlServer = "",
    [string]$SqlDatabase = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$IdeData = Join-Path $Root "ide-data"
$SourcesPath = Join-Path $IdeData "sources.json"
New-Item -ItemType Directory -Force -Path $IdeData | Out-Null

function Read-Sources {
    if (-not (Test-Path $SourcesPath)) {
        return [ordered]@{
            folders   = @()
            databases = @(
                [ordered]@{
                    name = "Local SQLite"
                    kind = "sqlite"
                    path = (Join-Path $Root "data\local.sqlite")
                }
            )
        }
    }
    return (Get-Content $SourcesPath -Raw -Encoding utf8 | ConvertFrom-Json)
}

function Save-Sources($obj) {
    $json = $obj | ConvertTo-Json -Depth 6
    Set-Content -Path $SourcesPath -Value $json -Encoding utf8
}

function Pick-Folder([string]$Message) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Message
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return "" }
    return $dialog.SelectedPath
}

function Pick-File([string]$Filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = $Filter
    $dialog.CheckFileExists = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return "" }
    return $dialog.FileName
}

$sources = Read-Sources
if (-not $sources.folders) { $sources | Add-Member -NotePropertyName folders -NotePropertyValue @() -Force }
if (-not $sources.databases) { $sources | Add-Member -NotePropertyName databases -NotePropertyValue @() -Force }

if (-not $Folder -and -not $Sqlite -and -not $SqlServer) {
    Write-Host "Talon - connect local PHI" -ForegroundColor Cyan
    Write-Host "Data stays on this PC. Do not pick a cloud-synced folder if you can avoid it."
    Write-Host ""
    Write-Host "1) Add a local folder (CSV, Excel, SQLite, extracts)"
    Write-Host "2) Add a SQLite file"
    Write-Host "3) Add SQL Server on this PC (Windows auth)"
    Write-Host "4) Save and open Talon"
    Write-Host "5) Show current connections"
    Write-Host "6) Quit"
    $choice = Read-Host "Choice"
    switch ($choice) {
        "1" { $Folder = Pick-Folder "Folder that holds PHI on this PC" }
        "2" { $Sqlite = Pick-File "SQLite (*.sqlite;*.db)|*.sqlite;*.db|All files (*.*)|*.*" }
        "3" {
            $SqlServer = Read-Host "Server (default 127.0.0.1)"
            if (-not $SqlServer) { $SqlServer = "127.0.0.1" }
            $SqlDatabase = Read-Host "Database name"
        }
        "4" { }
        "5" {
            Write-Host ($sources | ConvertTo-Json -Depth 6)
            exit 0
        }
        default { exit 0 }
    }
}

if ($Folder) {
    $name = Split-Path $Folder -Leaf
    $sources.folders = @($sources.folders) + @([ordered]@{ name = $name; path = $Folder })
    Write-Host "Added folder: $Folder"
}

if ($Sqlite) {
    $name = [IO.Path]::GetFileNameWithoutExtension($Sqlite)
    $sources.databases = @($sources.databases) + @([ordered]@{ name = $name; kind = "sqlite"; path = $Sqlite })
    $parent = Split-Path $Sqlite -Parent
    $sources.folders = @($sources.folders) + @([ordered]@{ name = (Split-Path $parent -Leaf); path = $parent })
    Write-Host "Added SQLite: $Sqlite"
}

if ($SqlServer -and $SqlDatabase) {
    $sources.databases = @($sources.databases) + @([ordered]@{
            name     = $SqlDatabase
            kind     = "mssql"
            server   = $SqlServer
            database = $SqlDatabase
            trusted  = $true
        })
    Write-Host "Added SQL Server: $SqlServer / $SqlDatabase (Windows auth)"
}

Save-Sources $sources
Write-Host "Saved $SourcesPath"

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }
& $py (Join-Path $Root "learn\apply_sources.py") $Root

if (-not $NoLaunch) {
    $open = $Folder
    if (-not $open -and $Sqlite) { $open = Split-Path $Sqlite -Parent }
    if ($open) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "run.ps1") -Workspace $open
    } else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "run.ps1")
    }
}
