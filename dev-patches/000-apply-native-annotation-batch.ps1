param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$root = Join-Path $SourceRoot 'dev-patches'
& (Join-Path $root '310-native-annotations.ps1') -SourceRoot $SourceRoot
if (-not $?) { throw 'Native annotation carrier failed.' }
& (Join-Path $root '311-native-annotation-compile-fix.ps1') -SourceRoot $SourceRoot
if (-not $?) { throw 'Native annotation compile fix failed.' }
Write-Host 'Native annotation batch applied in deterministic order.' -ForegroundColor Green
