param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    Write-Text $Path $text
}
function Replace-Regex([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $regex = [Text.RegularExpressions.Regex]::new($Pattern, [Text.RegularExpressions.RegexOptions]::Multiline -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $matches = $regex.Matches($text)
    if ($matches.Count -ne 1) { throw "Expected one regex target for $Label in $Path, found $($matches.Count)" }
    $text = $regex.Replace($text, (Normalize $Replacement), 1)
    Write-Text $Path $text
}

$taskService = Join-Path $SourceRoot 'src\PdfRescue.App\Services\TaskCenterService.cs'
Replace-Exact $taskService @'
    private bool _retryRequested;
    private string? _outputPath;

    internal TaskCenterItem(PdfJob job, Action? cancelAction, Func<Task>? retryAction = null)
    {
        _job = job;
        _cancelAction = cancelAction;
        _retryAction = retryAction;
    }
'@ @'
    private bool _retryRequested;
    private string? _outputPath;
    private readonly string? _sourcePath;
    private readonly string _sourceLabel;
    private readonly Func<Task>? _runAgainAction;

    internal TaskCenterItem(
        PdfJob job,
        Action? cancelAction,
        Func<Task>? retryAction = null,
        string? sourcePath = null,
        string? sourceLabel = null,
        Func<Task>? runAgainAction = null)
    {
        _job = job;
        _cancelAction = cancelAction;
        _retryAction = retryAction;
        _sourcePath = string.IsNullOrWhiteSpace(sourcePath) ? null : Path.GetFullPath(sourcePath);
        _sourceLabel = !string.IsNullOrWhiteSpace(sourceLabel)
            ? sourceLabel.Trim()
            : _sourcePath is null ? "Source" : Path.GetFileName(_sourcePath);
        _runAgainAction = runAgainAction;
    }
'@ 'TaskCenterItem source and run-again metadata'

Replace-Exact $taskService @'
    public string? OutputPath => _outputPath;
    public string OutputName => string.IsNullOrWhiteSpace(_outputPath) ? string.Empty : Path.GetFileName(_outputPath);
    public bool CanOpenOutput => State == PdfJobState.Completed && !string.IsNullOrWhiteSpace(_outputPath) && File.Exists(_outputPath);
'@ @'
    public string? OutputPath => _outputPath;
    public string OutputName => string.IsNullOrWhiteSpace(_outputPath) ? string.Empty : Path.GetFileName(_outputPath);
    public string? SourcePath => _sourcePath;
    public string SourceLabel => _sourceLabel;
    public bool CanOpenOutput => State == PdfJobState.Completed && !string.IsNullOrWhiteSpace(_outputPath) && File.Exists(_outputPath);
    public bool CanRunAgain => State == PdfJobState.Completed && _runAgainAction is not null;
'@ 'TaskCenterItem result properties'

Replace-Exact $taskService @'
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

    internal void SetOutput(string? path)
'@ @'
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

    public Task RequestRunAgainAsync() =>
        CanRunAgain && _runAgainAction is not null ? _runAgainAction() : Task.CompletedTask;

    internal void SetOutput(string? path)
'@ 'TaskCenterItem run-again request'

Replace-Exact $taskService @'
        OnPropertyChanged(nameof(CanRetry));
        OnPropertyChanged(nameof(ShowProgress));
        OnPropertyChanged(nameof(CanOpenOutput));
'@ @'
        OnPropertyChanged(nameof(CanRetry));
        OnPropertyChanged(nameof(ShowProgress));
        OnPropertyChanged(nameof(CanOpenOutput));
        OnPropertyChanged(nameof(CanRunAgain));
'@ 'TaskCenterItem run-again refresh'

Replace-Exact $taskService @'
    public TaskCenterItem Track(PdfJob job, Action? cancelAction = null, Func<Task>? retryAction = null)
    {
        ArgumentNullException.ThrowIfNull(job);
        TaskCenterItem? created = null;
        RunOnUi(() =>
        {
            created = new TaskCenterItem(job, cancelAction, retryAction);
'@ @'
    public TaskCenterItem Track(
        PdfJob job,
        Action? cancelAction = null,
        Func<Task>? retryAction = null,
        string? sourcePath = null,
        string? sourceLabel = null,
        Func<Task>? runAgainAction = null)
    {
        ArgumentNullException.ThrowIfNull(job);
        TaskCenterItem? created = null;
        RunOnUi(() =>
        {
            created = new TaskCenterItem(job, cancelAction, retryAction, sourcePath, sourceLabel, runAgainAction);
'@ 'TaskCenterService track metadata'

$backgroundQueue = Join-Path $SourceRoot 'src\PdfRescue.App\Services\BackgroundTaskQueueService.cs'
Replace-Exact $backgroundQueue @'
    public TaskCenterItem Enqueue(
        PdfJobType type,
        string title,
        Func<BackgroundTaskContext, CancellationToken, Task<string?>> operation,
        bool retryable = true)
'@ @'
    public TaskCenterItem Enqueue(
        PdfJobType type,
        string title,
        Func<BackgroundTaskContext, CancellationToken, Task<string?>> operation,
        bool retryable = true,
        string? sourcePath = null,
        string? sourceLabel = null,
        Func<Task>? runAgainAction = null)
'@ 'Background queue metadata signature'

Replace-Exact $backgroundQueue @'
        Task RetryAsync()
        {
            if (Volatile.Read(ref _disposed) == 0)
                Enqueue(type, title, operation, retryable: true);
            return Task.CompletedTask;
        }

        var item = _taskCenter.Track(job, cts.Cancel, retryable ? RetryAsync : null);
'@ @'
        Task RetryAsync()
        {
            if (Volatile.Read(ref _disposed) == 0)
                Enqueue(
                    type,
                    title,
                    operation,
                    retryable: true,
                    sourcePath: sourcePath,
                    sourceLabel: sourceLabel,
                    runAgainAction: runAgainAction);
            return Task.CompletedTask;
        }

        var item = _taskCenter.Track(
            job,
            cts.Cancel,
            retryable ? RetryAsync : null,
            sourcePath,
            sourceLabel,
            runAgainAction);
'@ 'Background queue track metadata'

$taskViewXaml = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml'
Replace-Exact $taskViewXaml @'
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Open Result" Click="OpenOutput_Click"
                                            IsEnabled="{Binding CanOpenOutput}" ToolTip="{Binding OutputPath}" Padding="12,6" />
'@ @'
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Result Options" Click="OpenOutput_Click"
                                            IsEnabled="{Binding CanOpenOutput}" ToolTip="Open result actions" Padding="12,6" />
'@ 'Task Center result-options button'

$taskViewCode = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml.cs'
Replace-Exact $taskViewCode @'
    public event Func<string, Task>? OpenOutputRequested;
'@ @'
    public event Func<TaskCenterItem, Task>? ResultOptionsRequested;
'@ 'Task Center result-options event'
Replace-Exact $taskViewCode @'
        var handler = OpenOutputRequested;
        if (handler is not null) await handler(item.OutputPath);
'@ @'
        var handler = ResultOptionsRequested;
        if (handler is not null) await handler(item);
'@ 'Task Center result-options handler'

$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShell @'
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
'@ @'
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.ResultOptionsRequested += ShowTaskResultWorkflowAsync;
'@ 'Product shell Task Center result subscription'

$resultXaml = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml'
Replace-Exact $resultXaml @'
        <TextBlock Grid.Row="2" Text="Choose what to do with the new PDF. The original remains untouched unless you explicitly replace its tab."
'@ @'
        <TextBlock Grid.Row="2" Text="Choose what to do with the result. The source remains untouched unless you explicitly replace its tab."
'@ 'Generic completion guidance'
Replace-Exact $resultXaml @'
            <Button Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
'@ @'
            <Button x:Name="OpenNewTabButton" Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
'@ 'Named result open button'
Replace-Exact $resultXaml @'
            <Button Style="{StaticResource FlatButtonStyle}" Click="SaveCopy_Click" Content="Save a Copy" Padding="13,8" />
'@ @'
            <Button Style="{StaticResource FlatButtonStyle}" Click="SaveCopy_Click" Content="Save As…" Padding="13,8" />
'@ 'Completion Save As label'

$resultCode = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml.cs'
Replace-Exact $resultCode @'
        string summary,
        string originalPath,
        string resultPath,
        bool canReplaceCurrent,
        bool canRunAgain)
'@ @'
        string summary,
        string? originalPath,
        string resultPath,
        bool canReplaceCurrent,
        bool canRunAgain,
        bool resultIsPdf = true,
        string? sourceLabel = null)
'@ 'Generic result dialog constructor signature'
Replace-Exact $resultCode @'
        OriginalNameText.Text = Path.GetFileName(originalPath);
        OriginalPathText.Text = originalPath;
        ResultNameText.Text = Path.GetFileName(resultPath);
'@ @'
        OriginalNameText.Text = !string.IsNullOrWhiteSpace(sourceLabel)
            ? sourceLabel.Trim()
            : string.IsNullOrWhiteSpace(originalPath) ? "Source" : Path.GetFileName(originalPath);
        OriginalPathText.Text = string.IsNullOrWhiteSpace(originalPath) ? "Source details retained by the task." : originalPath;
        ResultNameText.Text = Path.GetFileName(resultPath);
'@ 'Generic source card'
Replace-Exact $resultCode @'
        ReplaceCurrentButton.IsEnabled = canReplaceCurrent;
        ReplaceCurrentButton.ToolTip = canReplaceCurrent
            ? "Open the result and close the original tab"
            : "The original tab has unsaved changes or is not the active source tab";
        RunAgainButton.IsEnabled = canRunAgain;
'@ @'
        ReplaceCurrentButton.Visibility = resultIsPdf ? Visibility.Visible : Visibility.Collapsed;
        ReplaceCurrentButton.IsEnabled = resultIsPdf && canReplaceCurrent;
        ReplaceCurrentButton.ToolTip = canReplaceCurrent
            ? "Open the result and close the original tab"
            : "The original tab has unsaved changes or is not the active source tab";
        OpenNewTabButton.Content = resultIsPdf ? "Open in New Tab" : "Open Result";
        RunAgainButton.IsEnabled = canRunAgain;
'@ 'Generic result actions'

$operationResults = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
Replace-Exact $operationResults @'
using Microsoft.Win32;

namespace PdfRescue.App;
'@ @'
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;
'@ 'Operation results TaskCenterItem import'
Replace-Exact $operationResults @'
    private async Task OpenTaskOutputAsync(string path)
'@ @'
    private async Task ShowTaskResultWorkflowAsync(TaskCenterItem item)
    {
        if (!item.CanOpenOutput || string.IsNullOrWhiteSpace(item.OutputPath)) return;
        var resultPath = item.OutputPath;
        if (!File.Exists(resultPath))
        {
            MessageBox.Show(this, "This task output is no longer available at its saved location.",
                "Task Center", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var isPdf = string.Equals(Path.GetExtension(resultPath), ".pdf", StringComparison.OrdinalIgnoreCase);
        var sourcePath = item.SourcePath;
        var originalTab = isPdf && !string.IsNullOrWhiteSpace(sourcePath)
            ? FindOpenDocumentTab(sourcePath)
            : null;
        var canReplaceCurrent = originalTab is not null &&
            ReferenceEquals(originalTab, _activeDocumentTab) &&
            !originalTab.IsDirty;

        var dialog = new PdfResultDialog(
            $"{item.Title} complete",
            string.IsNullOrWhiteSpace(item.Stage) ? "Your result is ready." : item.Stage,
            sourcePath,
            resultPath,
            canReplaceCurrent,
            item.CanRunAgain,
            isPdf,
            item.SourceLabel)
        {
            Owner = this
        };

        if (dialog.ShowDialog() != true) return;
        switch (dialog.SelectedAction)
        {
            case PdfResultAction.OpenNewTab:
                await OpenTaskOutputAsync(resultPath);
                break;
            case PdfResultAction.ReplaceCurrent:
                if (isPdf && canReplaceCurrent && originalTab is not null)
                {
                    await OpenPdfAsync(resultPath);
                    if (DocumentTabs.Contains(originalTab))
                        await CloseDocumentTabAsync(originalTab);
                }
                break;
            case PdfResultAction.OpenFolder:
                OpenContainingFolder(resultPath);
                break;
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
                await item.RequestRunAgainAsync();
                break;
        }
    }

    private Task InvokeToolOnUiAsync(Action action)
    {
        ArgumentNullException.ThrowIfNull(action);
        if (Dispatcher.CheckAccess())
        {
            action();
            return Task.CompletedTask;
        }
        return Dispatcher.InvokeAsync(action).Task;
    }

    private async Task OpenTaskOutputAsync(string path)
'@ 'Task Center completion workflow'
Replace-Exact $operationResults @'
        var dialog = new SaveFileDialog
        {
            Title = "Save a copy of the result",
            Filter = "PDF files (*.pdf)|*.pdf",
            FileName = Path.GetFileName(resultPath),
            DefaultExt = ".pdf",
            AddExtension = true,
            OverwritePrompt = true
        };
'@ @'
        var extension = Path.GetExtension(resultPath);
        var displayType = string.IsNullOrWhiteSpace(extension)
            ? "Result"
            : extension.TrimStart('.').ToUpperInvariant();
        var dialog = new SaveFileDialog
        {
            Title = "Save result as",
            Filter = string.IsNullOrWhiteSpace(extension)
                ? "All files|*.*"
                : $"{displayType} files (*{extension})|*{extension}|All files|*.*",
            FileName = Path.GetFileName(resultPath),
            DefaultExt = extension,
            AddExtension = !string.IsNullOrWhiteSpace(extension),
            OverwritePrompt = true
        };
'@ 'Generic result Save As'

$backgroundOps = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundOperations.cs'
Replace-Exact $backgroundOps @'
        });

        StatusText.Text = "Compression queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => Compress_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Compression queued in Task Center. You can keep working.";
'@ 'Compression task completion metadata'
Replace-Exact $backgroundOps @'
        });

        StatusText.Text = "Repair queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => Repair_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Repair queued in Task Center. You can keep working.";
'@ 'Repair task completion metadata'
Replace-Exact $backgroundOps @'
        });

        StatusText.Text = "Web optimization queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => Linearize_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Web optimization queued in Task Center. You can keep working.";
'@ 'Optimize task completion metadata'
Replace-Exact $backgroundOps @'
        }, retryable: false);

        StatusText.Text = "Unlock queued in Task Center. You can keep working.";
