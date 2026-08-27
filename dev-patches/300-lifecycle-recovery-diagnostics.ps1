param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

# Separate crash-recovery persistence from normal Recent/session persistence.
$recovery = Join-Path $SourceRoot 'src\PdfRescue.App\Services\RecoverySnapshotService.cs'
Write-Text $recovery @'
using System.IO;
using System.Text;
using System.Text.Json;
using PdfRescue.App;

namespace PdfRescue.App.Services;

public sealed record RecoveryDocumentState(
    string Path,
    bool IsDirty,
    int SelectedPage,
    uint PreviewWidth,
    double HorizontalOffset,
    double VerticalOffset,
    IReadOnlyList<DocumentTabPageState> WorkingLayout,
    IReadOnlyList<DocumentTabPageState> SavedLayout,
    IReadOnlyList<DocumentTabLayoutSnapshot> UndoHistory,
    IReadOnlyList<DocumentTabLayoutSnapshot> RedoHistory);

public sealed record RecoverySnapshot(
    IReadOnlyList<RecoveryDocumentState> Documents,
    int ActiveDocumentIndex,
    DateTimeOffset SavedUtc);

public sealed class RecoverySnapshotService
{
    private static readonly Lazy<RecoverySnapshotService> LazyCurrent = new(() => new RecoverySnapshotService());
    public static RecoverySnapshotService Current => LazyCurrent.Value;

    private readonly object _sync = new();
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private bool _sessionStarted;

    private static string RootDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AsantePDF", "Recovery");
    private static string SnapshotPath => Path.Combine(RootDirectory, "workspace-recovery.json");
    private static string RunningMarkerPath => Path.Combine(RootDirectory, "session-running.marker");

    public RecoverySnapshot? BeginSession()
    {
        lock (_sync)
        {
            if (_sessionStarted) return null;
            Directory.CreateDirectory(RootDirectory);
            var previousWasUnclean = File.Exists(RunningMarkerPath);
            var recovery = previousWasUnclean ? LoadSnapshotCore() : null;
            File.WriteAllText(RunningMarkerPath, $"{Environment.ProcessId}|{DateTimeOffset.UtcNow:O}", Encoding.UTF8);
            _sessionStarted = true;
            return recovery;
        }
    }

    public void SaveSnapshot(IEnumerable<DocumentTabSession> tabs, int activeIndex)
    {
        var documents = tabs
            .Where(tab => !string.IsNullOrWhiteSpace(tab.Path))
            .Select(tab => new RecoveryDocumentState(
                tab.Path,
                tab.IsDirty,
                Math.Max(1, tab.SelectedPage),
                Math.Clamp(tab.PreviewWidth, 320u, 4000u),
                Math.Max(0, tab.HorizontalOffset),
                Math.Max(0, tab.VerticalOffset),
                tab.WorkingLayout.ToArray(),
                tab.SavedLayout.ToArray(),
                tab.UndoHistory.ToArray(),
                tab.RedoHistory.ToArray()))
            .ToArray();

        lock (_sync)
        {
            Directory.CreateDirectory(RootDirectory);
            if (documents.Length == 0)
            {
                TryDelete(SnapshotPath);
                return;
            }

            var snapshot = new RecoverySnapshot(
                documents,
                Math.Clamp(activeIndex, 0, documents.Length - 1),
                DateTimeOffset.UtcNow);
            var staged = SnapshotPath + ".tmp";
            File.WriteAllText(staged, JsonSerializer.Serialize(snapshot, _json), Encoding.UTF8);
            File.Move(staged, SnapshotPath, true);
        }
    }

    public void DiscardSnapshot()
    {
        lock (_sync) TryDelete(SnapshotPath);
    }

    public void MarkCleanShutdown()
    {
        lock (_sync)
        {
            TryDelete(SnapshotPath);
            TryDelete(RunningMarkerPath);
            _sessionStarted = false;
        }
    }

