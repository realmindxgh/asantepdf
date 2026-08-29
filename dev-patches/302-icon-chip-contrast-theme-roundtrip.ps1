param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$appXamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml'
$appXaml = Read-Lf $appXamlPath
$anchor = '        <SolidColorBrush x:Key="SuccessBrush" Color="{StaticResource Color.Success}" presentationOptions:Freeze="False" />'
if (-not $appXaml.Contains($anchor)) { throw 'Could not locate semantic brush anchor in App.xaml.' }
if (-not $appXaml.Contains('x:Key="IconChipTextBrush"')) {
    $brushBlock = @'
        <!-- Fixed foreground for text/glyphs placed on saturated tool-category chips. -->
        <SolidColorBrush x:Key="IconChipTextBrush" Color="#FFFFFF" />
'@
    $appXaml = $appXaml.Replace($anchor, $anchor + "`n" + $brushBlock.TrimEnd())
}
Write-Lf $appXamlPath $appXaml

$appearancePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\AppearanceService.cs'
$appearance = Read-Lf $appearancePath
$oldKeys = @'
        "PanelPressedBrush", "BorderBrushSoft", "PrimaryTextBrush", "MutedTextBrush", "AccentBrush",
        "DangerBrush", "SuccessBrush"
'@
$newKeys = @'
        "PanelPressedBrush", "BorderBrushSoft", "PrimaryTextBrush", "MutedTextBrush", "AccentBrush",
        "DangerBrush", "SuccessBrush", "IconChipTextBrush"
'@
$oldKeys = $oldKeys.Replace("`r`n", "`n")
$newKeys = $newKeys.Replace("`r`n", "`n")
if (-not $appearance.Contains($oldKeys)) { throw 'Could not locate ThemeBrushKeys in AppearanceService.' }
$appearance = $appearance.Replace($oldKeys, $newKeys)
Write-Lf $appearancePath $appearance

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$main = Read-Lf $mainPath
$pattern = '(<Border Width="44" Height="44" Background="#[0-9A-Fa-f]{6}" CornerRadius="10" HorizontalAlignment="Left"><TextBlock )(?![^>]*Foreground=)'
$matchesBefore = [regex]::Matches($main, $pattern).Count
if ($matchesBefore -lt 10) { throw "Expected at least 10 unthemed tool-chip glyphs, found $matchesBefore." }
$main = [regex]::Replace($main, $pattern, '$1Foreground="{StaticResource IconChipTextBrush}" ')
if ([regex]::Matches($main, $pattern).Count -ne 0) { throw 'One or more tool chips still inherit the global theme foreground.' }
Write-Lf $mainPath $main

$selfTestPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\ThemeRuntimeSelfTest.cs'
$selfTest = Read-Lf $selfTestPath
$old = @'
            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#09131F", "Dark MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: false);
            AssertThemeText(window, "Get started with AsantePDF", isLight: false);
            AssertThemeText(window, "Quick Tools", isLight: false);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark.txt"), "Dark");
            Capture(window, Path.Combine(outputDirectory, "home-dark.png"));
'@
$new = @'
            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#09131F", "Dark MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: false);
            AssertThemeText(window, "Get started with AsantePDF", isLight: false);
            AssertThemeText(window, "Quick Tools", isLight: false);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark.txt"), "Dark");
            Capture(window, Path.Combine(outputDirectory, "home-dark.png"));

            // The installed acceptance failure appeared after live theme switching, so
            // startup-only tests are insufficient. Exercise a full round trip on the
            // same visual tree and assert that no control remembers the previous theme.
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#EEF3F8", "Round-trip Light MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: true);
            AssertThemeText(window, "Get started with AsantePDF", isLight: true);
            AssertThemeText(window, "Quick Tools", isLight: true);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-light-roundtrip.txt"), "Light round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-light-roundtrip.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#09131F", "Round-trip Dark MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: false);
            AssertThemeText(window, "Get started with AsantePDF", isLight: false);
            AssertThemeText(window, "Quick Tools", isLight: false);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark-roundtrip.txt"), "Dark round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-dark-roundtrip.png"));
'@
$old = $old.Replace("`r`n", "`n")
$new = $new.Replace("`r`n", "`n")
if (-not $selfTest.Contains($old)) { throw 'Could not locate whole-shell Dark-theme test block.' }
$selfTest = $selfTest.Replace($old, $new)
Write-Lf $selfTestPath $selfTest

Write-Host "Applied fixed high-contrast foreground to $matchesBefore tool chips, protected it from legacy mapping, and added Light/Dark round-trip validation." -ForegroundColor Green
