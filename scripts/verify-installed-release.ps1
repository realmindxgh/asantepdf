param(
    [Parameter(Mandatory = $true)] [string]$InstallerPath,
    [Parameter(Mandatory = $true)] [string]$SamplePdf,
    [string]$OutputDirectory = (Join-Path (Resolve-Path "$PSScriptRoot\..") 'dist\selftest-installed')
)

$ErrorActionPreference = 'Stop'
$installer = [System.IO.Path]::GetFullPath($InstallerPath)
$sample = [System.IO.Path]::GetFullPath($SamplePdf)
if (-not (Test-Path $installer)) { throw "Installer not found: $installer" }
if (-not (Test-Path $sample)) { throw "Sample PDF not found: $sample" }

Write-Host 'Silently installing the exact generated AsantePDF installer...' -ForegroundColor Cyan
$install = Start-Process -FilePath $installer `
    -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/TASKS=""') `
    -Wait -PassThru
if ($install.ExitCode -notin @(0,3010)) { throw "Installer failed with exit code $($install.ExitCode)." }

$installedExe = Join-Path $env:ProgramFiles 'AsantePDF\AsantePDF.exe'
if (-not (Test-Path $installedExe)) { throw "Installed application not found: $installedExe" }

$logDir = Join-Path $env:LOCALAPPDATA 'AsantePDF\Logs'
$readyFlag = Join-Path $logDir 'window-ready.flag'
Remove-Item $readyFlag -Force -ErrorAction SilentlyContinue

Write-Host 'Launching the installed copy and checking the WPF ready flag...' -ForegroundColor Cyan
$app = Start-Process -FilePath $installedExe -PassThru
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path $readyFlag) { $ready = $true; break }
    if ($app.HasExited) { break }
}
if (-not $ready) {
    if (Test-Path (Join-Path $logDir 'startup.log')) { Get-Content (Join-Path $logDir 'startup.log') | Write-Host }
    try { if (-not $app.HasExited) { $app.Kill() } } catch { }
    throw 'Installed AsantePDF did not reach its main-window ready state.'
}
try { if (-not $app.HasExited) { $app.Kill() } } catch { }

Remove-Item $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Write-Host 'Running final self-test through the installed copy...' -ForegroundColor Cyan
$selfTest = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-final', $sample, $OutputDirectory) -Wait -PassThru
if ($selfTest.ExitCode -ne 0) {
    $errorFile = Join-Path $OutputDirectory 'final-candidate-error.txt'
    if (Test-Path $errorFile) { Get-Content $errorFile | Write-Host }
    throw "Installed-copy final self-test failed with exit code $($selfTest.ExitCode)."
}
if (-not (Test-Path (Join-Path $OutputDirectory 'final-candidate-pass.flag'))) {
    throw 'Installed-copy self-test did not write the pass flag.'
}

Write-Host 'Installed-copy verification passed.' -ForegroundColor Green
