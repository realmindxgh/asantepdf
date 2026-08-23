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

$taskService = Join-Path $SourceRoot 'src\PdfRescue.App\Services\TaskCenterService.cs'
$oldRetryFields = @'
    private readonly Action? _cancelAction;
    private readonly Func<Task>? _retryAction;
    private string? _outputPath;
'@
$newRetryFields = @'
    private readonly Action? _cancelAction;
    private readonly Func<Task>? _retryAction;
    private bool _retryRequested;
    private string? _outputPath;
'@
Replace-Exact $taskService $oldRetryFields $newRetryFields 'single-use retry state'

Replace-Exact $taskService `
    '    public bool CanRetry => _retryAction is not null && State is PdfJobState.Failed or PdfJobState.Cancelled;' `
    '    public bool CanRetry => !_retryRequested && _retryAction is not null && State is PdfJobState.Failed or PdfJobState.Cancelled;' `
    'single-use retry availability'

$oldRetryMethod = @'
    public async Task RequestRetryAsync()
    {
        if (!CanRetry || _retryAction is null) return;
        await _retryAction();
    }
'@
$newRetryMethod = @'
    public async Task RequestRetryAsync()
    {
        if (!CanRetry || _retryAction is null) return;
        _retryRequested = true;
        OnPropertyChanged(nameof(CanRetry));
        try
        {
            await _retryAction();
        }
        catch
        {
            _retryRequested = false;
            OnPropertyChanged(nameof(CanRetry));
            throw;
        }
    }
'@
Replace-Exact $taskService $oldRetryMethod $newRetryMethod 'single-use retry execution'

$windowCode = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$oldMerge = @'
        var output = AskSavePath("Save merged PDF", "merged.pdf");
        if (output is null) return;
        await RunPdfOperationAsync("Merging PDFs...", $"Merged {inputs.Length:N0} PDFs.", token => _operations.MergeAsync(inputs, output, token));
'@
$newMerge = @'
        var output = AskSavePath("Save merged PDF", "merged.pdf");
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueMergeBackground(inputs, output);
            return;
        }
        await RunPdfOperationAsync("Merging PDFs...", $"Merged {inputs.Length:N0} PDFs.", token => _operations.MergeAsync(inputs, output, token));
'@
Replace-Exact $windowCode $oldMerge $newMerge 'background merge routing'

$oldOffice = @'
        var output = AskSaveFile("Save converted PDF", Path.GetFileNameWithoutExtension(dialog.FileName) + ".pdf", "PDF files (*.pdf)|*.pdf", ".pdf");
        if (output is null) return;
        await RunPdfOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", token =>
            _office.ConvertOfficeToPdfAsync(dialog.FileName, output, token));
'@
$newOffice = @'
        var output = AskSaveFile("Save converted PDF", Path.GetFileNameWithoutExtension(dialog.FileName) + ".pdf", "PDF files (*.pdf)|*.pdf", ".pdf");
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueOfficeToPdfBackground(dialog.FileName, output);
            return;
        }
        await RunPdfOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", token =>
            _office.ConvertOfficeToPdfAsync(dialog.FileName, output, token));
'@
Replace-Exact $windowCode $oldOffice $newOffice 'background Office-to-PDF routing'
