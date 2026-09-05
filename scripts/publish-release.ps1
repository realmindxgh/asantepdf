param(
    [switch]$SkipEngineInstall
)

$ErrorActionPreference = 'Stop'

function Assert-LastExitCode([string]$Operation) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}
$root = Resolve-Path "$PSScriptRoot\.."
$dist = Join-Path $root 'dist'
$appOut = Join-Path $dist 'app'
$prereqs = Join-Path $dist 'prereqs'
$selfTestOut = Join-Path $dist 'selftest-preinstall'
$samplePdf = Join-Path $dist 'release-sample.pdf'
$versionFile = Join-Path $root 'VERSION'
if (-not (Test-Path $versionFile)) { throw 'VERSION file is missing.' }
$releaseVersion = (Get-Content $versionFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($releaseVersion)) { throw 'VERSION file is empty.' }

Remove-Item $appOut -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $selfTestOut -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $appOut, $prereqs, $selfTestOut | Out-Null

Write-Host 'Restoring solution...' -ForegroundColor Cyan
dotnet restore (Join-Path $root 'AsantePDF.sln')
Assert-LastExitCode 'dotnet restore'

Write-Host 'Building solution in Release...' -ForegroundColor Cyan
dotnet build (Join-Path $root 'AsantePDF.sln') -c Release -p:Platform=x64 --no-restore
Assert-LastExitCode 'dotnet build'

Write-Host 'Running core smoke tests...' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\PdfRescue.SmokeTests\PdfRescue.SmokeTests.csproj') -c Release --no-build
Assert-LastExitCode 'core smoke tests'

Write-Host 'Publishing self-contained Windows x64 application...' -ForegroundColor Cyan
dotnet publish (Join-Path $root 'src\PdfRescue.App\PdfRescue.App.csproj') `
    -c Release -r win-x64 --self-contained true -p:Platform=x64 -p:PublishReadyToRun=false `
    -o $appOut
Assert-LastExitCode 'dotnet publish'

& (Join-Path $PSScriptRoot 'stage-release-engines.ps1') -Destination $appOut -SkipInstall:$SkipEngineInstall

$notices = Join-Path $root 'THIRD-PARTY-NOTICES.md'
if (Test-Path $notices) { Copy-Item $notices (Join-Path $appOut 'THIRD-PARTY-NOTICES.md') -Force }

Write-Host 'Downloading current Microsoft Visual C++ v14 x64 Redistributable...' -ForegroundColor Cyan
$vcRedist = Join-Path $prereqs 'vc_redist.x64.exe'
Invoke-WebRequest 'https://aka.ms/vc14/vc_redist.x64.exe' -OutFile $vcRedist
if ((Get-Item $vcRedist).Length -lt 5MB) { throw 'Downloaded VC++ redistributable is unexpectedly small.' }
$vcHash = (Get-FileHash $vcRedist -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -Path (Join-Path $prereqs 'VC-REDIST-SHA256.txt') -Value "$vcHash  vc_redist.x64.exe" -Encoding ASCII

# The final candidate must exercise genuine multi-page behaviour before installation.
& (Join-Path $PSScriptRoot 'New-SamplePdf.ps1') -OutputPath $samplePdf -PageCount 12
& (Join-Path $appOut 'engines\qpdf\qpdf.exe') --check $samplePdf
if ($LASTEXITCODE -notin @(0,3)) { throw 'The generated PDF fixture failed qpdf validation.' }

Write-Host 'Running the full candidate self-test against the published application...' -ForegroundColor Cyan
$process = Start-Process -FilePath (Join-Path $appOut 'AsantePDF.exe') `
    -ArgumentList @('--selftest-final', $samplePdf, $selfTestOut) -Wait -PassThru
if ($process.ExitCode -ne 0) {
    $errorFile = Join-Path $selfTestOut 'final-candidate-error.txt'
    if (Test-Path $errorFile) { Get-Content $errorFile | Write-Host }
    throw "Published app final self-test failed with exit code $($process.ExitCode)."
}
if (-not (Test-Path (Join-Path $selfTestOut 'final-candidate-pass.flag'))) {
    throw 'Published app did not produce final-candidate-pass.flag.'
}

Write-Host 'Compiling the production installer...' -ForegroundColor Cyan
$isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
$isccPath = if ($isccCommand) { $isccCommand.Source } else { $null }
if (-not $isccPath) {
    $candidate = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
    if (Test-Path $candidate) { $isccPath = $candidate }
}
if (-not $isccPath) { throw 'Inno Setup compiler (ISCC.exe) was not found.' }
& $isccPath "/DMyAppDisplayVersion=$releaseVersion" (Join-Path $root 'installer\AsantePDF.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }

$installer = Join-Path $dist 'installer\AsantePDF Setup.exe'
if (-not (Test-Path $installer)) { throw 'Expected installer was not produced.' }
Write-Host "Release installer built: $installer" -ForegroundColor Green
