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

$settingsRoot = Join-Path $env:LOCALAPPDATA 'AsantePDF'
New-Item -ItemType Directory -Force -Path $settingsRoot | Out-Null
@{
    theme = 'Light'
    defaultRenderWidth = 1100
    defaultPageView = 'SinglePage'
    reopenLastSession = $false
    trackRecentFiles = $false
    showRecentThumbnails = $false
    defaultOcrLanguage = 'eng'
    defaultOutputFolder = ''
    outputNamePattern = '{name}-{operation}'
    existingOutput = 'CreateUniqueCopy'
    recoveryEnabled = $false
    checkForUpdates = $false
    firstLaunchCompleted = $true
} | ConvertTo-Json | Set-Content (Join-Path $settingsRoot 'settings.json') -Encoding UTF8

$logDir = Join-Path $settingsRoot 'Logs'
$readyFlag = Join-Path $logDir 'window-ready.flag'
$startupLog = Join-Path $logDir 'startup.log'
Remove-Item $logDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host 'Launching the installed copy in Light mode, opening a PDF, and checking that the normal UI remains alive...' -ForegroundColor Cyan
$app = Start-Process -FilePath $installedExe -ArgumentList @($sample) -PassThru
$ready = $false
$opened = $false
for ($i = 0; $i -lt 80; $i++) {
    Start-Sleep -Milliseconds 500
    $app.Refresh()
    if (Test-Path $readyFlag) { $ready = $true }
    if (Test-Path $startupLog) {
        $log = Get-Content $startupLog -Raw
        if ($log -match 'Opened PDF:') { $opened = $true }
    }
    if ($app.HasExited -or ($ready -and $opened)) { break }
}
if (-not $ready -or -not $opened -or $app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    try { if (-not $app.HasExited) { $app.Kill() } } catch { }
    throw "Installed AsantePDF failed the normal Light-mode PDF-open UI regression. Ready=$ready Opened=$opened Exited=$($app.HasExited)."
}
Start-Sleep -Seconds 3
$app.Refresh()
if ($app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    throw "Installed AsantePDF opened the PDF but then exited unexpectedly with code $($app.ExitCode)."
}
try { $app.Kill() } catch { }

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
