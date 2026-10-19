<#
.SYNOPSIS
    Create the client chart flags procedures on a non-production SmartCare database.

.DESCRIPTION
    Refuses database names that contain Prod or Production.
    Does not register My Reports and does not upload the RDL.
    Do not test in Prod.

.NOTES
    Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
    Created: 2026-10-19
    Last Modified: 2026-10-19
    License: MIT

.EXAMPLE
    .\Apply_NonProd.ps1 -Server 'your-sql-host' -Database 'YourSmartCareTrain'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [Parameter(Mandatory = $true)]
    [string]$Database,
    [string]$User,
    [string]$Password
)

$ErrorActionPreference = 'Stop'

if ($Database -match '(?i)prod') {
    Write-Error "Stop. Do not test in Prod. Database '$Database' contains Prod. Pass a Train, QA, or Test database name."
    exit 1
}

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if (-not $sqlcmd) {
    $fallback = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'
    if (Test-Path -LiteralPath $fallback) {
        $sqlcmdPath = $fallback
    }
    else {
        Write-Error 'sqlcmd was not found. Install SQL Server command-line tools, or run the sql files in SSMS on a non-production database.'
        exit 1
    }
}
else {
    $sqlcmdPath = $sqlcmd.Source
}

$root = $PSScriptRoot

$check = Join-Path $root 'sql\01_readonly_check.sql'
$apply = Join-Path $root 'sql\02_create_procedures.sql'

function Invoke-ScSql {
    param([string]$File)
    $args = @('-S', $Server, '-d', $Database, '-b', '-I', '-W', '-i', $File)
    if ($User) {
        $args += @('-U', $User, '-P', $Password)
    }
    else {
        $args += '-E'
    }
    & $sqlcmdPath @args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "sqlcmd failed ($LASTEXITCODE) on $File. No further files were run."
        exit $LASTEXITCODE
    }
}

Write-Host "Non-production database: $Database on $Server"
Write-Host 'Running read-only check, then creating procedures.'
Invoke-ScSql -File $check
Invoke-ScSql -File $apply
Write-Host 'Procedures created. Edit rdl/ClientChartFlags.rdl and upload it to the non-production report server only. Do not test in Prod.'
