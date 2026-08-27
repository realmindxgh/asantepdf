param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$settingsService = Join-Path $SourceRoot 'src\PdfRescue.App\Services\AppSettingsService.cs'
Write-Text $settingsService @'
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PdfRescue.App.Services;

public enum AppThemeMode
{
    Light,
    Dark,
    FollowWindows
}

public enum DefaultPageViewMode
{
    SinglePage,
    Continuous,
    TwoPage
}

public sealed record AppPreferences
{
    public AppThemeMode Theme { get; init; } = AppThemeMode.Dark;
    public uint DefaultRenderWidth { get; init; } = 1100;
    public DefaultPageViewMode DefaultPageView { get; init; } = DefaultPageViewMode.SinglePage;
    public bool ReopenLastSession { get; init; } = true;
    public bool TrackRecentFiles { get; init; } = true;
    public bool ShowRecentThumbnails { get; init; } = true;
    public string DefaultOcrLanguage { get; init; } = "eng";
    public string DefaultOutputFolder { get; init; } = string.Empty;
    public string OutputNamePattern { get; init; } = "{name}-{operation}";
    public bool RecoveryEnabled { get; init; } = true;
    public bool CheckForUpdates { get; init; } = true;
    public bool FirstLaunchCompleted { get; init; }
}

public sealed class AppSettingsService
{
    private readonly object _sync = new();
    private readonly JsonSerializerOptions _jsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private static readonly Lazy<AppSettingsService> LazyCurrent = new(() => new AppSettingsService());
    public static AppSettingsService Current => LazyCurrent.Value;

    private static string RootDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AsantePDF");
    private static string SettingsPath => Path.Combine(RootDirectory, "settings.json");

    private AppPreferences _preferences;

    private AppSettingsService() => _preferences = LoadCore();

    public AppPreferences Preferences
    {
        get { lock (_sync) return _preferences; }
    }

    public event EventHandler? Changed;

    public void Save(AppPreferences preferences)
    {
        if (preferences is null) throw new ArgumentNullException(nameof(preferences));
        var normalized = preferences with
        {
            DefaultRenderWidth = Math.Clamp(preferences.DefaultRenderWidth, 320u, 4000u),
            DefaultOcrLanguage = string.IsNullOrWhiteSpace(preferences.DefaultOcrLanguage) ? "eng" : preferences.DefaultOcrLanguage.Trim(),
            DefaultOutputFolder = preferences.DefaultOutputFolder?.Trim() ?? string.Empty,
            OutputNamePattern = string.IsNullOrWhiteSpace(preferences.OutputNamePattern) ? "{name}-{operation}" : preferences.OutputNamePattern.Trim()
        };

        lock (_sync)
        {
            _preferences = normalized;
            Directory.CreateDirectory(RootDirectory);
            var staged = SettingsPath + ".tmp";
            File.WriteAllText(staged, JsonSerializer.Serialize(normalized, _jsonOptions), Encoding.UTF8);
            File.Move(staged, SettingsPath, true);
        }
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private AppPreferences LoadCore()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return new AppPreferences();
            return JsonSerializer.Deserialize<AppPreferences>(File.ReadAllText(SettingsPath), _jsonOptions) ?? new AppPreferences();
        }
        catch (Exception ex)
        {
            App.Log("Could not read settings.json: " + ex.Message);
            return new AppPreferences();
        }
    }
}
'@

$appearance = Join-Path $SourceRoot 'src\PdfRescue.App\Services\AppearanceService.cs'
Write-Text $appearance @'
using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace PdfRescue.App.Services;

public static class AppearanceService
{
    private sealed record ThemeColors(
        string Window,
        string Sidebar,
        string Surface,
        string Raised,
        string Hover,
        string Border,
        string Text,
        string Muted);

    private static readonly ThemeColors Dark = new(
        "#09131F", "#08111C", "#101C2A", "#162333", "#1B2B3D", "#26374A", "#F3F7FC", "#9FB0C3");
    private static readonly ThemeColors Light = new(
        "#F4F7FA", "#FFFFFF", "#F7F9FB", "#FFFFFF", "#E7EDF3", "#CBD5DF", "#17212B", "#607184");

