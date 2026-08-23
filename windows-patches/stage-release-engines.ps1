param(
    [string]$Destination = (Join-Path (Resolve-Path "$PSScriptRoot\..") 'dist\app'),
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
$destination = [System.IO.Path]::GetFullPath($Destination)
$engines = Join-Path $destination 'engines'
New-Item -ItemType Directory -Force -Path $engines | Out-Null

$qpdfVersion = '12.3.2'
$tesseractVersion = '5.5.3.20260724'
$libreOfficeVersion = '26.2.3'

function Install-PinnedPackage([string]$Name, [string]$Version) {
    if ($SkipInstall) { return }
    if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
        throw 'Chocolatey is required to stage the release engines on the Windows release runner.'
    }
    Write-Host "Installing $Name $Version for release staging..." -ForegroundColor Cyan
    & choco install $Name --version $Version -y --no-progress --limit-output
    if ($LASTEXITCODE -notin @(0, 1641, 3010)) {
        throw "Chocolatey failed to install $Name $Version. Exit code $LASTEXITCODE"
    }
}

Install-PinnedPackage 'qpdf' $qpdfVersion
Install-PinnedPackage 'tesseract' $tesseractVersion
Install-PinnedPackage 'libreoffice-fresh' $libreOfficeVersion

# QPDF. Chocolatey extracts the official 64-bit archive below its package tools directory.
$qpdfPackage = Join-Path $env:ChocolateyInstall 'lib\qpdf\tools'
$qpdfExe = Get-ChildItem $qpdfPackage -Recurse -Filter qpdf.exe -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\bin\\qpdf\.exe$' } |
    Select-Object -First 1
if (-not $qpdfExe) {
    $command = Get-Command qpdf.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notmatch '\\chocolatey\\bin\\') {
        $qpdfExe = Get-Item $command.Source
    }
}
if (-not $qpdfExe) { throw 'Could not locate the installed qpdf.exe.' }
$qpdfDest = Join-Path $engines 'qpdf'
Remove-Item $qpdfDest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $qpdfDest | Out-Null
Copy-Item (Join-Path $qpdfExe.Directory.FullName '*') $qpdfDest -Recurse -Force
if (-not (Test-Path (Join-Path $qpdfDest 'qpdf.exe'))) { throw 'Bundled qpdf.exe was not staged.' }

# Tesseract. The Windows installer places the engine and tessdata together.
$tesseractSource = Join-Path $env:ProgramFiles 'Tesseract-OCR'
if (-not (Test-Path (Join-Path $tesseractSource 'tesseract.exe'))) {
    $tessCommand = Get-Command tesseract.exe -ErrorAction SilentlyContinue
    if ($tessCommand -and $tessCommand.Source -notmatch '\\chocolatey\\bin\\') {
        $tesseractSource = Split-Path $tessCommand.Source -Parent
    }
}
if (-not (Test-Path (Join-Path $tesseractSource 'tesseract.exe'))) { throw 'Could not locate Tesseract OCR.' }
$tesseractDest = Join-Path $engines 'tesseract'
Remove-Item $tesseractDest -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $tesseractSource $tesseractDest -Recurse -Force
if (-not (Test-Path (Join-Path $tesseractDest 'tesseract.exe'))) { throw 'Bundled Tesseract was not staged.' }
if (-not (Test-Path (Join-Path $tesseractDest 'tessdata\eng.traineddata'))) {
    throw 'Tesseract English trained data is missing from the staged release.'
}

# LibreOffice. Copy the installed application tree so Office-to-PDF works without requiring a separate install.
$libreOfficeSource = Join-Path $env:ProgramFiles 'LibreOffice'
if (-not (Test-Path (Join-Path $libreOfficeSource 'program\soffice.exe'))) {
    $soffice = Get-Command soffice.exe -ErrorAction SilentlyContinue
    if ($soffice) {
        $libreOfficeSource = Split-Path (Split-Path $soffice.Source -Parent) -Parent
    }
}
if (-not (Test-Path (Join-Path $libreOfficeSource 'program\soffice.exe'))) { throw 'Could not locate LibreOffice.' }
$libreOfficeDest = Join-Path $engines 'libreoffice'
Remove-Item $libreOfficeDest -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $libreOfficeSource $libreOfficeDest -Recurse -Force
if (-not (Test-Path (Join-Path $libreOfficeDest 'program\soffice.exe'))) { throw 'Bundled LibreOffice was not staged.' }

Write-Host 'Validating staged engines...' -ForegroundColor Cyan
$qpdfProbe = (& (Join-Path $qpdfDest 'qpdf.exe') --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Bundled qpdf failed its version probe.' }
if ($qpdfProbe -notmatch [regex]::Escape($qpdfVersion)) {
    throw "Bundled qpdf version mismatch. Expected $qpdfVersion; got: $qpdfProbe"
}
Write-Host $qpdfProbe

$tesseractProbe = (& (Join-Path $tesseractDest 'tesseract.exe') --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Bundled Tesseract failed its version probe.' }
if ($tesseractProbe -notmatch [regex]::Escape("tesseract v$tesseractVersion")) {
    throw "Bundled Tesseract version mismatch. Expected $tesseractVersion; got: $tesseractProbe"
}
Write-Host (($tesseractProbe -split "`r?`n")[0])

$libreOfficeProbe = (& (Join-Path $libreOfficeDest 'program\soffice.exe') --headless --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Bundled LibreOffice failed its version probe.' }
if ($libreOfficeProbe -notmatch [regex]::Escape($libreOfficeVersion)) {
    throw "Bundled LibreOffice version mismatch. Expected $libreOfficeVersion; got: $libreOfficeProbe"
}
Write-Host $libreOfficeProbe

$manifest = @"
AsantePDF bundled engine manifest
Generated: $([DateTimeOffset]::UtcNow.ToString('O'))
qpdf: $qpdfVersion
Tesseract OCR: $tesseractVersion
LibreOffice Fresh: $libreOfficeVersion
"@
Set-Content -Path (Join-Path $engines 'ENGINE-VERSIONS.txt') -Value $manifest -Encoding UTF8
Write-Host "Release engines staged under $engines" -ForegroundColor Green
