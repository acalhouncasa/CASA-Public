# Sign toolkit scripts with an organization Authenticode certificate.
# This is the legitimate way to stop "unknown publisher" prompts internally.
param(
    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,
    [string]$TimestampServer = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cert = Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My |
    Where-Object { $_.Thumbprint -eq ($Thumbprint -replace '\s', '') } |
    Select-Object -First 1
if (-not $cert) {
    throw "No code-signing certificate with thumbprint $Thumbprint in CurrentUser or LocalMachine My."
}
if (-not $cert.HasPrivateKey) {
    throw "Certificate has no private key on this machine."
}

$files = @(Get-ChildItem $Root -File -Include *.ps1, *.psd1, *.psm1)
$files += Get-ChildItem (Join-Path $Root "pack") -File -Include *.ps1 -ErrorAction SilentlyContinue
$files = $files | Where-Object { $_ -and $_.FullName -notmatch '\\ide-data\\|\\ide-extensions\\|\\dist\\' } | Sort-Object FullName -Unique

foreach ($file in $files) {
    Write-Host "Signing $($file.Name)"
    $sig = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $cert -TimestampServer $TimestampServer -HashAlgorithm SHA256
    Write-Host "  $($sig.Status) $($sig.StatusMessage)"
    if ($sig.Status -ne "Valid") {
        throw "Signature failed for $($file.FullName): $($sig.Status)"
    }
}

Write-Host "Signed $($files.Count) script(s) with $($cert.Subject)"
Write-Host "Inno Setup EXE signing (if you built one):"
Write-Host '  signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /sha1 THUMBPRINT dist\LocalCoder-*-Setup.exe'