    private static readonly Dictionary<string, string> DarkToLight = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#09131F"] = "#F4F7FA", ["#08111C"] = "#FFFFFF", ["#101C2A"] = "#F7F9FB",
        ["#162333"] = "#FFFFFF", ["#1B2B3D"] = "#E7EDF3", ["#26374A"] = "#CBD5DF",
        ["#F3F7FC"] = "#17212B", ["#9FB0C3"] = "#607184", ["#08121E"] = "#FFFFFF",
        ["#0D1A28"] = "#F5F7FA", ["#0D1926"] = "#FFFFFF", ["#0E1C2B"] = "#F7F9FB",
        ["#0B1724"] = "#F1F4F7", ["#132236"] = "#E6EDF5", ["#13202E"] = "#FFFFFF",
        ["#0F1B29"] = "#F7F9FB", ["#111C28"] = "#EEF2F6", ["#0C1723"] = "#FFFFFF",
        ["#101F2E"] = "#FFFFFF", ["#172738"] = "#D7E0E8", ["#243D56"] = "#C2CED9",
        ["#24415F"] = "#C7D3DE", ["#24364A"] = "#CBD5DF", ["#0A1520"] = "#EEF2F6",
        ["#0E1B29"] = "#F1F4F7", ["#17283A"] = "#FFFFFF", ["#102A45"] = "#DCE7F2",
        ["#35506B"] = "#B8C6D4", ["#6F8399"] = "#637588", ["#71869D"] = "#607488",
        ["#73879D"] = "#607488", ["#7E92A8"] = "#62778C", ["#7192B1"] = "#536F88"
    };

    public static bool IsLight { get; private set; }

    public static void Apply(AppThemeMode mode)
    {
        IsLight = mode == AppThemeMode.Light || mode == AppThemeMode.FollowWindows && WindowsUsesLightTheme();
        var colors = IsLight ? Light : Dark;
        SetBrush("AppBackground", colors.Window);
        SetBrush("SidebarBackground", colors.Sidebar);
        SetBrush("PanelBackground", colors.Surface);
        SetBrush("PanelRaisedBrush", colors.Raised);
        SetBrush("PanelHoverBrush", colors.Hover);
        SetBrush("BorderBrushSoft", colors.Border);
        SetBrush("PrimaryTextBrush", colors.Text);
        SetBrush("MutedTextBrush", colors.Muted);

        foreach (Window window in Application.Current.Windows)
            ApplyToWindow(window);
    }

    public static void ApplyToWindow(Window window)
    {
        if (window is null) return;
        if (!window.Dispatcher.CheckAccess())
        {
            window.Dispatcher.Invoke(() => ApplyToWindow(window));
            return;
        }
        window.Background = ResourceBrush("AppBackground");
        ApplyTree(window, IsLight);
    }

    private static bool WindowsUsesLightTheme()
    {
        try
        {
            var value = Registry.GetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "AppsUseLightTheme",
                0);
            return Convert.ToInt32(value ?? 0) != 0;
        }
        catch { return false; }
    }

    private static void SetBrush(string key, string value)
    {
        var color = (Color)ColorConverter.ConvertFromString(value)!;
        if (Application.Current.Resources[key] is SolidColorBrush brush && !brush.IsFrozen)
            brush.Color = color;
        else
            Application.Current.Resources[key] = new SolidColorBrush(color);
    }

    private static Brush ResourceBrush(string key) =>
        Application.Current.Resources[key] as Brush ?? Brushes.Transparent;

    private static void ApplyTree(DependencyObject root, bool light)
    {
        switch (root)
        {
            case Panel panel when panel.Background is SolidColorBrush panelBrush:
                panel.Background = MapBrush(panelBrush, light);
                break;
            case Border border:
                if (border.Background is SolidColorBrush background) border.Background = MapBrush(background, light);
                if (border.BorderBrush is SolidColorBrush borderBrush) border.BorderBrush = MapBrush(borderBrush, light);
                break;
            case Control control:
                if (control.Background is SolidColorBrush controlBackground) control.Background = MapBrush(controlBackground, light);
                if (control.Foreground is SolidColorBrush controlForeground) control.Foreground = MapBrush(controlForeground, light);
                if (control.BorderBrush is SolidColorBrush controlBorder) control.BorderBrush = MapBrush(controlBorder, light);
                break;
            case TextBlock text when text.Foreground is SolidColorBrush textBrush:
                text.Foreground = MapBrush(textBrush, light);
                break;
            case Shape shape:
                if (shape.Fill is SolidColorBrush fill) shape.Fill = MapBrush(fill, light);
                if (shape.Stroke is SolidColorBrush stroke) shape.Stroke = MapBrush(stroke, light);
                break;
        }

        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++) ApplyTree(VisualTreeHelper.GetChild(root, i), light);
    }

    private static Brush MapBrush(SolidColorBrush brush, bool light)
    {
        var current = brush.Color.ToString();
        if (light && DarkToLight.TryGetValue(current, out var lightColor))
            return new SolidColorBrush((Color)ColorConverter.ConvertFromString(lightColor)!);
        if (!light)
        {
            var pair = DarkToLight.FirstOrDefault(item => string.Equals(item.Value, current, StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(pair.Key))
                return new SolidColorBrush((Color)ColorConverter.ConvertFromString(pair.Key)!);
        }
        return brush;
    }
}
'@

