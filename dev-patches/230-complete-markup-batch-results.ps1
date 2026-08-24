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

$multi = Join-Path $SourceRoot 'src\PdfRescue.App\MultiResultDialog.xaml.cs'
Replace-Exact $multi @'
    public MultiResultDialog(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        bool canRunAgain)
    {
        InitializeComponent();
        Title = title;
        TitleText.Text = title;
        SummaryText.Text = summary;
        SourceNameText.Text = Path.GetFileName(sourcePath);
        SourcePathText.Text = sourcePath;
'@ @'
    public MultiResultDialog(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        bool canRunAgain,
        string? sourceLabel = null,
        string? sourceDescription = null)
    {
        InitializeComponent();
        Title = title;
        TitleText.Text = title;
        SummaryText.Text = summary;
        SourceNameText.Text = string.IsNullOrWhiteSpace(sourceLabel) ? Path.GetFileName(sourcePath) : sourceLabel;
        SourcePathText.Text = string.IsNullOrWhiteSpace(sourceDescription) ? sourcePath : sourceDescription;
'@ 'multi-result source description'

$results = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
Replace-Exact $results @'
    private async Task ShowMultiResultWorkflowAsync(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        Action runAgain)
'@ @'
    private async Task ShowMultiResultWorkflowAsync(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        Action runAgain,
        string? sourceLabel = null,
        string? sourceDescription = null)
'@ 'multi-result workflow optional source labels'
Replace-Exact $results @'
        var dialog = new MultiResultDialog(title, summary, sourcePath, available, runAgain is not null)
'@ @'
        var dialog = new MultiResultDialog(
            title,
            summary,
            sourcePath,
            available,
            runAgain is not null,
            sourceLabel,
            sourceDescription)
'@ 'multi-result dialog source labels'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        var success = results.Count(r => r.Success);
        var failed = results.Count - success;
        var details = failed == 0
            ? $"Processed {success:N0} PDF(s) successfully.\n\nOutput folder:\n{folderDialog.FolderName}"
            : $"Completed {success:N0} PDF(s); {failed:N0} failed.\n\n" +
              string.Join("\n", results.Where(r => !r.Success).Take(8).Select(r => $"• {Path.GetFileName(r.InputPath)}: {r.Error}"));
        MessageBox.Show(this, details, "AsantePDF Batch", MessageBoxButton.OK,
            failed == 0 ? MessageBoxImage.Information : MessageBoxImage.Warning);
'@ @'
        var success = results.Count(r => r.Success);
        var failed = results.Count - success;
        var successfulOutputs = results
            .Where(result => result.Success && !string.IsNullOrWhiteSpace(result.OutputPath) && File.Exists(result.OutputPath))
            .Select(result => result.OutputPath)
            .ToArray();
        var failureDetails = results
            .Where(result => !result.Success)
            .Take(6)
            .Select(result => $"• {Path.GetFileName(result.InputPath)}: {result.Error ?? "Unknown error"}")
            .ToArray();
        var summary = failed == 0
            ? $"Processed all {success:N0} PDF(s) successfully. Select any result below to open or save elsewhere."
            : $"Completed {success:N0} PDF(s); {failed:N0} failed." +
              (failureDetails.Length == 0 ? string.Empty : "\n\n" + string.Join("\n", failureDetails));

        if (successfulOutputs.Length == 0)
        {
            MessageBox.Show(this,
                summary + $"\n\nOutput folder:\n{folderDialog.FolderName}",
                "AsantePDF Batch",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }

        await ShowMultiResultWorkflowAsync(
            "Batch processing complete",
            summary,
            files.FileNames[0],
            successfulOutputs,
            () => BatchProcess_Click(this, new RoutedEventArgs()),
            files.FileNames.Length == 1 ? Path.GetFileName(files.FileNames[0]) : $"{files.FileNames.Length:N0} source PDFs",
            files.FileNames.Length == 1
                ? files.FileNames[0]
                : $"{Path.GetFileName(files.FileNames[0])} + {files.FileNames.Length - 1:N0} more · {operation.Value}");
'@ 'batch completion result set'

Replace-Exact $main @'
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

        var selectedPages = SelectedPages();
        var targetPositions = selectedPages
            .Select(page => page.Position)
            .Append(pageNumber)
            .Distinct()
            .OrderBy(position => position)
            .ToArray();
        var targetSummary = FormatPagePositionSummary(targetPositions);

        var output = AskSavePath(
            targetPositions.Length == 1 ? "Save cropped PDF" : $"Save PDF with {targetPositions.Length:N0} cropped pages",
            SuggestName(_currentPdf, "cropped"));
        if (output is null) return;

        var runningText = targetPositions.Length == 1
            ? "Cropping page..."
            : $"Cropping {targetPositions.Length:N0} selected pages...";
        var completedText = targetPositions.Length == 1
            ? $"Crop applied to page {targetPositions[0]:N0}."
            : $"Crop applied to {targetPositions.Length:N0} selected pages: {targetSummary}.";

        await RunPdfOperationAsync(runningText, completedText, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.CropPagesAsync(working, output, targetPositions, rect, ct), token));
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
'@ @'
    private async Task ApplyTextMarkupAsync(int pageNumber, double normalizedX, double normalizedY, string text)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF with added text", SuggestName(source, "text"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Adding text...", "Text added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.AddTextAsync(working, output, pageNumber, normalizedX, normalizedY, text, 14, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Text added",
                $"Created a copy with text added on page {pageNumber:N0}. The source PDF was not overwritten.",
                source,
                output,
                () => AddTextMarkup_Click(this, new RoutedEventArgs()));
    }

    private async Task ApplyHighlightMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save highlighted PDF", SuggestName(source, "highlighted"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Adding highlight...", "Highlight added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.AddHighlightAsync(working, output, pageNumber, rect, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Highlight complete",
                $"Created a highlighted copy from page {pageNumber:N0}. The source PDF was not overwritten.",
                source,
                output,
                () => HighlightMarkup_Click(this, new RoutedEventArgs()));
    }

    private async Task ApplyRectangleMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF with rectangle", SuggestName(source, "rectangle"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Drawing rectangle...", "Rectangle added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddRectangleAsync(working, output, pageNumber, rect, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Rectangle complete",
                $"Created a copy with the rectangle markup on page {pageNumber:N0}.",
                source,
                output,
                () => RectangleMarkup_Click(this, new RoutedEventArgs()));
    }

    private async Task ApplyEllipseMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF with ellipse", SuggestName(source, "ellipse"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Drawing ellipse...", "Ellipse added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddEllipseAsync(working, output, pageNumber, rect, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Ellipse complete",
                $"Created a copy with the ellipse markup on page {pageNumber:N0}.",
                source,
                output,
                () => EllipseMarkup_Click(this, new RoutedEventArgs()));
    }

    private async Task ApplyCropMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;

        var selectedPages = SelectedPages();
        var targetPositions = selectedPages
            .Select(page => page.Position)
            .Append(pageNumber)
            .Distinct()
            .OrderBy(position => position)
            .ToArray();
        var targetSummary = FormatPagePositionSummary(targetPositions);

        var output = AskSavePath(
            targetPositions.Length == 1 ? "Save cropped PDF" : $"Save PDF with {targetPositions.Length:N0} cropped pages",
            SuggestName(source, "cropped"));
        if (output is null) return;

        var runningText = targetPositions.Length == 1
            ? "Cropping page..."
            : $"Cropping {targetPositions.Length:N0} selected pages...";
        var completedText = targetPositions.Length == 1
            ? $"Crop applied to page {targetPositions[0]:N0}."
            : $"Crop applied to {targetPositions.Length:N0} selected pages: {targetSummary}.";

        var success = await RunPdfOutputOperationAsync(runningText, completedText, output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.CropPagesAsync(working, output, targetPositions, rect, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Crop complete",
                targetPositions.Length == 1
                    ? $"Created a cropped copy of page {targetPositions[0]:N0}. The source PDF was not overwritten."
                    : $"Created a copy with the crop applied to {targetPositions.Length:N0} pages: {targetSummary}. The source PDF was not overwritten.",
                source,
                output,
                () => CropMarkup_Click(this, new RoutedEventArgs()));
    }

    private async Task ApplyPermanentRedactionAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save permanently redacted PDF", SuggestName(source, "redacted"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Applying permanent redaction...", "Permanent redaction applied.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.PermanentRedactAsync(working, output, pageNumber, rect, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Permanent redaction complete",
                $"Created a permanently redacted copy of page {pageNumber:N0}. The source PDF was preserved.",
                source,
                output,
                () => RedactMarkup_Click(this, new RoutedEventArgs()));
    }


    private async Task ApplyVisualSignatureAsync(int pageNumber, NormalizedPdfRect rect, string imagePath)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save visually signed PDF", SuggestName(source, "signed"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Placing visual signature...", "Visual signature placed.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _markup.StampImageAsync(working, output, pageNumber, rect, imagePath, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Visual signature complete",
                $"Created a visually signed copy on page {pageNumber:N0}. The source PDF was not overwritten.",
                source,
                output,
                () => PlaceSignature_Click(this, new RoutedEventArgs()));
    }
'@ 'markup completion workflows'

Write-Host 'Markup and batch completion workflows applied.' -ForegroundColor Green
& cmd /c exit 0
