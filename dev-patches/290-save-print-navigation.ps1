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

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                            <Button x:Name="SaveButton" Style="{StaticResource RibbonButtonStyle}" Click="SaveAs_Click" IsEnabled="False" ToolTip="Save As (Ctrl+Shift+S)">
                                                <StackPanel><TextBlock Text="&#xE74E;" FontFamily="Segoe MDL2 Assets" FontSize="22" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Save As" FontSize="12" Margin="0,5,0,0"/></StackPanel>
                                            </Button>
'@ @'
                                            <Button x:Name="SaveButton" Style="{StaticResource RibbonButtonStyle}" Click="Save_Click" IsEnabled="False" ToolTip="Save (Ctrl+S)">
                                                <StackPanel><TextBlock Text="&#xE74E;" FontFamily="Segoe MDL2 Assets" FontSize="22" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Save" FontSize="12" Margin="0,5,0,0"/></StackPanel>
                                            </Button>
                                            <Button x:Name="SaveAsButton" Style="{StaticResource RibbonButtonStyle}" Click="SaveAs_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Save As (Ctrl+Shift+S)">
                                                <StackPanel><TextBlock Text="&#xE792;" FontFamily="Segoe MDL2 Assets" FontSize="22" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Save As" FontSize="12" Margin="0,5,0,0"/></StackPanel>
                                            </Button>
                                            <Button x:Name="SaveCopyButton" Style="{StaticResource RibbonButtonStyle}" Click="SaveCopy_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Save a copy without changing this document">
                                                <StackPanel><TextBlock Text="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="22" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Save Copy" FontSize="12" Margin="0,5,0,0"/></StackPanel>
                                            </Button>
                                            <Button x:Name="PrintButton" Style="{StaticResource RibbonButtonStyle}" Click="Print_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Print (Ctrl+P)">
                                                <StackPanel><TextBlock Text="&#xE749;" FontFamily="Segoe MDL2 Assets" FontSize="22" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Print" FontSize="12" Margin="0,5,0,0"/></StackPanel>
                                            </Button>
'@ 'save print ribbon controls'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
    private async void SaveAs_Click(object sender, RoutedEventArgs e)
    {
        await SaveCurrentLayoutAsync(showSuccessMessage: true);
    }

    private async Task<bool> SaveCurrentLayoutAsync(bool showSuccessMessage)
    {
        if (_currentPdf is null || Pages.Count == 0) return false;
        var output = AskSavePath("Save PDF As", SuggestName(_currentPdf, "edited"));
        if (output is null) return false;

        var saved = await RunPdfOperationAsync("Saving PDF...", "Saved PDF successfully.", async token =>
        {
            var transforms = Pages.Select(p => new PdfPageTransform(p.SourcePageNumber, p.Rotation)).ToArray();
            await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, output, token);
        });

        if (!saved) return false;

        _savedLayoutBaseline = CaptureLayout();
        UpdateCommandStates();

        if (showSuccessMessage)
            MessageBox.Show(this, "Saved successfully.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);

        return true;
    }