$settingsWindow = Join-Path $SourceRoot 'src\PdfRescue.App\SettingsWindow.cs'
Write-Text $settingsWindow @'
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
    private readonly CheckBox _recovery = new() { Content = "Keep crash-recovery state separate from originals" };
    private readonly CheckBox _updates = new() { Content = "Check for updates when requested" };

    public AppPreferences? SavedPreferences { get; private set; }

    public SettingsWindow(AppPreferences preferences, RecentDocumentService recentDocuments)
    {
        _recentDocuments = recentDocuments;
        Title = "AsantePDF Settings";
        Width = 650;
        Height = 760;
        MinWidth = 560;
        MinHeight = 620;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (System.Windows.Media.Brush)Application.Current.Resources["AppBackground"];
        Foreground = (System.Windows.Media.Brush)Application.Current.Resources["PrimaryTextBrush"];

        _theme.ItemsSource = Enum.GetValues<AppThemeMode>();
        _theme.SelectedItem = preferences.Theme;
        _pageView.ItemsSource = Enum.GetValues<DefaultPageViewMode>();
        _pageView.SelectedItem = preferences.DefaultPageView;
        _zoom.Text = preferences.DefaultRenderWidth.ToString();
        _reopen.IsChecked = preferences.ReopenLastSession;
        _trackRecent.IsChecked = preferences.TrackRecentFiles;
        _thumbnails.IsChecked = preferences.ShowRecentThumbnails;
        _ocrLanguage.Text = preferences.DefaultOcrLanguage;
        _outputFolder.Text = preferences.DefaultOutputFolder;
        _outputPattern.Text = preferences.OutputNamePattern;
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
        AddField(content, "Default render width", _zoom, "320 to 4000. Current default is 1100.");
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
            panel.Children.Add(new TextBlock { Text = help, Foreground = (System.Windows.Media.Brush)Application.Current.Resources["MutedTextBrush"], FontSize = 11, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 3, 0, 4) });
    }

    private Button ActionButton(string label, RoutedEventHandler handler)
    {
        var button = new Button { Content = label, Padding = new Thickness(10, 6, 10, 6), Margin = new Thickness(0, 0, 7, 5), Style = (Style)FindResource("FlatButtonStyle") };
        button.Click += handler;
        return button;
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (!uint.TryParse(_zoom.Text.Trim(), out var width) || width < 320 || width > 4000)
        {
            MessageBox.Show(this, "Default render width must be between 320 and 4000.", "Settings", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

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
'@

$mainSettings = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Settings.cs'
Write-Text $mainSettings @'
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
'@

$recent = Join-Path $SourceRoot 'src\PdfRescue.App\Services\RecentDocumentService.cs'
Replace-Exact $recent @'
    public void SetViewMode(RecentViewMode viewMode)
'@ @'
    public void ClearHistory()
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            state.Documents.Clear();
            SaveStateCore(state);
        }
    }

    public void ClearLastSession()
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            state.LastSession = null;
            SaveStateCore(state);
        }
    }

    public void ClearThumbnailCache()
    {
        try
        {
            if (Directory.Exists(ThumbnailDirectory)) Directory.Delete(ThumbnailDirectory, true);
        }
        catch (Exception ex) { App.Log("Could not clear recent thumbnail cache: " + ex.Message); }
    }

    public void SetViewMode(RecentViewMode viewMode)
