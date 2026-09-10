<#
.SYNOPSIS
    Signs the Exalere Windows executable and installer using Authenticode digital signature.

.DESCRIPTION
    Supports using an official PFX certificate (with password) or automatically generating/using
    a local Authenticode code-signing certificate with RFC 3161 timestamping.
    Used for both local builds and automated GitHub Actions CI/CD workflows.

.PARAMETER TargetPath
    Path to the .exe file to sign (e.g. build\windows\x64\runner\Release\exalere.exe).

.PARAMETER PfxPath
    Optional path to a .pfx code signing certificate file.

.PARAMETER PfxPassword
    Optional password for the .pfx certificate.

.PARAMETER TimestampServer
    RFC 3161 timestamp authority URL. Defaults to DigiCert.
#>

param(
    [string]$TargetPath = "",
    [string]$PfxPath = "",
    [string]$PfxPassword = "",
    [string]$TimestampServer = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Exalere Windows Authenticode Code-Signing Utility     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Resolve target files to sign
$targets = @()
if ($TargetPath -and (Test-Path $TargetPath)) {
    $targets += (Resolve-Path $TargetPath).Path
} else {
    $candidates = @(
        "build\windows\x64\runner\Release\exalere.exe",
        "build\windows\runner\Release\exalere.exe",
        "build\Exalere-Windows-Setup-x64.exe",
        "windows\build\Exalere-Windows-Setup-x64.exe",
        ".\Exalere-Windows-Setup-x64.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $targets += (Resolve-Path $cand).Path
        }
    }
}

if ($targets.Count -eq 0) {
    Write-Warning "No target executable found to sign. Build the project first via: flutter build windows --release"
    exit 0
}

# Resolve or create certificate
$cert = $null

if ($PfxPath -and (Test-Path $PfxPath)) {
    Write-Host "[1/3] Loading provided PFX certificate from: $PfxPath" -ForegroundColor Green
    $secPass = ConvertTo-SecureString $PfxPassword -AsPlainText -Force
    $cert = Get-PfxCertificate -FilePath $PfxPath
    if (!$cert) {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Resolve-Path $PfxPath).Path, $PfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    }
} else {
    Write-Host "[1/3] Checking Windows Certificate Store for 'CN=Abhishek Razy' / 'Exalere'..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue | 
             Where-Object { $_.Subject -like "*Abhishek Razy*" -or $_.Subject -like "*Exalere*" } | 
             Select-Object -First 1

    if ($found) {
        Write-Host "      Found existing code-signing certificate: $($found.Thumbprint)" -ForegroundColor Green
        $cert = $found
    } else {
        Write-Host "      Creating Authenticode code-signing certificate for Abhishek Razy (abhishekrazy.com)..." -ForegroundColor Yellow
        $cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject "CN=Abhishek Razy, O=abhishekrazy.com, OU=Mobile & TV Development, L=Chandigarh, S=Chandigarh, C=IN" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -KeyExportPolicy Exportable `
            -NotAfter (Get-Date).AddYears(10) `
            -FriendlyName "Exalere Release Code Signing"

        Write-Host "      Created new certificate: $($cert.Thumbprint)" -ForegroundColor Green
    }
}

if (!$cert) {
    Write-Error "Failed to obtain a code-signing certificate."
    exit 1
}

# Sign each executable
Write-Host "[2/3] Applying Authenticode signature with timestamping ($TimestampServer)..." -ForegroundColor Cyan

foreach ($target in $targets) {
    Write-Host "      Signing: $target" -ForegroundColor White
    try {
        $sig = Set-AuthenticodeSignature -FilePath $target -Certificate $cert -TimestampServer $TimestampServer -HashAlgorithm SHA256
        if ($sig.Status -eq "Valid" -or $sig.Status -eq "UnknownError") {
            Write-Host "      [OK] Signature applied successfully! Status: $($sig.Status)" -ForegroundColor Green
        } else {
            Write-Host "      [INFO] Signature status: $($sig.Status) ($($sig.StatusMessage))" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "      Timestamp server fallback to Sectigo..."
        $sig = Set-AuthenticodeSignature -FilePath $target -Certificate $cert -TimestampServer "http://timestamp.sectigo.com" -HashAlgorithm SHA256
        Write-Host "      [OK] Signature applied! Status: $($sig.Status)" -ForegroundColor Green
    }
}

# Verify signatures
Write-Host "[3/3] Verifying signatures on generated binaries..." -ForegroundColor Cyan
foreach ($target in $targets) {
    $verification = Get-AuthenticodeSignature -FilePath $target
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "File:       $($target)" -ForegroundColor White
    Write-Host "Signer:     $($verification.SignerCertificate.Subject)" -ForegroundColor White
    Write-Host "Thumbprint: $($verification.SignerCertificate.Thumbprint)" -ForegroundColor DarkCyan
    Write-Host "Status:     $($verification.Status)" -ForegroundColor Green
    Write-Host "TimeStamper:$($verification.TimeStamperCertificate.Subject)" -ForegroundColor DarkGray
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Windows Code Signing Completed Successfully!           " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
