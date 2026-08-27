using System.Windows;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private void InitializeAppearanceAndSettings()
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (_currentPdf is null) _previewWidth = preferences.DefaultRenderWidth;
        AppearanceService.Apply(preferences.Theme);
        UpdateThemeToggleState();
    }

    private void ThemeToggle_Click(object sender, RoutedEventArgs e)
    {
        var current = AppSettingsService.Current.Preferences;
        var next = AppearanceService.IsLight ? AppThemeMode.Dark : AppThemeMode.Light;
        AppSettingsService.Current.Save(current with { Theme = next });
        AppearanceService.Apply(next);
        UpdateThemeToggleState();
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SettingsWindow(AppSettingsService.Current.Preferences, _recentDocuments) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.SavedPreferences is null) return;

        AppSettingsService.Current.Save(dialog.SavedPreferences);
        AppearanceService.Apply(dialog.SavedPreferences.Theme);
        if (_currentPdf is null) _previewWidth = dialog.SavedPreferences.DefaultRenderWidth;
        _syncingPageViewSelection = true;
        PageViewModeCombo.SelectedIndex = (int)dialog.SavedPreferences.DefaultPageView;
        _syncingPageViewSelection = false;
        _ = SetPageViewModeAsync(dialog.SavedPreferences.DefaultPageView, persist: false);
        UpdateThemeToggleState();
        LoadHomeRecents();
        RefreshResumeCommandState();
    }

    private void UpdateThemeToggleState()
    {
        if (ThemeToggleGlyph is null || ThemeToggleButton is null) return;
        ThemeToggleGlyph.Text = AppearanceService.IsLight ? "\uE708" : "\uE706";
        ThemeToggleButton.ToolTip = AppearanceService.IsLight ? "Switch to dark theme" : "Switch to light theme";
    }
}