'@ @'
        }, retryable: false, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => Unlock_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Unlock queued in Task Center. You can keep working.";
'@ 'Unlock task completion metadata'

$backgroundIndependent = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundIndependentOperations.cs'
Replace-Exact $backgroundIndependent @'
        });

        StatusText.Text = $"Merge queued in Task Center ({capturedInputs.Length:N0} PDFs). You can keep working.";
'@ @'
        }, sourceLabel: $"{capturedInputs.Length:N0} source PDFs", runAgainAction: () => InvokeToolOnUiAsync(() => Merge_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = $"Merge queued in Task Center ({capturedInputs.Length:N0} PDFs). You can keep working.";
'@ 'Merge task completion metadata'
Replace-Exact $backgroundIndependent @'
        });

        StatusText.Text = "Office conversion queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: capturedInput, runAgainAction: () => InvokeToolOnUiAsync(() => OfficeToPdf_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Office conversion queued in Task Center. You can keep working.";
'@ 'Office conversion task completion metadata'

$backgroundOcr = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.BackgroundOcrExports.cs'
Replace-Exact $backgroundOcr @'
        });

        StatusText.Text = "Word export queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => PdfToWord_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Word export queued in Task Center. You can keep working.";
'@ 'Word task completion metadata'
Replace-Exact $backgroundOcr @'
        });

        StatusText.Text = "Excel export queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => PdfToExcel_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "Excel export queued in Task Center. You can keep working.";
