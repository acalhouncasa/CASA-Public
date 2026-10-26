#requires -Version 5.1
<#
.SYNOPSIS
  Copy a newer Local Coder kit over this folder without wiping PHI or the profile.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$From
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = (Resolve-Path $From).Path

if (-not (Test-Path (Join-Path $Source "run.ps1"))) {
    $nested = Join-Path $Source "Local_AI"
    if (Test-Path (Join-Path $nested "run.ps1")) { $Source = $nested }
}
if (-not (Test-Path (Join-Path $Source "run.ps1"))) {
    throw "No Local Coder kit at $From (expected run.ps1)."
}
if ($Source -eq $Root) {
    throw "Source and destination are the same folder."
}

$skipTop = @("ide-data", "ide-extensions", ".venv", "dist", "logs", ".git")
$skipExt = @(".sqlite", ".csv", ".xlsx", ".parquet", ".log")
# examples\*.csv is kit demo data and is safe to refresh
$allowCsvUnder = @("examples")

Write-Host "Update Local Coder" -ForegroundColor Cyan
Write-Host "From: $Source"
Write-Host "To:   $Root"
Write-Host "Leaving ide-data, .venv, and working data files in place."

Get-ChildItem $Source -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($Source.Length).TrimStart("\", "/")
    $top = ($rel -split "[\\/]")[0]
    if ($skipTop -contains $top) { return }
    $ext = $_.Extension.ToLowerInvariant()
    if ($skipExt -contains $ext) {
        $underExamples = $rel.StartsWith("examples\", [System.StringComparison]::OrdinalIgnoreCase)
        if (-not ($ext -eq ".csv" -and $underExamples)) { return }
    }
    $dest = Join-Path $Root $rel
    $destDir = Split-Path $dest -Parent
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $_.FullName $dest -Force
}

Write-Host ""
Write-Host "Files updated. Profile and SQLite were not touched."
Write-Host "Next: python .\seed_cline.py .\ide-data"
Write-Host "Then: .\doctor.ps1"
