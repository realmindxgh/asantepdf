param([string]$Root = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = 'Stop'
$keys = 'AppBackground|SidebarBackground|PanelBackground|PanelRaisedBrush|PanelHoverBrush|PanelPressedBrush|BorderBrushSoft|PrimaryTextBrush|MutedTextBrush|AccentBrush|DangerBrush|SuccessBrush'
$violations = @()
Get-ChildItem (Join-Path $Root 'src\PdfRescue.App') -Filter '*.xaml' -File -Recurse | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $matches = [regex]::Matches($text, "\{StaticResource\s+($keys)\}")
    foreach ($match in $matches) { $violations += "$($_.FullName): $($match.Value)" }
}
if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw 'Theme contract failed: semantic palette brushes must use DynamicResource.'
}
Write-Host 'Theme resource contract passed.' -ForegroundColor Green