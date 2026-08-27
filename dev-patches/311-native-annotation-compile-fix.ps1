param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\NativePdfAnnotationService.cs'
$text = Normalize ([IO.File]::ReadAllText($path))
$old = @'
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
    public static NativeAnnotationStyle Blue { get; } = new(45, 125, 255, 220, 1.5);
    public static NativeAnnotationStyle Red { get; } = new(206, 17, 38, 220, 1.5);
'@
$new = @'
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
'@
if (-not $text.Contains((Normalize $old))) { throw 'Native annotation preset block not found.' }
$text = $text.Replace((Normalize $old), (Normalize $new))
Write-Text $path $text

Replace-Exact $path @'
        private int Write(IntPtr pThis, IntPtr data, uint size)
        {
            try
            {
                var length = checked((int)size);
'@ @'
        private int Write(IntPtr pThis, IntPtr data, ulong size)
        {
            try
            {
                var length = checked((int)size);
'@ 'PDFium file writer ulong delegate'

$inspector = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.InspectorContext.cs'
Replace-Exact $inspector @'
using System.Windows.Media;

namespace PdfRescue.App;
'@ @'
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;
'@ 'Inspector annotation service namespace'

Write-Host 'Native annotation compile fixes staged.' -ForegroundColor Green
