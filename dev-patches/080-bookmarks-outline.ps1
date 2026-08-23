param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    [IO.File]::WriteAllText($Path, $Content.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    [IO.File]::WriteAllText($Path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

$outlineServicePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\DocumentOutlineService.cs'
Write-Utf8NoBom $outlineServicePath @'
using System.IO;
using System.Runtime.InteropServices;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfOutlineItem(
    string Title,
    int? SourcePageNumber,
    IReadOnlyList<PdfOutlineItem> Children,
    bool IsInitiallyExpanded)
{
    public string PageLabel => SourcePageNumber is int page ? $"Page {page:N0}" : string.Empty;
}

public sealed class DocumentOutlineService
{
    private const int MaxOutlineDepth = 64;
    private const int MaxOutlineNodes = 10_000;
    private const ulong MaxTitleBytes = 1024 * 1024;

    public Task<IReadOnlyList<PdfOutlineItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    private static IReadOnlyList<PdfOutlineItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);

        using var runtimeAnchor = PdfRendererFactory.CreateProduction();
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for outline navigation.");

        try
        {
            var first = fpdf_doc.FPDFBookmarkGetFirstChild(document, null);
            if (first is null) return [];

            var visited = new HashSet<IntPtr>();
            var total = 0;
            return ReadSiblings(document, first, visited, ref total, 0, token);
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static IReadOnlyList<PdfOutlineItem> ReadSiblings(
        FpdfDocumentT document,
        FpdfBookmarkT first,
        HashSet<IntPtr> visited,
        ref int total,
        int depth,
        CancellationToken token)
    {
        var items = new List<PdfOutlineItem>();
        if (depth > MaxOutlineDepth) return items;

        var current = first;
        while (current is not null && total < MaxOutlineNodes)
        {
            token.ThrowIfCancellationRequested();

            var handle = current.__Instance;
            if (handle == IntPtr.Zero || !visited.Add(handle)) break;
            total++;

            var title = ReadTitle(current);
            var sourcePage = ResolveSourcePageNumber(document, current);
            IReadOnlyList<PdfOutlineItem> children = [];

            if (depth < MaxOutlineDepth)
            {
                var child = fpdf_doc.FPDFBookmarkGetFirstChild(document, current);
                if (child is not null)
                    children = ReadSiblings(document, child, visited, ref total, depth + 1, token);
            }

            items.Add(new PdfOutlineItem(
                title,
                sourcePage,
                children,
                children.Count > 0));

            current = fpdf_doc.FPDFBookmarkGetNextSibling(document, current);
        }

        return items;
    }

    private static string ReadTitle(FpdfBookmarkT bookmark)
    {
        var required = fpdf_doc.FPDFBookmarkGetTitle(bookmark, IntPtr.Zero, 0);
        if (required < 2 || required > MaxTitleBytes) return "Untitled bookmark";

        var buffer = Marshal.AllocHGlobal(checked((int)required));
        try
        {
            var written = fpdf_doc.FPDFBookmarkGetTitle(bookmark, buffer, required);
            if (written == 0) return "Untitled bookmark";
            var title = (Marshal.PtrToStringUni(buffer) ?? string.Empty).TrimEnd('\0').Trim();
            return string.IsNullOrWhiteSpace(title) ? "Untitled bookmark" : title;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static int? ResolveSourcePageNumber(FpdfDocumentT document, FpdfBookmarkT bookmark)
    {
        var destination = fpdf_doc.FPDFBookmarkGetDest(document, bookmark);
        if (destination is null)
        {
            var action = fpdf_doc.FPDFBookmarkGetAction(bookmark);
            if (action is not null)
                destination = fpdf_doc.FPDFActionGetDest(document, action);
        }

        if (destination is null) return null;
        var pageIndex = fpdf_doc.FPDFDestGetDestPageIndex(document, destination);
        return pageIndex >= 0 ? pageIndex + 1 : null;
    }
}
'@

$bookmarksControllerPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Bookmarks.cs'
Write-Utf8NoBom $bookmarksControllerPath @'
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
'@

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath `
@'
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModePlaceholder_Click" Content="Bookmarks" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
'@ `
@'
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModeBookmarks_Click" Content="Bookmarks" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
'@ 'Bookmarks tab click handler'

Replace-Exact $xamlPath `
@'
                                <StackPanel x:Name="NavigationPlaceholder" Grid.Row="1" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18">
                                    <TextBlock Text="Bookmarks" FontWeight="SemiBold" HorizontalAlignment="Center" />
                                    <TextBlock Text="PDF outline and bookmark navigation are still being built." TextWrapping="Wrap" TextAlignment="Center" Foreground="{StaticResource MutedTextBrush}" FontSize="12" Margin="0,6,0,0" />
                                </StackPanel>
'@ `
@'
                                <Grid x:Name="BookmarksPanel" Grid.Row="1" Visibility="Collapsed">
                                    <TreeView x:Name="OutlineTree" Background="Transparent" BorderThickness="0" Margin="6"
                                              SelectedItemChanged="OutlineTree_SelectedItemChanged"
                                              ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                        <TreeView.ItemContainerStyle>
                                            <Style TargetType="TreeViewItem">
                                                <Setter Property="IsExpanded" Value="{Binding IsInitiallyExpanded}" />
                                                <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
                                                <Setter Property="Padding" Value="2" />
                                            </Style>
                                        </TreeView.ItemContainerStyle>
                                        <TreeView.ItemTemplate>
                                            <HierarchicalDataTemplate ItemsSource="{Binding Children}">
                                                <Grid Margin="2,3,4,3">
                                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                    <TextBlock Text="{Binding Title}" TextWrapping="Wrap" FontSize="12" />
                                                    <TextBlock Grid.Column="1" Text="{Binding PageLabel}" Foreground="{StaticResource MutedTextBrush}"
                                                               FontSize="10" Margin="8,0,0,0" VerticalAlignment="Center" />
                                                </Grid>
                                            </HierarchicalDataTemplate>
                                        </TreeView.ItemTemplate>
                                    </TreeView>
                                    <TextBlock x:Name="BookmarksEmptyText" Text="Open Bookmarks to load this PDF's outline."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18"
                                               IsHitTestVisible="False" />
                                </Grid>
'@ 'Bookmarks placeholder panel'

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShellPath `
@'
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        InitializeDocumentTabs();

        _recentFilesView = new RecentFilesView();
'@ `
@'
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        InitializeDocumentTabs();
        InitializeDocumentOutline();

        _recentFilesView = new RecentFilesView();
'@ 'outline lifecycle initialization'

Replace-Exact $productShellPath `
@'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        NavigationPlaceholder.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
    }

    private void PageModePlaceholder_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        NavigationPlaceholder.Visibility = Visibility.Visible;
    }
'@ `
@'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
    }
'@ 'page mode handlers'

$searchPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Search.cs'
Replace-Exact $searchPath '        NavigationPlaceholder.Visibility = Visibility.Collapsed;' '        BookmarksPanel.Visibility = Visibility.Collapsed;' 'search sidebar bookmark collapse'

$mainWindowPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $mainWindowPath `
@'
            _currentPdf = fullPath;
            ResetDocumentSearchForDocumentChange();
            _documentGeneration++;
'@ `
@'
            _currentPdf = fullPath;
            ResetDocumentSearchForDocumentChange();
            ResetDocumentOutlineForDocumentChange();
            _documentGeneration++;
'@ 'outline reset on document open'

$tabsPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
Replace-Exact $tabsPath `
@'
        PreviewImage.Source = null;
        ResetDocumentSearchForDocumentChange();
        DocumentTitle.Text = "No document open";
'@ `
@'
        PreviewImage.Source = null;
        ResetDocumentSearchForDocumentChange();
        ResetDocumentOutlineForDocumentChange();
        DocumentTitle.Text = "No document open";
'@ 'outline reset when last tab closes'

Write-Host 'Native PDF bookmarks/outline development patch applied.' -ForegroundColor Green
