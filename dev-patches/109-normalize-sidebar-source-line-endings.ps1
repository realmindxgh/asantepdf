param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$targets = @(
    'src\PdfRescue.App\MainWindow.Bookmarks.cs'
)

foreach ($relative in $targets) {
    $path = Join-Path $SourceRoot $relative
    $text = [IO.File]::ReadAllText($path)
    $normalized = $text.Replace("`r`r`n", "`n").Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText($path, $normalized.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

Write-Host 'Normalized sidebar source line endings for staged patching.' -ForegroundColor Green
