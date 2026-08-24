param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    [IO.File]::WriteAllText($Path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

function Set-TextFile([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    [IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n").Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

$pageScopePath = Join-Path $SourceRoot 'src\PdfRescue.App\PageScopeParser.cs'
Set-TextFile $pageScopePath @'
namespace PdfRescue.App;

internal static class PageScopeParser
{
    public static bool TryParse(string? text, int pageCount, out int[] positions, out string error)
    {
        positions = [];
        error = string.Empty;
        if (pageCount < 1)
        {
            error = "This PDF has no pages.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(text) || string.Equals(text.Trim(), "all", StringComparison.OrdinalIgnoreCase))
        {
            positions = Enumerable.Range(1, pageCount).ToArray();
            return true;
        }

        var result = new List<int>();
        var seen = new HashSet<int>();
        foreach (var token in text.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            var dash = token.IndexOf('-');
            if (dash < 0)
            {
                if (!int.TryParse(token, out var page) || page < 1 || page > pageCount)
                {
                    error = $"'{token}' is not a valid page number from 1 to {pageCount:N0}.";
                    return false;
                }
                if (seen.Add(page)) result.Add(page);
                continue;
            }

            if (token.IndexOf('-', dash + 1) >= 0 ||
                !int.TryParse(token[..dash].Trim(), out var start) ||
                !int.TryParse(token[(dash + 1)..].Trim(), out var end) ||
                start < 1 || end < start || end > pageCount)
            {
                error = $"'{token}' is not a valid ascending page range within 1 to {pageCount:N0}.";
                return false;
            }

            for (var page = start; page <= end; page++)
                if (seen.Add(page)) result.Add(page);
        }

        if (result.Count == 0)
        {
            error = "Enter at least one page number or range, for example 1-3,5,8-10.";
            return false;
        }

        positions = result.ToArray();
        return true;
    }
}
'@

$ocrPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\LocalOcrService.cs'
Replace-Exact $ocrPath @'
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;
'@ @'
using Windows.Globalization;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;
'@ 'Windows OCR language namespace'

Replace-Exact $ocrPath @'
public sealed record OcrPageResult(string Text, IReadOnlyList<OcrWordPlacement> Words);

public sealed class LocalOcrService
'@ @'
public sealed record OcrPageResult(string Text, IReadOnlyList<OcrWordPlacement> Words);
public sealed record OcrLanguageOption(string Id, string Label, string Detail)
{
    public override string ToString() => Label;
}

public sealed class LocalOcrService
'@ 'OCR language option record'

Replace-Exact $ocrPath @'
    public bool IsAvailable => OcrEngine.TryCreateFromUserProfileLanguages() is not null || IsBundledTesseractAvailable;

    public Task<OcrPageResult> RecognizeWithBundledTesseractAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
'@ @'
    public bool IsAvailable => OcrEngine.TryCreateFromUserProfileLanguages() is not null || IsBundledTesseractAvailable;

    public IReadOnlyList<OcrLanguageOption> GetLanguageOptions()
    {
        var options = new List<OcrLanguageOption>
        {
            new("auto", "Automatic", "Use the best local recognizer available for this computer. Background OCR keeps the bundled English engine as the deterministic fallback when available.")
        };

        foreach (var language in OcrEngine.AvailableRecognizerLanguages
                     .OrderBy(language => language.DisplayName, StringComparer.CurrentCultureIgnoreCase)
                     .ThenBy(language => language.LanguageTag, StringComparer.OrdinalIgnoreCase))
        {
            options.Add(new OcrLanguageOption(
                "windows:" + language.LanguageTag,
                $"{language.DisplayName} ({language.LanguageTag})",
                "Use the Windows OCR recognizer installed for this language."));
        }

        if (IsBundledTesseractAvailable)
        {
            options.Add(new OcrLanguageOption(
                "tesseract:eng",
                "English · bundled Tesseract",
                "Use AsantePDF's bundled English OCR data directly. This works even when Windows has no English OCR pack installed."));
        }

        return options
            .GroupBy(option => option.Id, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .ToArray();
    }

    public Task<OcrPageResult> RecognizeWithBundledTesseractAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
'@ 'OCR language discovery'

Replace-Exact $ocrPath @'
    public async Task<OcrPageResult> RecognizeAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var engine = OcrEngine.TryCreateFromUserProfileLanguages();
        if (engine is not null)
        {
            try
            {
                return await RecognizeWithWindowsAsync(engine, bitmap, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch when (IsBundledTesseractAvailable)
            {
                // Windows OCR can reject individual raster formats/pages even
                // when an engine is available. The bundled Tesseract engine is
                // the deterministic local fallback for those page-level failures.
                return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
            }
        }
        if (IsBundledTesseractAvailable)
            return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
        throw new InvalidOperationException("No local OCR engine is available. AsantePDF could not find Windows OCR or its bundled Tesseract fallback.");
    }
'@ @'
    public async Task<OcrPageResult> RecognizeAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var engine = OcrEngine.TryCreateFromUserProfileLanguages();
        if (engine is not null)
        {
            try
            {
                return await RecognizeWithWindowsAsync(engine, bitmap, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch when (IsBundledTesseractAvailable)
            {
                return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
            }
        }
        if (IsBundledTesseractAvailable)
            return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
        throw new InvalidOperationException("No local OCR engine is available. AsantePDF could not find Windows OCR or its bundled Tesseract fallback.");
    }

    public async Task<OcrPageResult> RecognizeAsync(
        BitmapSource bitmap,
        string? languageId,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (string.IsNullOrWhiteSpace(languageId) || string.Equals(languageId, "auto", StringComparison.OrdinalIgnoreCase))
            return await RecognizeAsync(bitmap, cancellationToken);

        if (string.Equals(languageId, "tesseract:eng", StringComparison.OrdinalIgnoreCase))
            return await RecognizeWithBundledTesseractAsync(bitmap, cancellationToken);

        const string windowsPrefix = "windows:";
        if (languageId.StartsWith(windowsPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var tag = languageId[windowsPrefix.Length..];
            var language = OcrEngine.AvailableRecognizerLanguages.FirstOrDefault(candidate =>
                string.Equals(candidate.LanguageTag, tag, StringComparison.OrdinalIgnoreCase));
            if (language is null)
                throw new InvalidOperationException($"Windows OCR language '{tag}' is no longer installed.");

            var engine = OcrEngine.TryCreateFromLanguage(language);
            if (engine is null)
                throw new InvalidOperationException($"Windows could not create an OCR recognizer for '{language.DisplayName}'.");
            return await RecognizeWithWindowsAsync(engine, bitmap, cancellationToken);
        }

        throw new InvalidOperationException("The selected OCR language is not available on this computer.");
    }
'@ 'configured OCR recognition overload'

$backgroundPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundOperations.cs'
Replace-Exact $backgroundPath @'
    private BackgroundPdfSnapshot CaptureBackgroundPdfSnapshot()
    {
        if (_currentPdf is null || Pages.Count == 0)
            throw new InvalidOperationException("No PDF is open.");

        return new BackgroundPdfSnapshot(
            _currentPdf,
            Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray(),
            HasLayoutChanges());
    }
'@ @'
    private BackgroundPdfSnapshot CaptureBackgroundPdfSnapshot(IReadOnlyCollection<int>? pagePositions = null)
    {
        if (_currentPdf is null || Pages.Count == 0)
            throw new InvalidOperationException("No PDF is open.");

        PdfPageItem[] selectedPages;
        if (pagePositions is null)
        {
            selectedPages = Pages.ToArray();
        }
        else
        {
            var positions = pagePositions.Distinct().ToArray();
            if (positions.Length == 0 || positions.Any(position => position < 1 || position > Pages.Count))
                throw new ArgumentOutOfRangeException(nameof(pagePositions), "Page positions must refer to the current working layout.");
            selectedPages = positions.Select(position => Pages[position - 1]).ToArray();
        }

        var isWholeCurrentLayout = selectedPages.Length == Pages.Count &&
                                   selectedPages.Select((page, index) => ReferenceEquals(page, Pages[index])).All(value => value);
        return new BackgroundPdfSnapshot(
            _currentPdf,
            selectedPages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray(),
            HasLayoutChanges() || !isWholeCurrentLayout);
    }
'@ 'background page-scope snapshots'

$backgroundOcrPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundOcrExports.cs'
Replace-Exact $backgroundOcrPath @'
    private Task<OcrPageResult> RecognizeBackgroundPageAsync(
        System.Windows.Media.Imaging.BitmapSource bitmap,
        CancellationToken token) =>
        _ocr.IsBundledTesseractAvailable
            ? _ocr.RecognizeWithBundledTesseractAsync(bitmap, token)
            : _ocr.RecognizeAsync(bitmap, token);
'@ @'
    private Task<OcrPageResult> RecognizeBackgroundPageAsync(
        System.Windows.Media.Imaging.BitmapSource bitmap,
        string? languageId,
        CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(languageId) || string.Equals(languageId, "auto", StringComparison.OrdinalIgnoreCase))
        {
            return _ocr.IsBundledTesseractAvailable
                ? _ocr.RecognizeWithBundledTesseractAsync(bitmap, token)
                : _ocr.RecognizeAsync(bitmap, token);
        }
        return _ocr.RecognizeAsync(bitmap, languageId, token);
    }
'@ 'background configured OCR language'

# Existing Word/Excel exports retain automatic language behaviour.
Replace-Exact $backgroundOcrPath 'var result = await RecognizeBackgroundPageAsync(bitmap, ct);' 'var result = await RecognizeBackgroundPageAsync(bitmap, null, ct);' 'Word/Excel automatic OCR calls'

Replace-Exact $backgroundOcrPath @'
    private void QueueSearchableOcrPdfBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();
'@ @'
    private void QueueSearchableOcrPdfBackground(
        string source,
        string output,
        IReadOnlyCollection<int>? pagePositions = null,
        string? languageId = null)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot(pagePositions);
'@ 'searchable OCR scoped queue signature'
Replace-Exact $backgroundOcrPath 'var recognized = await RecognizeBackgroundPageAsync(bitmap, ct);' 'var recognized = await RecognizeBackgroundPageAsync(bitmap, languageId, ct);' 'searchable OCR configured recognition'

Replace-Exact $backgroundOcrPath @'
    private void QueueOcrTextBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();
'@ @'
    private void QueueOcrTextBackground(
        string source,
        string output,
        IReadOnlyCollection<int>? pagePositions = null,
        string? languageId = null)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot(pagePositions);
'@ 'OCR text scoped queue signature'
# The remaining configured recognition occurrence belongs to OCR text after the searchable one was replaced.
$text = [IO.File]::ReadAllText($backgroundOcrPath).Replace("`r`n", "`n")
$needle = 'var recognized = await RecognizeBackgroundPageAsync(bitmap, null, ct);'
$last = $text.LastIndexOf($needle, [StringComparison]::Ordinal)
if ($last -lt 0) { throw 'Could not find OCR text automatic recognition call.' }
$text = $text.Remove($last, $needle.Length).Insert($last, 'var recognized = await RecognizeBackgroundPageAsync(bitmap, languageId, ct);')
[IO.File]::WriteAllText($backgroundOcrPath, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))

$configPath = Join-Path $SourceRoot 'src\PdfRescue.App\ToolConfigurationDialogs.cs'
Replace-Exact $configPath @'
internal sealed record MergeDialogResult(IReadOnlyList<string> Files, string OutputPath);

internal static class ToolConfigurationDialogs
'@ @'
internal sealed record MergeDialogResult(IReadOnlyList<string> Files, string OutputPath);
internal enum OcrOutputKind
{
    SearchablePdf,
    PlainText
}
internal sealed record OcrDialogResult(
    OcrOutputKind OutputKind,
    string LanguageId,
    IReadOnlyList<int> PagePositions,
    string OutputPath);

internal static class ToolConfigurationDialogs
'@ 'OCR configuration result types'

# Insert OCR dialog before CreateShell.
Replace-Exact $configPath @'
    private static Window CreateShell(
'@ @'
    public static OcrDialogResult? ShowOcr(
        Window owner,
        string sourcePath,
        int pageCount,
        IReadOnlyList<PdfRescue.App.Services.OcrLanguageOption> languageOptions,
        OcrOutputKind defaultOutputKind)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(
            owner,
            "OCR PDF",
            "Choose the recognizer, page scope and local output you actually need. All OCR stays on this computer.",
            680,
            650,
            out var body,
            out var actions);

        body.Children.Add(FieldLabel("Input PDF"));
        body.Children.Add(ReadOnlyPathBox($"{source}   •   {pageCount:N0} pages"));

        body.Children.Add(FieldLabel("OCR language", top: 18));
        var language = CreateComboBox();
        language.ItemsSource = languageOptions;
        language.SelectedIndex = 0;
        body.Children.Add(language);
        var languageDetail = MutedText(languageOptions.FirstOrDefault()?.Detail ?? "No OCR language information is available.");
        languageDetail.TextWrapping = TextWrapping.Wrap;
        languageDetail.Margin = new Thickness(0, 7, 0, 0);
        body.Children.Add(languageDetail);
        language.SelectionChanged += (_, _) =>
        {
            if (language.SelectedItem is PdfRescue.App.Services.OcrLanguageOption option)
                languageDetail.Text = option.Detail;
        };

        body.Children.Add(FieldLabel("Pages", top: 18));
        var allPages = CreateRadio($"All pages ({pageCount:N0})", isChecked: true);
        var customPages = CreateRadio("Custom page range", isChecked: false);
        allPages.GroupName = "OcrPageScope";
        customPages.GroupName = "OcrPageScope";
        body.Children.Add(allPages);
        body.Children.Add(customPages);
        var range = CreateTextBox(pageCount > 1 ? $"1-{pageCount}" : "1");
        range.Margin = new Thickness(24, 5, 0, 0);
        range.IsEnabled = false;
        range.Opacity = 0.55;
        body.Children.Add(range);
        var rangeHint = MutedText("Examples: 1-3,5,8-10. Page numbers refer to the current working page layout.");
        rangeHint.Margin = new Thickness(24, 5, 0, 0);
        rangeHint.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(rangeHint);
        customPages.Checked += (_, _) => { range.IsEnabled = true; range.Opacity = 1; };
        allPages.Checked += (_, _) => { range.IsEnabled = false; range.Opacity = 0.55; };

        body.Children.Add(FieldLabel("Output", top: 18));
        var outputKind = CreateComboBox();
        outputKind.ItemsSource = new[] { "Searchable PDF", "Plain text (.txt)" };
        outputKind.SelectedIndex = defaultOutputKind == OcrOutputKind.SearchablePdf ? 0 : 1;
        body.Children.Add(outputKind);
        var outputNote = MutedText(string.Empty);
        outputNote.Margin = new Thickness(0, 7, 0, 0);
        outputNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(outputNote);

        var initialKind = defaultOutputKind;
        string Suggested(OcrOutputKind kind) => kind == OcrOutputKind.SearchablePdf
            ? SuggestedSibling(source, "searchable")
            : Path.Combine(Path.GetDirectoryName(source)!, Path.GetFileNameWithoutExtension(source) + "-ocr.txt");

        body.Children.Add(FieldLabel("Output location", top: 14));
        var outputGrid = new Grid();
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var outputBox = CreateTextBox(Suggested(initialKind));
        outputGrid.Children.Add(outputBox);
        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        browse.Click += (_, _) =>
        {
            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            var extension = kind == OcrOutputKind.SearchablePdf ? ".pdf" : ".txt";
            var dialog = new SaveFileDialog
            {
                Title = kind == OcrOutputKind.SearchablePdf ? "Save searchable OCR PDF" : "Save OCR text",
                Filter = kind == OcrOutputKind.SearchablePdf ? "PDF files (*.pdf)|*.pdf" : "Text files (*.txt)|*.txt",
                AddExtension = true,
                DefaultExt = extension,
                OverwritePrompt = true,
                FileName = Path.GetFileName(outputBox.Text)
            };
            var directory = Path.GetDirectoryName(outputBox.Text);
            if (!string.IsNullOrWhiteSpace(directory) && Directory.Exists(directory)) dialog.InitialDirectory = directory;
            if (dialog.ShowDialog(window) == true) outputBox.Text = dialog.FileName;
        };
        Grid.SetColumn(browse, 1);
        outputGrid.Children.Add(browse);
        body.Children.Add(outputGrid);

        void RefreshOutputKind(bool replacePath)
        {
            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            outputNote.Text = kind == OcrOutputKind.SearchablePdf
                ? "Creates a new PDF containing the selected pages with a searchable text layer over their raster image."
                : "Recognises the selected pages and writes their text to a UTF-8 text file.";
            if (replacePath) outputBox.Text = Suggested(kind);
        }
        outputKind.SelectionChanged += (_, _) => RefreshOutputKind(replacePath: true);
        RefreshOutputKind(replacePath: false);

        OcrDialogResult? result = null;
        var run = CreateButton("Run OCR", primary: true);
        run.Click += (_, _) =>
        {
            if (language.SelectedItem is not PdfRescue.App.Services.OcrLanguageOption languageOption)
            {
                MessageBox.Show(window, "Choose an OCR language.", "OCR PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            int[] positions;
            if (customPages.IsChecked == true)
            {
                if (!PageScopeParser.TryParse(range.Text, pageCount, out positions, out var error))
                {
                    MessageBox.Show(window, error, "OCR PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
            }
            else
            {
                positions = Enumerable.Range(1, pageCount).ToArray();
            }

            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            var extension = kind == OcrOutputKind.SearchablePdf ? ".pdf" : ".txt";
            var path = ValidateOutputPath(window, source, outputBox.Text, extension);
            if (path is null) return;
            result = new OcrDialogResult(kind, languageOption.Id, positions, path);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    private static Window CreateShell(
'@ 'OCR configuration dialog'

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $mainPath @'
    private async void OcrPdf_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to OCR") is null) return;
        if (!_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var source = _currentPdf!;
        var output = AskSavePath("Save searchable OCR PDF", SuggestName(source, "searchable"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueSearchableOcrPdfBackground(source, output);
            return;
        }

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
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract") is null) return;
        if (!_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var source = _currentPdf!;
        var suggested = Path.GetFileNameWithoutExtension(source) + "-ocr.txt";
        var dialog = new SaveFileDialog
        {
            Title = "Save OCR text",
            Filter = "Text file (*.txt)|*.txt",
            FileName = suggested,
            AddExtension = true,
            DefaultExt = ".txt"
        };
        if (dialog.ShowDialog(this) != true) return;
        if (_backgroundTasks is not null)
        {
            QueueOcrTextBackground(source, dialog.FileName);
            return;
        }

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
'@ @'
    private async void OcrPdf_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredOcrAsync(OcrOutputKind.SearchablePdf);

    private async void ExtractOcrText_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredOcrAsync(OcrOutputKind.PlainText);

    private async Task RunConfiguredOcrAsync(OcrOutputKind defaultOutputKind)
    {
        var pickerTitle = defaultOutputKind == OcrOutputKind.SearchablePdf
            ? "Choose a PDF to OCR"
            : "Choose a PDF whose text you want to extract";
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync(pickerTitle) is null) return;
        if (!_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var source = _currentPdf!;
        var configuration = ToolConfigurationDialogs.ShowOcr(
            this,
            source,
            Pages.Count,
            _ocr.GetLanguageOptions(),
            defaultOutputKind);
        if (configuration is null) return;

        if (_backgroundTasks is not null)
        {
            if (configuration.OutputKind == OcrOutputKind.SearchablePdf)
                QueueSearchableOcrPdfBackground(source, configuration.OutputPath, configuration.PagePositions, configuration.LanguageId);
            else
                QueueOcrTextBackground(source, configuration.OutputPath, configuration.PagePositions, configuration.LanguageId);
            return;
        }

        var workingPages = configuration.PagePositions.Select(position => Pages[position - 1]).ToArray();
        if (configuration.OutputKind == OcrOutputKind.SearchablePdf)
        {
            await RunPdfOperationAsync("Running local OCR...", "Searchable OCR PDF created.", async token =>
            {
                var rasterPages = new List<PdfRasterPage>(workingPages.Length);
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(i, workingPages.Length, $"OCR page {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                    var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                    rasterPages.Add(ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, recognized.Words));
                }
                SetDeterminateProgress(workingPages.Length, workingPages.Length, "Writing searchable PDF...");
                await ImagePdfBuilder.WriteAsync(rasterPages, configuration.OutputPath, token);
            });
            return;
        }

        await RunPdfOperationAsync("Extracting text with local OCR...", "OCR text extracted.", async token =>
        {
            var output = new System.Text.StringBuilder();
            for (var i = 0; i < workingPages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, workingPages.Length, $"Reading page {i + 1:N0} of {workingPages.Length:N0}...");
                var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                if (i > 0)
                    output.AppendLine().AppendLine($"--- Page {configuration.PagePositions[i]} ---").AppendLine();
                output.Append(recognized.Text);
            }
            await File.WriteAllTextAsync(configuration.OutputPath, output.ToString(), token);
        });
    }
'@ 'unified configured OCR workflow'

Write-Host 'OCR configuration and page-scope patch applied.' -ForegroundColor Green
