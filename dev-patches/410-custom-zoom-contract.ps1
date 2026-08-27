param([Parameter(Mandatory = $true)][string]$SourceRoot)

$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New) {
    $text = [System.IO.File]::ReadAllText($Path)
    if (-not $text.Contains($Old)) {
        throw "Expected source fragment was not found in $Path"
    }
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
}

$appRoot = Join-Path $SourceRoot 'src\PdfRescue.App'
$xamlPath = Join-Path $appRoot 'MainWindow.xaml'
$mainPath = Join-Path $appRoot 'MainWindow.xaml.cs'
$settingsPath = Join-Path $appRoot 'SettingsWindow.cs'
$zoomCodePath = Join-Path $appRoot 'MainWindow.Zoom.cs'

$oldZoomControl = '                                <Button x:Name="ZoomButton" Style="{StaticResource FlatButtonStyle}" Click="ActualSizeShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="100%" MinWidth="66" Padding="7,4" AutomationProperties.Name="Zoom percentage and actual size" AutomationProperties.HelpText="Shows current zoom. Activate to return to 100 percent." />'
$newZoomControl = @'
                                <TextBox x:Name="ZoomPercentBox" Width="68" Height="30" Margin="1,0" Text="100%" TextAlignment="Center" VerticalContentAlignment="Center" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" KeyDown="ZoomPercentBox_KeyDown" LostKeyboardFocus="ZoomPercentBox_LostKeyboardFocus" ToolTip="Type a zoom percentage and press Enter" AutomationProperties.Name="Custom zoom percentage" AutomationProperties.HelpText="Type a zoom percentage from 30 to 350 and press Enter." />
                                <Button Style="{StaticResource FlatButtonStyle}" Click="ActualSizeShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="1:1" Width="42" Padding="5,4" ToolTip="Actual size / 100%" AutomationProperties.Name="Actual size, 100 percent zoom" />
'@.TrimEnd()
Replace-Exact $xamlPath $oldZoomControl $newZoomControl

Replace-Exact $mainPath '        ZoomButton.Content = $"{percent}%";' '        ZoomPercentBox.Text = $"{percent}%";'

Replace-Exact $settingsPath '        _zoom.Text = preferences.DefaultRenderWidth.ToString();' '        _zoom.Text = $"{Math.Round(preferences.DefaultRenderWidth / 1100d * 100d):0}";'
Replace-Exact $settingsPath '        AddField(content, "Default render width", _zoom, "320 to 4000. Current default is 1100.");' '        AddField(content, "Default zoom (%)", _zoom, "30 to 350. 100% is actual size.");'
Replace-Exact $settingsPath '        if (!uint.TryParse(_zoom.Text.Trim(), out var width) || width < 320 || width > 4000)' '        if (!double.TryParse(_zoom.Text.Trim().TrimEnd(''%'').Trim(), out var zoomPercent) || zoomPercent < 30 || zoomPercent > 350)'
Replace-Exact $settingsPath '            MessageBox.Show(this, "Default render width must be between 320 and 4000.", "Settings", MessageBoxButton.OK, MessageBoxImage.Information);' '            MessageBox.Show(this, "Default zoom must be between 30% and 350%.", "Settings", MessageBoxButton.OK, MessageBoxImage.Information);'
Replace-Exact $settingsPath '        SavedPreferences = new AppPreferences' ('        var width = (uint)Math.Clamp((int)Math.Round(1100d * zoomPercent / 100d), 320, 4000);' + [Environment]::NewLine + [Environment]::NewLine + '        SavedPreferences = new AppPreferences')

$zoomCode = @'
using System.Windows;
using System.Windows.Input;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async void ZoomPercentBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true;
        await ApplyCustomZoomPercentageAsync(showValidationMessage: true);
        Keyboard.ClearFocus();
    }

    private void ZoomPercentBox_LostKeyboardFocus(object sender, KeyboardFocusChangedEventArgs e)
    {
        _ = ApplyCustomZoomPercentageAsync(showValidationMessage: false);
    }

    private async Task ApplyCustomZoomPercentageAsync(bool showValidationMessage)
    {
        if (ZoomPercentBox is null) return;
        var raw = ZoomPercentBox.Text.Trim().TrimEnd('%').Trim();
        if (!double.TryParse(raw, out var percent) || percent < 30 || percent > 350)
        {
            if (showValidationMessage)
            {
                MessageBox.Show(this,
                    "Enter a zoom percentage from 30% to 350%.",
                    "Custom zoom",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
            UpdateZoomText();
            return;
        }

        _previewWidth = (uint)Math.Clamp((int)Math.Round(1100d * percent / 100d), 320, 4000);
        PersistWorkspacePosition();
        await RerenderSelectedPageAsync();
    }
}
'@
[System.IO.File]::WriteAllText($zoomCodePath, $zoomCode.TrimStart(), [System.Text.UTF8Encoding]::new($false))

Write-Host 'Staged human-facing custom zoom percentage support.' -ForegroundColor Green
