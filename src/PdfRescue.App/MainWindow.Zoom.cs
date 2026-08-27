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