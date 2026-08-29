param(
    [Parameter(Mandatory = $true)] [string]$InstallerPath,
    [Parameter(Mandatory = $true)] [string]$SamplePdf,
    [string]$OutputDirectory = (Join-Path (Resolve-Path "$PSScriptRoot\..") 'dist\selftest-installed')
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\.."
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
$logDir = Join-Path $settingsRoot 'Logs'
$startupLog = Join-Path $logDir 'startup.log'
New-Item -ItemType Directory -Force -Path $settingsRoot | Out-Null

function Write-TestSettings([string]$Theme) {
    @{
        theme = $Theme
        defaultRenderWidth = 1100
        defaultPageView = 'SinglePage'
        reopenLastSession = $true
        trackRecentFiles = $true
        showRecentThumbnails = $true
        defaultOcrLanguage = 'eng'
        defaultOutputFolder = ''
        outputNamePattern = '{name}-{operation}'
        existingOutput = 'CreateUniqueCopy'
        recoveryEnabled = $false
        checkForUpdates = $false
        firstLaunchCompleted = $true
    } | ConvertTo-Json | Set-Content (Join-Path $settingsRoot 'settings.json') -Encoding UTF8
}

function Run-InstalledUiProbe([string]$Theme, [string]$Pdf, [int]$ExpectedPages, [int]$LingerSeconds, [string]$Label) {
    Write-TestSettings $Theme
    Remove-Item $logDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Write-Host "Installed UI probe: ${Label} / $Theme / $ExpectedPages pages" -ForegroundColor Cyan
    $app = Start-Process -FilePath $installedExe -ArgumentList @($Pdf) -PassThru
    $ready = $false
    $opened = $false
    $thumbnails = $false
    for ($i = 0; $i -lt 220; $i++) {
        Start-Sleep -Milliseconds 500
        $app.Refresh()
        if ($app.HasExited) {
            if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
            throw "$Label exited while opening in $Theme mode. Exit=$($app.ExitCode)"
        }
        if (Test-Path $startupLog) {
            $log = Get-Content $startupLog -Raw
            if ($log -match 'Main window loaded and ready flag written') { $ready = $true }
            if ($log -match 'Opened PDF: foreground view refresh completed') { $opened = $true }
            if ($log -match "Thumbnail rendering completed: $ExpectedPages pages") { $thumbnails = $true }
        }
        if ($ready -and $opened -and $thumbnails) { break }
    }
    if (-not ($ready -and $opened -and $thumbnails)) {
        if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
        try { if (-not $app.HasExited) { $app.Kill() } } catch { }
        throw "$Label did not complete the installed UI open path in $Theme. Ready=$ready Opened=$opened Thumbnails=$thumbnails"
    }
    Start-Sleep -Seconds $LingerSeconds
    $app.Refresh()
    if ($app.HasExited) {
        if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
        throw "$Label completed open but then exited in $Theme mode. Exit=$($app.ExitCode)"
    }
    try { $app.Kill() } catch { }
}

Remove-Item $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$themeOutput = Join-Path $OutputDirectory 'theme-runtime'
New-Item -ItemType Directory -Force -Path $themeOutput | Out-Null
Write-TestSettings 'Light'
Write-Host 'Running installed-copy Light/Dark Home, Recent, Settings, Task Center, workspace and DPI visual probe...' -ForegroundColor Cyan
$themeProbe = Start-Process -FilePath $installedExe -ArgumentList @('--selftest-theme', $themeOutput, $sample) -Wait -PassThru
if ($themeProbe.ExitCode -ne 0 -or -not (Test-Path (Join-Path $themeOutput 'theme-runtime-pass.flag'))) {
    $themeError = Join-Path $themeOutput 'theme-runtime-error.txt'
    if (Test-Path $themeError) { Get-Content $themeError | Write-Host }
    throw "Installed AsantePDF failed the full runtime theme/DPI probe with exit code $($themeProbe.ExitCode)."
}

# The release sample is deliberately 12 pages. Exercise it from the Program Files copy
# in both themes before moving on to more unusual document shapes.
Run-InstalledUiProbe 'Light' $sample 12 8 'release sample'
Run-InstalledUiProbe 'Dark' $sample 12 8 'release sample'

$corpus = Join-Path $root 'dist\installed-regression-corpus'
& (Join-Path $PSScriptRoot 'New-PdfRegressionCorpus.ps1') -OutputDirectory $corpus
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$cases = @(
    @{ Name='research-like-18.pdf'; Pages=18 },
    @{ Name='scanned-image-only-8.pdf'; Pages=8 },
    @{ Name='feature-rich-3.pdf'; Pages=3 },
    @{ Name='rotated-cropped-6.pdf'; Pages=6 },
    @{ Name='large-text-50.pdf'; Pages=50 }
)
foreach ($theme in @('Light','Dark')) {
    foreach ($case in $cases) {
        Run-InstalledUiProbe $theme (Join-Path $corpus $case.Name) $case.Pages 4 $case.Name
    }
}

# Prove lifecycle persistence across two distinct executions of the exact Program Files EXE.
# Seed runs the real first-launch dialog, real theme toggle, opens two tabs and closes cleanly.
# Verify starts a fresh process, proves onboarding does not recur, then uses the real Recent
# Resume/Grid/List/Compact controls to restore the two-tab page-3 session.
$lifecycleOutput = Join-Path $OutputDirectory 'lifecycle-restart'
Remove-Item $lifecycleOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $lifecycleOutput | Out-Null
$lifecycleSecond = Join-Path $corpus 'research-like-18.pdf'
Write-Host 'Running installed first-launch/session seed through the real Program Files EXE...' -ForegroundColor Cyan
$lifecycleSeed = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-lifecycle-seed', $sample, $lifecycleSecond, $lifecycleOutput) -Wait -PassThru
if ($lifecycleSeed.ExitCode -ne 0 -or -not (Test-Path (Join-Path $lifecycleOutput 'lifecycle-seed-pass.flag'))) {
    $lifecycleError = Join-Path $lifecycleOutput 'lifecycle-restart-error.txt'
    if (Test-Path $lifecycleError) { Get-Content $lifecycleError | Write-Host }
    throw "Installed lifecycle seed failed with exit code $($lifecycleSeed.ExitCode)."
}

Write-Host 'Restarting installed AsantePDF to verify onboarding, settings, Recent and Resume persistence...' -ForegroundColor Cyan
$lifecycleVerify = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-lifecycle-verify', $sample, $lifecycleSecond, $lifecycleOutput) -Wait -PassThru
if ($lifecycleVerify.ExitCode -ne 0 -or -not (Test-Path (Join-Path $lifecycleOutput 'lifecycle-verify-pass.flag'))) {
    $lifecycleError = Join-Path $lifecycleOutput 'lifecycle-restart-error.txt'
    if (Test-Path $lifecycleError) { Get-Content $lifecycleError | Write-Host }
    throw "Installed lifecycle restart verification failed with exit code $($lifecycleVerify.ExitCode)."
}

$finalOutput = Join-Path $OutputDirectory 'final-selftest'
Remove-Item $finalOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $finalOutput | Out-Null
Write-Host 'Running final engine and document-operation self-test through the installed copy...' -ForegroundColor Cyan
$selfTest = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-final', $sample, $finalOutput) -Wait -PassThru
if ($selfTest.ExitCode -ne 0) {
    $errorFile = Join-Path $finalOutput 'final-candidate-error.txt'
    if (Test-Path $errorFile) { Get-Content $errorFile | Write-Host }
    throw "Installed-copy final self-test failed with exit code $($selfTest.ExitCode)."
}
if (-not (Test-Path (Join-Path $finalOutput 'final-candidate-pass.flag'))) {
    throw 'Installed-copy self-test did not write the pass flag.'
}

Copy-Item (Join-Path $corpus 'CORPUS-MANIFEST.txt') (Join-Path $OutputDirectory 'CORPUS-MANIFEST.txt') -Force
Write-Host 'Installed-copy theme, DPI, representative PDF and engine verification passed.' -ForegroundColor Green
