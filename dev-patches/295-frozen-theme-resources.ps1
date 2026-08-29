param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$carrier = Join-Path $SourceRoot 'dev-patches\300-theme-pdfium-runtime-hardening.ps1'
if (-not (Test-Path $carrier)) { throw "Carrier not found: $carrier" }
$text = [System.IO.File]::ReadAllText($carrier)
$old = @'
        if (Application.Current.Resources[key] is SolidColorBrush brush)
        {
            // Theme brushes are declared Freeze=False. Replacing a frozen brush would
            // strand StaticResource consumers on the old object, so fail loudly in
            // development instead of silently creating a mixed theme.
            if (brush.IsFrozen)
                throw new InvalidOperationException($"Theme brush '{key}' was unexpectedly frozen.");
            brush.Color = color;
            return;
        }
        Application.Current.Resources[key] = new SolidColorBrush(color);
'@
$new = @'
        if (Application.Current.Resources[key] is SolidColorBrush brush && !brush.IsFrozen)
        {
            brush.Color = color;
            return;
        }

        // WPF may freeze application-level Freezables while loading resources. This is
        // safe because the theme contract requires every semantic palette consumer to
        // use DynamicResource, so replacing a frozen resource is observed immediately.
        Application.Current.Resources[key] = new SolidColorBrush(color);
'@
if (-not $text.Contains($old)) { throw 'Could not locate AppearanceService SetBrush frozen-resource block.' }
$text = $text.Replace($old, $new)
[System.IO.File]::WriteAllText($carrier, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host 'Theme resource replacement now handles WPF-frozen brushes safely.' -ForegroundColor Green
