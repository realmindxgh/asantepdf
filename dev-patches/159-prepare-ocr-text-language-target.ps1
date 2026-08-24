param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundOcrExports.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$method = '    private void QueueOcrTextBackground(string source, string output)'
$start = $text.IndexOf($method, [StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Could not find QueueOcrTextBackground.' }
$needle = 'var recognized = await RecognizeBackgroundPageAsync(bitmap, ct);'
$target = $text.IndexOf($needle, $start, [StringComparison]::Ordinal)
if ($target -lt 0) { throw 'Could not find OCR text recognition call.' }
$text = $text.Remove($target, $needle.Length).Insert($target, 'var recognized = await RecognizeBackgroundPageAsync(bitmap, null, ct);')
[IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'Prepared OCR text recognition call for configured language migration.' -ForegroundColor Green
