param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $text = (Get-Content $Path -Raw).Replace("`r`n", "`n")
    $oldNormalized = $Old.Replace("`r`n", "`n")
    $newNormalized = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldNormalized)) {
        throw "Could not apply $Description. Expected source text was not found in $Path."
    }
    Set-Content -Path $Path -Value $text.Replace($oldNormalized, $newNormalized) -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$window = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'

$oldWord = @'
        var output = AskSaveFile("Export PDF to Word", Path.GetFileNameWithoutExtension(_currentPdf) + ".docx", "Word document (*.docx)|*.docx", ".docx");
        if (output is null) return;
        await RunPdfOperationAsync("Recovering PDF text for Word...", "Word document created.", async token =>
'@
$newWord = @'
        var source = _currentPdf;
        var output = AskSaveFile("Export PDF to Word", Path.GetFileNameWithoutExtension(source) + ".docx", "Word document (*.docx)|*.docx", ".docx");
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueuePdfToWordBackground(source, output);
            return;
        }
        await RunPdfOperationAsync("Recovering PDF text for Word...", "Word document created.", async token =>
'@
Replace-Exact $window $oldWord $newWord 'background PDF-to-Word routing'

$oldExcel = @'
        var output = AskSaveFile("Export PDF to Excel", Path.GetFileNameWithoutExtension(_currentPdf) + ".xlsx", "Excel workbook (*.xlsx)|*.xlsx", ".xlsx");
        if (output is null) return;
        await RunPdfOperationAsync("Recovering PDF text for Excel...", "Excel workbook created.", async token =>
'@
$newExcel = @'
        var source = _currentPdf;
        var output = AskSaveFile("Export PDF to Excel", Path.GetFileNameWithoutExtension(source) + ".xlsx", "Excel workbook (*.xlsx)|*.xlsx", ".xlsx");
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueuePdfToExcelBackground(source, output);
            return;
        }
        await RunPdfOperationAsync("Recovering PDF text for Excel...", "Excel workbook created.", async token =>
'@
Replace-Exact $window $oldExcel $newExcel 'background PDF-to-Excel routing'

$oldPpt = @'
        var output = AskSaveFile("Export PDF to PowerPoint", Path.GetFileNameWithoutExtension(_currentPdf) + ".pptx", "PowerPoint presentation (*.pptx)|*.pptx", ".pptx");
        if (output is null) return;
        await RunPdfOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", async token =>
'@
$newPpt = @'
        var source = _currentPdf;
        var output = AskSaveFile("Export PDF to PowerPoint", Path.GetFileNameWithoutExtension(source) + ".pptx", "PowerPoint presentation (*.pptx)|*.pptx", ".pptx");
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueuePdfToPowerPointBackground(source, output);
            return;
        }
        await RunPdfOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", async token =>
'@
Replace-Exact $window $oldPpt $newPpt 'background PDF-to-PowerPoint routing'

$oldOcrPdf = @'
        var output = AskSavePath("Save searchable OCR PDF", SuggestName(_currentPdf, "searchable"));
        if (output is null) return;

        await RunPdfOperationAsync("Running local OCR...", "Searchable OCR PDF created.", async token =>
'@
$newOcrPdf = @'
        var source = _currentPdf;
        var output = AskSavePath("Save searchable OCR PDF", SuggestName(source, "searchable"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueSearchableOcrPdfBackground(source, output);
            return;
        }

        await RunPdfOperationAsync("Running local OCR...", "Searchable OCR PDF created.", async token =>
'@
Replace-Exact $window $oldOcrPdf $newOcrPdf 'background searchable OCR PDF routing'

$oldOcrText = @'
        var suggested = Path.GetFileNameWithoutExtension(_currentPdf) + "-ocr.txt";
        var dialog = new SaveFileDialog
'@
$newOcrText = @'
        var source = _currentPdf;
        var suggested = Path.GetFileNameWithoutExtension(source) + "-ocr.txt";
        var dialog = new SaveFileDialog
'@
Replace-Exact $window $oldOcrText $newOcrText 'capture OCR text source'

$oldOcrTextRun = @'
        if (dialog.ShowDialog(this) != true) return;

        await RunPdfOperationAsync("Extracting text with local OCR...", "OCR text extracted.", async token =>
'@
$newOcrTextRun = @'
        if (dialog.ShowDialog(this) != true) return;
        if (_backgroundTasks is not null)
        {
            QueueOcrTextBackground(source, dialog.FileName);
            return;
        }

        await RunPdfOperationAsync("Extracting text with local OCR...", "OCR text extracted.", async token =>
'@
Replace-Exact $window $oldOcrTextRun $newOcrTextRun 'background OCR text routing'
