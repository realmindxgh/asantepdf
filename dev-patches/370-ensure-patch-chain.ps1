param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
# The development workflow checks $LASTEXITCODE after each PowerShell carrier.
# Pure PowerShell/.NET carriers may leave it null, which makes the workflow exit successfully
# before later carriers run. Seed an explicit zero so this one coherent corrective chain runs fully.
$global:LASTEXITCODE = 0
Write-Host 'Final contract patch chain initialized.' -ForegroundColor Cyan
