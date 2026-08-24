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

$markupPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\PdfMarkupService.cs'
Replace-Exact $markupPath @'
    public Task CropPageAsync(string inputPath, string outputPath, int pageNumber, NormalizedPdfRect area, CancellationToken token = default) =>
        Task.Run(() =>
        {
            var input = Path.GetFullPath(inputPath);
            var output = Path.GetFullPath(outputPath);
            ValidatePaths(input, output);
            var rect = area.Clamp();
            if (rect.Width < 0.02 || rect.Height < 0.02) throw new ArgumentException("The crop area is too small.", nameof(area));
            var tempDir = Path.Combine(Path.GetTempPath(), "AsantePDF", "crop", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);
            var raw = Path.Combine(tempDir, "cropped-raw.pdf");
            var normalized = Path.Combine(tempDir, "cropped-normalized.pdf");
            try
            {
                using (var document = PdfReader.Open(input, PdfDocumentOpenMode.Modify))
                {
                    if (pageNumber < 1 || pageNumber > document.Pages.Count) throw new ArgumentOutOfRangeException(nameof(pageNumber));
                    token.ThrowIfCancellationRequested();
                    var page = document.Pages[pageNumber - 1];
                    page.CropBox = new PdfRectangle(
                        new XPoint(
                            rect.X * page.Width.Point,
                            (1d - rect.Y - rect.Height) * page.Height.Point),
                        new XPoint(
                            (rect.X + rect.Width) * page.Width.Point,
                            (1d - rect.Y) * page.Height.Point));
                    document.Save(raw);
                }
                token.ThrowIfCancellationRequested();
                var sourceForCommit = NormalizeWithQpdf(raw, normalized, token) ? normalized : raw;
                CommitTransactional(sourceForCommit, output);
            }
            finally { try { Directory.Delete(tempDir, true); } catch { } }
        }, token);
'@ @'
    public Task CropPageAsync(string inputPath, string outputPath, int pageNumber, NormalizedPdfRect area, CancellationToken token = default) =>
        CropPagesAsync(inputPath, outputPath, [pageNumber], area, token);

    public Task CropPagesAsync(string inputPath, string outputPath, IReadOnlyCollection<int> pageNumbers, NormalizedPdfRect area, CancellationToken token = default) =>
        Task.Run(() =>
        {
            var input = Path.GetFullPath(inputPath);
            var output = Path.GetFullPath(outputPath);
            ValidatePaths(input, output);
            var rect = area.Clamp();
            if (rect.Width < 0.02 || rect.Height < 0.02) throw new ArgumentException("The crop area is too small.", nameof(area));

            var targets = pageNumbers
                .Distinct()
                .OrderBy(pageNumber => pageNumber)
                .ToArray();
            if (targets.Length == 0)
                throw new ArgumentException("At least one page must be selected for cropping.", nameof(pageNumbers));

            var tempDir = Path.Combine(Path.GetTempPath(), "AsantePDF", "crop", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);
            var raw = Path.Combine(tempDir, "cropped-raw.pdf");
            var normalized = Path.Combine(tempDir, "cropped-normalized.pdf");
            try
            {
                using (var document = PdfReader.Open(input, PdfDocumentOpenMode.Modify))
                {
                    foreach (var pageNumber in targets)
                    {
                        token.ThrowIfCancellationRequested();
                        if (pageNumber < 1 || pageNumber > document.Pages.Count)
                            throw new ArgumentOutOfRangeException(nameof(pageNumbers), $"Page {pageNumber:N0} is outside this PDF.");

                        var page = document.Pages[pageNumber - 1];
                        page.CropBox = new PdfRectangle(
                            new XPoint(
                                rect.X * page.Width.Point,
                                (1d - rect.Y - rect.Height) * page.Height.Point),
                            new XPoint(
                                (rect.X + rect.Width) * page.Width.Point,
                                (1d - rect.Y) * page.Height.Point));
                    }
                    document.Save(raw);
                }
                token.ThrowIfCancellationRequested();
                var sourceForCommit = NormalizeWithQpdf(raw, normalized, token) ? normalized : raw;
                CommitTransactional(sourceForCommit, output);
            }
            finally { try { Directory.Delete(tempDir, true); } catch { } }
        }, token);
'@ 'extend crop service to selected page sets'

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $mainPath @'
    private async void PagesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateCommandStates();
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
    }
'@ @'
    private async void PagesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateCommandStates();
        var selectedPages = SelectedPages();
        if (selectedPages.Count > 1)
            StatusText.Text = $"Selected {selectedPages.Count:N0} pages: {FormatPagePositionSummary(selectedPages)}.";
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
    }
'@ 'show selected-page operation scope'

Replace-Exact $mainPath @'
    private void CropMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Crop, "Crop mode: drag the area to keep on the current page.");
    }
'@ @'
    private void CropMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var selectedPages = SelectedPages();
        if (selectedPages.Count > 1)
        {
            BeginMarkupMode(
                MarkupMode.Crop,
                $"Crop mode: drag the area to keep. The same crop will apply to {selectedPages.Count:N0} selected pages: {FormatPagePositionSummary(selectedPages)}.");
            return;
        }

        BeginMarkupMode(MarkupMode.Crop, "Crop mode: drag the area to keep on the current page.");
    }
'@ 'explain multi-page crop scope before drawing'

Replace-Exact $mainPath @'
    private async Task ApplyCropMarkupAsync(int pageNumber, NormalizedPdfRect rect)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save cropped PDF", SuggestName(_currentPdf, "cropped"));
        if (output is null) return;
        await RunPdfOperationAsync("Cropping page...", "Page crop applied.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.CropPageAsync(working, output, pageNumber, rect, ct), token));
    }
'@ @'
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
'@ 'apply one crop box to selected working-layout pages'

Replace-Exact $mainPath @'
    private List<PdfPageItem> SelectedPages() =>
        PagesList.SelectedItems.Cast<PdfPageItem>().OrderBy(p => p.Position).ToList();

    private void AfterLayoutChange(IReadOnlyCollection<PdfPageItem> selection, string status)
'@ @'
    private List<PdfPageItem> SelectedPages() =>
        PagesList.SelectedItems.Cast<PdfPageItem>().OrderBy(p => p.Position).ToList();

    private static string FormatPagePositionSummary(IReadOnlyCollection<PdfPageItem> pages) =>
        FormatPagePositionSummary(pages.Select(page => page.Position));

    private static string FormatPagePositionSummary(IEnumerable<int> positions)
    {
        var ordered = positions.Distinct().OrderBy(position => position).ToArray();
        if (ordered.Length == 0) return "none";

        var ranges = new List<string>();
        var start = ordered[0];
        var end = start;
        for (var i = 1; i < ordered.Length; i++)
        {
            if (ordered[i] == end + 1)
            {
                end = ordered[i];
                continue;
            }

            ranges.Add(start == end ? $"{start:N0}" : $"{start:N0}–{end:N0}");
            start = end = ordered[i];
        }
        ranges.Add(start == end ? $"{start:N0}" : $"{start:N0}–{end:N0}");

        if (ranges.Count <= 6) return string.Join(", ", ranges);
        return string.Join(", ", ranges.Take(5)) + $", … (+{ranges.Count - 5:N0} ranges)";
    }

    private void AfterLayoutChange(IReadOnlyCollection<PdfPageItem> selection, string status)
'@ 'format selected page ranges for operation scope feedback'

Write-Host 'Multi-page crop and selection-scope patch applied.' -ForegroundColor Green
