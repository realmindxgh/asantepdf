using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed record DocumentSearchResultItem(
    int ResultOrdinal,
    int PagePosition,
    int SourcePageNumber,
    int MatchIndexOnPage,
    string Snippet,
    IReadOnlyList<PdfSearchRect> Rectangles)
{
    public string PageLabel => $"Page {PagePosition:N0}";
}

public partial class MainWindow
{
    private readonly DocumentSearchService _documentSearch = new();
    private CancellationTokenSource? _documentSearchCts;
    private IReadOnlyList<DocumentSearchResultItem> _documentSearchResults = [];
    private string _documentSearchQuery = string.Empty;
    private int _activeDocumentSearchIndex = -1;
    private bool _suppressSearchResultSelection;

    private void FocusDocumentSearch()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        EmptyPanel.Visibility = Visibility.Collapsed;
        PreviewScroll.Visibility = Visibility.Visible;
        ShowSearchSidebar();
        DocumentSearchBox.Focus();
        DocumentSearchBox.SelectAll();
    }

    private async void DocumentSearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            ClearDocumentSearch(clearText: true);
            e.Handled = true;
            return;
        }

        if (e.Key != Key.Enter) return;
        e.Handled = true;

        var query = DocumentSearchBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(query))
        {
            ClearDocumentSearch(clearText: false);
            return;
        }

        if (!string.Equals(query, _documentSearchQuery, StringComparison.Ordinal) || _documentSearchResults.Count == 0)
        {
            await RunDocumentSearchAsync(query);
            return;
        }

        await NavigateDocumentSearchAsync(Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) ? -1 : 1);
    }

    private async void SearchPrevious_Click(object sender, RoutedEventArgs e) =>
        await NavigateDocumentSearchAsync(-1);

    private async void SearchNext_Click(object sender, RoutedEventArgs e) =>
        await NavigateDocumentSearchAsync(1);

    private void SearchClear_Click(object sender, RoutedEventArgs e) =>
        ClearDocumentSearch(clearText: true);

    private void PageModeSearch_Click(object sender, RoutedEventArgs e)
    {
        ShowSearchSidebar();
        DocumentSearchBox.Focus();
    }

    private void ShowSearchSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Visible;
        UpdateSearchEmptyState();
    }

    private async Task RunDocumentSearchAsync(string query)
    {
        if (_currentPdf is null || Pages.Count == 0) return;

        _documentSearchCts?.Cancel();
        _documentSearchCts?.Dispose();
        _documentSearchCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _documentSearchCts.Token;
        var path = _currentPdf;
        var generation = _documentGeneration;

        _documentSearchQuery = query;
        _activeDocumentSearchIndex = -1;
        _documentSearchResults = [];
        SearchResultsList.ItemsSource = null;
        SearchCountText.Text = "Searching…";
        SearchPreviousButton.IsEnabled = false;
        SearchNextButton.IsEnabled = false;
        SearchClearButton.IsEnabled = true;
        SearchEmptyText.Text = "Searching this PDF…";
        ShowSearchSidebar();
        ClearDocumentSearchHighlights();

        try
        {
            var raw = await _documentSearch.SearchAsync(path, query, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(query, _documentSearchQuery, StringComparison.Ordinal))
                return;

            var expanded = new List<DocumentSearchResultItem>();
            foreach (var match in raw)
            {
                foreach (var page in Pages.Where(page => page.SourcePageNumber == match.SourcePageNumber))
                {
                    expanded.Add(new DocumentSearchResultItem(
                        0,
                        page.Position,
                        match.SourcePageNumber,
                        match.MatchIndexOnPage,
                        match.Snippet,
                        match.Rectangles));
                }
            }

            _documentSearchResults = expanded
                .OrderBy(result => result.PagePosition)
                .ThenBy(result => result.MatchIndexOnPage)
                .Select((result, index) => result with { ResultOrdinal = index + 1 })
                .ToArray();

            SearchResultsList.ItemsSource = _documentSearchResults;
            SearchPreviousButton.IsEnabled = _documentSearchResults.Count > 0;
            SearchNextButton.IsEnabled = _documentSearchResults.Count > 0;
            UpdateSearchEmptyState();

            if (_documentSearchResults.Count == 0)
            {
                SearchCountText.Text = "0 / 0";
                StatusText.Text = $"No matches for “{query}”.";
                return;
            }

            await NavigateToDocumentSearchResultAsync(0);
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Document search failed: " + ex);
            if (generation != _documentGeneration) return;
            SearchCountText.Text = "Search failed";
            SearchEmptyText.Text = "Search could not be completed for this PDF.";
            StatusText.Text = "Document search failed.";
        }
    }

    private async Task NavigateDocumentSearchAsync(int delta)
    {
        if (_documentSearchResults.Count == 0) return;
        var next = _activeDocumentSearchIndex < 0
            ? 0
            : (_activeDocumentSearchIndex + delta + _documentSearchResults.Count) % _documentSearchResults.Count;
        await NavigateToDocumentSearchResultAsync(next);
    }

    private async Task NavigateToDocumentSearchResultAsync(int index)
    {
        if (index < 0 || index >= _documentSearchResults.Count || Pages.Count == 0) return;

        _activeDocumentSearchIndex = index;
        var result = _documentSearchResults[index];
        SearchCountText.Text = $"{index + 1:N0} / {_documentSearchResults.Count:N0}";

        _suppressSearchResultSelection = true;
        try
        {
            SearchResultsList.SelectedIndex = index;
            SearchResultsList.ScrollIntoView(SearchResultsList.SelectedItem);
        }
        finally
        {
            _suppressSearchResultSelection = false;
        }

        var pageIndex = Math.Clamp(result.PagePosition, 1, Pages.Count) - 1;
        var pageChanged = PagesList.SelectedIndex != pageIndex;
        PagesList.SelectedIndex = pageIndex;
        PagesList.ScrollIntoView(PagesList.SelectedItem);

        if (!pageChanged && PagesList.SelectedItem is PdfPageItem page)
            RefreshDocumentSearchHighlights(page);

        StatusText.Text = $"Search result {index + 1:N0} of {_documentSearchResults.Count:N0} on page {result.PagePosition:N0}.";
        await Task.CompletedTask;
    }

    private async void SearchResultsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressSearchResultSelection || SearchResultsList.SelectedIndex < 0) return;
        await NavigateToDocumentSearchResultAsync(SearchResultsList.SelectedIndex);
    }

    private void UpdateSearchEmptyState()
    {
        if (SearchResultsPanel.Visibility != Visibility.Visible) return;
        SearchEmptyText.Visibility = _documentSearchResults.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        SearchResultsList.Visibility = _documentSearchResults.Count == 0 ? Visibility.Collapsed : Visibility.Visible;
        if (_documentSearchResults.Count == 0 && !string.IsNullOrWhiteSpace(_documentSearchQuery))
            SearchEmptyText.Text = "No matching text found in this PDF.";
        else if (_documentSearchResults.Count == 0)
            SearchEmptyText.Text = "Enter text above or press Ctrl+F to search this PDF.";
    }

    private void RefreshDocumentSearchHighlights(PdfPageItem page)
    {
        ClearDocumentSearchHighlights();
        if (_documentSearchResults.Count == 0 || PreviewImage.Source is not System.Windows.Media.Imaging.BitmapSource bitmap)
            return;

        var pageResults = _documentSearchResults
            .Select((result, index) => (Result: result, Index: index))
            .Where(item => item.Result.PagePosition == page.Position)
            .ToArray();
        if (pageResults.Length == 0) return;

        SearchHighlightCanvas.Width = bitmap.PixelWidth;
        SearchHighlightCanvas.Height = bitmap.PixelHeight;
        SearchHighlightCanvas.LayoutTransform = new RotateTransform(page.Rotation);
        SearchHighlightCanvas.Visibility = Visibility.Visible;

        foreach (var item in pageResults)
        {
            var active = item.Index == _activeDocumentSearchIndex;
            foreach (var rect in item.Result.Rectangles)
            {
                var highlight = new Rectangle
                {
                    Width = Math.Max(2, rect.Width * bitmap.PixelWidth),
                    Height = Math.Max(2, rect.Height * bitmap.PixelHeight),
                    Fill = new SolidColorBrush(active
                        ? Color.FromArgb(145, 255, 190, 48)
                        : Color.FromArgb(90, 255, 224, 92)),
                    Stroke = active ? new SolidColorBrush(Color.FromRgb(255, 159, 26)) : null,
                    StrokeThickness = active ? 1.5 : 0,
                    IsHitTestVisible = false
                };
                Canvas.SetLeft(highlight, rect.X * bitmap.PixelWidth);
                Canvas.SetTop(highlight, rect.Y * bitmap.PixelHeight);
                SearchHighlightCanvas.Children.Add(highlight);
            }
        }
    }

    private void ClearDocumentSearchHighlights()
    {
        if (SearchHighlightCanvas is null) return;
        SearchHighlightCanvas.Children.Clear();
        SearchHighlightCanvas.Visibility = Visibility.Collapsed;
    }

    private void ClearDocumentSearch(bool clearText)
    {
        _documentSearchCts?.Cancel();
        _documentSearchCts?.Dispose();
        _documentSearchCts = null;
        _documentSearchResults = [];
        _documentSearchQuery = string.Empty;
        _activeDocumentSearchIndex = -1;
        SearchResultsList.ItemsSource = null;
        SearchResultsList.SelectedIndex = -1;
        SearchCountText.Text = string.Empty;
        SearchPreviousButton.IsEnabled = false;
        SearchNextButton.IsEnabled = false;
        SearchClearButton.IsEnabled = false;
        if (clearText) DocumentSearchBox.Text = string.Empty;
        ClearDocumentSearchHighlights();
        UpdateSearchEmptyState();
    }

    private void ResetDocumentSearchForDocumentChange()
    {
        if (!_productShellInitialized) return;
        ClearDocumentSearch(clearText: true);
        PagesList.Visibility = Visibility.Visible;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
    }
}
