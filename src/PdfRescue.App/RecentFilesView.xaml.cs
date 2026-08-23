using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class RecentFilesView : UserControl
{
    private RecentDocumentService? _service;
    private List<RecentDocumentItem> _allItems = [];
    private CancellationTokenSource? _thumbnailCts;
    private RecentViewMode _viewMode = RecentViewMode.Grid;
    private RecentSortMode _sortMode = RecentSortMode.LastOpened;
    private bool _suppressPreferenceEvents;
    private int _refreshGeneration;

    public RecentFilesView()
    {
        InitializeComponent();
        Loaded += RecentFilesView_Loaded;
        Unloaded += RecentFilesView_Unloaded;
    }

    public event Func<string, Task>? OpenRequested;
    public event Func<WorkspaceSessionState, Task>? ResumeRequested;

    public void SetService(RecentDocumentService service)
    {
        _service = service;
        if (IsLoaded) _ = RefreshAsync();
    }

    public void SetSearch(string query)
    {
        query ??= string.Empty;
        if (!string.Equals(RecentSearchBox.Text, query, StringComparison.Ordinal))
            RecentSearchBox.Text = query;
        else
            RefreshVisibleItems();
    }

    public async Task RefreshAsync()
    {
        var service = _service;
        if (service is null) return;

        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = new CancellationTokenSource();
        var token = _thumbnailCts.Token;
        var generation = ++_refreshGeneration;

        _allItems = service.LoadItems().ToList();
        _viewMode = service.PreferredView;
        _sortMode = service.PreferredSort;

        _suppressPreferenceEvents = true;
        SortCombo.SelectedIndex = _sortMode switch
        {
            RecentSortMode.Name => 1,
            RecentSortMode.Modified => 2,
            _ => 0
        };
        _suppressPreferenceEvents = false;

        ApplyViewMode();
        RefreshVisibleItems();
        RefreshResumeState();

        foreach (var item in _allItems.Where(item => item.Available))
        {
            try
            {
                token.ThrowIfCancellationRequested();
                var result = await service.GetThumbnailAsync(item.Path, token);
                if (generation != _refreshGeneration || token.IsCancellationRequested) return;
                if (result is null) continue;
                item.PageCount = result.PageCount;
                item.Thumbnail = result.Thumbnail;
            }
            catch (OperationCanceledException)
            {
                return;
            }
            catch (Exception ex)
            {
                App.Log($"Recent thumbnail failed for {item.Path}: {ex.Message}");
            }
        }
    }

    private void RecentFilesView_Loaded(object sender, RoutedEventArgs e)
    {
        if (_service is not null) _ = RefreshAsync();
    }

    private void RecentFilesView_Unloaded(object sender, RoutedEventArgs e)
    {
        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = null;
    }

    private void RefreshVisibleItems()
    {
        var query = RecentSearchBox.Text.Trim();
        IEnumerable<RecentDocumentItem> filtered = _allItems;
        if (!string.IsNullOrWhiteSpace(query))
        {
            filtered = filtered.Where(item =>
                item.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                item.Path.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                item.Location.Contains(query, StringComparison.OrdinalIgnoreCase));
        }

        IOrderedEnumerable<RecentDocumentItem> ordered = _sortMode switch
        {
            RecentSortMode.Name => filtered
                .OrderByDescending(item => item.IsPinned)
                .ThenBy(item => item.Name, StringComparer.OrdinalIgnoreCase),
            RecentSortMode.Modified => filtered
                .OrderByDescending(item => item.IsPinned)
                .ThenByDescending(item => item.ModifiedUtc ?? DateTime.MinValue),
            _ => filtered
                .OrderByDescending(item => item.IsPinned)
                .ThenByDescending(item => item.LastOpenedUtc)
        };

        var visible = ordered.ToArray();
        RecentItems.ItemsSource = visible;
        EmptyState.Visibility = visible.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ApplyViewMode()
    {
        RecentItems.ItemsPanel = (ItemsPanelTemplate)FindResource(_viewMode switch
        {
            RecentViewMode.List => "RecentListPanel",
            RecentViewMode.Compact => "RecentCompactPanel",
            _ => "RecentGridPanel"
        });
        RecentItems.ItemTemplate = (DataTemplate)FindResource(_viewMode switch
        {
            RecentViewMode.List => "RecentListTemplate",
            RecentViewMode.Compact => "RecentCompactTemplate",
            _ => "RecentGridTemplate"
        });

        var activeBrush = TryFindResource("PanelHoverBrush") as Brush ?? Brushes.Transparent;
        GridViewButton.Background = _viewMode == RecentViewMode.Grid ? activeBrush : Brushes.Transparent;
        ListViewButton.Background = _viewMode == RecentViewMode.List ? activeBrush : Brushes.Transparent;
        CompactViewButton.Background = _viewMode == RecentViewMode.Compact ? activeBrush : Brushes.Transparent;
        GridViewButton.FontWeight = _viewMode == RecentViewMode.Grid ? FontWeights.SemiBold : FontWeights.Normal;
        ListViewButton.FontWeight = _viewMode == RecentViewMode.List ? FontWeights.SemiBold : FontWeights.Normal;
        CompactViewButton.FontWeight = _viewMode == RecentViewMode.Compact ? FontWeights.SemiBold : FontWeights.Normal;
    }

    private void RefreshResumeState()
    {
        var session = _service?.GetLastSession();
        ResumeSessionButton.Visibility = session is not null && session.Documents.Any(document => File.Exists(document.Path))
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private async void RecentOpen_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null) return;
        await OpenItemAsync(item);
    }

    private async void OpenMenu_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null) return;
        await OpenItemAsync(item);
    }

    private async Task OpenItemAsync(RecentDocumentItem item)
    {
        if (item.Missing || !File.Exists(item.Path))
        {
            MessageBox.Show(Window.GetWindow(this),
                "This PDF is no longer at its previous location. You can keep the entry, remove it, or locate the file manually.",
                "Recent file unavailable", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var handler = OpenRequested;
        if (handler is not null) await handler(item.Path);
    }

    private async void ResumeSession_Click(object sender, RoutedEventArgs e)
    {
        var session = _service?.GetLastSession();
        if (session is null) return;
        var handler = ResumeRequested;
        if (handler is not null) await handler(session);
    }

    private async void PinMenu_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null || _service is null) return;
        _service.TogglePin(item.Path);
        await RefreshAsync();
    }

    private async void RemoveMenu_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null || _service is null) return;
        _service.Remove(item.Path);
        await RefreshAsync();
    }

    private async void RemoveMissingMenu_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null || _service is null) return;
        if (File.Exists(item.Path))
        {
            MessageBox.Show(Window.GetWindow(this), "This file is still available, so the entry was not removed as missing.",
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        _service.Remove(item.Path);
        await RefreshAsync();
    }

    private void ShowInFolderMenu_Click(object sender, RoutedEventArgs e)
    {
        var item = GetItem(sender);
        if (item is null) return;
        try
        {
            if (File.Exists(item.Path))
            {
                Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{item.Path}\"") { UseShellExecute = true });
                return;
            }

            if (Directory.Exists(item.Location))
            {
                Process.Start(new ProcessStartInfo("explorer.exe", $"\"{item.Location}\"") { UseShellExecute = true });
                return;
            }

            MessageBox.Show(Window.GetWindow(this), "The original folder is also unavailable.",
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            App.Log("Show in Folder failed: " + ex.Message);
        }
    }

    private void RecentSearchBox_TextChanged(object sender, TextChangedEventArgs e) => RefreshVisibleItems();

    private void SortCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressPreferenceEvents || _service is null) return;
        _sortMode = SortCombo.SelectedIndex switch
        {
            1 => RecentSortMode.Name,
            2 => RecentSortMode.Modified,
            _ => RecentSortMode.LastOpened
        };
        _service.SetSortMode(_sortMode);
        RefreshVisibleItems();
    }

    private void GridView_Click(object sender, RoutedEventArgs e) => SetViewMode(RecentViewMode.Grid);
    private void ListView_Click(object sender, RoutedEventArgs e) => SetViewMode(RecentViewMode.List);
    private void CompactView_Click(object sender, RoutedEventArgs e) => SetViewMode(RecentViewMode.Compact);

    private void SetViewMode(RecentViewMode viewMode)
    {
        if (_service is null) return;
        _viewMode = viewMode;
        _service.SetViewMode(viewMode);
        ApplyViewMode();
    }

    private static RecentDocumentItem? GetItem(object sender) =>
        sender is FrameworkElement { DataContext: RecentDocumentItem item } ? item : null;
}
