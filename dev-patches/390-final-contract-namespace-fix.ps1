param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\ToolConfigurationDialogs.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$old = "using Microsoft.Win32;`nusing PdfRescue.Core.Models;"
$new = "using Microsoft.Win32;`nusing PdfRescue.App.Services;`nusing PdfRescue.Core.Models;"
if (-not $text.Contains($old)) { throw 'ToolConfigurationDialogs using anchor not found.' }
$text = $text.Replace($old, $new)
[IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'ToolConfigurationDialogs service namespace imported.' -ForegroundColor Green
exit 0