'@ 'Excel task completion metadata'
Replace-Exact $backgroundOcr @'
        });

        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => PdfToPowerPoint_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
'@ 'PowerPoint task completion metadata'
Replace-Exact $backgroundOcr @'
        });

        StatusText.Text = "OCR queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => OcrPdf_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "OCR queued in Task Center. You can keep working.";
'@ 'OCR PDF task completion metadata'
Replace-Exact $backgroundOcr @'
        });

        StatusText.Text = "OCR text extraction queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => ExtractOcrText_Click(this, new System.Windows.RoutedEventArgs())));

        StatusText.Text = "OCR text extraction queued in Task Center. You can keep working.";
'@ 'OCR text task completion metadata'

$configuredTools = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ConfiguredTools.cs'
Replace-Exact $configuredTools @'
        });
        StatusText.Text = $"{label} export queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: kind == PdfConversionKind.Excel
            ? () => InvokeToolOnUiAsync(() => PdfToExcel_Click(this, new System.Windows.RoutedEventArgs()))
            : () => InvokeToolOnUiAsync(() => PdfToWord_Click(this, new System.Windows.RoutedEventArgs())));
        StatusText.Text = $"{label} export queued in Task Center. You can keep working.";
'@ 'Configured text conversion completion metadata'
Replace-Exact $configuredTools @'
        });
        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
