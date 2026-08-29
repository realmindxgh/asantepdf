param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\ThemeRuntimeSelfTest.cs'
$text = Read-Lf $path

$lightAnchor = '            AssertThemeText(window, "Quick Tools", isLight: true);'
$darkAnchor = '            AssertThemeText(window, "Quick Tools", isLight: false);'
if (-not $text.Contains($lightAnchor)) { throw 'Light Quick Tools assertion anchor not found.' }
if (-not $text.Contains($darkAnchor)) { throw 'Dark Quick Tools assertion anchor not found.' }

$lightCall = '            AssertHomeToolBadgesWhite(window, "Light Home tool badges");'
$darkCall = '            AssertHomeToolBadgesWhite(window, "Dark Home tool badges");'
if (-not $text.Contains($lightCall)) { $text = $text.Replace($lightAnchor, $lightAnchor + "`n" + $lightCall) }
if (-not $text.Contains($darkCall)) { $text = $text.Replace($darkAnchor, $darkAnchor + "`n" + $darkCall) }

$methodAnchor = '    private static void AssertThemeText(DependencyObject root, string text, bool isLight)'
if (-not $text.Contains($methodAnchor)) { throw 'AssertThemeText method anchor not found.' }
if (-not $text.Contains('private static void AssertHomeToolBadgesWhite')) {
$method = @'
    private static void AssertHomeToolBadgesWhite(DependencyObject root, string label)
    {
        var badges = Descendants(root)
            .OfType<Border>()
            .Where(border => Math.Abs(border.Width - 44) < 0.1 && Math.Abs(border.Height - 44) < 0.1)
            .Select(border => border.Child as TextBlock)
            .Where(text => text is not null && text.IsVisible)
            .Cast<TextBlock>()
            .ToList();

        if (badges.Count < 20)
            throw new InvalidOperationException($"{label}: expected at least 20 visible Home tool badges, found {badges.Count}.");

        foreach (var badge in badges)
            AssertBrush(badge.Foreground, "#FFFFFF", $"{label} '{badge.Text}' foreground");
    }

'@
    $text = $text.Replace($methodAnchor, $method.Replace("`r`n", "`n") + $methodAnchor)
}

Write-Lf $path $text
Write-Host 'Pinned all visible Home tool badge glyphs to white in Light and Dark acceptance.' -ForegroundColor Green
