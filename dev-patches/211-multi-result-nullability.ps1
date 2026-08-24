param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference='Stop'
$p=Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
$t=[IO.File]::ReadAllText($p)
$before='await InvokeToolOnUiAsync(runAgain);'
$after='await InvokeToolOnUiAsync(runAgain!);'
if(-not $t.Contains($before)){throw 'Target not found.'}
[IO.File]::WriteAllText($p,$t.Replace($before,$after),[Text.UTF8Encoding]::new($false))
Write-Host 'Nullability hardening applied.'
