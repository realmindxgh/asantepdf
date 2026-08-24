param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$target = Join-Path $SourceRoot 'dev-patches\220-foreground-result-workflows.ps1'
if (-not (Test-Path $target)) { throw 'Foreground completion carrier is missing.' }
$text = [IO.File]::ReadAllText($target)

$oldHandler = '() => ExtractSelected_Click(this, new RoutedEventArgs()));'
$newHandler = '() => Extract_Click(this, new RoutedEventArgs()));'
if (-not $text.Contains($oldHandler)) { throw 'Could not find selected-page Run Another callback.' }
$text = $text.Replace($oldHandler, $newHandler)

$oldPowerPoint = 'var success = await RunPdfOutputOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", configuration.OutputPath, async token =>'
$newPowerPoint = 'var powerPointSuccess = await RunPdfOutputOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", configuration.OutputPath, async token =>'
if (-not $text.Contains($oldPowerPoint)) { throw 'Could not find PowerPoint success variable.' }
$text = $text.Replace($oldPowerPoint, $newPowerPoint)

$oldPowerPointCheck = @'
            if (success)
                await ShowResultWorkflowAsync(
                    "PowerPoint export complete",
'@
$newPowerPointCheck = @'
            if (powerPointSuccess)
                await ShowResultWorkflowAsync(
                    "PowerPoint export complete",
'@
if (-not $text.Contains($oldPowerPointCheck)) { throw 'Could not find PowerPoint completion check.' }
$text = $text.Replace($oldPowerPointCheck, $newPowerPointCheck)

[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
Write-Host 'Prepared foreground carrier compiler fixes.' -ForegroundColor Green
& cmd /c exit 0
