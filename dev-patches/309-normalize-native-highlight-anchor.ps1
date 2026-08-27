param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$old = @'
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.AddHighlightAsync(working, output, pageNumber, rect, ct), token));
'@.Replace("`r`n", "`n")
$new = @'
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddHighlightAsync(working, output, pageNumber, rect, ct), token));
'@.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'Current multiline highlight anchor was not found.' }
$text = $text.Replace($old, $new)
[IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host 'Native highlight staging anchor normalized.' -ForegroundColor Green
