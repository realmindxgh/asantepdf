using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using PdfRescue.App.Services;
using PdfRescue.Core.Diagnostics;
using PdfRescue.Core.Models;
using PdfRescue.Core.Services;
using PdfRescue.Infrastructure.Processes;
using PdfRescue.Infrastructure.Qpdf;

namespace PdfRescue.App;

public partial class MainWindow : Window
{
    private const string PageDragFormat = "AsantePDF.PageItems";
    private const int MaxUndoDepth = 50;

    private readonly IPdfOperations _operations;
    private readonly PdfDoctor _doctor;
    private readonly IPdfRenderer _renderer = PdfRendererFactory.CreateProduction();
    private readonly LocalOcrService _ocr = new();
    private readonly PdfFinishingService _finishing = new();
    private readonly PdfMarkupService _markup = new();
    private readonly PdfFormService _forms = new();
    private readonly OfficeConversionService _office = new();
    private readonly BatchPdfService _batch;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly Stack<PageLayoutSnapshot> _undo = new();
    private readonly Stack<PageLayoutSnapshot> _redo = new();
    private readonly Dictionary<int, BitmapSource?> _thumbnailCache = new();

    private CancellationTokenSource? _activeOperationCts;
    private CancellationTokenSource? _thumbnailCts;
    private CancellationTokenSource? _previewCts;
    private string? _currentPdf;
    private bool _busy;
    private int _documentGeneration;
    private int _previewGeneration;
    private uint _previewWidth = 1100;
    private Point _dragStartPoint;
    private Point _markupStartPoint;
    private bool _markupDragging;
    private MarkupMode _markupMode;
    private string? _pendingMarkupText;
    private string? _pendingSignatureImage;
    private PageLayoutSnapshot? _savedLayoutBaseline;
    private bool _closeAfterConfirmation;
    private bool _closeConfirmationInProgress;

    private enum MarkupMode
    {
        None,
        AddText,
        Highlight,
        Rectangle,
        Ellipse,
        Crop,
        PermanentRedaction,
        SignatureImage
    }

    public ObservableCollection<PdfPageItem> Pages { get; } = new();

    private static string RecentDocumentsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AsantePDF", "recent.txt");

    public MainWindow()
    {
        InitializeComponent();
        PagesList.ItemsSource = Pages;

        var runner = new ExternalProcessRunner();
        var qpdf = QpdfLocator.Resolve();
        _operations = new QpdfOperations(runner, qpdf);
        _doctor = new PdfDoctor(new QpdfInspector(runner, qpdf));
        _batch = new BatchPdfService(_operations);

        RefreshRecentMenu();
        UpdateCommandStates();

        Closing += MainWindow_Closing;
        Closed += (_, _) =>
        {
            _activeOperationCts?.Cancel();
            _thumbnailCts?.Cancel();
            _previewCts?.Cancel();
            _lifetime.Cancel();
            _activeOperationCts?.Dispose();
            _thumbnailCts?.Dispose();
            _previewCts?.Dispose();
            _lifetime.Dispose();
            _renderer.Dispose();
        };

        App.Log("MainWindow constructor completed.");
    }

    public Task OpenPdfFromCommandLineAsync(string path) => OpenPdfAsync(path);