    private RecoverySnapshot? LoadSnapshotCore()
    {
        try
        {
            if (!File.Exists(SnapshotPath)) return null;
            var snapshot = JsonSerializer.Deserialize<RecoverySnapshot>(File.ReadAllText(SnapshotPath), _json);
            if (snapshot is null || snapshot.Documents.Count == 0) return null;
            var available = snapshot.Documents.Where(document => File.Exists(document.Path)).ToArray();
            return available.Length == 0
                ? null
                : snapshot with
                {
                    Documents = available,
                    ActiveDocumentIndex = Math.Clamp(snapshot.ActiveDocumentIndex, 0, available.Length - 1)
                };
        }
        catch (Exception ex)
        {
            App.Log("Could not load crash-recovery snapshot: " + ex.Message);
            return null;
        }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); }
        catch { }
    }
}
'@

$updates = Join-Path $SourceRoot 'src\PdfRescue.App\Services\UpdateService.cs'
Write-Text $updates @'
using System.Diagnostics;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace PdfRescue.App.Services;

public sealed record UpdateInfo(string Version, string ReleaseUrl, DateTimeOffset? PublishedUtc, string Notes);

public static class UpdateService
{
    private const string LatestReleaseApi = "https://api.github.com/repos/realmindxgh/asantepdf/releases/latest";
    private static readonly HttpClient Client = CreateClient();

    public static string CurrentVersion => typeof(UpdateService).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
        .InformationalVersion?
        .Split('+', 2)[0] ?? "1.0.0";

    public static async Task<UpdateInfo?> CheckAsync(CancellationToken token = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, LatestReleaseApi);
        using var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(token);
        using var json = await JsonDocument.ParseAsync(stream, cancellationToken: token);
        var root = json.RootElement;
        var tag = root.TryGetProperty("tag_name", out var tagNode) ? tagNode.GetString() : null;
        var url = root.TryGetProperty("html_url", out var urlNode) ? urlNode.GetString() : null;
        var notes = root.TryGetProperty("body", out var bodyNode) ? bodyNode.GetString() ?? string.Empty : string.Empty;
        DateTimeOffset? published = null;
        if (root.TryGetProperty("published_at", out var dateNode) && DateTimeOffset.TryParse(dateNode.GetString(), out var parsed))
            published = parsed;
        if (string.IsNullOrWhiteSpace(tag) || string.IsNullOrWhiteSpace(url)) return null;
        return new UpdateInfo(tag.TrimStart('v', 'V'), url, published, notes);
    }

    public static bool IsNewer(UpdateInfo update) => CompareVersions(update.Version, CurrentVersion) > 0;

    public static void OpenRelease(UpdateInfo update) =>
        Process.Start(new ProcessStartInfo(update.ReleaseUrl) { UseShellExecute = true });

    private static int CompareVersions(string left, string right)
    {
        static Version Parse(string value)
        {
            var core = value.Trim().TrimStart('v', 'V').Split('-', 2)[0];
            return Version.TryParse(core, out var parsed) ? parsed : new Version(0, 0);
        }
        return Parse(left).CompareTo(Parse(right));
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AsantePDF-Windows/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }
}
'@

$lifecycleWindows = Join-Path $SourceRoot 'src\PdfRescue.App\LifecycleWindows.cs'
Write-Text $lifecycleWindows @'
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed class FirstLaunchWindow : Window
{
    public FirstLaunchWindow()
    {
        Title = "Welcome to AsantePDF";
        Width = 650;
        Height = 520;
        MinWidth = 560;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new StackPanel { Margin = new Thickness(34) };
        root.Children.Add(new TextBlock { Text = "Welcome to AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "A free, local-first PDF workspace built for real document work.",
            FontSize = 15,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 7, 0, 26)
        });
        AddCard(root, "Free means free", "There is no Premium tier, subscription, feature lock or usage limit in AsantePDF.");
        AddCard(root, "Your files stay local", "Normal viewing, editing, OCR, conversion and PDF processing happen on this computer.");
        AddCard(root, "Start from Home", "Open a PDF, drag one into the window, or choose a standalone tool without opening a document first.");
        AddCard(root, "Your workspace can recover", "AsantePDF can remember normal sessions and separately keep a local crash-recovery snapshot for unsaved page-layout work.");

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        var settings = new Button { Content = "You can change themes and privacy in Settings", IsEnabled = false, Style = (Style)FindResource("FlatButtonStyle"), Margin = new Thickness(0, 0, 10, 0) };
        var start = new Button { Content = "Start using AsantePDF", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(18, 9, 18, 9) };
        start.Click += (_, _) => { DialogResult = true; Close(); };
        buttons.Children.Add(settings);
        buttons.Children.Add(start);
        root.Children.Add(buttons);
        Content = root;
    }

    private static void AddCard(Panel root, string title, string description)
    {
        var card = new Border
        {
            Background = (Brush)Application.Current.Resources["PanelRaisedBrush"],
            BorderBrush = (Brush)Application.Current.Resources["BorderBrushSoft"],
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(8), Padding = new Thickness(14), Margin = new Thickness(0, 0, 0, 10)
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = title, FontWeight = FontWeights.SemiBold, FontSize = 15 });
        stack.Children.Add(new TextBlock { Text = description, TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 4, 0, 0) });
        card.Child = stack;
        root.Children.Add(card);
    }
}

