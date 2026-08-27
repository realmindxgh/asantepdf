param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\NativePdfAnnotationService.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$old = @'
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
    public static NativeAnnotationStyle Blue { get; } = new(45, 125, 255, 220, 1.5);
    public static NativeAnnotationStyle Red { get; } = new(206, 17, 38, 220, 1.5);
'@
$new = @'
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
'@
if (-not $text.Contains($old.Replace("`r`n", "`n"))) { throw 'Native annotation preset block not found.' }
$text = $text.Replace($old.Replace("`r`n", "`n"), $new.Replace("`r`n", "`n"))
[IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'Native annotation compile fix staged.' -ForegroundColor Green