'@ @'
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => PdfToPowerPoint_Click(this, new System.Windows.RoutedEventArgs())));
        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
'@ 'Configured PowerPoint completion metadata'

$matrix = Join-Path $SourceRoot 'IMPLEMENTATION_MATRIX.md'
Replace-Regex $matrix '^\| 17 \|.*$' @'
| 17 | Create an application-wide task/progress framework | IMPLEMENTED, NOT ACCEPTED | Foreground `RunBusyAsync` and background `PdfJobQueue`/`BackgroundTaskQueueService` now form one application-wide task framework with task name, stage, percentage/progress, elapsed time, page/item counts where available, cancellation and non-blocking queued execution. Renderer-dependent jobs use isolated PDFium renderers; dirty/scoped layouts are snapshotted separately; qpdf writes are transactional. Page-image export now stages the complete image set in a hidden same-volume directory and publishes with backup/rollback, so cancellation/failure cannot leave a half-published set. Staged job `97376499301` and clean no-patch rerun `97377277505` both passed exact .NET 10.0.202 Windows x64 Release with 0 warnings, 0 errors and all smoke tests. Clean-proven source: `059327d0c37f8a55625dfe59417d875884d9ea20`. Hands-on progress/cancellation UX acceptance remains. |
'@ 'Matrix item 17'
Replace-Regex $matrix '^\| 18 \|.*$' @'
| 18 | Add a Task Center | IMPLEMENTED, NOT ACCEPTED | Task Center provides Running, Queued, Completed, Failed and Cancelled states, filters, stage/progress/percentage, elapsed time, Cancel, result opening, single-use Retry for retry-safe failures and multiple queued jobs while users keep working in other tabs. The permanent navigation entry now acts as the minimized task indicator: a live badge shows running+queued count (capped at `99+`) and the tooltip reports active counts or failed-task attention. Sensitive password jobs remain non-retryable. Staged job `97400172851` and clean no-patch rerun `97400644796` both passed exact .NET 10.0.202 Windows x64 Release with 0 warnings, 0 errors and all smoke tests. Clean-proven source: `db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`. Hands-on Task Center visual/runtime acceptance remains. |
'@ 'Matrix item 18'
Replace-Regex $matrix '^\| 43 \|.*$' @'
| 43 | Maintain the release-quality engineering standard | IMPLEMENTED, NOT ACCEPTED | RC10 full Windows release gate passed end to end. Redesign iterations are repeatedly Windows compiled/smoke-tested and then clean-rerun from promoted ordinary source. Key later gates include background queue `97232413507`, Merge/Office `97232877751`, isolated OCR/export `97233635107`, search `97236130041`, Bookmarks staged/clean `97254983823`/`97255242296`, interactive text staged/clean `97256072705`/`97256350665`, sidebar collapse staged/clean `97256927225`/`97341768147`, Comments/Attachments `97343869116`, sidebar reset `97344342154`, item-13 clean `97344623846`, item-14 staged/clean `97345750241`/`97346132649`, item-15 warning-hardening/clean `97364231968`/`97364651130`, item-16 foundation `97365833964`/`97366567224`, OCR config `97371701920`/`97372254897`, advanced config `97374175885`/`97374705820`, item-17 staged/clean `97376499301`/`97377277505`, and item-18 staged/clean `97400172851`/`97400644796`. The item-17 hardening removed the former CS4014 compiler warning; current clean source builds with 0 warnings and 0 errors. Full installer/installed-copy gate must be rerun for a release candidate. |
'@ 'Matrix item 43'