internal sealed class RecoveryWindow : Window
{
    public RecoveryWindow(RecoverySnapshot snapshot)
    {
        Title = "Recover AsantePDF workspace";
        Width = 640;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF did not close normally", FontSize = 27, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "A local recovery snapshot is available. Restoring it can reopen the PDFs below, including unsaved page order/rotation state. Original PDF files are not modified by recovery.",
            TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 8, 0, 18)
        });

        var list = new ListBox { MaxHeight = 230, Margin = new Thickness(0, 0, 0, 18) };
        foreach (var document in snapshot.Documents)
            list.Items.Add($"{Path.GetFileName(document.Path)}  •  {(document.IsDirty ? "unsaved layout" : "saved state")}  •  page {document.SelectedPage:N0}");
        root.Children.Add(list);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        var fresh = new Button { Content = "Start fresh", Style = (Style)FindResource("FlatButtonStyle"), Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(0, 0, 10, 0) };
        fresh.Click += (_, _) => { DialogResult = false; Close(); };
        var restore = new Button { Content = "Restore workspace", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(16, 8, 16, 8) };
        restore.Click += (_, _) => { DialogResult = true; Close(); };
        buttons.Children.Add(fresh);
        buttons.Children.Add(restore);
        root.Children.Add(buttons);
        Content = root;
    }
}

internal sealed class AppErrorDialog : Window
{
    private AppErrorDialog(string title, string message, string technicalDetails)
    {
        Title = title;
        Width = 680;
        Height = 510;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new Grid { Margin = new Thickness(26) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var heading = new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold };
        root.Children.Add(heading);
        var summary = new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 8, 0, 14) };
        Grid.SetRow(summary, 1); root.Children.Add(summary);
        var details = new TextBox { Text = technicalDetails, IsReadOnly = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, FontFamily = new FontFamily("Consolas"), FontSize = 12 };
        Grid.SetRow(details, 2); root.Children.Add(details);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 14, 0, 0) };
        var copy = new Button { Content = "Copy details", Style = (Style)FindResource("FlatButtonStyle") };
        copy.Click += (_, _) => Clipboard.SetText(technicalDetails);
        var logs = new Button { Content = "Open logs", Style = (Style)FindResource("FlatButtonStyle") };
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        var close = new Button { Content = "Close", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        close.Click += (_, _) => Close();
        buttons.Children.Add(copy); buttons.Children.Add(logs); buttons.Children.Add(close);
        Grid.SetRow(buttons, 3); root.Children.Add(buttons);
        Content = root;
    }

    public static void Show(Window? owner, string title, string message, Exception exception)
    {
        var details = $"{DateTimeOffset.Now:O}\n{message}\n\n{exception}\n\nLog: {App.StartupLogPath}";
        var dialog = new AppErrorDialog(title, message, details);
        if (owner is not null && owner.IsVisible) dialog.Owner = owner;
        dialog.ShowDialog();
    }
}

internal sealed class DiagnosticsWindow : Window
{
    private readonly TextBlock _updateStatus = new();
    private UpdateInfo? _availableUpdate;