'@ @'
    private async void Save_Click(object sender, RoutedEventArgs e) => await SaveInPlaceAsync(showSuccessMessage: true);

    private async void SaveAs_Click(object sender, RoutedEventArgs e) => await SaveAsCurrentDocumentAsync(showSuccessMessage: true);

    private async void SaveCopy_Click(object sender, RoutedEventArgs e) => await SaveCopyCurrentLayoutAsync(showSuccessMessage: true);

    private async Task<bool> SaveInPlaceAsync(bool showSuccessMessage)
    {
        if (_currentPdf is null || Pages.Count == 0) return false;
        if (!HasUnsavedLayoutChanges())
        {
            if (showSuccessMessage) StatusText.Text = "No unsaved page-layout changes.";
            return true;
        }

        var source = _currentPdf;
        var directory = Path.GetDirectoryName(source)!;
        var temp = Path.Combine(Path.GetTempPath(), "AsantePDF", "save", Guid.NewGuid().ToString("N") + ".pdf");
        Directory.CreateDirectory(Path.GetDirectoryName(temp)!);

        var saved = await RunPdfOperationAsync("Saving PDF...", "Saved PDF successfully.", async token =>
        {
            var transforms = Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray();
            await _operations.ApplyPageLayoutAsync(source, transforms, temp, token);
            token.ThrowIfCancellationRequested();

            var staged = Path.Combine(directory, "." + Path.GetFileName(source) + "." + Guid.NewGuid().ToString("N") + ".staged");
            File.Copy(temp, staged, true);
            try
            {
                if (File.Exists(source)) File.Replace(staged, source, null, true);
                else File.Move(staged, source);
            }
            finally { try { if (File.Exists(staged)) File.Delete(staged); } catch { } }
        });

        try { if (File.Exists(temp)) File.Delete(temp); } catch { }
        if (!saved) return false;

        await ReloadCurrentPdfAfterInPlaceSaveAsync(source);
        if (showSuccessMessage)
            MessageBox.Show(this, "Saved successfully.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
        return true;
    }

    private async Task ReloadCurrentPdfAfterInPlaceSaveAsync(string source)
    {
        _thumbnailCts?.Cancel();
        _previewCts?.Cancel();
        await _renderer.OpenAsync(source, _lifetime.Token);
        _currentPdf = source;
        ResetDocumentSearchForDocumentChange();
        ResetDocumentOutlineForDocumentChange();
        ResetDocumentTextSelectionForDocumentChange();
        ResetDocumentNavigationMetadataForDocumentChange();
        _documentGeneration++;
        _undo.Clear();
        _redo.Clear();
        _thumbnailCache.Clear();
        Pages.Clear();
        var count = checked((int)_renderer.PageCount);
        for (var page = 1; page <= count; page++) Pages.Add(new PdfPageItem(page, page));
        _savedLayoutBaseline = CaptureLayout();
        PagesList.SelectedIndex = Math.Clamp(PagesList.SelectedIndex, 0, Math.Max(0, Pages.Count - 1));
        if (PagesList.SelectedItem is PdfPageItem selected) await RenderPreviewAsync(selected);
        CaptureActiveDocumentTabState();
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
    }

    private async Task<bool> SaveAsCurrentDocumentAsync(bool showSuccessMessage)
    {
        if (_currentPdf is null || Pages.Count == 0) return false;
        var original = _currentPdf;
        var output = AskSavePath("Save PDF As", SuggestName(original, "edited"));
        if (output is null) return false;
        if (string.Equals(Path.GetFullPath(output), Path.GetFullPath(original), StringComparison.OrdinalIgnoreCase))
            return await SaveInPlaceAsync(showSuccessMessage);

        var saved = await WriteLayoutCopyAsync(output, "Saving PDF As...");
        if (!saved) return false;

        var originalTab = _activeDocumentTab;
        if (originalTab is not null)
        {
            _savedLayoutBaseline = CaptureLayout();
            originalTab.IsDirty = false;
            CaptureActiveDocumentTabState();
        }
        await OpenPdfAsync(output);
        if (originalTab is not null && DocumentTabs.Contains(originalTab) && !ReferenceEquals(originalTab, _activeDocumentTab))
            await CloseDocumentTabAsync(originalTab);

        if (showSuccessMessage)
            MessageBox.Show(this, "Saved As successfully. The new file is now the active document.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
        return true;
    }

    private async Task<bool> SaveCopyCurrentLayoutAsync(bool showSuccessMessage)
    {
        if (_currentPdf is null || Pages.Count == 0) return false;
        var output = AskSavePath("Save a Copy", SuggestName(_currentPdf, "copy"));
        if (output is null) return false;
        if (string.Equals(Path.GetFullPath(output), Path.GetFullPath(_currentPdf), StringComparison.OrdinalIgnoreCase))
        {
            MessageBox.Show(this, "Save a Copy must use a different file. Use Save if you want to update the current PDF.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return false;
        }

        var saved = await WriteLayoutCopyAsync(output, "Saving a copy...");
        if (saved && showSuccessMessage)
            MessageBox.Show(this, "Copy saved. Your current document and its unsaved state were left unchanged.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
        return saved;
    }

    private Task<bool> WriteLayoutCopyAsync(string output, string status)
    {
        if (_currentPdf is null) return Task.FromResult(false);
        var source = _currentPdf;
        return RunPdfOperationAsync(status, "Saved successfully.", async token =>
        {
            var transforms = Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray();
            await _operations.ApplyPageLayoutAsync(source, transforms, output, token);
        });
    }
'@ 'proper save contract'

Replace-Exact $main @'
        if (choice == MessageBoxResult.Yes)
            return await SaveCurrentLayoutAsync(showSuccessMessage: false);
'@ @'
        if (choice == MessageBoxResult.Yes)
            return await SaveCopyCurrentLayoutAsync(showSuccessMessage: false);
'@ 'close prompt saves a copy'

Replace-Exact $main @'
        else if (ctrl && e.Key == Key.C && TryCopySelectedDocumentTextFromKeyboard()) { e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@ @'
        else if (ctrl && e.Key == Key.C && TryCopySelectedDocumentTextFromKeyboard()) { e.Handled = true; }
        else if (ctrl && !shift && e.Key == Key.S) { Save_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.P) { Print_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@ 'save print keyboard shortcuts'

Replace-Exact $main @'
        else if (ctrl && e.Key == Key.D0) { FitWidth_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (e.Key == Key.Delete) { DeletePages_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@ @'
        else if (ctrl && e.Key == Key.D0) { FitWidth_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (!ctrl && Keyboard.FocusedElement is not TextBox && (e.Key == Key.Left || e.Key == Key.PageUp)) { PreviousPage_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (!ctrl && Keyboard.FocusedElement is not TextBox && (e.Key == Key.Right || e.Key == Key.PageDown)) { NextPage_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (!ctrl && Keyboard.FocusedElement is not TextBox && e.Key == Key.Home && Pages.Count > 0) { PagesList.SelectedIndex = 0; PagesList.ScrollIntoView(PagesList.SelectedItem); e.Handled = true; }
        else if (!ctrl && Keyboard.FocusedElement is not TextBox && e.Key == Key.End && Pages.Count > 0) { PagesList.SelectedIndex = Pages.Count - 1; PagesList.ScrollIntoView(PagesList.SelectedItem); e.Handled = true; }
        else if (e.Key == Key.Delete) { DeletePages_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@ 'page navigation keyboard shortcuts'

$printOptions = Join-Path $SourceRoot 'src\PdfRescue.App\PrintOptionsWindow.cs'
Write-Text $printOptions @'
using System.Windows;
using System.Windows.Controls;

namespace PdfRescue.App;

internal enum PrintPageScope
{
    All,
    Current,
    Selected,
    Custom
}

internal sealed record PrintOptions(int[] Pages, bool Landscape, bool FitToPrintableArea);

internal sealed class PrintOptionsWindow : Window
{
    private readonly int _pageCount;
    private readonly int _currentPage;
    private readonly int[] _selectedPages;
    private readonly ComboBox _scope = new();
    private readonly TextBox _customRange = new();
    private readonly ComboBox _orientation = new();
    private readonly CheckBox _fit = new() { Content = "Fit each page to the printer's printable area", IsChecked = true };

    public PrintOptions? Options { get; private set; }

    public PrintOptionsWindow(int pageCount, int currentPage, int[] selectedPages)
    {
        _pageCount = Math.Max(1, pageCount);
        _currentPage = Math.Clamp(currentPage, 1, _pageCount);
        _selectedPages = selectedPages.Where(page => page >= 1 && page <= _pageCount).Distinct().OrderBy(page => page).ToArray();

        Title = "Print AsantePDF document";
        Width = 520;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (System.Windows.Media.Brush)Application.Current.Resources["AppBackground"];
        Foreground = (System.Windows.Media.Brush)Application.Current.Resources["PrimaryTextBrush"];

        _scope.ItemsSource = new[] { "All pages", $"Current page ({_currentPage})", _selectedPages.Length > 0 ? $"Selected pages ({FormatPages(_selectedPages)})" : "Selected pages (none)", "Custom range" };
        _scope.SelectedIndex = _selectedPages.Length > 1 ? 2 : 0;
        _scope.SelectionChanged += (_, _) => _customRange.IsEnabled = _scope.SelectedIndex == 3;
        _customRange.Text = "1-" + _pageCount;
        _customRange.IsEnabled = false;
        _orientation.ItemsSource = new[] { "Printer default / Portrait", "Landscape" };
        _orientation.SelectedIndex = 0;

        var content = new StackPanel { Margin = new Thickness(24) };
        content.Children.Add(new TextBlock { Text = "Print", FontSize = 26, FontWeight = FontWeights.SemiBold });
        content.Children.Add(new TextBlock { Text = "Choose pages and layout, then select the printer and number of copies in the Windows print dialog.", TextWrapping = TextWrapping.Wrap, Foreground = (System.Windows.Media.Brush)FindResource("MutedTextBrush"), Margin = new Thickness(0, 5, 0, 18) });
        AddField(content, "Pages", _scope);
        AddField(content, "Custom range", _customRange, "Examples: 1-3,5,8-10");
        AddField(content, "Orientation", _orientation);
        content.Children.Add(_fit);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle"), Padding = new Thickness(15, 8, 15, 8) };
        cancel.Click += (_, _) => Close();
        var next = new Button { Content = "Choose Printer", Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(16, 8, 16, 8) };
        next.Click += Next_Click;
        buttons.Children.Add(cancel); buttons.Children.Add(next); content.Children.Add(buttons);
        Content = content;
        Loaded += (_, _) => PdfRescue.App.Services.AppearanceService.ApplyToWindow(this);
    }

    private void Next_Click(object sender, RoutedEventArgs e)
    {
        int[] pages;
        switch (_scope.SelectedIndex)
        {
            case 1: pages = [_currentPage]; break;
            case 2:
                if (_selectedPages.Length == 0)
                {
                    MessageBox.Show(this, "No pages are selected in the document.", "Print", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                pages = _selectedPages;
                break;
            case 3:
                if (!PageScopeParser.TryParse(_customRange.Text, _pageCount, out pages, out var error))
                {
                    MessageBox.Show(this, error, "Print range", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                break;
            default: pages = Enumerable.Range(1, _pageCount).ToArray(); break;
        }

        Options = new PrintOptions(pages, _orientation.SelectedIndex == 1, _fit.IsChecked == true);
        DialogResult = true;
    }

    private static void AddField(Panel panel, string label, UIElement control, string? help = null)
    {
        panel.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 4) });
        panel.Children.Add(control);
        if (!string.IsNullOrWhiteSpace(help)) panel.Children.Add(new TextBlock { Text = help, FontSize = 11, Foreground = (System.Windows.Media.Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 3, 0, 0) });
    }

    private static string FormatPages(IEnumerable<int> pages) => string.Join(", ", pages.Take(6)) + (pages.Count() > 6 ? "…" : string.Empty);
}
'@

$printer = Join-Path $SourceRoot 'src\PdfRescue.App\Services\PdfPrintService.cs'
Write-Text $printer @'
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace PdfRescue.App.Services;

internal sealed class PdfPrintService
{
    public async Task<FixedDocument> BuildAsync(
        string pdfPath,
        IReadOnlyList<int> pages,
        double printableWidth,
        double printableHeight,
        bool landscape,
        bool fitToPrintableArea,
        CancellationToken token)
    {
        using var renderer = PdfRendererFactory.CreateProduction();
        await renderer.OpenAsync(pdfPath, token);

        var document = new FixedDocument();
        var pageWidth = landscape ? Math.Max(printableWidth, printableHeight) : Math.Min(printableWidth, printableHeight);
        var pageHeight = landscape ? Math.Min(printableWidth, printableHeight) : Math.Max(printableWidth, printableHeight);
        pageWidth = Math.Max(100, pageWidth);
        pageHeight = Math.Max(100, pageHeight);
        document.DocumentPaginator.PageSize = new Size(pageWidth, pageHeight);

        foreach (var pageNumber in pages)
        {
            token.ThrowIfCancellationRequested();
            if (pageNumber < 1 || pageNumber > renderer.PageCount) continue;
            var targetRenderWidth = fitToPrintableArea ? Math.Clamp((uint)Math.Round(pageWidth * 2.2), 900u, 2600u) : 1100u;
            var bitmap = await renderer.RenderAsync(pageNumber, targetRenderWidth, token);
            token.ThrowIfCancellationRequested();

            var availableWidth = Math.Max(1, pageWidth - 28);
            var availableHeight = Math.Max(1, pageHeight - 28);
            var scale = fitToPrintableArea
                ? Math.Min(availableWidth / bitmap.PixelWidth, availableHeight / bitmap.PixelHeight)
                : Math.Min(1d, Math.Min(availableWidth / bitmap.PixelWidth, availableHeight / bitmap.PixelHeight));
            var imageWidth = Math.Max(1, bitmap.PixelWidth * scale);
            var imageHeight = Math.Max(1, bitmap.PixelHeight * scale);

            var image = new Image { Source = bitmap, Width = imageWidth, Height = imageHeight, Stretch = Stretch.Uniform };
            var canvas = new Canvas { Width = pageWidth, Height = pageHeight, Background = Brushes.White };
            Canvas.SetLeft(image, (pageWidth - imageWidth) / 2);
            Canvas.SetTop(image, (pageHeight - imageHeight) / 2);
            canvas.Children.Add(image);

            var fixedPage = new FixedPage { Width = pageWidth, Height = pageHeight, Background = Brushes.White };
            fixedPage.Children.Add(canvas);
            var pageContent = new PageContent();
            ((System.Windows.Markup.IAddChild)pageContent).AddChild(fixedPage);
            document.Pages.Add(pageContent);
        }

        return document;
    }
}
'@

$savePrint = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.SavePrint.cs'
Write-Text $savePrint @'
using System.IO;
using System.Printing;
using System.Windows;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly PdfPrintService _printService = new();

    private async void Print_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0 || _busy) return;
        var selected = SelectedPages().Select(page => page.Position).ToArray();
        var current = PagesList.SelectedItem is PdfPageItem item ? item.Position : 1;
        var optionsWindow = new PrintOptionsWindow(Pages.Count, current, selected) { Owner = this };
        if (optionsWindow.ShowDialog() != true || optionsWindow.Options is null) return;

        var printDialog = new PrintDialog();
        if (printDialog.ShowDialog() != true) return;
        if (optionsWindow.Options.Landscape)
            printDialog.PrintTicket.PageOrientation = PageOrientation.Landscape;

        var working = _currentPdf;
        string? snapshot = null;
        try
        {
            if (HasLayoutChanges())
            {
                var directory = Path.Combine(Path.GetTempPath(), "AsantePDF", "print");
                Directory.CreateDirectory(directory);
                snapshot = Path.Combine(directory, Guid.NewGuid().ToString("N") + ".pdf");
                var transforms = Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray();
                await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, snapshot, _lifetime.Token);
                working = snapshot;
            }

            var printed = await RunBusyAsync("Preparing print job...", async token =>
            {
                var document = await _printService.BuildAsync(
                    working,
                    optionsWindow.Options.Pages,
                    printDialog.PrintableAreaWidth,
                    printDialog.PrintableAreaHeight,
                    optionsWindow.Options.Landscape,
                    optionsWindow.Options.FitToPrintableArea,
                    token);
                token.ThrowIfCancellationRequested();
                printDialog.PrintDocument(document.DocumentPaginator, Path.GetFileName(_currentPdf));
            });
            if (printed) StatusText.Text = "Print job sent to the selected printer.";
        }
        finally
        {
            try { if (snapshot is not null && File.Exists(snapshot)) File.Delete(snapshot); } catch { }
        }
    }
}
'@

Write-Host 'Proper Save, Print and navigation contracts staged.' -ForegroundColor Green
& cmd /c exit 0