$state = Join-Path $SourceRoot 'docs\PROJECT_STATE.md'
Replace-Exact $state 'Updated after master items 15 and 16 reached green staged Windows gates and clean committed-source reruns.' 'Updated after master items 17 and 18 reached green staged Windows gates and clean committed-source reruns.' 'Project state heading'
Replace-Exact $state '`b0dd94da3266b94e63470c2abd697149218de156`' '`db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`' 'Latest clean-proven source'
Replace-Exact $state @'
Task Center supports Running, Queued, Completed, Failed and Cancelled states, progress/stage updates, percentage, elapsed time, Cancel, Open Result, clear-finished history and single-use Retry for retry-safe jobs.
'@ @'
Task Center supports Running, Queued, Completed, Failed and Cancelled states, progress/stage updates, percentage, elapsed time, Cancel, result options, clear-finished history and single-use Retry for retry-safe jobs. The permanent Task Center navigation entry also carries a live running+queued badge and failed-task attention tooltip, so background work remains visible while the user works elsewhere.
'@ 'Task Center state description'
Replace-Exact $state @'
## Result routing
'@ @'
## Master item 17 — application-wide task/progress framework

Status: `IMPLEMENTED, NOT ACCEPTED`.

Foreground and queued work now share the same task model, with task name, stage, percentage/progress, elapsed time, page/item counts where useful and graceful cancellation. Renderer-dependent queued work owns isolated renderers; dirty/scoped layouts use disposable snapshots; transactional writers preserve sources/destinations on failure. Page-image export additionally stages the complete image set and publishes it with backup/rollback so cancellation cannot leave a half-exported set.