    public DiagnosticsWindow()
    {
        Title = "About & Diagnostics — AsantePDF";
        Width = 720;
        Height = 610;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var version = UpdateService.CurrentVersion;
        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = $"Version {version}  •  Completely free  •  Local-first", Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 5, 0, 20) });

        var info = new StringBuilder();
        info.AppendLine($"Version: {version}");
        info.AppendLine($"Operating system: {Environment.OSVersion}");
        info.AppendLine($"Runtime: {Environment.Version}");
        info.AppendLine($"Process architecture: {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}");
        info.AppendLine($"64-bit process: {Environment.Is64BitProcess}");
        info.AppendLine($"Install/base folder: {AppContext.BaseDirectory}");
        info.AppendLine($"Logs: {App.LogDirectory}");
        var box = new TextBox { Text = info.ToString(), IsReadOnly = true, FontFamily = new FontFamily("Consolas"), FontSize = 12, Height = 245, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        root.Children.Add(box);

        _updateStatus.Text = "Update status has not been checked.";
        _updateStatus.TextWrapping = TextWrapping.Wrap;
        _updateStatus.Foreground = (Brush)Application.Current.Resources["MutedTextBrush"];
        _updateStatus.Margin = new Thickness(0, 16, 0, 8);
        root.Children.Add(_updateStatus);

        var actions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Left };
        var check = new Button { Content = "Check for updates", Style = (Style)FindResource("PrimaryButtonStyle") };
        check.Click += async (_, _) => await CheckUpdatesAsync();
        var release = new Button { Content = "Open update page", Style = (Style)FindResource("FlatButtonStyle"), IsEnabled = false };
        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
        var logs = new Button { Content = "Open logs folder", Style = (Style)FindResource("FlatButtonStyle") };
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        var copy = new Button { Content = "Copy diagnostics", Style = (Style)FindResource("FlatButtonStyle") };
        copy.Click += (_, _) => Clipboard.SetText(info.ToString());
        actions.Children.Add(check); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = root;

        async Task CheckUpdatesAsync()
        {
            _updateStatus.Text = "Checking GitHub Releases…";
            try
            {
                var update = await UpdateService.CheckAsync();
                if (update is null)
                {
                    _updateStatus.Text = "No release information was returned.";
                    return;
                }
                _availableUpdate = update;
                if (UpdateService.IsNewer(update))
                {
                    _updateStatus.Text = $"AsantePDF {update.Version} is available. The update page will open in your browser so you can review and install it.";
                    release.IsEnabled = true;
                }
                else
                {
                    _updateStatus.Text = $"You are up to date. Latest release: {update.Version}.";
                    release.IsEnabled = false;
                }
            }
            catch (Exception ex)
            {
                App.Log("Update check failed: " + ex);
                _updateStatus.Text = "Could not check for updates. Your current installation is unchanged.";
            }
        }
    }
}
'@

$lifecycle = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Lifecycle.cs'
Write-Text $lifecycle @'
using System.IO;
using System.Windows;
using System.Windows.Threading;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private RecoverySnapshot? _pendingRecoverySnapshot;
    private UpdateInfo? _availableUpdate;

    private async Task OfferStartupRecoveryAndOnboardingAsync()
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.RecoveryEnabled && _pendingRecoverySnapshot is { Documents.Count: > 0 } snapshot)
        {
            var recovery = new RecoveryWindow(snapshot) { Owner = this };
            if (recovery.ShowDialog() == true)
                await RestoreRecoverySnapshotAsync(snapshot);
            else
                RecoverySnapshotService.Current.DiscardSnapshot();
        }

        preferences = AppSettingsService.Current.Preferences;
        if (!preferences.FirstLaunchCompleted && !App.StartedWithPdfArgument)
        {
            var firstLaunch = new FirstLaunchWindow { Owner = this };
            if (firstLaunch.ShowDialog() == true)
                AppSettingsService.Current.Save(AppSettingsService.Current.Preferences with { FirstLaunchCompleted = true });
        }

        if (AppSettingsService.Current.Preferences.CheckForUpdates)
            _ = CheckForUpdatesSilentlyAsync();
    }

    private async Task RestoreRecoverySnapshotAsync(RecoverySnapshot snapshot)
    {
        var available = snapshot.Documents.Where(document => File.Exists(document.Path)).ToArray();
        if (available.Length == 0) return;

        foreach (var state in available)
        {
            if (DocumentTabs.Any(tab => string.Equals(tab.Path, state.Path, StringComparison.OrdinalIgnoreCase))) continue;
            DocumentTabs.Add(new DocumentTabSession(state.Path)
            {
                IsDirty = state.IsDirty,
                SelectedPage = state.SelectedPage,
                PreviewWidth = state.PreviewWidth,
                HorizontalOffset = state.HorizontalOffset,
                VerticalOffset = state.VerticalOffset,
                WorkingLayout = state.WorkingLayout.ToArray(),
                SavedLayout = state.SavedLayout.ToArray(),
                UndoHistory = state.UndoHistory.ToArray(),
                RedoHistory = state.RedoHistory.ToArray()
            });
        }

        var targetIndex = Math.Clamp(snapshot.ActiveDocumentIndex, 0, Math.Max(0, available.Length - 1));
        var targetPath = available[targetIndex].Path;
        var target = DocumentTabs.FirstOrDefault(tab => string.Equals(tab.Path, targetPath, StringComparison.OrdinalIgnoreCase))
                     ?? DocumentTabs.FirstOrDefault(tab => File.Exists(tab.Path));
        if (target is not null)
        {
            await ActivateDocumentTabAsync(target);
            StatusText.Text = available.Any(document => document.IsDirty)
                ? $"Recovered {available.Length:N0} PDF tab(s), including unsaved page-layout state."
                : $"Recovered {available.Length:N0} PDF tab(s) from the interrupted session.";
        }
        PersistWorkspacePosition(immediate: true);
    }

    private async Task CheckForUpdatesSilentlyAsync()
    {
        try
        {
            var update = await UpdateService.CheckAsync(_lifetime.Token);
            if (update is null || !UpdateService.IsNewer(update)) return;
            _availableUpdate = update;
            if (SettingsButton is not null)
                SettingsButton.ToolTip = $"Settings · AsantePDF {update.Version} update available";
            App.Log($"Update available: {update.Version}");
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Silent update check failed: " + ex.Message);
        }
    }

    private void SaveRecoverySnapshot()
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (!preferences.RecoveryEnabled)
        {
            RecoverySnapshotService.Current.DiscardSnapshot();
            return;
        }
        RecoverySnapshotService.Current.SaveSnapshot(DocumentTabs, GetActiveDocumentTabIndex());
    }
}
'@

