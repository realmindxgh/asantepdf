param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [string]$OutputDirectory = (Join-Path (Resolve-Path "$PSScriptRoot\..") 'dist\release-evidence'),
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$versionFile = Join-Path $root 'VERSION'

Write-Host '=== Release receipt diagnostics ===' -ForegroundColor Cyan
Write-Host "Repository root: $root"
Write-Host "Requested installer path: $InstallerPath"
Write-Host "Output directory: $OutputDirectory"
Write-Host "VERSION file: $versionFile (exists=$([bool](Test-Path $versionFile)))"

if ([string]::IsNullOrWhiteSpace($Version)) {
    if (-not (Test-Path $versionFile)) { throw 'VERSION file is missing.' }
    $Version = (Get-Content $versionFile -Raw).Trim()
}
Write-Host "Resolved version: $Version"

if ($Version -match '-rc(?<number>[0-9]+)$') {
    $releaseLabel = "RC$($Matches.number)"
} else {
    $releaseLabel = ($Version -replace '[^A-Za-z0-9._-]', '_')
}
Write-Host "Release label: $releaseLabel"

Write-Host "Installer exists before Resolve-Path: $([bool](Test-Path $InstallerPath))"
$installer = (Resolve-Path $InstallerPath).Path
$appExe = Join-Path $root 'dist\app\AsantePDF.exe'
$preinstallFlag = Join-Path $root 'dist\selftest-preinstall\final-candidate-pass.flag'
$installedFlagCandidates = @(
    (Join-Path $root 'dist\installed-final-candidate-pass.flag'),
    (Join-Path $root 'dist\selftest-installed\final-selftest\final-candidate-pass.flag'),
    (Join-Path $root 'dist\selftest-installed\final-candidate-pass.flag')
)
$installedFlag = $installedFlagCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $installedFlag) {
    $installedFlag = $installedFlagCandidates[0]
}

Write-Host "Resolved installer path: $installer"
Write-Host "Published executable: $appExe"
Write-Host "Preinstall flag: $preinstallFlag"
for ($i = 0; $i -lt $installedFlagCandidates.Count; $i++) {
    Write-Host "Installed flag candidate $($i + 1): $($installedFlagCandidates[$i]) (exists=$([bool](Test-Path $installedFlagCandidates[$i])))"
}
Write-Host "Selected installed flag: $installedFlag"

foreach ($required in @($installer, $appExe, $preinstallFlag, $installedFlag)) {
    $exists = Test-Path $required
    Write-Host "Required evidence: $required (exists=$([bool]$exists))"
    if (-not $exists) {
        throw "Release receipt cannot be written because required evidence is missing: $required"
    }
}

Write-Host "Resetting output directory: $OutputDirectory"
Remove-Item $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Write-Host "Output directory ready: $([bool](Test-Path $OutputDirectory))"

Write-Host 'Hashing final installer bytes...'
$installerHash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host 'Hashing published executable bytes...'
$appHash = (Get-FileHash $appExe -Algorithm SHA256).Hash.ToLowerInvariant()
$installerBytes = (Get-Item $installer).Length
$appBytes = (Get-Item $appExe).Length
Write-Host "Installer bytes: $installerBytes"
Write-Host "Installer SHA256: $installerHash"
Write-Host "Executable bytes: $appBytes"
Write-Host "Executable SHA256: $appHash"

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$repository = if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { 'local' }
$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { 'local' }
$sourceSha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { 'local' }
Write-Host "GitHub repository: $repository"
Write-Host "GitHub run ID: $runId"
Write-Host "Source commit: $sourceSha"

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
- installed-copy Light/Dark visual, DPI, representative-PDF and restart/Resume acceptance
- installed-copy final candidate functional self-test

Evidence flags:
- selftest-preinstall/final-candidate-pass.flag = pass
- installed-final-candidate-pass.flag = pass
"@

$receiptPath = Join-Path $OutputDirectory "AsantePDF-$releaseLabel-Release-Receipt.txt"
$checksumPath = Join-Path $OutputDirectory "AsantePDF-$releaseLabel-SHA256.txt"
Write-Host "Receipt path: $receiptPath"
Write-Host "Checksum path: $checksumPath"
Write-Host 'Writing release receipt...'
$receipt | Set-Content -Path $receiptPath -Encoding UTF8
Write-Host 'Writing checksum file...'
@(
    "$installerHash  AsantePDF Setup.exe",
    "$appHash  AsantePDF.exe"
) | Set-Content -Path $checksumPath -Encoding ASCII
Write-Host "Receipt exists after write: $([bool](Test-Path $receiptPath))"
Write-Host "Checksum exists after write: $([bool](Test-Path $checksumPath))"

Write-Host 'Copying preinstall evidence flag...'
Copy-Item $preinstallFlag (Join-Path $OutputDirectory 'preinstall-final-candidate-pass.flag') -Force
Write-Host 'Copying installed evidence flag...'
Copy-Item $installedFlag (Join-Path $OutputDirectory 'installed-final-candidate-pass.flag') -Force

$engineManifest = Join-Path $root 'dist\app\engines\ENGINE-VERSIONS.txt'
Write-Host "Engine manifest: $engineManifest (exists=$([bool](Test-Path $engineManifest)))"
if (Test-Path $engineManifest) {
    Copy-Item $engineManifest (Join-Path $OutputDirectory 'ENGINE-VERSIONS.txt') -Force
}
$vcHashFile = Join-Path $root 'dist\prereqs\VC-REDIST-SHA256.txt'
Write-Host "VC++ checksum evidence: $vcHashFile (exists=$([bool](Test-Path $vcHashFile)))"
if (Test-Path $vcHashFile) {
    Copy-Item $vcHashFile (Join-Path $OutputDirectory 'VC-REDIST-SHA256.txt') -Force
}

$zip = Join-Path (Split-Path $OutputDirectory -Parent) "AsantePDF-$releaseLabel-Release-Evidence.zip"
Write-Host "Evidence ZIP destination: $zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Write-Host 'Compressing release evidence...'
Compress-Archive -Path (Join-Path $OutputDirectory '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Host "Evidence ZIP exists after compression: $([bool](Test-Path $zip))"

Write-Host "Release receipt written: $receiptPath" -ForegroundColor Green
Write-Host "Release checksums written: $checksumPath" -ForegroundColor Green
Write-Host "Release evidence ZIP written: $zip" -ForegroundColor Green
