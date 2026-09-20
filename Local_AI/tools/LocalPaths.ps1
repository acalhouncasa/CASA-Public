# Shared path checks for Connect and memory backup. Dot-source only.

function Get-TalonCloudRoots {
    $roots = @()
    foreach ($name in @("OneDrive", "OneDriveConsumer", "OneDriveCommercial")) {
        $val = [Environment]::GetEnvironmentVariable($name)
        if ($val) { $roots += $val }
    }
    foreach ($known in @("Desktop", "MyDocuments")) {
        try {
            $p = [Environment]::GetFolderPath($known)
            if ($p) { $roots += $p }
        } catch { }
    }
    $downloads = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path $downloads) { $roots += $downloads }
    return @($roots | Where-Object { $_ } | ForEach-Object {
            try { [IO.Path]::GetFullPath($_) } catch { $_ }
        } | Select-Object -Unique)
}

function Test-TalonCloudPath([string]$Path) {
    if (-not $Path) { return $false }
    try { $full = [IO.Path]::GetFullPath($Path) } catch { return $true }
    $low = $full.ToLowerInvariant()
    if ($low -match '\\onedrive\\' -or $low -match '\\onedrive -') { return $true }
    foreach ($root in Get-TalonCloudRoots) {
        $r = $root.TrimEnd("\").ToLowerInvariant()
        if ($low -eq $r -or $low.StartsWith($r + "\")) { return $true }
    }
    return $false
}

function Confirm-TalonLocalPath([string]$Path, [string]$Action = "use") {
    if (-not $Path) { return $false }
    if (-not (Test-Path $Path)) {
        Write-Host "Path not found: $Path" -ForegroundColor Red
        return $false
    }
    if (-not (Test-TalonCloudPath $Path)) { return $true }
    Write-Host ""
    Write-Host "This path looks like Desktop, Documents, Downloads, or OneDrive." -ForegroundColor Yellow
    Write-Host $Path
    Write-Host "PHI there can sync off this PC. Prefer a local disk such as D:\TalonPHI." -ForegroundColor Yellow
    $ans = Read-Host "Type YES to $Action this path anyway"
    return ($ans -eq "YES")
}

function Normalize-TalonPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd("\").ToLowerInvariant()
}