# Wire lifecycle to the existing product shell.
$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShell @'
        InitializeDocumentNavigationMetadata();

        _recentFilesView = new RecentFilesView();
'@ @'
        InitializeDocumentNavigationMetadata();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();

        _recentFilesView = new RecentFilesView();
'@ 'begin recovery session'

Replace-Exact $productShell @'
        Closed += async (_, _) =>
        {
            if (_backgroundTasks is not null)
                await _backgroundTasks.DisposeAsync();
        };

        LoadHomeRecents();
        RefreshResumeCommandState();
        RefreshProductShellMode();
'@ @'
        Closed += async (_, _) =>
        {
            RecoverySnapshotService.Current.MarkCleanShutdown();
            if (_backgroundTasks is not null)
                await _backgroundTasks.DisposeAsync();
        };

        LoadHomeRecents();
        RefreshResumeCommandState();
        RefreshProductShellMode();
        _ = Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(async () =>
            await OfferStartupRecoveryAndOnboardingAsync()));
'@ 'startup recovery onboarding dispatch'

Replace-Exact $productShell @'
        if (preferences.ReopenLastSession)
            _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        else
            _recentDocuments.ClearLastSession();
        RefreshResumeCommandState();
'@ @'
        if (preferences.ReopenLastSession)
            _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        else
            _recentDocuments.ClearLastSession();
        SaveRecoverySnapshot();
        RefreshResumeCommandState();
'@ 'save crash recovery alongside normal session state'

# Coalesce layout edits into the existing 450ms persistence timer so crash state captures unsaved layout work.
$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        CompareTabsButton.IsEnabled = available && DocumentTabs.Count >= 2;
        UpdateDocumentTitleDirtyIndicator();
        UpdateInspectorContext();
    }
'@ @'
        CompareTabsButton.IsEnabled = available && DocumentTabs.Count >= 2;
        UpdateDocumentTitleDirtyIndicator();
        UpdateInspectorContext();
        if (_productShellInitialized) PersistWorkspacePosition();
    }
'@ 'coalesced recovery persistence'