Evidence:

- staged `97376499301`
- clean `97377277505`
- clean-proven source `059327d0c37f8a55625dfe59417d875884d9ea20`
- exact .NET 10.0.202 Windows x64 Release
- 0 warnings, 0 errors, all smoke tests passed

Hands-on progress/cancellation UX acceptance remains.

## Master item 18 — Task Center

Status: `IMPLEMENTED, NOT ACCEPTED`.

Task Center exposes Running, Queued, Completed, Failed and Cancelled work with filters, progress, elapsed time, cancellation, retry for retry-safe failures, output opening and multiple queued jobs. Users can continue working in other tabs. A live badge on the permanent Task Center navigation entry now acts as the minimized task indicator and reports active or failed-task attention without forcing a modal progress window.

Evidence:

- staged `97400172851`
- clean `97400644796`
- clean-proven source `db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`
- exact .NET 10.0.202 Windows x64 Release
- 0 warnings, 0 errors, all smoke tests passed

Hands-on visual/runtime acceptance remains.

## Result routing
'@ 'Insert item 17 and 18 project-state sections'
Replace-Exact $state @'
- item 16 final clean: `97374705820`

The one current compiler warning remains the pre-existing unawaited-call warning in `MainWindow.DocumentTabs.cs(142,9)` and was not introduced by items 13–16.
'@ @'
- item 16 final clean: `97374705820`
- item 17 task/progress hardening staged: `97376499301`
- item 17 clean: `97377277505`
- item 18 live Task Center indicator staged: `97400172851`
- item 18 clean: `97400644796`

The former `MainWindow.DocumentTabs.cs` CS4014 warning was explicitly fixed during item 17. Current clean source compiles with 0 warnings and 0 errors.
'@ 'Windows validation item17/18 evidence'
Replace-Regex $state '## Immediate next work\n\n.*?## Item 17 audit starting point\n\n.*?(?=## Product source of truth)' @'
## Immediate next work

1. expand master item 19 so background Task Center results get the same meaningful completion choices as foreground PDF transformations
2. keep side-by-side original/result comparison explicitly pending until master item 6 split view is implemented
3. audit item 20 non-destructive behavior operation by operation
4. continue the context-aware command audit
5. enrich Inspector and PDF Doctor states
6. implement Light / Follow Windows themes and a real Settings experience
7. add first-launch/privacy/recovery polish
8. implement remaining viewing modes and split-view comparison
9. visually inspect the running Windows app against the canonical Home and Document targets

## Item 19 audit starting point

The existing foreground PDF result dialog already makes ORIGINAL versus RESULT explicit and provides Open in New Tab, safe Use Result Here, Open Folder, Save As/Copy, Run Another and Close. The remaining gap is shared completion treatment for background Task Center outputs and multi-output workflows. True side-by-side comparison depends on master item 6 split view and must not be credited before that feature exists.

'@ 'Project state immediate next work'

# Stage documentation explicitly because the development promotion step otherwise limits git add to src/tests.
Push-Location $SourceRoot
try {
    git add -- IMPLEMENTATION_MATRIX.md docs/PROJECT_STATE.md
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage project ledgers.' }
}
finally { Pop-Location }

Write-Host 'Item 19 shared background completion workflow and item 17/18 ledgers applied.' -ForegroundColor Green
