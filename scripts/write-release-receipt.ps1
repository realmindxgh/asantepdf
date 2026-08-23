param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [string]$OutputDirectory = (Join-Path (Resolve-Path "$PSScriptRoot\..") 'dist\release-evidence'),
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$versionFile = Join-Path $root 'VERSION'
if ([string]::IsNullOrWhiteSpace($Version)) {
    if (-not (Test-Path $versionFile)) { throw 'VERSION file is missing.' }
    $Version = (Get-Content $versionFile -Raw).Trim()
}
if ($Version -match '-rc(?<number>[0-9]+)$') {
    $releaseLabel = "RC$($Matches.number)"
} else {
    $releaseLabel = ($Version -replace '[^A-Za-z0-9._-]', '_')
}
$installer = (Resolve-Path $InstallerPath).Path
$appExe = Join-Path $root 'dist\app\AsantePDF.exe'
$preinstallFlag = Join-Path $root 'dist\selftest-preinstall\final-candidate-pass.flag'
$installedFlag = Join-Path $root 'dist\selftest-installed\final-candidate-pass.flag'

foreach ($required in @($installer, $appExe, $preinstallFlag, $installedFlag)) {
    if (-not (Test-Path $required)) {
        throw "Release receipt cannot be written because required evidence is missing: $required"
    }
}

Remove-Item $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$installerHash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$appHash = (Get-FileHash $appExe -Algorithm SHA256).Hash.ToLowerInvariant()
$installerBytes = (Get-Item $installer).Length
$appBytes = (Get-Item $appExe).Length
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$repository = if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { 'local' }
$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { 'local' }
$sourceSha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { 'local' }

$receipt = @"
AsantePDF Windows Release Receipt

Version: $Version
Generated UTC: $timestamp
Release gate: SUCCESS
Repository: $repository
GitHub Actions run ID: $runId
Source commit: $sourceSha

Installer: AsantePDF Setup.exe
Installer bytes: $installerBytes
Installer SHA256: $installerHash

Published executable: AsantePDF.exe
Executable bytes: $appBytes
Executable SHA256: $appHash

Validated gate:
- static source validation
- Release x64 compilation
- automated smoke tests
- self-contained Windows x64 publish
- bundled qpdf, Tesseract, LibreOffice and VC++ redistributable
- final candidate functional self-test against the published application
- Inno Setup installer compilation
- silent installation of the exact generated AsantePDF Setup.exe
- launch and verification of the installed Program Files copy
- installed-copy final candidate functional self-test

Evidence flags:
- selftest-preinstall/final-candidate-pass.flag = pass
- selftest-installed/final-candidate-pass.flag = pass
"@

$receiptPath = Join-Path $OutputDirectory "AsantePDF-$releaseLabel-Release-Receipt.txt"
$checksumPath = Join-Path $OutputDirectory "AsantePDF-$releaseLabel-SHA256.txt"
$receipt | Set-Content -Path $receiptPath -Encoding UTF8
@(
    "$installerHash  AsantePDF Setup.exe",
    "$appHash  AsantePDF.exe"
) | Set-Content -Path $checksumPath -Encoding ASCII

Copy-Item $preinstallFlag (Join-Path $OutputDirectory 'preinstall-final-candidate-pass.flag') -Force
Copy-Item $installedFlag (Join-Path $OutputDirectory 'installed-final-candidate-pass.flag') -Force

$engineManifest = Join-Path $root 'dist\app\engines\ENGINE-VERSIONS.txt'
if (Test-Path $engineManifest) {
    Copy-Item $engineManifest (Join-Path $OutputDirectory 'ENGINE-VERSIONS.txt') -Force
}
$vcHashFile = Join-Path $root 'dist\prereqs\VC-REDIST-SHA256.txt'
if (Test-Path $vcHashFile) {
    Copy-Item $vcHashFile (Join-Path $OutputDirectory 'VC-REDIST-SHA256.txt') -Force
}

$zip = Join-Path (Split-Path $OutputDirectory -Parent) "AsantePDF-$releaseLabel-Release-Evidence.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $OutputDirectory '*') -DestinationPath $zip -CompressionLevel Optimal

Write-Host "Release receipt written: $receiptPath" -ForegroundColor Green
Write-Host "Release checksums written: $checksumPath" -ForegroundColor Green
Write-Host "Release evidence ZIP written: $zip" -ForegroundColor Green