    private async void OpenPdf_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Open PDF",
            Filter = "PDF files (*.pdf)|*.pdf",
            Multiselect = false,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) == true)
            await OpenPdfAsync(dialog.FileName);
    }

    private async Task OpenPdfAsync(string path)
    {
        if (_busy || !File.Exists(path)) return;
        if (!await ConfirmDocumentReplacementAsync("opening another PDF")) return;

        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = null;

        var fullPath = Path.GetFullPath(path);
        var opened = await RunBusyAsync("Opening PDF...", async token =>
        {
            await _renderer.OpenAsync(fullPath, token);
            token.ThrowIfCancellationRequested();

            _currentPdf = fullPath;
            _documentGeneration++;
            _undo.Clear();
            _redo.Clear();
            _thumbnailCache.Clear();
            Pages.Clear();

            var count = checked((int)_renderer.PageCount);
            if (count < 1)
                throw new InvalidDataException("This PDF contains no pages.");

            for (var i = 1; i <= count; i++)
                Pages.Add(new PdfPageItem(i, i));

            _savedLayoutBaseline = CaptureLayout();

            var fi = new FileInfo(fullPath);
            DocumentTitle.Text = fi.Name;
            DocumentMeta.Text = $"{count:N0} pages  •  {FormatBytes(fi.Length)}";
            InspectorFile.Text = fi.Name;
            InspectorPages.Text = count.ToString("N0");
            InspectorSize.Text = FormatBytes(fi.Length);
            InspectorVersion.Text = "Not checked";
            InspectorSecurity.Text = "Not checked";
            InspectorFeatures.Text = "Run PDF Doctor to inspect";
            HealthText.Text = "Not checked";
            FindingsList.ItemsSource = null;
            EmptyPanel.Visibility = Visibility.Collapsed;
            PreviewScroll.Visibility = Visibility.Visible;

            PagesList.SelectedIndex = 0;
            await RenderPreviewAsync(Pages[0]);
            StatusText.Text = "PDF opened locally. Changes remain non-destructive until Save As.";
            App.Log($"Opened PDF: {fi.Name}, {count} pages.");
        });

        if (!opened || _currentPdf is null) return;

        AddRecentDocument(_currentPdf);
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
    }

    private async void PagesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateCommandStates();
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
    }

    private async Task RenderPreviewAsync(PdfPageItem page)
    {
        if (_currentPdf is null) return;

        _previewCts?.Cancel();
        _previewCts?.Dispose();
        _previewCts = _activeOperationCts is null
            ? CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token)
            : CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token, _activeOperationCts.Token);

        var token = _previewCts.Token;
        var renderGeneration = ++_previewGeneration;
        try
        {
            var bitmap = await _renderer.RenderAsync(page.SourcePageNumber, _previewWidth, token);
            if (renderGeneration != _previewGeneration || token.IsCancellationRequested) return;
            if (!Pages.Contains(page)) return;

            PreviewImage.Source = bitmap;
            PreviewImage.LayoutTransform = new RotateTransform(page.Rotation);
            PreviewImage.Width = bitmap.PixelWidth;
            PageStatusText.Text = $"Page {page.Position:N0} of {Pages.Count:N0}";
            UpdateZoomText();
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Preview error: " + ex);
            StatusText.Text = "Could not render the selected page.";
        }
    }

    private void StartThumbnailRendering(int generation)
    {
        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        _ = RenderThumbnailsIncrementallyAsync(generation, _thumbnailCts.Token);
    }

    private async Task RenderThumbnailsIncrementallyAsync(int generation, CancellationToken token)
    {
        try
        {
            var pageCount = checked((int)_renderer.PageCount);
            for (var sourcePage = 1; sourcePage <= pageCount; sourcePage++)
            {
                token.ThrowIfCancellationRequested();
                if (generation != _documentGeneration) return;
                if (_thumbnailCache.ContainsKey(sourcePage)) continue;

                if (!_busy)
                    StatusText.Text = $"Preparing page thumbnails {sourcePage:N0} of {pageCount:N0}...";

                var bitmap = await _renderer.RenderAsync(sourcePage, 160, token);
                if (generation != _documentGeneration) return;

                _thumbnailCache[sourcePage] = bitmap;
                foreach (var item in Pages.Where(p => p.SourcePageNumber == sourcePage))
                    item.Thumbnail = bitmap;
            }

            if (!_busy && generation == _documentGeneration)
                StatusText.Text = "Ready.";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Thumbnail rendering error: " + ex);
            if (!_busy) StatusText.Text = "Some page thumbnails could not be rendered.";
        }
    }

    private void MoveUp_Click(object sender, RoutedEventArgs e)
    {
        var selected = SelectedPages();
        if (selected.Count == 0) return;
        RecordUndoState();

        var set = selected.ToHashSet();
        foreach (var page in selected)
        {
            var index = Pages.IndexOf(page);
            if (index > 0 && !set.Contains(Pages[index - 1]))
                Pages.Move(index, index - 1);
        }
        AfterLayoutChange(selected, "Moved selected page(s) up.");
    }

    private void MoveDown_Click(object sender, RoutedEventArgs e)
    {
        var selected = SelectedPages();
        if (selected.Count == 0) return;
        RecordUndoState();

        var set = selected.ToHashSet();
        for (var i = selected.Count - 1; i >= 0; i--)
        {
            var page = selected[i];
            var index = Pages.IndexOf(page);
            if (index < Pages.Count - 1 && !set.Contains(Pages[index + 1]))
                Pages.Move(index, index + 1);
        }
        AfterLayoutChange(selected, "Moved selected page(s) down.");
    }

    private async void RotateLeft_Click(object sender, RoutedEventArgs e)
    {
        var selectedPages = SelectedPages();
        if (selectedPages.Count == 0) return;
        RecordUndoState();
        foreach (var page in selectedPages) page.Rotation -= 90;
        if (PagesList.SelectedItem is PdfPageItem selected) await RenderPreviewAsync(selected);
        StatusText.Text = "Rotated selected page(s) left in the working layout.";
        UpdateCommandStates();
    }

    private async void RotateRight_Click(object sender, RoutedEventArgs e)
    {
        var selectedPages = SelectedPages();
        if (selectedPages.Count == 0) return;
        RecordUndoState();
        foreach (var page in selectedPages) page.Rotation += 90;
        if (PagesList.SelectedItem is PdfPageItem selected) await RenderPreviewAsync(selected);
        StatusText.Text = "Rotated selected page(s) right in the working layout.";
        UpdateCommandStates();
    }

    private void DuplicatePages_Click(object sender, RoutedEventArgs e)
    {
        var selected = SelectedPages();
        if (selected.Count == 0) return;
        RecordUndoState();

        var insertIndex = selected.Max(page => Pages.IndexOf(page)) + 1;
        var duplicates = selected
            .Select(page => new PdfPageItem(page.SourcePageNumber, 0)
            {
                Rotation = page.Rotation,
                Thumbnail = page.Thumbnail ?? GetCachedThumbnail(page.SourcePageNumber)
            })
            .ToArray();

        foreach (var duplicate in duplicates)
            Pages.Insert(insertIndex++, duplicate);

        AfterLayoutChange(duplicates, $"Duplicated {duplicates.Length:N0} page(s).");
    }

    private void DeletePages_Click(object sender, RoutedEventArgs e)
    {
        var selected = SelectedPages();
        if (selected.Count == 0) return;
        if (selected.Count == Pages.Count)
        {
            MessageBox.Show(this, "A PDF must keep at least one page.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        RecordUndoState();
        var firstIndex = selected.Min(page => Pages.IndexOf(page));
        foreach (var page in selected) Pages.Remove(page);
        Renumber();
        if (Pages.Count > 0) PagesList.SelectedIndex = Math.Min(firstIndex, Pages.Count - 1);
        StatusText.Text = "Removed selected page(s) from the working layout.";
    }

    private void SelectAllPages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.SelectAll();
        StatusText.Text = $"Selected {Pages.Count:N0} pages.";
    }

    private void ResetLayout_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || _renderer.PageCount == 0) return;
        RecordUndoState();

        Pages.Clear();
        for (var page = 1; page <= (int)_renderer.PageCount; page++)
            Pages.Add(new PdfPageItem(page, page) { Thumbnail = GetCachedThumbnail(page) });

        Renumber();
        PagesList.SelectedIndex = 0;
        StatusText.Text = "Restored the original page order and rotation.";
    }

    private void Undo_Click(object sender, RoutedEventArgs e)
    {
        if (_undo.Count == 0 || _busy) return;
        _redo.Push(CaptureLayout());
        RestoreLayout(_undo.Pop());
        StatusText.Text = "Undid the last page-layout change.";
    }

    private void Redo_Click(object sender, RoutedEventArgs e)
    {
        if (_redo.Count == 0 || _busy) return;
        _undo.Push(CaptureLayout());
        RestoreLayout(_redo.Pop());
        StatusText.Text = "Redid the page-layout change.";
    }

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

    private async void Extract_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var selected = SelectedPages();
        if (selected.Count == 0) return;
        var output = AskSavePath("Extract selected pages", SuggestName(_currentPdf, "extracted"));
        if (output is null) return;

        await RunPdfOperationAsync("Extracting pages...", "Extracted selected pages.", async token =>
        {
            var transforms = selected.OrderBy(p => p.Position)
                .Select(p => new PdfPageTransform(p.SourcePageNumber, p.Rotation))
                .ToArray();
            await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, output, token);
        });
    }

    private async void Merge_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Select PDFs to merge",
            Filter = "PDF files (*.pdf)|*.pdf",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) == true)
            await MergeFilesAsync(dialog.FileNames);
    }

    private async Task MergeFilesAsync(IReadOnlyList<string> files)
    {
        var inputs = files.Where(File.Exists)
            .Where(path => string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (inputs.Length < 2)
        {
            MessageBox.Show(this, "Choose at least two PDFs to merge.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var output = AskSavePath("Save merged PDF", "merged.pdf");
        if (output is null) return;
        await RunPdfOperationAsync("Merging PDFs...", $"Merged {inputs.Length:N0} PDFs.", token => _operations.MergeAsync(inputs, output, token));
    }

    private async void Split_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var pagesPerFile = PromptForPositiveInt("Split PDF", "Pages per output file:", 1);
        if (pagesPerFile is null) return;
        var outputBase = AskSavePath("Choose split output base name", SuggestName(_currentPdf, "part"));
        if (outputBase is null) return;

        IReadOnlyList<string>? outputs = null;
        var success = await RunBusyAsync("Splitting PDF...", async token =>
        {
            await RunAgainstWorkingLayoutAsync(async (working, ct) =>
            {
                outputs = await _operations.SplitAsync(working, pagesPerFile.Value, outputBase, ct);
            }, token);
            StatusText.Text = $"Created {outputs!.Count:N0} split PDF file(s).";
        });

        if (success && outputs is not null)
            MessageBox.Show(this, $"Created {outputs.Count:N0} PDF file(s) in:\n\n{Path.GetDirectoryName(outputs[0])}", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private async void Compress_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var profile = PromptCompressionProfile();
        if (profile is null) return;
        var output = AskSavePath("Save compressed PDF", SuggestName(_currentPdf, "compressed"));
        if (output is null) return;

        long before = 0;
        var success = await RunBusyAsync("Compressing PDF...", async token =>
        {
            await RunAgainstWorkingLayoutAsync(async (working, ct) =>
            {
                before = new FileInfo(working).Length;
                await _operations.CompressAsync(working, profile.Value, output, ct);
            }, token);
            var after = new FileInfo(output).Length;
            var delta = before - after;
            StatusText.Text = delta > 0
                ? $"Compression completed. Saved {FormatBytes(delta)} ({(double)delta / before:P0})."
                : "Compression completed. This PDF was already efficiently encoded, so the output is not smaller.";
        });

        if (success)
        {
            var after = new FileInfo(output).Length;
            MessageBox.Show(this,
                $"Original: {FormatBytes(before)}\nOutput: {FormatBytes(after)}",
                "Compression complete", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private async void Repair_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save repaired PDF", SuggestName(_currentPdf, "repaired"));
        if (output is null) return;
        await RunPdfOperationAsync("Repairing PDF structure...", "Repaired PDF structure.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.RepairAsync(working, output, ct), token));
    }

    private async void Linearize_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save web-optimized PDF", SuggestName(_currentPdf, "web"));
        if (output is null) return;
        await RunPdfOperationAsync("Optimizing PDF for web viewing...", "Created web-optimized PDF.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.LinearizeAsync(working, output, ct), token));
    }

    private async void Protect_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var passwords = PromptProtectionPasswords();
        if (passwords is null) return;
        var output = AskSavePath("Save password-protected PDF", SuggestName(_currentPdf, "protected"));
        if (output is null) return;

        await RunPdfOperationAsync("Protecting PDF...", "Created password-protected PDF.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _operations.ProtectAsync(working, passwords.Value.UserPassword, passwords.Value.OwnerPassword, output, ct), token));
    }

    private async void Unlock_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Select password-protected PDF",
            Filter = "PDF files (*.pdf)|*.pdf",
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true) return;

        var password = PromptPassword("Remove PDF Password", "Enter the current PDF password:");
        if (password is null) return;
        var output = AskSavePath("Save unlocked PDF", SuggestName(dialog.FileName, "unlocked"));
        if (output is null) return;

        await RunPdfOperationAsync("Removing PDF password...", "Created unlocked PDF.", token =>
            _operations.DecryptAsync(dialog.FileName, password, output, token));
    }

    private async void OfficeToPdf_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        if (!_office.IsLibreOfficeAvailable)
        {
            MessageBox.Show(this, "The bundled Office conversion engine is unavailable.", "AsantePDF Convert", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        var dialog = new OpenFileDialog
        {
            Title = "Choose Office document to convert",
            Filter = "Office documents|*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.odt;*.ods;*.odp;*.rtf|All files|*.*",
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true) return;
        var output = AskSaveFile("Save converted PDF", Path.GetFileNameWithoutExtension(dialog.FileName) + ".pdf", "PDF files (*.pdf)|*.pdf", ".pdf");
        if (output is null) return;
        await RunPdfOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", token =>
            _office.ConvertOfficeToPdfAsync(dialog.FileName, output, token));
    }

    private async void PdfToWord_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (!_ocr.IsAvailable) { ShowOcrUnavailable(); return; }
        var output = AskSaveFile("Export PDF to Word", Path.GetFileNameWithoutExtension(_currentPdf) + ".docx", "Word document (*.docx)|*.docx", ".docx");
        if (output is null) return;
        await RunPdfOperationAsync("Recovering PDF text for Word...", "Word document created.", async token =>
        {
            var texts = await RecognizeWorkingPagesAsync(token);
            await _office.ExportWordAsync(texts, output, token);
        });
    }

    private async void PdfToExcel_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (!_ocr.IsAvailable) { ShowOcrUnavailable(); return; }
        var output = AskSaveFile("Export PDF to Excel", Path.GetFileNameWithoutExtension(_currentPdf) + ".xlsx", "Excel workbook (*.xlsx)|*.xlsx", ".xlsx");
        if (output is null) return;
        await RunPdfOperationAsync("Recovering PDF text for Excel...", "Excel workbook created.", async token =>
        {
            var texts = await RecognizeWorkingPagesAsync(token);
            await _office.ExportExcelAsync(texts, output, token);
        });
    }

    private async void PdfToPowerPoint_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var output = AskSaveFile("Export PDF to PowerPoint", Path.GetFileNameWithoutExtension(_currentPdf) + ".pptx", "PowerPoint presentation (*.pptx)|*.pptx", ".pptx");
        if (output is null) return;
        await RunPdfOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", async token =>
        {
            var slides = new List<PowerPointPage>(Pages.Count);
            for (var i = 0; i < Pages.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, Pages.Count, $"Rendering slide {i + 1:N0} of {Pages.Count:N0}...");
                var bitmap = await RenderWorkingPageAsync(Pages[i], 1800, token);
                slides.Add(new PowerPointPage(OfficeConversionService.EncodePng(bitmap), bitmap.PixelWidth, bitmap.PixelHeight));
            }
            await _office.ExportPowerPointAsync(slides, output, token);
            SetDeterminateProgress(Pages.Count, Pages.Count, "Finishing PowerPoint...");
        });
    }

    private async Task<IReadOnlyList<string>> RecognizeWorkingPagesAsync(CancellationToken token)
    {
        var texts = new List<string>(Pages.Count);
        for (var i = 0; i < Pages.Count; i++)
        {
            token.ThrowIfCancellationRequested();
            SetDeterminateProgress(i, Pages.Count, $"Reading page {i + 1:N0} of {Pages.Count:N0}...");
            var bitmap = await RenderWorkingPageAsync(Pages[i], 1800, token);
            var result = await _ocr.RecognizeAsync(bitmap, token);
            texts.Add(result.Text);
        }
        SetDeterminateProgress(Pages.Count, Pages.Count, "Writing converted document...");
        return texts;
    }

    private void ShowOcrUnavailable() => MessageBox.Show(this,
        "No local OCR engine is available. AsantePDF could not find Windows OCR or its bundled OCR fallback.",
        "AsantePDF OCR", MessageBoxButton.OK, MessageBoxImage.Information);

    private async void ImagesToPdf_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        var dialog = new OpenFileDialog
        {
            Title = "Choose images to combine into a PDF",
            Filter = "Image files|*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff|All files|*.*",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true || dialog.FileNames.Length == 0) return;

        var suggested = Path.GetFileNameWithoutExtension(dialog.FileNames[0]) + "-images.pdf";
        var output = AskSavePath("Save image PDF", suggested);
        if (output is null) return;

        await RunPdfOperationAsync(
            "Building PDF from images...",
            "Image PDF created.",
            token => ImagePdfBuilder.CreateFromImageFilesAsync(dialog.FileNames, output, token));
    }

    private async void ExportPagesAsImages_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var imageDialog = new SaveFileDialog
        {
            Title = "Choose page image destination",
            Filter = "PNG image (*.png)|*.png",
            FileName = Path.GetFileNameWithoutExtension(_currentPdf) + "-page-001.png",
            AddExtension = true,
            DefaultExt = ".png",
            OverwritePrompt = true
        };
        if (imageDialog.ShowDialog(this) != true) return;
        var first = imageDialog.FileName;

        var folder = Path.GetDirectoryName(first)!;
        var firstStem = Path.GetFileNameWithoutExtension(first);
        var stem = firstStem.EndsWith("-page-001", StringComparison.OrdinalIgnoreCase)
            ? firstStem[..^9]
            : firstStem;

        await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
        {
            Directory.CreateDirectory(folder);
            for (var i = 0; i < Pages.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, Pages.Count, $"Exporting page {i + 1:N0} of {Pages.Count:N0}...");
                var bitmap = await RenderWorkingPageAsync(Pages[i], 1800, token);
                var path = Path.Combine(folder, $"{stem}-page-{i + 1:000}.png");
                SaveBitmap(bitmap, path, png: true);
            }
            SetDeterminateProgress(Pages.Count, Pages.Count, "Finishing page export...");
        });
    }

    private async void OcrPdf_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (!_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var output = AskSavePath("Save searchable OCR PDF", SuggestName(_currentPdf, "searchable"));
        if (output is null) return;

        await RunPdfOperationAsync("Running local OCR...", "Searchable OCR PDF created.", async token =>
        {
            var rasterPages = new List<PdfRasterPage>(Pages.Count);
            for (var i = 0; i < Pages.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, Pages.Count, $"OCR page {i + 1:N0} of {Pages.Count:N0}...");
                var bitmap = await RenderWorkingPageAsync(Pages[i], 1800, token);
                var recognized = await _ocr.RecognizeAsync(bitmap, token);
                rasterPages.Add(ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, recognized.Words));
            }
            SetDeterminateProgress(Pages.Count, Pages.Count, "Writing searchable PDF...");
            await ImagePdfBuilder.WriteAsync(rasterPages, output, token);
        });
    }

    private async void ExtractOcrText_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (!_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var suggested = Path.GetFileNameWithoutExtension(_currentPdf) + "-ocr.txt";
        var dialog = new SaveFileDialog
        {
            Title = "Save OCR text",
            Filter = "Text file (*.txt)|*.txt",
            FileName = suggested,
            AddExtension = true,
            DefaultExt = ".txt"
        };
        if (dialog.ShowDialog(this) != true) return;

        await RunPdfOperationAsync("Extracting text with local OCR...", "OCR text extracted.", async token =>
        {
            var output = new System.Text.StringBuilder();
            for (var i = 0; i < Pages.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, Pages.Count, $"Reading page {i + 1:N0} of {Pages.Count:N0}...");
                var bitmap = await RenderWorkingPageAsync(Pages[i], 1800, token);
                var recognized = await _ocr.RecognizeAsync(bitmap, token);
                if (i > 0) output.AppendLine().AppendLine($"--- Page {i + 1} ---").AppendLine();
                output.Append(recognized.Text);
            }
            await File.WriteAllTextAsync(dialog.FileName, output.ToString(), token);
        });
    }

    private async void Watermark_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var text = PromptText("Add Watermark", "Watermark text:", "CONFIDENTIAL");
        if (string.IsNullOrWhiteSpace(text)) return;
        var output = AskSavePath("Save watermarked PDF", SuggestName(_currentPdf, "watermarked"));
        if (output is null) return;

        await RunPdfOperationAsync("Adding watermark...", "Watermark added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddWatermarkAsync(working, output, text, ct), token));
    }

    private async void PageNumbers_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var prefix = PromptText("Add Page Numbers", "Text before the number (optional):", "Page ");
        if (prefix is null) return;
        var start = PromptForPositiveInt("Add Page Numbers", "Starting number:", 1);
        if (start is null) return;
        var output = AskSavePath("Save numbered PDF", SuggestName(_currentPdf, "numbered"));
        if (output is null) return;

        await RunPdfOperationAsync("Adding page numbers...", "Page numbers added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddPageNumbersAsync(working, output, prefix, start.Value, ct), token));
    }

    private async void HeaderFooter_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var values = PromptHeaderFooter();
        if (values is null) return;
        var output = AskSavePath("Save PDF with header/footer", SuggestName(_currentPdf, "header-footer"));
        if (output is null) return;

        await RunPdfOperationAsync("Adding header and footer...", "Header/footer added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddHeaderFooterAsync(working, output, values.Value.Header, values.Value.Footer, ct), token));
    }

    private async void Metadata_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var metadata = PromptMetadata();
        if (metadata is null) return;
        var output = AskSavePath("Save PDF with updated metadata", SuggestName(_currentPdf, "metadata"));
        if (output is null) return;

        await RunPdfOperationAsync("Updating PDF metadata...", "Metadata updated.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.UpdateMetadataAsync(working, output, metadata, ct), token));
    }

    private async void StampImage_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var imageDialog = new OpenFileDialog
        {
            Title = "Choose image or signature stamp",
            Filter = "Image files|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff|All files|*.*",
            CheckFileExists = true
        };
        if (imageDialog.ShowDialog(this) != true) return;

        var suggestedPage = SelectedPages().FirstOrDefault()?.Position ?? Pages.Count;
        var page = PromptForPositiveInt("Stamp Image / Signature", $"Page number (1 to {Pages.Count:N0}):", suggestedPage);
        if (page is null || page.Value > Pages.Count)
        {
            if (page is not null)
                MessageBox.Show(this, $"Enter a page number from 1 to {Pages.Count:N0}.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var output = AskSavePath("Save stamped PDF", SuggestName(_currentPdf, "stamped"));
        if (output is null) return;

        await RunPdfOperationAsync("Stamping image...", "Image/signature stamp added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.StampImageAsync(working, output, imageDialog.FileName, page.Value, ct), token));
    }


    private async void FillForm_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (HasLayoutChanges())
        {
            MessageBox.Show(this,
                "Form filling works on the currently opened PDF structure. Save your page-layout changes first, reopen the saved PDF, then fill the form.",
                "AsantePDF Forms", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        IReadOnlyList<PdfFormFieldInfo> fields = Array.Empty<PdfFormFieldInfo>();
        var loaded = await RunBusyAsync("Reading form fields...", token => Task.Run(() =>
        {
            token.ThrowIfCancellationRequested();
            fields = _forms.ReadFields(_currentPdf);
        }, token));
        if (!loaded) return;

        if (fields.Count == 0)
        {
            MessageBox.Show(this,
                "No standard AcroForm fields were found in this PDF. XFA-only forms are not editable in this build.",
                "AsantePDF Forms", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var values = PromptFormValues(fields);
        if (values is null) return;
        var output = AskSavePath("Save filled form", SuggestName(_currentPdf, "filled"));
        if (output is null) return;

        await RunPdfOperationAsync("Filling PDF form...", "Form fields filled.", token =>
            _forms.FillAsync(_currentPdf, output, values, token));
    }

    private void PlaceSignature_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var imageDialog = new OpenFileDialog
        {
            Title = "Choose signature image",
            Filter = "Signature images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff|All files|*.*",
            CheckFileExists = true,
            Multiselect = false
        };
        if (imageDialog.ShowDialog(this) != true) return;

        _pendingSignatureImage = imageDialog.FileName;
        BeginMarkupMode(MarkupMode.SignatureImage,
            "Visual Signature mode: drag a rectangle where the signature should appear on the current page.");
    }

    private async void BatchProcess_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        var files = new OpenFileDialog
        {
            Title = "Choose PDFs for batch processing",
            Filter = "PDF files (*.pdf)|*.pdf",
            CheckFileExists = true,
            Multiselect = true
        };
        if (files.ShowDialog(this) != true || files.FileNames.Length == 0) return;

        var operation = PromptBatchOperation();
        if (operation is null) return;

        var folderDialog = new OpenFolderDialog
        {
            Title = "Choose batch output folder",
            Multiselect = false
        };
        if (folderDialog.ShowDialog(this) != true) return;

        IReadOnlyList<BatchPdfResult> results = Array.Empty<BatchPdfResult>();
        var progress = new Progress<(int Completed, int Total, string FileName)>(item =>
            SetDeterminateProgress(item.Completed, item.Total,
                $"Batch {item.Completed:N0} of {item.Total:N0}: {item.FileName}"));

        var completed = await RunPdfOperationAsync("Batch processing PDFs...", "Batch processing finished.", async token =>
        {
            results = await _batch.ProcessAsync(files.FileNames, folderDialog.FolderName, operation.Value, progress, token);
        });
        if (!completed) return;

        var success = results.Count(r => r.Success);
        var failed = results.Count - success;
        var details = failed == 0
            ? $"Processed {success:N0} PDF(s) successfully.\n\nOutput folder:\n{folderDialog.FolderName}"
            : $"Completed {success:N0} PDF(s); {failed:N0} failed.\n\n" +
              string.Join("\n", results.Where(r => !r.Success).Take(8).Select(r => $"• {Path.GetFileName(r.InputPath)}: {r.Error}"));
        MessageBox.Show(this, details, "AsantePDF Batch", MessageBoxButton.OK,
            failed == 0 ? MessageBoxImage.Information : MessageBoxImage.Warning);
    }


    private void AddTextMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var text = PromptText("Add Text", "Text to place on the current page:");
        if (string.IsNullOrWhiteSpace(text)) return;
        _pendingMarkupText = text.Trim();
        BeginMarkupMode(MarkupMode.AddText,
            "Add Text mode: click the position on the current page where the text should begin.");
    }

    private void HighlightMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Highlight,
            "Highlight mode: drag a rectangle over the area to highlight.");
    }

    private void RectangleMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Rectangle, "Rectangle mode: drag the area to outline.");
    }

    private void EllipseMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Ellipse, "Ellipse mode: drag the area to outline.");
    }

    private void CropMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Crop, "Crop mode: drag the area to keep on the current page.");
    }

    private void RedactMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var result = MessageBox.Show(this,
            "Permanent redaction removes the original content from the affected page by rasterizing that page and painting the selected area black.\n\n" +
            "Text, links, and vector content on that one page will no longer be selectable after redaction. Other pages remain unchanged.\n\nContinue?",
            "Permanent Redaction",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (result != MessageBoxResult.Yes) return;

        BeginMarkupMode(MarkupMode.PermanentRedaction,
            "Permanent Redaction mode: drag a rectangle over the content that must be permanently removed.");
    }

    private void CancelMarkup_Click(object sender, RoutedEventArgs e) => EndMarkupMode("Markup mode cancelled.");

    private void BeginMarkupMode(MarkupMode mode, string instruction)
    {
        if (_busy || _currentPdf is null || PreviewImage.Source is null) return;
        _markupMode = mode;
        _markupDragging = false;
        MarkupSelectionRectangle.Visibility = Visibility.Collapsed;
        MarkupCanvas.Visibility = Visibility.Visible;
        MarkupCanvas.Cursor = Cursors.Cross;
        StatusText.Text = instruction;
    }

    private void EndMarkupMode(string? status = null)
    {
        _markupMode = MarkupMode.None;
        _markupDragging = false;
        _pendingMarkupText = null;
        _pendingSignatureImage = null;
        try { MarkupCanvas.ReleaseMouseCapture(); } catch { }
        MarkupSelectionRectangle.Visibility = Visibility.Collapsed;
        MarkupCanvas.Visibility = Visibility.Collapsed;
        if (!string.IsNullOrWhiteSpace(status)) StatusText.Text = status;
    }

    private async void MarkupCanvas_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (_markupMode == MarkupMode.None || _busy || PreviewImage.Source is null) return;
        var point = ClampMarkupPoint(e.GetPosition(MarkupCanvas));

        if (_markupMode == MarkupMode.AddText)
        {
            var page = PagesList.SelectedItem as PdfPageItem;
            var text = _pendingMarkupText;
            var normalizedX = point.X / Math.Max(1d, MarkupCanvas.ActualWidth);
            var normalizedY = point.Y / Math.Max(1d, MarkupCanvas.ActualHeight);
            EndMarkupMode();
            if (page is null || string.IsNullOrWhiteSpace(text)) return;
            await ApplyTextMarkupAsync(page.Position, normalizedX, normalizedY, text);
            e.Handled = true;
            return;
        }

        _markupStartPoint = point;
        _markupDragging = true;
        MarkupCanvas.CaptureMouse();
        Canvas.SetLeft(MarkupSelectionRectangle, point.X);
        Canvas.SetTop(MarkupSelectionRectangle, point.Y);
        MarkupSelectionRectangle.Width = 0;
        MarkupSelectionRectangle.Height = 0;
        MarkupSelectionRectangle.Visibility = Visibility.Visible;
        e.Handled = true;
    }

    private void MarkupCanvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        UpdateMarkupSelection(ClampMarkupPoint(e.GetPosition(MarkupCanvas)));
    }

    private async void MarkupCanvas_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        var current = ClampMarkupPoint(e.GetPosition(MarkupCanvas));
        UpdateMarkupSelection(current);
        _markupDragging = false;
        try { MarkupCanvas.ReleaseMouseCapture(); } catch { }

        var page = PagesList.SelectedItem as PdfPageItem;
        var mode = _markupMode;
        var signatureImage = _pendingSignatureImage;
        var rect = GetNormalizedMarkupSelection(current);
        EndMarkupMode();

        if (page is null || rect.Width < 0.004 || rect.Height < 0.004)
        {
            StatusText.Text = "The selected area was too small. No change was made.";
            return;
        }

        if (mode == MarkupMode.Highlight)
            await ApplyHighlightMarkupAsync(page.Position, rect);
        else if (mode == MarkupMode.Rectangle)
            await ApplyRectangleMarkupAsync(page.Position, rect);
        else if (mode == MarkupMode.Ellipse)
            await ApplyEllipseMarkupAsync(page.Position, rect);
        else if (mode == MarkupMode.Crop)
            await ApplyCropMarkupAsync(page.Position, rect);
        else if (mode == MarkupMode.PermanentRedaction)
            await ApplyPermanentRedactionAsync(page.Position, rect);
        else if (mode == MarkupMode.SignatureImage && !string.IsNullOrWhiteSpace(signatureImage))
            await ApplyVisualSignatureAsync(page.Position, rect, signatureImage);

        e.Handled = true;
    }

    private Point ClampMarkupPoint(Point point) =>
        new(Math.Clamp(point.X, 0, Math.Max(0, MarkupCanvas.ActualWidth)),
            Math.Clamp(point.Y, 0, Math.Max(0, MarkupCanvas.ActualHeight)));

    private void UpdateMarkupSelection(Point current)
    {
        var left = Math.Min(_markupStartPoint.X, current.X);
        var top = Math.Min(_markupStartPoint.Y, current.Y);
        var width = Math.Abs(current.X - _markupStartPoint.X);
        var height = Math.Abs(current.Y - _markupStartPoint.Y);
        Canvas.SetLeft(MarkupSelectionRectangle, left);
        Canvas.SetTop(MarkupSelectionRectangle, top);
        MarkupSelectionRectangle.Width = width;
        MarkupSelectionRectangle.Height = height;
    }

    private NormalizedPdfRect GetNormalizedMarkupSelection(Point current)
    {
        var width = Math.Max(1d, MarkupCanvas.ActualWidth);
        var height = Math.Max(1d, MarkupCanvas.ActualHeight);
        var left = Math.Min(_markupStartPoint.X, current.X);
        var top = Math.Min(_markupStartPoint.Y, current.Y);
        return new NormalizedPdfRect(
            left / width,
            top / height,
            Math.Abs(current.X - _markupStartPoint.X) / width,
            Math.Abs(current.Y - _markupStartPoint.Y) / height).Clamp();
    }

    private async Task ApplyTextMarkupAsync(int pageNumber, double normalizedX, double normalizedY, string text)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save PDF with added text", SuggestName(_currentPdf, "text"));
        if (output is null) return;
        await RunPdfOperationAsync("Adding text...", "Text added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.AddTextAsync(working, output, pageNumber, normalizedX, normalizedY, text, 14, ct), token));
    }

    private async Task ApplyHighlightMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save highlighted PDF", SuggestName(_currentPdf, "highlighted"));
        if (output is null) return;
        await RunPdfOperationAsync("Adding highlight...", "Highlight added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.AddHighlightAsync(working, output, pageNumber, rect, ct), token));
    }

    private async Task ApplyRectangleMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save PDF with rectangle", SuggestName(_currentPdf, "rectangle"));
        if (output is null) return;
        await RunPdfOperationAsync("Drawing rectangle...", "Rectangle added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddRectangleAsync(working, output, pageNumber, rect, ct), token));
    }

    private async Task ApplyEllipseMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save PDF with ellipse", SuggestName(_currentPdf, "ellipse"));
        if (output is null) return;
        await RunPdfOperationAsync("Drawing ellipse...", "Ellipse added.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddEllipseAsync(working, output, pageNumber, rect, ct), token));
    }

    private async Task ApplyCropMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save cropped PDF", SuggestName(_currentPdf, "cropped"));
        if (output is null) return;
        await RunPdfOperationAsync("Cropping page...", "Page crop applied.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.CropPageAsync(working, output, pageNumber, rect, ct), token));
    }

    private async Task ApplyPermanentRedactionAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save permanently redacted PDF", SuggestName(_currentPdf, "redacted"));
        if (output is null) return;
        await RunPdfOperationAsync("Applying permanent redaction...", "Permanent redaction applied.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.PermanentRedactAsync(working, output, pageNumber, rect, ct), token));
    }


    private async Task ApplyVisualSignatureAsync(int pageNumber, NormalizedPdfRect rect, string imagePath)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save visually signed PDF", SuggestName(_currentPdf, "signed"));
        if (output is null) return;
        await RunPdfOperationAsync("Placing visual signature...", "Visual signature placed.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.StampImageAsync(working, output, pageNumber, rect, imagePath, ct), token));
    }

    private async Task RunAgainstWorkingLayoutAsync(Func<string, CancellationToken, Task> operation, CancellationToken token)
    {
        if (_currentPdf is null) throw new InvalidOperationException("No PDF is open.");

        if (!HasLayoutChanges())
        {
            await operation(_currentPdf, token);
            return;
        }

        var tempDir = Path.Combine(Path.GetTempPath(), "AsantePDF", "working-layout");
        Directory.CreateDirectory(tempDir);
        var working = Path.Combine(tempDir, Guid.NewGuid().ToString("N") + ".pdf");
        try
        {
            var transforms = Pages.Select(p => new PdfPageTransform(p.SourcePageNumber, p.Rotation)).ToArray();
            await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, working, token);
            token.ThrowIfCancellationRequested();
            await operation(working, token);
        }
        finally
        {
            try { if (File.Exists(working)) File.Delete(working); } catch { }
        }
    }

    private async Task<BitmapSource> RenderWorkingPageAsync(PdfPageItem page, uint width, CancellationToken token)
    {
        var bitmap = await _renderer.RenderAsync(page.SourcePageNumber, width, token);
        if (page.Rotation % 360 == 0) return bitmap;

        var transformed = new TransformedBitmap(bitmap, new RotateTransform(page.Rotation));
        transformed.Freeze();
        return transformed;
    }

    private static void SaveBitmap(BitmapSource bitmap, string path, bool png)
    {
        BitmapEncoder encoder = png
            ? new PngBitmapEncoder()
            : new JpegBitmapEncoder { QualityLevel = 90 };
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
        encoder.Save(stream);
    }

    private void SetDeterminateProgress(int completed, int total, string status)
    {
        Progress.IsIndeterminate = false;
        Progress.Minimum = 0;
        Progress.Maximum = Math.Max(1, total);
        Progress.Value = Math.Clamp(completed, 0, Math.Max(1, total));
        StatusText.Text = status;
        if (_activeTaskCenterItem is not null)
            _taskCenterService.ReportProgress(_activeTaskCenterItem, completed / (double)Math.Max(1, total), status);
    }

    private async void Doctor_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        if (InspectorColumn.Width.Value == 0) InspectorColumn.Width = new GridLength(300);

        await RunBusyAsync("Inspecting PDF...", async token =>
        {
            PdfDoctorReport? report = null;
            await RunAgainstWorkingLayoutAsync(async (working, ct) =>
            {
                report = await _doctor.DiagnoseAsync(working, ct);
            }, token);
            if (report is null) throw new InvalidOperationException("PDF Doctor did not return a report.");
            HealthText.Text = $"{report.HealthScore}% health";
            InspectorVersion.Text = report.Inspection.PdfVersion ?? "Unknown";
            InspectorSecurity.Text = report.Inspection.IsEncrypted ? "Encrypted" : "Not encrypted";
            InspectorFeatures.Text = BuildFeatureSummary(report.Inspection);
            FindingsList.ItemsSource = report.Issues.Count == 0
                ? new[] { "No structural problems detected." }
                : report.Issues.Select(i => $"{i.Title}\n{i.Description}").ToArray();
            StatusText.Text = report.NeedsAttention
                ? "PDF Doctor found issues that may need attention."
                : "PDF Doctor found no serious structural issues.";
        });
    }

    private void ZoomIn_Click(object sender, RoutedEventArgs e)
    {
        _previewWidth = (uint)Math.Min(2400, Math.Round(_previewWidth * 1.15));
        _ = RerenderSelectedPageAsync();
    }

    private void ZoomOut_Click(object sender, RoutedEventArgs e)
    {
        _previewWidth = (uint)Math.Max(320, Math.Round(_previewWidth / 1.15));
        _ = RerenderSelectedPageAsync();
    }

    private void FitWidth_Click(object sender, RoutedEventArgs e)
    {
        var viewport = PreviewScroll.ViewportWidth > 100 ? PreviewScroll.ViewportWidth : PreviewScroll.ActualWidth;
        _previewWidth = (uint)Math.Clamp((int)Math.Round(viewport - 80), 360, 2000);
        _ = RerenderSelectedPageAsync();
    }

    private async Task RerenderSelectedPageAsync()
    {
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
        else
            UpdateZoomText();
    }

    private void UpdateZoomText()
    {
        var percent = (int)Math.Round(_previewWidth / 1100d * 100d);
        ZoomStatusText.Text = $"{percent}%";
        ZoomButton.Content = $"{percent}%";
    }

    private void TogglePages_Click(object sender, RoutedEventArgs e) =>
        PagesColumn.Width = PagesColumn.Width.Value == 0 ? new GridLength(230) : new GridLength(0);

    private void ToggleInspector_Click(object sender, RoutedEventArgs e) =>
        InspectorColumn.Width = InspectorColumn.Width.Value == 0 ? new GridLength(300) : new GridLength(0);

    private async void MainWindow_Closing(object? sender, CancelEventArgs e)
    {
        if (_closeAfterConfirmation) return;
        if (!_busy && !HasUnsavedLayoutChanges()) return;

        e.Cancel = true;
        if (_closeConfirmationInProgress) return;
        _closeConfirmationInProgress = true;

        try
        {
            if (_busy)
            {
                var cancelRunning = MessageBox.Show(this,
                    "An operation is still running. Cancel it and exit after cancellation finishes?",
                    "Exit AsantePDF", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (cancelRunning != MessageBoxResult.Yes) return;

                StatusText.Text = "Cancelling before exit...";
                _activeOperationCts?.Cancel();

                var cancelDeadline = DateTime.UtcNow.AddSeconds(10);
                while (_busy && DateTime.UtcNow < cancelDeadline)
                    await Task.Delay(75);

                if (_busy)
                {
                    MessageBox.Show(this,
                        "The running operation has not stopped yet. AsantePDF will stay open to avoid interrupting a file write. Try Exit again after the operation finishes.",
                        "Exit postponed", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
            }

            if (!await ConfirmDocumentReplacementAsync("closing AsantePDF")) return;

            _closeAfterConfirmation = true;
            Close();
        }
        finally
        {
            _closeConfirmationInProgress = false;
        }
    }

    private async Task<bool> ConfirmDocumentReplacementAsync(string action)
    {
        if (!HasUnsavedLayoutChanges()) return true;

        var choice = MessageBox.Show(this,
            $"You have unsaved page-layout changes. Save them before {action}?\n\n" +
            "Yes = Save a copy first\nNo = Discard the unsaved layout changes\nCancel = Stay with this document",
            "Unsaved AsantePDF changes", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning);

        if (choice == MessageBoxResult.Yes)
            return await SaveCurrentLayoutAsync(showSuccessMessage: false);

        return choice == MessageBoxResult.No;
    }

    private void Exit_Click(object sender, RoutedEventArgs e) => Close();

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

    private void CancelOperation_Click(object sender, RoutedEventArgs e)
    {
        if (_activeOperationCts is null) return;
        StatusText.Text = "Cancelling...";
        _activeOperationCts.Cancel();
    }

    private async Task<bool> RunPdfOperationAsync(string status, string successStatus, Func<CancellationToken, Task> operation)
    {
        var success = await RunBusyAsync(status, operation);
        if (success) StatusText.Text = successStatus;
        return success;
    }

    private async Task<bool> RunBusyAsync(string status, Func<CancellationToken, Task> operation)
    {
        if (_busy) return false;
        _busy = true;
        _activeOperationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        _activeTaskCenterItem = _taskCenterService.Start(status, () => _activeOperationCts?.Cancel());
        StatusText.Text = status;
        Progress.Visibility = Visibility.Visible;
        Progress.IsIndeterminate = true;
        CancelButton.Visibility = Visibility.Visible;
        UpdateCommandStates();

        try
        {
            await operation(_activeOperationCts.Token);
            _taskCenterService.Complete(_activeTaskCenterItem);
            return true;
        }
        catch (OperationCanceledException)
        {
            _taskCenterService.Cancel(_activeTaskCenterItem);
            StatusText.Text = "Operation cancelled.";
            return false;
        }
        catch (Exception ex)
        {
            _taskCenterService.Fail(_activeTaskCenterItem, ex);
            App.Log($"Operation failed [{status}]: {ex}");
            StatusText.Text = "Operation failed.";
            MessageBox.Show(this, ex.Message, "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Error);
            return false;
        }
        finally
        {
            Progress.IsIndeterminate = false;
            Progress.Visibility = Visibility.Collapsed;
            CancelButton.Visibility = Visibility.Collapsed;
            _activeOperationCts.Dispose();
            _activeOperationCts = null;
            _activeTaskCenterItem = null;
            _busy = false;
            UpdateCommandStates();
        }
    }

    private List<PdfPageItem> SelectedPages() =>
        PagesList.SelectedItems.Cast<PdfPageItem>().OrderBy(p => p.Position).ToList();

    private void AfterLayoutChange(IReadOnlyCollection<PdfPageItem> selection, string status)
    {
        Renumber();
        PagesList.SelectedItems.Clear();
        foreach (var page in selection)
            if (Pages.Contains(page)) PagesList.SelectedItems.Add(page);
        StatusText.Text = status;
        UpdateCommandStates();
    }

    private void Renumber()
    {
        for (var i = 0; i < Pages.Count; i++) Pages[i].Position = i + 1;
        InspectorPages.Text = Pages.Count.ToString("N0");
        UpdateCommandStates();
    }

    private void UpdateCommandStates()
    {
        var hasDocument = _currentPdf is not null && Pages.Count > 0;
        var hasSelection = hasDocument && PagesList.SelectedItems.Count > 0;
        var available = !_busy;

        SaveButton.IsEnabled = available && hasDocument;
        SaveMenuItem.IsEnabled = available && hasDocument;
        SplitMenuItem.IsEnabled = available && hasDocument;
        CompressMenuItem.IsEnabled = available && hasDocument;
        CompressButton.IsEnabled = available && hasDocument;
        RepairMenuItem.IsEnabled = available && hasDocument;
        LinearizeMenuItem.IsEnabled = available && hasDocument;
        ProtectMenuItem.IsEnabled = available && hasDocument;
        ExportImagesMenuItem.IsEnabled = available && hasDocument;
        ConvertExportImagesMenuItem.IsEnabled = available && hasDocument;
        PdfToWordMenuItem.IsEnabled = available && hasDocument;
        PdfToExcelMenuItem.IsEnabled = available && hasDocument;
        PdfToPowerPointMenuItem.IsEnabled = available && hasDocument;
        OcrMenuItem.IsEnabled = available && hasDocument;
        OcrButton.IsEnabled = available && hasDocument;
        ExtractOcrTextMenuItem.IsEnabled = available && hasDocument;
        FinishingMenuItem.IsEnabled = available && hasDocument;
        MarkupMenuItem.IsEnabled = available && hasDocument;
        FormsMenuItem.IsEnabled = available && hasDocument;
        BatchMenuItem.IsEnabled = available;
        PageNumbersButton.IsEnabled = available && hasDocument;
        AddTextButton.IsEnabled = available && hasDocument;
        HighlightButton.IsEnabled = available && hasDocument;
        CropButton.IsEnabled = available && hasDocument;
        RedactButton.IsEnabled = available && hasDocument;
        DoctorButton.IsEnabled = available && hasDocument;
        DoctorMenuItem.IsEnabled = available && hasDocument;
        SelectAllMenuItem.IsEnabled = available && hasDocument;
        ResetMenuItem.IsEnabled = available && hasDocument;

        MoveUpButton.IsEnabled = available && hasSelection;
        MoveDownButton.IsEnabled = available && hasSelection;
        DuplicateButton.IsEnabled = available && hasSelection;
        DuplicateMenuItem.IsEnabled = available && hasSelection;
        RotateLeftButton.IsEnabled = available && hasSelection;
        RotateRightButton.IsEnabled = available && hasSelection;
        DeleteButton.IsEnabled = available && hasSelection;
        DeleteMenuItem.IsEnabled = available && hasSelection;
        ExtractButton.IsEnabled = available && hasSelection;

        UndoButton.IsEnabled = available && _undo.Count > 0;
        UndoMenuItem.IsEnabled = available && _undo.Count > 0;
        RedoButton.IsEnabled = available && _redo.Count > 0;
        RedoMenuItem.IsEnabled = available && _redo.Count > 0;
        UpdateDocumentTitleDirtyIndicator();
    }

    private bool HasUnsavedLayoutChanges()
    {
        if (_currentPdf is null || _savedLayoutBaseline is null) return false;
        if (Pages.Count != _savedLayoutBaseline.Pages.Count) return true;

        for (var i = 0; i < Pages.Count; i++)
        {
            var current = Pages[i];
            var saved = _savedLayoutBaseline.Pages[i];
            if (current.SourcePageNumber != saved.SourcePageNumber ||
                NormalizeRotation(current.Rotation) != NormalizeRotation(saved.Rotation))
                return true;
        }

        return false;
    }

    private static int NormalizeRotation(int rotation) => ((rotation % 360) + 360) % 360;

    private void UpdateDocumentTitleDirtyIndicator()
    {
        if (_currentPdf is null) return;
        var fileName = Path.GetFileName(_currentPdf);
        DocumentTitle.Text = HasUnsavedLayoutChanges() ? fileName + " *" : fileName;
    }

    private bool HasLayoutChanges()
    {
        if (_currentPdf is null) return false;
        if (Pages.Count != (int)_renderer.PageCount) return true;
        for (var i = 0; i < Pages.Count; i++)
        {
            if (Pages[i].SourcePageNumber != i + 1 || NormalizeRotation(Pages[i].Rotation) != 0)
                return true;
        }
        return false;
    }

    private void RecordUndoState()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        _undo.Push(CaptureLayout());
        while (_undo.Count > MaxUndoDepth)
        {
            var keep = _undo.Take(MaxUndoDepth).Reverse().ToArray();
            _undo.Clear();
            foreach (var item in keep) _undo.Push(item);
        }
        _redo.Clear();
        UpdateCommandStates();
    }

    private PageLayoutSnapshot CaptureLayout() => new(
        Pages.Select(page => new PageState(page.SourcePageNumber, page.Rotation, page.Thumbnail)).ToArray(),
        PagesList.SelectedItems.Cast<PdfPageItem>().Select(page => page.Position).ToArray());

    private void RestoreLayout(PageLayoutSnapshot snapshot)
    {
        Pages.Clear();
        foreach (var state in snapshot.Pages)
        {
            Pages.Add(new PdfPageItem(state.SourcePageNumber, Pages.Count + 1)
            {
                Rotation = state.Rotation,
                Thumbnail = state.Thumbnail ?? GetCachedThumbnail(state.SourcePageNumber)
            });
        }

        Renumber();
        PagesList.SelectedItems.Clear();
        foreach (var position in snapshot.SelectedPositions)
        {
            var index = position - 1;
            if (index >= 0 && index < Pages.Count) PagesList.SelectedItems.Add(Pages[index]);
        }
        if (PagesList.SelectedItems.Count == 0 && Pages.Count > 0) PagesList.SelectedIndex = 0;
        UpdateCommandStates();
    }

    private BitmapSource? GetCachedThumbnail(int sourcePageNumber) =>
        _thumbnailCache.TryGetValue(sourcePageNumber, out var bitmap) ? bitmap : null;

    private void PagesList_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e) =>
        _dragStartPoint = e.GetPosition(PagesList);

    private void PagesList_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _busy) return;
        var current = e.GetPosition(PagesList);
        if (Math.Abs(current.X - _dragStartPoint.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(current.Y - _dragStartPoint.Y) < SystemParameters.MinimumVerticalDragDistance)
            return;

        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (container?.DataContext is not PdfPageItem dragged) return;

        if (!PagesList.SelectedItems.Contains(dragged))
        {
            PagesList.SelectedItems.Clear();
            PagesList.SelectedItems.Add(dragged);
        }

        var selected = SelectedPages().ToArray();
        if (selected.Length == 0) return;
        var data = new DataObject(PageDragFormat, selected);
        DragDrop.DoDragDrop(PagesList, data, DragDropEffects.Move);
    }

    private void PagesList_DragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(PageDragFormat))
        {
            e.Effects = DragDropEffects.Move;
            e.Handled = true;
        }
    }

    private void PagesList_Drop(object sender, DragEventArgs e)
    {
        if (_busy || !e.Data.GetDataPresent(PageDragFormat)) return;
        if (e.Data.GetData(PageDragFormat) is not PdfPageItem[] selected || selected.Length == 0) return;

        var targetContainer = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        var target = targetContainer?.DataContext as PdfPageItem;
        if (target is not null && selected.Contains(target)) return;

        var targetIndex = target is null ? Pages.Count : Pages.IndexOf(target);
        var originalIndices = selected.Select(Pages.IndexOf).Where(index => index >= 0).ToArray();
        targetIndex -= originalIndices.Count(index => index < targetIndex);
        targetIndex = Math.Clamp(targetIndex, 0, Pages.Count - selected.Length);

        RecordUndoState();
        foreach (var page in selected) Pages.Remove(page);
        for (var i = 0; i < selected.Length; i++) Pages.Insert(targetIndex + i, selected[i]);
        AfterLayoutChange(selected, "Reordered pages by drag and drop.");
        e.Handled = true;
    }

    private static T? FindAncestor<T>(DependencyObject? current) where T : DependencyObject
    {
        while (current is not null)
        {
            if (current is T match) return match;
            current = VisualTreeHelper.GetParent(current);
        }
        return null;
    }

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        var pdfs = GetDroppedPdfs(e.Data);
        if (pdfs.Length == 0) return;
        e.Effects = DragDropEffects.Copy;
        e.Handled = true;
    }

    private async void Window_Drop(object sender, DragEventArgs e)
    {
        var pdfs = GetDroppedPdfs(e.Data);
        if (pdfs.Length == 0) return;
        e.Handled = true;

        if (pdfs.Length == 1)
        {
            await OpenPdfAsync(pdfs[0]);
            return;
        }

        var answer = MessageBox.Show(this,
            $"You dropped {pdfs.Length:N0} PDFs. Merge them into one PDF?",
            "AsantePDF", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (answer == MessageBoxResult.Yes)
            await MergeFilesAsync(pdfs);
        else
            await OpenPdfAsync(pdfs[0]);
    }

    private static string[] GetDroppedPdfs(IDataObject data)
    {
        if (!data.GetDataPresent(DataFormats.FileDrop)) return [];
        return (data.GetData(DataFormats.FileDrop) as string[] ?? [])
            .Where(File.Exists)
            .Where(path => string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private void Window_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (_busy)
        {
            if (e.Key == Key.Escape)
            {
                CancelOperation_Click(sender, new RoutedEventArgs());
                e.Handled = true;
            }
            return;
        }

        var ctrl = Keyboard.Modifiers.HasFlag(ModifierKeys.Control);
        var shift = Keyboard.Modifiers.HasFlag(ModifierKeys.Shift);

        if (ctrl && e.Key == Key.O) { OpenPdf_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.Z) { Undo_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.Y) { Redo_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.A) { SelectAllPages_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.D) { DuplicatePages_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && (e.Key == Key.Add || e.Key == Key.OemPlus)) { ZoomIn_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && (e.Key == Key.Subtract || e.Key == Key.OemMinus)) { ZoomOut_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.D0) { FitWidth_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (e.Key == Key.Delete) { DeletePages_Click(sender, new RoutedEventArgs()); e.Handled = true; }
    }

    private void AddRecentDocument(string path)
    {
        try
        {
            var directory = Path.GetDirectoryName(RecentDocumentsPath)!;
            Directory.CreateDirectory(directory);
            var existing = File.Exists(RecentDocumentsPath)
                ? File.ReadAllLines(RecentDocumentsPath)
                : [];
            var updated = new[] { Path.GetFullPath(path) }
                .Concat(existing)
                .Where(File.Exists)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(8)
                .ToArray();
            File.WriteAllLines(RecentDocumentsPath, updated);
            RefreshRecentMenu();
        }
        catch (Exception ex)
        {
            App.Log("Could not update recent documents: " + ex.Message);
        }
    }

    private void RefreshRecentMenu()
    {
        RecentMenu.Items.Clear();
        string[] paths;
        try
        {
            paths = File.Exists(RecentDocumentsPath)
                ? File.ReadAllLines(RecentDocumentsPath).Where(File.Exists).Take(8).ToArray()
                : [];
        }
        catch
        {
            paths = [];
        }

        if (paths.Length == 0)
        {
            RecentMenu.Items.Add(new MenuItem { Header = "(No recent PDFs)", IsEnabled = false });
            return;
        }

        foreach (var path in paths)
        {
            var captured = path;
            var item = new MenuItem { Header = Path.GetFileName(path), ToolTip = path };
            item.Click += async (_, _) => await OpenPdfAsync(captured);
            RecentMenu.Items.Add(item);
        }
    }

    private static string BuildFeatureSummary(PdfInspectionResult inspection)
    {
        var items = new List<string>();
        if (inspection.PageCount > 0) items.Add($"{inspection.PageCount:N0} page(s)");
        if (!string.IsNullOrWhiteSpace(inspection.PdfVersion)) items.Add($"PDF {inspection.PdfVersion}");
        if (inspection.HasErrors) items.Add("Structural errors detected");
        else if (inspection.HasWarnings) items.Add("Structural warnings detected");
        else items.Add("Structure checks clean");
        return string.Join(" · ", items);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        double value = bytes;
        var i = 0;
        while (value >= 1024 && i < units.Length - 1) { value /= 1024; i++; }
        return $"{value:0.##} {units[i]}";
    }

    private static string SuggestName(string input, string suffix) =>
        $"{Path.GetFileNameWithoutExtension(input)}_{suffix}.pdf";

    private string? AskSaveFile(string title, string suggestedName, string filter, string defaultExtension)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = filter,
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = defaultExtension,
            OverwritePrompt = true
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }

    private string? AskSavePath(string title, string suggestedName)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = ".pdf",
            OverwritePrompt = true
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }

    private string? PromptText(string title, string label, string initial = "")
    {
        var box = new TextBox { Text = initial, Margin = new Thickness(0, 8, 0, 12), MinWidth = 320 };
        box.SelectAll();
        var window = BuildPromptWindow(title, label, box, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        return window.ShowDialog() == true ? box.Text : null;
    }

    private (string Header, string Footer)? PromptHeaderFooter()
    {
        var header = new TextBox { Margin = new Thickness(0, 5, 0, 10), MinWidth = 330 };
        var footer = new TextBox { Margin = new Thickness(0, 5, 0, 10), MinWidth = 330 };
        var panel = new StackPanel();
        panel.Children.Add(new TextBlock { Text = "Header text", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(header);
        panel.Children.Add(new TextBlock { Text = "Footer text", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(footer);
        var window = BuildPromptWindow("Header / Footer", "Enter one or both values.", panel, out var ok);
        ok.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(header.Text) && string.IsNullOrWhiteSpace(footer.Text))
            {
                MessageBox.Show(window, "Enter a header, footer, or both.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            window.DialogResult = true;
        };
        return window.ShowDialog() == true ? (header.Text, footer.Text) : null;
    }

    private PdfMetadataValues? PromptMetadata()
    {
        var title = new TextBox { Margin = new Thickness(0, 4, 0, 8), MinWidth = 330 };
        var author = new TextBox { Margin = new Thickness(0, 4, 0, 8), MinWidth = 330 };
        var subject = new TextBox { Margin = new Thickness(0, 4, 0, 8), MinWidth = 330 };
        var keywords = new TextBox { Margin = new Thickness(0, 4, 0, 8), MinWidth = 330 };
        var panel = new StackPanel();
        panel.Children.Add(new TextBlock { Text = "Title", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(title);
        panel.Children.Add(new TextBlock { Text = "Author", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(author);
        panel.Children.Add(new TextBlock { Text = "Subject", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(subject);
        panel.Children.Add(new TextBlock { Text = "Keywords", FontWeight = FontWeights.SemiBold });
        panel.Children.Add(keywords);
        var window = BuildPromptWindow("Edit PDF Metadata", "Blank fields are saved as blank metadata values.", panel, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        return window.ShowDialog() == true
            ? new PdfMetadataValues(title.Text, author.Text, subject.Text, keywords.Text)
            : null;
    }

    private int? PromptForPositiveInt(string title, string label, int initial)
    {
        var box = new TextBox { Text = initial.ToString(), Margin = new Thickness(0, 8, 0, 12) };
        var window = BuildPromptWindow(title, label, box, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        if (window.ShowDialog() != true) return null;
        if (int.TryParse(box.Text, out var value) && value > 0) return value;
        MessageBox.Show(this, "Enter a whole number greater than zero.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
        return null;
    }

    private PdfCompressionProfile? PromptCompressionProfile()
    {
        var combo = new ComboBox
        {
            ItemsSource = Enum.GetValues<PdfCompressionProfile>(),
            SelectedItem = PdfCompressionProfile.Balanced,
            Margin = new Thickness(0, 8, 0, 6),
            MinWidth = 220
        };
        var panel = new StackPanel();
        panel.Children.Add(combo);
        panel.Children.Add(new TextBlock
        {
            Text = "Lossless keeps image quality. Balanced and Strong can recompress JPEG images to reduce size.",
            Foreground = Brushes.DimGray,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 10)
        });

        var window = BuildPromptWindow("Compress PDF", "Compression profile:", panel, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        return window.ShowDialog() == true && combo.SelectedItem is PdfCompressionProfile profile ? profile : null;
    }

    private IReadOnlyDictionary<string, string>? PromptFormValues(IReadOnlyList<PdfFormFieldInfo> fields)
    {
        var editors = new Dictionary<string, FrameworkElement>(StringComparer.Ordinal);
        var rows = new StackPanel { Margin = new Thickness(0, 8, 0, 8) };

        foreach (var field in fields)
        {
            rows.Children.Add(new TextBlock
            {
                Text = string.IsNullOrWhiteSpace(field.Name) ? "(unnamed field)" : field.Name,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 8, 0, 2),
                TextWrapping = TextWrapping.Wrap
            });
            rows.Children.Add(new TextBlock
            {
                Text = field.Kind + (field.Writable ? string.Empty : " • read only"),
                Foreground = Brushes.DimGray,
                FontSize = 11,
                Margin = new Thickness(0, 0, 0, 3)
            });

            FrameworkElement editor;
            if (field.Kind == "Checkbox")
            {
                editor = new CheckBox
                {
                    IsChecked = field.Value.Equals("true", StringComparison.OrdinalIgnoreCase),
                    Content = "Checked",
                    IsEnabled = field.Writable,
                    Margin = new Thickness(0, 2, 0, 4)
                };
            }
            else
            {
                editor = new TextBox
                {
                    Text = field.Value,
                    IsReadOnly = !field.Writable,
                    MinWidth = 460,
                    Margin = new Thickness(0, 2, 0, 4),
                    ToolTip = field.Kind is "Radio" or "Combo" or "List"
                        ? "Enter the zero-based selection index for this field."
                        : null
                };
            }
            rows.Children.Add(editor);
            editors[field.Name] = editor;
        }

        var scroll = new ScrollViewer
        {
            Content = rows,
            MaxHeight = 520,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        var window = BuildPromptWindow("Fill PDF Form",
            "Review the detected AcroForm fields. For radio buttons, combo boxes and list boxes, enter the selection index.",
            scroll, out var ok);
        window.Width = 620;
        ok.Click += (_, _) => window.DialogResult = true;
        if (window.ShowDialog() != true) return null;

        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var field in fields.Where(f => f.Writable))
        {
            if (!editors.TryGetValue(field.Name, out var editor)) continue;
            values[field.Name] = editor switch
            {
                CheckBox check => check.IsChecked == true ? "true" : "false",
                TextBox text => text.Text,
                _ => field.Value
            };
        }
        return values;
    }

    private BatchPdfOperation? PromptBatchOperation()
    {
        var combo = new ComboBox
        {
            ItemsSource = new[]
            {
                "Balanced compression",
                "Repair PDF structure",
                "Optimize for web viewing"
            },
            SelectedIndex = 0,
            MinWidth = 300,
            Margin = new Thickness(0, 8, 0, 10)
        };
        var window = BuildPromptWindow("Batch Process PDFs",
            "Choose the operation AsantePDF should apply to every selected PDF.", combo, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        if (window.ShowDialog() != true) return null;
        return combo.SelectedIndex switch
        {
            1 => BatchPdfOperation.Repair,
            2 => BatchPdfOperation.OptimizeForWeb,
            _ => BatchPdfOperation.CompressBalanced
        };
    }

    private string? PromptPassword(string title, string label)
    {
        var box = new PasswordBox { Margin = new Thickness(0, 8, 0, 12) };
        var window = BuildPromptWindow(title, label, box, out var ok);
        ok.Click += (_, _) => window.DialogResult = true;
        return window.ShowDialog() == true ? box.Password : null;
    }

    private (string UserPassword, string OwnerPassword)? PromptProtectionPasswords()
    {
        var user = new PasswordBox { Margin = new Thickness(0, 5, 0, 10) };
        var confirm = new PasswordBox { Margin = new Thickness(0, 5, 0, 10) };
        var owner = new PasswordBox { Margin = new Thickness(0, 5, 0, 10) };

        var grid = new StackPanel();
        grid.Children.Add(new TextBlock { Text = "Password required to open the PDF", FontWeight = FontWeights.SemiBold });
        grid.Children.Add(user);
        grid.Children.Add(new TextBlock { Text = "Confirm opening password", FontWeight = FontWeights.SemiBold });
        grid.Children.Add(confirm);
        grid.Children.Add(new TextBlock { Text = "Owner password (optional)", FontWeight = FontWeights.SemiBold });
        grid.Children.Add(owner);
        grid.Children.Add(new TextBlock
        {
            Text = "If owner password is blank, AsantePDF creates a secure internal owner password. Passwords are not written to the normal process command line.",
            Foreground = Brushes.DimGray,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 10)
        });

        var window = BuildPromptWindow("Protect PDF", "Use 256-bit PDF encryption.", grid, out var ok);
        ok.Click += (_, _) =>
        {
            if (string.IsNullOrEmpty(user.Password))
            {
                MessageBox.Show(window, "Enter an opening password.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            if (!string.Equals(user.Password, confirm.Password, StringComparison.Ordinal))
            {
                MessageBox.Show(window, "The opening passwords do not match.", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            window.DialogResult = true;
        };

        if (window.ShowDialog() != true) return null;
        var ownerPassword = string.IsNullOrEmpty(owner.Password)
            ? Convert.ToHexString(RandomNumberGenerator.GetBytes(24))
            : owner.Password;
        return (user.Password, ownerPassword);
    }

    private Window BuildPromptWindow(string title, string label, FrameworkElement control, out Button okButton)
    {
        var window = new Window
        {
            Title = title,
            Owner = this,
            Width = 440,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Background = Brushes.White,
            ShowInTaskbar = false
        };
        var stack = new StackPanel { Margin = new Thickness(18) };
        stack.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap });
        stack.Children.Add(control);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        var cancel = new Button { Content = "Cancel", IsCancel = true, MinWidth = 82 };
        okButton = new Button { Content = "OK", IsDefault = true, MinWidth = 82 };
        buttons.Children.Add(cancel);
        buttons.Children.Add(okButton);
        stack.Children.Add(buttons);
        window.Content = stack;
        return window;
    }

    private sealed record PageState(int SourcePageNumber, int Rotation, BitmapSource? Thumbnail);
    private sealed record PageLayoutSnapshot(IReadOnlyList<PageState> Pages, IReadOnlyList<int> SelectedPositions);
}
