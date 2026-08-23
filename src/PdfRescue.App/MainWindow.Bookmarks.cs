using System.Windows;
using System.Windows.Controls;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly DocumentOutlineService _documentOutline = new();
    private CancellationTokenSource? _outlineCts;
    private string? _outlineLoadedForPath;

    private void InitializeDocumentOutline()
    {
        Closed += (_, _) =>
        {
            _outlineCts?.Cancel();
            _outlineCts?.Dispose();
            _outlineCts = null;
        };
    }

    private async void PageModeBookmarks_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        ShowBookmarksSidebar();
        await LoadDocumentOutlineAsync();
    }

    private void ShowBookmarksSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Visible;
    }

    private async Task LoadDocumentOutlineAsync()
    {
        if (_currentPdf is null) return;
        var path = _currentPdf;

        if (string.Equals(_outlineLoadedForPath, path, StringComparison.OrdinalIgnoreCase))
        {
            UpdateBookmarksEmptyState();
            return;
        }

        _outlineCts?.Cancel();
        _outlineCts?.Dispose();
        _outlineCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _outlineCts.Token;
        var generation = _documentGeneration;

        OutlineTree.ItemsSource = null;
        BookmarksEmptyText.Text = "Loading PDF outline…";
        BookmarksEmptyText.Visibility = Visibility.Visible;

        try
        {
            var outline = await _documentOutline.LoadAsync(path, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase))
                return;

            _outlineLoadedForPath = path;
            OutlineTree.ItemsSource = outline;
            UpdateBookmarksEmptyState();
            StatusText.Text = outline.Count == 0
                ? "This PDF does not contain an outline."
                : $"Loaded {CountOutlineNodes(outline):N0} PDF bookmark(s).";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF outline load failed: " + ex);
            if (generation != _documentGeneration) return;
            OutlineTree.ItemsSource = null;
            BookmarksEmptyText.Text = "Could not read this PDF's outline.";
            BookmarksEmptyText.Visibility = Visibility.Visible;
            StatusText.Text = "PDF bookmark navigation could not be loaded.";
        }
    }

    private void UpdateBookmarksEmptyState()
    {
        var hasItems = OutlineTree.Items.Count > 0;
        OutlineTree.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        BookmarksEmptyText.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;
        if (!hasItems)
            BookmarksEmptyText.Text = "This PDF does not contain an outline.";
    }

    private void OutlineTree_SelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
    {
        if (e.NewValue is not PdfOutlineItem item || item.SourcePageNumber is not int sourcePage) return;

        var target = Pages.FirstOrDefault(page => page.SourcePageNumber == sourcePage);
        if (target is null)
        {
            StatusText.Text = $"Bookmark “{item.Title}” points to a page removed from the working layout.";
            return;
        }

        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Bookmark “{item.Title}” opened page {target.Position:N0}.";
    }

    private void ResetDocumentOutlineForDocumentChange()
    {
        _outlineCts?.Cancel();
        _outlineCts?.Dispose();
        _outlineCts = null;
        _outlineLoadedForPath = null;

        if (!_productShellInitialized || OutlineTree is null) return;
        OutlineTree.ItemsSource = null;
        OutlineTree.Visibility = Visibility.Collapsed;
        BookmarksEmptyText.Text = "Open Bookmarks to load this PDF's outline.";
        BookmarksEmptyText.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
    }

    private static int CountOutlineNodes(IEnumerable<PdfOutlineItem> items)
    {
        var count = 0;
        foreach (var item in items)
        {
            count++;
            count += CountOutlineNodes(item.Children);
        }
        return count;
    }
}