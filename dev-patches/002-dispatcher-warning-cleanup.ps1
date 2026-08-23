param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
$text = (Get-Content $path -Raw).Replace("`r`n", "`n")
$old = '        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>'
$new = '        _ = Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>'
if (-not $text.Contains($old)) {
    throw "Could not apply dispatcher warning cleanup. Expected source text was not found."
}
Set-Content -Path $path -Value ($text.Replace($old, $new)) -Encoding UTF8 -NoNewline
Write-Host 'Applied: dispatcher warning cleanup' -ForegroundColor Green
