param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '320-context-menus-dragdrop.ps1') -SourceRoot $SourceRoot

$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ContextMenusAndDrop.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$needle = "using System.Windows.Controls;`n`nnamespace PdfRescue.App;"
$replacement = "using System.Windows.Controls;`nusing PdfRescue.App.Services;`n`nnamespace PdfRescue.App;"
if (-not $text.Contains($needle)) { throw 'Context-menu generated source import anchor not found.' }
$text = $text.Replace($needle, $replacement)
[IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'Context-menu namespace fix staged.' -ForegroundColor Green