'@ 'recent privacy actions'

$recentView = Join-Path $SourceRoot 'src\PdfRescue.App\RecentFilesView.xaml.cs'
Replace-Exact $recentView @'
        _allItems = service.LoadItems().ToList();
        _viewMode = service.PreferredView;
'@ @'
        var appPreferences = AppSettingsService.Current.Preferences;
        _allItems = appPreferences.TrackRecentFiles ? service.LoadItems().ToList() : [];
        _viewMode = service.PreferredView;
'@ 'recent tracking preference'
Replace-Exact $recentView @'
        RefreshVisibleItems();
        RefreshResumeState();

        foreach (var item in _allItems.Where(item => item.Available))
'@ @'
        RefreshVisibleItems();
        RefreshResumeState();

        if (!appPreferences.ShowRecentThumbnails) return;
        foreach (var item in _allItems.Where(item => item.Available))
'@ 'recent thumbnail preference'
Replace-Exact $recentView @'
        var session = _service?.GetLastSession();
        ResumeSessionButton.Visibility = session is not null && session.Documents.Any(document => File.Exists(document.Path))
'@ @'
        var session = AppSettingsService.Current.Preferences.ReopenLastSession ? _service?.GetLastSession() : null;
        ResumeSessionButton.Visibility = session is not null && session.Documents.Any(document => File.Exists(document.Path))
'@ 'recent session preference'

$product = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $product @'
        if (_productShellInitialized) return;
        _productShellInitialized = true;

        _homeContent = EmptyPanel.Child;
'@ @'
        if (_productShellInitialized) return;
        _productShellInitialized = true;
        InitializeAppearanceAndSettings();

        _homeContent = EmptyPanel.Child;
'@ 'initialize settings and appearance'
Replace-Exact $product @'
        if (!string.Equals(_lastRecentRecordedPath, _currentPdf, StringComparison.OrdinalIgnoreCase))
        {
            _recentDocuments.RecordOpened(_currentPdf, page, _previewWidth);
            _lastRecentRecordedPath = _currentPdf;
            if (_recentFilesView is not null) _ = _recentFilesView.RefreshAsync();
            RefreshResumeCommandState();
        }
'@ @'
        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.TrackRecentFiles && !string.Equals(_lastRecentRecordedPath, _currentPdf, StringComparison.OrdinalIgnoreCase))
        {
            _recentDocuments.RecordOpened(_currentPdf, page, _previewWidth);
            _lastRecentRecordedPath = _currentPdf;
            if (_recentFilesView is not null) _ = _recentFilesView.RefreshAsync();
            RefreshResumeCommandState();
        }
'@ 'respect recent tracking preference'
Replace-Exact $product @'
        _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        CaptureActiveDocumentTabState();
        _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        RefreshResumeCommandState();
'@ @'
        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.TrackRecentFiles)
            _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        CaptureActiveDocumentTabState();
        if (preferences.ReopenLastSession)
            _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        else
            _recentDocuments.ClearLastSession();
        RefreshResumeCommandState();
'@ 'respect session preferences'
Replace-Exact $product @'
        var session = _recentDocuments.GetLastSession();
        ResumeSessionButton.IsEnabled = session is not null && session.Documents.Any(document => File.Exists(document.Path));
'@ @'
        var preferences = AppSettingsService.Current.Preferences;
        var session = preferences.ReopenLastSession ? _recentDocuments.GetLastSession() : null;
        var available = session?.Documents.Where(document => File.Exists(document.Path)).ToArray() ?? [];
        var hasSession = available.Length > 0;
        ResumeSessionButton.IsEnabled = hasSession;
        ResumeSessionButton.Visibility = hasSession ? Visibility.Visible : Visibility.Collapsed;
        ResumeSessionButton.ToolTip = hasSession
            ? available.Length == 1
                ? $"Restore {Path.GetFileName(available[0].Path)} at page {available[0].PageNumber:N0}"
                : $"Restore {available.Length:N0} PDFs from the previous session"
            : null;
'@ 'contextual resume visibility'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        await SynchronizeDocumentTabAfterOpenAsync(_currentPdf);
        AddRecentDocument(_currentPdf);
        UpdateCommandStates();
