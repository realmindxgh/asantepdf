using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public sealed class SettingsWindow : Window
{
    private readonly RecentDocumentService _recentDocuments;
    private readonly ComboBox _theme = new();
    private readonly TextBox _zoom = new();
    private readonly ComboBox _pageView = new();
    private readonly CheckBox _reopen = new() { Content = "Reopen the previous session" };
    private readonly CheckBox _trackRecent = new() { Content = "Track recent files" };
    private readonly CheckBox _thumbnails = new() { Content = "Generate recent-file thumbnails" };
    private readonly TextBox _ocrLanguage = new();
    private readonly TextBox _outputFolder = new();
    private readonly TextBox _outputPattern = new();
    private readonly ComboBox _existingOutput = new();
    private readonly CheckBox _recovery = new() { Content = "Keep crash-recovery state separate from originals" };
    private readonly CheckBox _updates = new() { Content = "Check for updates when requested" };

    public AppPreferences? SavedPreferences { get; private set; }

    public SettingsWindow(AppPreferences preferences, RecentDocumentService recentDocuments)
    {
        _recentDocuments = recentDocuments;
        Title = "AsantePDF Settings";
        Width = Math.Min(650, Math.Max(560, SystemParameters.WorkArea.Width - 80));
        Height = Math.Min(760, Math.Max(540, SystemParameters.WorkArea.Height - 80));
        MinWidth = 520;
        MinHeight = 500;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (System.Windows.Media.Brush)Application.Current.Resources["AppBackground"];
        Foreground = (System.Windows.Media.Brush)Application.Current.Resources["PrimaryTextBrush"];

        _theme.ItemsSource = Enum.GetValues<AppThemeMode>();
        _theme.SelectedItem = preferences.Theme;
        _pageView.ItemsSource = Enum.GetValues<DefaultPageViewMode>();
        _pageView.SelectedItem = preferences.DefaultPageView;
        _zoom.Text = $"{Math.Round(preferences.DefaultRenderWidth / 1100d * 100d):0}";
        _reopen.IsChecked = preferences.ReopenLastSession;
        _trackRecent.IsChecked = preferences.TrackRecentFiles;
        _thumbnails.IsChecked = preferences.ShowRecentThumbnails;
        _ocrLanguage.Text = preferences.DefaultOcrLanguage;
        _outputFolder.Text = preferences.DefaultOutputFolder;
        _outputPattern.Text = preferences.OutputNamePattern;
        _existingOutput.ItemsSource = Enum.GetValues<ExistingOutputBehavior>();
        _existingOutput.SelectedItem = preferences.ExistingOutput;
        _recovery.IsChecked = preferences.RecoveryEnabled;
        _updates.IsChecked = preferences.CheckForUpdates;

        var root = new DockPanel { Margin = new Thickness(24) };
        var footer = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 18, 0, 0) };
        var cancel = new Button { Content = "Cancel", Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(4), Style = (Style)FindResource("FlatButtonStyle") };
        cancel.Click += (_, _) => Close();
        var save = new Button { Content = "Save settings", Padding = new Thickness(18, 8, 18, 8), Margin = new Thickness(4), Style = (Style)FindResource("PrimaryButtonStyle") };
        save.Click += Save_Click;
        footer.Children.Add(cancel);
        footer.Children.Add(save);
        DockPanel.SetDock(footer, Dock.Bottom);
        root.Children.Add(footer);

        var content = new StackPanel();
        content.Children.Add(new TextBlock { Text = "Settings", FontSize = 26, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 4) });
        content.Children.Add(new TextBlock { Text = "Useful defaults and privacy controls. AsantePDF remains completely free.", Foreground = (System.Windows.Media.Brush)FindResource("MutedTextBrush"), Margin = new Thickness(0, 0, 0, 20) });

        AddSection(content, "Appearance");
        AddField(content, "Theme", _theme);
        AddField(content, "Default zoom (%)", _zoom, "30 to 350. 100% is actual size.");
        AddField(content, "Default page view", _pageView);

        AddSection(content, "Session and privacy");
        content.Children.Add(_reopen);
        content.Children.Add(_trackRecent);
        content.Children.Add(_thumbnails);
        content.Children.Add(_recovery);

        var privacyActions = new WrapPanel { Margin = new Thickness(0, 10, 0, 8) };
        privacyActions.Children.Add(ActionButton("Clear recent history", ClearRecent_Click));
        privacyActions.Children.Add(ActionButton("Clear thumbnail cache", ClearThumbnails_Click));
        privacyActions.Children.Add(ActionButton("Forget saved session", ClearSession_Click));
        content.Children.Add(privacyActions);

        AddSection(content, "OCR and output");
        AddField(content, "Default OCR language", _ocrLanguage, "Tesseract language code such as eng.");
        var folderPanel = new DockPanel();
        var browse = ActionButton("Browse", BrowseOutputFolder_Click);
        DockPanel.SetDock(browse, Dock.Right);
        folderPanel.Children.Add(browse);
        folderPanel.Children.Add(_outputFolder);
        AddField(content, "Default output folder", folderPanel, "Leave blank to choose each time.");
        AddField(content, "Output naming pattern", _outputPattern, "Use {name} and {operation} placeholders.");
        AddField(content, "If an output file already exists", _existingOutput,
            "CreateUniqueCopy never replaces an existing result. AskBeforeReplace requires an explicit confirmation before replacing an output file.");

        AddSection(content, "Updates");
        content.Children.Add(_updates);
        content.Children.Add(new TextBlock { Text = "Updates are always user-controlled. AsantePDF will not silently replace itself.", Foreground = (System.Windows.Media.Brush)FindResource("MutedTextBrush"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 5, 0, 0) });

        root.Children.Add(new ScrollViewer { Content = content, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        Content = root;
        Loaded += (_, _) => AppearanceService.ApplyToWindow(this);
    }

    private static void AddSection(Panel panel, string title) =>
        panel.Children.Add(new TextBlock { Text = title, FontSize = 17, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 20, 0, 10) });

    private static void AddField(Panel panel, string label, UIElement control, string? help = null)
    {
        panel.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 7, 0, 4) });
        panel.Children.Add(control);
        if (!string.IsNullOrWhiteSpace(help))
            panel.Children.Add(new TextBlock { Text = help, Foreground = (System.Windows.Media.Brush)Application.Current.Resources["MutedTextBrush"], FontSize = 12, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 3, 0, 4) });
    }

    private Button ActionButton(string label, RoutedEventHandler handler)
    {
        var button = new Button { Content = label, Padding = new Thickness(10, 6, 10, 6), Margin = new Thickness(0, 0, 7, 5), Style = (Style)FindResource("FlatButtonStyle") };
        button.Click += handler;
        return button;
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (!double.TryParse(_zoom.Text.Trim().TrimEnd('%').Trim(), out var zoomPercent) || zoomPercent < 30 || zoomPercent > 350)
        {
            MessageBox.Show(this, "Default zoom must be between 30% and 350%.", "Settings", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var width = (uint)Math.Clamp((int)Math.Round(1100d * zoomPercent / 100d), 320, 4000);

        SavedPreferences = new AppPreferences
        {
            Theme = _theme.SelectedItem is AppThemeMode theme ? theme : AppThemeMode.Dark,
            DefaultRenderWidth = width,
            DefaultPageView = _pageView.SelectedItem is DefaultPageViewMode pageView ? pageView : DefaultPageViewMode.SinglePage,
            ReopenLastSession = _reopen.IsChecked == true,
            TrackRecentFiles = _trackRecent.IsChecked == true,
            ShowRecentThumbnails = _thumbnails.IsChecked == true,
            DefaultOcrLanguage = _ocrLanguage.Text,
            DefaultOutputFolder = _outputFolder.Text,
            OutputNamePattern = _outputPattern.Text,
            ExistingOutput = _existingOutput.SelectedItem is ExistingOutputBehavior existingOutput
                ? existingOutput
                : ExistingOutputBehavior.CreateUniqueCopy,
            RecoveryEnabled = _recovery.IsChecked == true,
            CheckForUpdates = _updates.IsChecked == true,
            FirstLaunchCompleted = AppSettingsService.Current.Preferences.FirstLaunchCompleted
        };
        DialogResult = true;
    }

    private void BrowseOutputFolder_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFolderDialog { Title = "Choose default AsantePDF output folder", Multiselect = false };
        if (dialog.ShowDialog(this) == true) _outputFolder.Text = dialog.FolderName;
    }

    private void ClearRecent_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show(this, "Clear all recent-file history? Pinned entries will also be removed.", "Privacy", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            _recentDocuments.ClearHistory();
    }

    private void ClearThumbnails_Click(object sender, RoutedEventArgs e) => _recentDocuments.ClearThumbnailCache();
    private void ClearSession_Click(object sender, RoutedEventArgs e) => _recentDocuments.ClearLastSession();
}