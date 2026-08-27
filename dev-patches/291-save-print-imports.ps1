param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.SavePrint.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$old = @'
using System.IO;
using System.Printing;
using System.Windows;
using PdfRescue.App.Services;
'@
$new = @'
using System.IO;
using System.Printing;
using System.Windows;
using System.Windows.Controls;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;
'@
$old = $old.Replace("`r`n", "`n")
$new = $new.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'Save/Print using block was not found after carrier 290.' }
[IO.File]::WriteAllText($path, $text.Replace($old, $new).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'Save/Print compile imports corrected.' -ForegroundColor Green
& cmd /c exit 0