# Replace generic operation-failure message with a diagnostic-aware dialog.
Replace-Exact $main @'
            App.Log($"Operation failed [{status}]: {ex}");
            StatusText.Text = "Operation failed.";
            MessageBox.Show(this, ex.Message, "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Error);
            return false;
'@ @'
            App.Log($"Operation failed [{status}]: {ex}");
            StatusText.Text = "Operation failed.";
            AppErrorDialog.Show(this, "AsantePDF operation failed", $"{status} could not be completed. Your source file was left unchanged unless the operation had already completed successfully.", ex);
            return false;
'@ 'professional operation error dialog'

# Replace the old About message with a real diagnostics surface.
$aboutOld = @'
    private void About_Click(object sender, RoutedEventArgs e)
    {
        var version = typeof(MainWindow).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion?
            .Split('+', 2)[0]
            ?? "1.0";

        MessageBox.Show(this,
            $"AsantePDF\nLocal-first PDF workspace for Windows\n\nVersion {version}\nRealMindX Education Ltd",
            "About AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
    }
'@
$aboutNew = @'
    private void About_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new DiagnosticsWindow { Owner = this };
        dialog.ShowDialog();
    }
'@
Replace-Exact $main $aboutOld $aboutNew 'About diagnostics window'

# Help button becomes the discoverable About/Diagnostics entry point.
$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Help"><TextBlock Text="?" FontSize="17" /></Button>
'@ @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="About, diagnostics and updates" Click="About_Click"><TextBlock Text="?" FontSize="17" /></Button>
'@ 'help diagnostics button'

# Record command-line startup before the main window is shown so first-launch UI never blocks file-association launches.
$app = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml.cs'
Replace-Exact $app @'
    public static string WindowReadyPath => Path.Combine(LogDirectory, "window-ready.flag");

    protected override void OnStartup(StartupEventArgs e)
'@ @'
    public static string WindowReadyPath => Path.Combine(LogDirectory, "window-ready.flag");
    public static bool StartedWithPdfArgument { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
'@ 'command line startup flag property'

Replace-Exact $app @'
            var window = new MainWindow();
            MainWindow = window;
'@ @'
            var pdfArgument = e.Args.FirstOrDefault(a =>
                a.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase) && File.Exists(a));
            StartedWithPdfArgument = pdfArgument is not null;

            var window = new MainWindow();
            MainWindow = window;
'@ 'move pdf argument detection before show'

Replace-Exact $app @'
            var pdfArgument = e.Args.FirstOrDefault(a =>
                a.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase) && File.Exists(a));
            if (pdfArgument is not null)
                _ = window.OpenPdfFromCommandLineAsync(pdfArgument);
'@ @'
            if (pdfArgument is not null)
                _ = window.OpenPdfFromCommandLineAsync(pdfArgument);
'@ 'remove duplicate pdf argument detection'

Replace-Exact $app @'
            Log("Fatal startup exception: " + ex);
            MessageBox.Show(
                "AsantePDF could not start. A diagnostic log was written to:\n\n" + StartupLogPath,
                "AsantePDF",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(-1);
'@ @'
            Log("Fatal startup exception: " + ex);
            try { AppErrorDialog.Show(null, "AsantePDF could not start", "Startup failed before the main workspace became available. A diagnostic log has been preserved.", ex); }
            catch
            {
                MessageBox.Show("AsantePDF could not start. Diagnostic log:\n\n" + StartupLogPath,
                    "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            Shutdown(-1);
'@ 'startup error dialog'

Replace-Exact $app @'
        Log("Dispatcher exception: " + e.Exception);
        MessageBox.Show(
            "AsantePDF encountered an unexpected error. Details were written to:\n\n" + StartupLogPath,
            "AsantePDF",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
'@ @'
        Log("Dispatcher exception: " + e.Exception);
        try { AppErrorDialog.Show(Current?.MainWindow, "AsantePDF encountered an unexpected error", "The application caught an unexpected interface error and preserved diagnostic details.", e.Exception); }
        catch
        {
            MessageBox.Show("AsantePDF encountered an unexpected error. Diagnostic log:\n\n" + StartupLogPath,
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        e.Handled = true;
'@ 'dispatcher error dialog'

# Explicit modern DPI behaviour for sharp WPF rendering across mixed-monitor setups.
$manifest = Join-Path $SourceRoot 'src\PdfRescue.App\app.manifest'
Write-Text $manifest @'
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="AsantePDF"/>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>
    </windowsSettings>
  </application>
</assembly>
'@

Write-Host 'Lifecycle recovery onboarding diagnostics updates and DPI support staged.' -ForegroundColor Green