'@ @'
        await SynchronizeDocumentTabAfterOpenAsync(_currentPdf);
        if (AppSettingsService.Current.Preferences.TrackRecentFiles)
            AddRecentDocument(_currentPdf);
        UpdateCommandStates();
'@ 'legacy recent tracking preference'

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                    <Border Width="28" Height="28" CornerRadius="7" Background="#113661" Margin="0,0,10,0">
                        <TextBlock Text="A" Foreground="#5EB4FF" FontWeight="Bold" FontSize="17" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock FontSize="17" FontWeight="SemiBold">
                            <Run Text="Asante" /><Run Text="PDF" Foreground="#2D8CFF" />
'@ @'
                    <Grid Width="28" Height="28" Margin="0,0,10,0" ToolTip="AsantePDF">
                        <Border Background="#111111" CornerRadius="6" />
                        <Grid Margin="4">
                            <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
                            <Border Grid.Row="0" Background="#CE1126" CornerRadius="2,2,0,0" />
                            <Border Grid.Row="1" Background="#FCD116" />
                            <Border Grid.Row="2" Background="#006B3F" CornerRadius="0,0,2,2" />
                            <Path Grid.RowSpan="3" Data="M 5,17 L 9,3 L 13,17 M 7,11 L 11,11" Stroke="#111111" StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" />
                            <Path Grid.RowSpan="3" Data="M 14,1 L 19,6 L 14,6 Z" Fill="#FFFFFF" Opacity="0.88" HorizontalAlignment="Right" VerticalAlignment="Top" />
                        </Grid>
                    </Grid>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock FontSize="17" FontWeight="SemiBold">
                            <Run Text="Asante" /><Run Text="PDF" Foreground="#FCD116" />
'@ 'Ghana-inspired title identity'
Replace-Exact $xaml @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Help"><TextBlock Text="?" FontSize="17" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Settings" IsEnabled="False"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="16" /></Button>
'@ @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Help"><TextBlock Text="?" FontSize="17" /></Button>
                    <Button x:Name="ThemeToggleButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" Click="ThemeToggle_Click" ToolTip="Switch theme">
                        <TextBlock x:Name="ThemeToggleGlyph" Text="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="16" />
                    </Button>
                    <Button x:Name="SettingsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Settings" Click="Settings_Click"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="16" /></Button>
'@ 'visible theme and settings controls'
Replace-Exact $xaml @'
                                <Button x:Name="ResumeSessionButton" Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="ResumeLastSession_Click" IsEnabled="False" ToolTip="Restore the last available document, page and zoom position" Padding="16,9">
'@ @'
                                <Button x:Name="ResumeSessionButton" Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="ResumeLastSession_Click" IsEnabled="False" Visibility="Collapsed" Padding="16,9">
'@ 'hide dead resume action by default'

$app = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml.cs'
Replace-Exact $app @'
            base.OnStartup(e);

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-conversions", StringComparison.OrdinalIgnoreCase))
'@ @'
            base.OnStartup(e);
            AppearanceService.Apply(AppSettingsService.Current.Preferences.Theme);
            EventManager.RegisterClassHandler(typeof(Window), FrameworkElement.LoadedEvent,
                new RoutedEventHandler((sender, _) =>
                {
                    if (sender is Window loadedWindow) AppearanceService.ApplyToWindow(loadedWindow);
                }));

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-conversions", StringComparison.OrdinalIgnoreCase))
'@ 'startup theme application'

$svg = Join-Path $SourceRoot 'assets\asantepdf-ghana-mark.svg'
Write-Text $svg @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" role="img" aria-label="AsantePDF Ghana-inspired document mark">
  <rect x="28" y="18" width="188" height="220" rx="34" fill="#111111"/>
  <path d="M60 50h112l32 32v32H60z" fill="#CE1126"/>
  <path d="M60 114h144v48H60z" fill="#FCD116"/>
  <path d="M60 162h144v44H60z" fill="#006B3F"/>
  <path d="M172 50v32h32" fill="#ffffff" opacity=".9"/>
  <path d="M92 190l34-100 38 100M107 146h42" fill="none" stroke="#111111" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
'@

Write-Host 'Settings, theme switching, privacy controls, contextual recovery and Ghana identity staged.' -ForegroundColor Green
& cmd /c exit 0