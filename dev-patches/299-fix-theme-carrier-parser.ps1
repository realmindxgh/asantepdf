param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$carrier = Join-Path $SourceRoot 'dev-patches\300-theme-pdfium-runtime-hardening.ps1'
if (-not (Test-Path $carrier)) { throw "Carrier not found: $carrier" }

$text = [System.IO.File]::ReadAllText($carrier)

$oldLine = @'
$devWorkflow = $devWorkflow.Replace("            throw 'Normal UI did not report a successfully opened PDF within 20 seconds.'", "            throw \"Normal UI did not complete the multi-page open path. Opened=`$opened Thumbnails=`$thumbnails.\"")
'@
$newLine = @'
$devWorkflow = $devWorkflow.Replace("            throw 'Normal UI did not report a successfully opened PDF within 20 seconds.'", "            throw `"Normal UI did not complete the multi-page open path. Opened=`$opened Thumbnails=`$thumbnails.`"")
'@
if (-not $text.Contains($oldLine)) { throw 'Could not locate the malformed development-workflow replacement line.' }
$text = $text.Replace($oldLine, $newLine)

$oldImports = @'
using System.Windows.Media;
using System.Windows.Shapes;

namespace PdfRescue.App.Services;
'@
$newImports = @'
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace PdfRescue.App.Services;
'@
if (-not $text.Contains($oldImports)) { throw 'Could not locate AppearanceService imports in the staged carrier.' }
$text = $text.Replace($oldImports, $newImports)

[System.IO.File]::WriteAllText($carrier, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host 'Corrected theme/PDFium hardening carrier parser and dispatcher import.' -ForegroundColor Green
