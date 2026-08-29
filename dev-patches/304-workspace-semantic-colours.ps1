param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$appPath = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml'
$app = Read-Lf $appPath
$anchor = '        <SolidColorBrush x:Key="IconChipTextBrush" Color="#FFFFFF" />'
if (-not $app.Contains($anchor)) { throw 'IconChipTextBrush anchor not found.' }
if (-not $app.Contains('x:Key="CommandCyanBrush"')) {
$resources = @'
        <SolidColorBrush x:Key="CommandBlueBrush" Color="#4D9BFF" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandCyanBrush" Color="#49D6FF" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandGoldBrush" Color="#FCD116" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandGreenBrush" Color="#38C986" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandPurpleBrush" Color="#D187FF" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandOrangeBrush" Color="#EF7D45" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandTealBrush" Color="#34C5C3" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandLimeBrush" Color="#6FD15C" presentationOptions:Freeze="False" />
        <SolidColorBrush x:Key="CommandDangerBrush" Color="#FF6B72" presentationOptions:Freeze="False" />
'@
    $app = $app.Replace($anchor, $anchor + "`n" + $resources.TrimEnd())
}
Write-Lf $appPath $app

$appearancePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\AppearanceService.cs'
$appearance = Read-Lf $appearancePath
$keyAnchor = '        "DangerBrush", "SuccessBrush", "IconChipTextBrush"'
$keyReplacement = @'
        "DangerBrush", "SuccessBrush", "IconChipTextBrush", "CommandBlueBrush", "CommandCyanBrush",
        "CommandGoldBrush", "CommandGreenBrush", "CommandPurpleBrush", "CommandOrangeBrush",
        "CommandTealBrush", "CommandLimeBrush", "CommandDangerBrush"
'@.Replace("`r`n", "`n").TrimEnd()
if (-not $appearance.Contains($keyAnchor)) { throw 'ThemeBrushKeys anchor not found.' }
$appearance = $appearance.Replace($keyAnchor, $keyReplacement)
$applyAnchor = '        SetBrush("MutedTextBrush", colors.Muted);'
if (-not $appearance.Contains($applyAnchor)) { throw 'Appearance Apply anchor not found.' }
if (-not $appearance.Contains('SetBrush("CommandCyanBrush"')) {
$commandApply = @'
        SetBrush("CommandBlueBrush", IsLight ? "#155DA8" : "#4D9BFF");
        SetBrush("CommandCyanBrush", IsLight ? "#006A8A" : "#49D6FF");
        SetBrush("CommandGoldBrush", IsLight ? "#7A5900" : "#FCD116");
        SetBrush("CommandGreenBrush", IsLight ? "#147B4A" : "#38C986");
        SetBrush("CommandPurpleBrush", IsLight ? "#7040A0" : "#D187FF");
        SetBrush("CommandOrangeBrush", IsLight ? "#9A3F10" : "#EF7D45");
        SetBrush("CommandTealBrush", IsLight ? "#0B6F6E" : "#34C5C3");
        SetBrush("CommandLimeBrush", IsLight ? "#357A25" : "#6FD15C");
        SetBrush("CommandDangerBrush", IsLight ? "#B4232E" : "#FF6B72");
'@
    $appearance = $appearance.Replace($applyAnchor, $applyAnchor + "`n" + $commandApply.Replace("`r`n", "`n").TrimEnd())
}
Write-Lf $appearancePath $appearance

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$main = Read-Lf $mainPath

# Late-created document surfaces must use semantic resources directly. The legacy mapper
# runs at theme application time and cannot rescue controls materialized later by templates.
$replacements = [ordered]@{
    '<Setter Property="Background" Value="#132236" />' = '<Setter Property="Background" Value="{DynamicResource PanelPressedBrush}" />'
    '<Setter Property="BorderBrush" Value="#2D7DFF" />' = '<Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}" />'
    'BorderBrush="#29425B" BorderThickness="1" Background="#122131"' = 'BorderBrush="{DynamicResource BorderBrushSoft}" BorderThickness="1" Background="{DynamicResource PanelRaisedBrush}"'
    '<Setter TargetName="PageThumbnailCard" Property="BorderBrush" Value="#4D9BFF" />' = '<Setter TargetName="PageThumbnailCard" Property="BorderBrush" Value="{DynamicResource AccentBrush}" />'
    '<Setter TargetName="PageThumbnailCard" Property="Background" Value="#17304A" />' = '<Setter TargetName="PageThumbnailCard" Property="Background" Value="{DynamicResource PanelHoverBrush}" />'
    'Background="#122131" BorderBrush="#29425B" BorderThickness="1"' = 'Background="{DynamicResource PanelRaisedBrush}" BorderBrush="{DynamicResource BorderBrushSoft}" BorderThickness="1"'
    'Foreground="#72B5FF"' = 'Foreground="{DynamicResource CommandBlueBrush}"'
}
foreach ($pair in $replacements.GetEnumerator()) {
    if (-not $main.Contains($pair.Key)) { throw "Expected workspace literal was not found: $($pair.Key)" }
    $main = $main.Replace($pair.Key, $pair.Value)
}

# Ribbon glyphs retain category distinction while receiving accessible Light/Dark variants.
$foregroundMap = [ordered]@{
    'Foreground="#4D9BFF"' = 'Foreground="{DynamicResource CommandBlueBrush}"'
    'Foreground="#49D6FF"' = 'Foreground="{DynamicResource CommandCyanBrush}"'
    'Foreground="#FCD116"' = 'Foreground="{DynamicResource CommandGoldBrush}"'
    'Foreground="#38C986"' = 'Foreground="{DynamicResource CommandGreenBrush}"'
    'Foreground="#D187FF"' = 'Foreground="{DynamicResource CommandPurpleBrush}"'
    'Foreground="#3F8CFF"' = 'Foreground="{DynamicResource CommandBlueBrush}"'
    'Foreground="#27B67A"' = 'Foreground="{DynamicResource CommandGreenBrush}"'
    'Foreground="#EF7D45"' = 'Foreground="{DynamicResource CommandOrangeBrush}"'
    'Foreground="#34C5C3"' = 'Foreground="{DynamicResource CommandTealBrush}"'
    'Foreground="#6FD15C"' = 'Foreground="{DynamicResource CommandLimeBrush}"'
    'Foreground="#EF5C5C"' = 'Foreground="{DynamicResource CommandDangerBrush}"'
    'Foreground="#FF5C62"' = 'Foreground="{DynamicResource CommandDangerBrush}"'
    'Foreground="#6B7D90"' = 'Foreground="{DynamicResource MutedTextBrush}"'
}
foreach ($pair in $foregroundMap.GetEnumerator()) {
    if ($main.Contains($pair.Key)) { $main = $main.Replace($pair.Key, $pair.Value) }
}

# Duplicate icon uses stroked rectangles rather than a TextBlock.
$main = $main.Replace('BorderBrush="#4D9BFF" BorderThickness="2"', 'BorderBrush="{DynamicResource CommandBlueBrush}" BorderThickness="2"')
Write-Lf $mainPath $main

Write-Host 'Converted late-created workspace cards and ribbon command colours to semantic Light/Dark resources.' -ForegroundColor Green
