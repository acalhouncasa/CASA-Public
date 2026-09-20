#requires -Version 5.1
<#
.SYNOPSIS
  Attach a local project/PHI folder or database, then open Talon.
#>
param(
    [string]$Folder = "",
    [ValidateSet("", "project", "phi", "other")]
    [string]$Role = "",
    [string]$Sqlite = "",
    [string]$SqlServer = "",
    [string]$SqlDatabase = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root "tools\LocalPaths.ps1")
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

function Ensure-List($obj, [string]$Name) {
    if (-not $obj.$Name) {
        $obj | Add-Member -NotePropertyName $Name -NotePropertyValue @() -Force
    }
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

function Folder-Exists($sources, [string]$Path) {
    $norm = Normalize-TalonPath $Path
    foreach ($item in @($sources.folders)) {
        if ($item.path -and ((Normalize-TalonPath $item.path) -eq $norm)) { return $true }
    }
    return $false
}

function Database-Exists($sources, [string]$Kind, [string]$Key) {
    $want = $Key.ToLowerInvariant()
    foreach ($item in @($sources.databases)) {
        if ($item.kind -ne $Kind) { continue }
        $have = if ($item.path) { $item.path } else { "$($item.server)/$($item.database)" }
        if (([string]$have).ToLowerInvariant() -eq $want) { return $true }
    }
    return $false
}

function Add-ConnectedFolder($sources, [string]$Path, [string]$FolderRole) {
    if (-not $Path) { return $false }
    if (-not (Confirm-TalonLocalPath $Path "connect")) { return $false }
    $full = [IO.Path]::GetFullPath($Path)
    if (Folder-Exists $sources $full) {
        Write-Host "Already connected: $full"
        return $true
    }
    $leaf = Split-Path $full -Leaf
    $name = switch ($FolderRole) {
        "phi" { "PHI: $leaf" }
        "project" { "Project: $leaf" }
        default { $leaf }
    }
    $sources.folders = @($sources.folders) + @([ordered]@{
            name = $name
            path = $full
            role = $FolderRole
        })
    Write-Host "Added folder ($FolderRole): $full"
    return $true
}

function Show-Sources($sources) {
    Write-Host ""
    Write-Host "Folders" -ForegroundColor Cyan
    $i = 1
    foreach ($item in @($sources.folders)) {
        Write-Host ("  F{0}. {1}  {2}" -f $i, $item.name, $item.path)
        $i++
    }
    if (@($sources.folders).Count -eq 0) { Write-Host "  (none)" }
    Write-Host "Databases" -ForegroundColor Cyan
    $i = 1
    foreach ($item in @($sources.databases)) {
        $detail = if ($item.path) { $item.path } else { "$($item.server) / $($item.database)" }
        Write-Host ("  D{0}. {1} ({2})  {3}" -f $i, $item.name, $item.kind, $detail)
        $i++
    }
}

function Remove-Connection($sources) {
    Show-Sources $sources
    $pick = Read-Host "Remove which? Example F1 or D2"
    if ($pick -match '^[Ff](\d+)$') {
        $idx = [int]$Matches[1] - 1
        $list = @($sources.folders)
        if ($idx -lt 0 -or $idx -ge $list.Count) { Write-Host "No such folder."; return }
        Write-Host "Removed folder: $($list[$idx].path)"
        $keep = @()
        for ($i = 0; $i -lt $list.Count; $i++) {
            if ($i -ne $idx) { $keep += $list[$i] }
        }
        $sources.folders = $keep
        return
    }
    if ($pick -match '^[Dd](\d+)$') {
        $idx = [int]$Matches[1] - 1
        $list = @($sources.databases)
        if ($idx -lt 0 -or $idx -ge $list.Count) { Write-Host "No such database."; return }
        if ($list[$idx].name -eq "Local SQLite") {
            Write-Host "Local SQLite is the kit scratch DB and stays."
            return
        }
        Write-Host "Removed database: $($list[$idx].name)"
        $keep = @()
        for ($i = 0; $i -lt $list.Count; $i++) {
            if ($i -ne $idx) { $keep += $list[$i] }
        }
        $sources.databases = $keep
        return
    }
    Write-Host "Enter F1 or D2."
}

function Test-LocalSqlHost([string]$Server) {
    $s = $Server.Trim().ToLowerInvariant()
    if ($s -in @("127.0.0.1", "localhost", "(local)", ".", "localhost\sqlexpress", "127.0.0.1\sqlexpress")) {
        return $true
    }
    if ($s.StartsWith("127.0.0.1\") -or $s.StartsWith("localhost\")) { return $true }
    $machine = $env:COMPUTERNAME.ToLowerInvariant()
    if ($s -eq $machine -or $s.StartsWith("$machine\")) { return $true }
    return $false
}

$sources = Read-Sources
Ensure-List $sources "folders"
Ensure-List $sources "databases"

$launched = $false
$interactive = -not ($Folder -or $Sqlite -or $SqlServer)

if ($interactive) {
    do {
        Write-Host ""
        Write-Host "Talon Connect" -ForegroundColor Cyan
        Write-Host "Keep the kit as the main root. Attach project and PHI beside it."
        Write-Host "Do not pick OneDrive / Desktop / Downloads if they hold PHI."
        Write-Host ""
        Write-Host "1) Add a project folder"
        Write-Host "2) Add a PHI folder"
        Write-Host "3) Add a SQLite file"
        Write-Host "4) Add SQL Server on this PC (Windows auth)"
        Write-Host "5) Remove a connection"
        Write-Host "6) Backup memory to a local folder"
        Write-Host "7) Show current connections"
        Write-Host "8) Save and open Talon"
        Write-Host "9) Quit"
        $choice = Read-Host "Choice"
        switch ($choice) {
            "1" {
                $picked = Pick-Folder "Project folder (SQL, notebooks, scripts)"
                if ($picked) { [void](Add-ConnectedFolder $sources $picked "project") }
            }
            "2" {
                $picked = Pick-Folder "PHI folder on this PC"
                if ($picked) { [void](Add-ConnectedFolder $sources $picked "phi") }
            }
            "3" { $Sqlite = Pick-File "SQLite (*.sqlite;*.db)|*.sqlite;*.db|All files (*.*)|*.*" }
            "4" {
                $SqlServer = Read-Host "Server (default 127.0.0.1)"
                if (-not $SqlServer) { $SqlServer = "127.0.0.1" }
                $SqlDatabase = Read-Host "Database name"
            }
            "5" { Remove-Connection $sources }
            "6" {
                Save-Sources $sources
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "Backup-TalonMemory.ps1")
            }
            "7" { Show-Sources $sources }
            "8" { $launched = $true }
            default { Save-Sources $sources; exit 0 }
        }

        if ($Sqlite) {
            if (Confirm-TalonLocalPath $Sqlite "connect") {
                $full = [IO.Path]::GetFullPath($Sqlite)
                if (Database-Exists $sources "sqlite" $full) {
                    Write-Host "Already connected: $full"
                } else {
                    $name = [IO.Path]::GetFileNameWithoutExtension($full)
                    $sources.databases = @($sources.databases) + @([ordered]@{ name = $name; kind = "sqlite"; path = $full })
                    Write-Host "Added SQLite: $full"
                }
                $parent = Split-Path $full -Parent
                [void](Add-ConnectedFolder $sources $parent "phi")
            }
            $Sqlite = ""
        }
        if ($SqlServer -and $SqlDatabase) {
            if (-not (Test-LocalSqlHost $SqlServer)) {
                Write-Host "Server '$SqlServer' does not look local. Prefer 127.0.0.1." -ForegroundColor Yellow
                $ans = Read-Host "Type YES to add it anyway"
                if ($ans -ne "YES") { $SqlServer = ""; $SqlDatabase = ""; continue }
            }
            $key = "$SqlServer/$SqlDatabase"
            if (Database-Exists $sources "mssql" $key) {
                Write-Host "Already connected: $key"
            } else {
                $sources.databases = @($sources.databases) + @([ordered]@{
                        name     = $SqlDatabase
                        kind     = "mssql"
                        server   = $SqlServer
                        database = $SqlDatabase
                        trusted  = $true
                    })
                Write-Host "Added SQL Server: $SqlServer / $SqlDatabase (Windows auth)"
            }
            $SqlServer = ""
            $SqlDatabase = ""
        }
        Save-Sources $sources
    } while (-not $launched)
} else {
    if ($Folder) {
        if (-not $Role) { $Role = "phi" }
        [void](Add-ConnectedFolder $sources $Folder $Role)
    }
    if ($Sqlite -and (Confirm-TalonLocalPath $Sqlite "connect")) {
        $full = [IO.Path]::GetFullPath($Sqlite)
        if (-not (Database-Exists $sources "sqlite" $full)) {
            $name = [IO.Path]::GetFileNameWithoutExtension($full)
            $sources.databases = @($sources.databases) + @([ordered]@{ name = $name; kind = "sqlite"; path = $full })
            Write-Host "Added SQLite: $full"
        }
        [void](Add-ConnectedFolder $sources (Split-Path $full -Parent) "phi")
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
    $launched = -not $NoLaunch
}

Write-Host "Saved $SourcesPath"

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }
& $py (Join-Path $Root "learn\apply_sources.py") $Root

if ($launched -and -not $NoLaunch) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "run.ps1")
}
