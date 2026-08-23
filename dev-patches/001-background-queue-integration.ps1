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
    $updated = $text.Replace($oldNormalized, $newNormalized)
    Set-Content -Path $Path -Value $updated -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$oldField = @'
    private readonly TaskCenterService _taskCenterService = new();
    private RecentFilesView? _recentFilesView;
'@
$newField = @'
    private readonly TaskCenterService _taskCenterService = new();
    private BackgroundTaskQueueService? _backgroundTasks;
    private RecentFilesView? _recentFilesView;
'@
Replace-Exact $productShell $oldField $newField 'background task service field'

$oldTaskInit = @'
        _homeContent = EmptyPanel.Child;
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        InitializeDocumentTabs();
'@
$newTaskInit = @'
        _homeContent = EmptyPanel.Child;
        _backgroundTasks = new BackgroundTaskQueueService(_taskCenterService);
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        InitializeDocumentTabs();
'@
Replace-Exact $productShell $oldTaskInit $newTaskInit 'background task service initialization'

$oldLifecycle = @'
        PagesList.SelectionChanged += ProductShell_PagesSelectionChanged;
        PreviewImage.SizeChanged += ProductShell_PreviewSizeChanged;
        Closing += ProductShell_Closing;

        LoadHomeRecents();
'@
$newLifecycle = @'
        PagesList.SelectionChanged += ProductShell_PagesSelectionChanged;
        PreviewImage.SizeChanged += ProductShell_PreviewSizeChanged;
        Closing += ProductShell_Closing;
        Closed += async (_, _) =>
        {
            if (_backgroundTasks is not null)
                await _backgroundTasks.DisposeAsync();
        };

        LoadHomeRecents();
'@
Replace-Exact $productShell $oldLifecycle $newLifecycle 'background task service shutdown'

$taskView = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml'
$oldTaskActions = @'
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Open Result" Click="OpenOutput_Click"
                                            IsEnabled="{Binding CanOpenOutput}" ToolTip="{Binding OutputPath}" Padding="12,6" />
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Cancel" Click="CancelTask_Click"
                                            IsEnabled="{Binding CanCancel}" Padding="12,6" />
'@
$newTaskActions = @'
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Open Result" Click="OpenOutput_Click"
                                            IsEnabled="{Binding CanOpenOutput}" ToolTip="{Binding OutputPath}" Padding="12,6" />
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Retry" Click="RetryTask_Click"
                                            IsEnabled="{Binding CanRetry}" Padding="12,6" />
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Cancel" Click="CancelTask_Click"
                                            IsEnabled="{Binding CanCancel}" Padding="12,6" />
'@
Replace-Exact $taskView $oldTaskActions $newTaskActions 'Task Center Retry action'

$taskViewCode = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml.cs'
$oldCancelHandler = @'
    private void CancelTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            item.RequestCancel();
    }
'@
$newCancelHandler = @'
    private async void RetryTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            await item.RequestRetryAsync();
    }

    private void CancelTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            item.RequestCancel();
    }
'@
Replace-Exact $taskViewCode $oldCancelHandler $newCancelHandler 'Task Center Retry handler'

$windowCode = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$oldCompress = @'
        var output = AskSavePath("Save compressed PDF", SuggestName(source, "compressed"));
        if (output is null) return;

        long before = 0;
'@
$newCompress = @'
        var output = AskSavePath("Save compressed PDF", SuggestName(source, "compressed"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueCompressionBackground(source, profile.Value, output);
            return;
        }

        long before = 0;
'@
Replace-Exact $windowCode $oldCompress $newCompress 'background compression routing'

$oldRepair = @'
        var output = AskSavePath("Save repaired PDF", SuggestName(source, "repaired"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Repairing PDF structure...", "Repaired PDF structure.", output, token =>
'@
$newRepair = @'
        var output = AskSavePath("Save repaired PDF", SuggestName(source, "repaired"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueRepairBackground(source, output);
            return;
        }
        var success = await RunPdfOutputOperationAsync("Repairing PDF structure...", "Repaired PDF structure.", output, token =>
'@
Replace-Exact $windowCode $oldRepair $newRepair 'background repair routing'

$oldLinearize = @'
        var output = AskSavePath("Save web-optimized PDF", SuggestName(source, "web"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Optimizing PDF for web viewing...", "Created web-optimized PDF.", output, token =>
'@
$newLinearize = @'
        var output = AskSavePath("Save web-optimized PDF", SuggestName(source, "web"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueLinearizeBackground(source, output);
            return;
        }
        var success = await RunPdfOutputOperationAsync("Optimizing PDF for web viewing...", "Created web-optimized PDF.", output, token =>
'@
Replace-Exact $windowCode $oldLinearize $newLinearize 'background web optimization routing'

$oldUnlock = @'
        var output = AskSavePath("Save unlocked PDF", SuggestName(dialog.FileName, "unlocked"));
        if (output is null) return;

        var success = await RunPdfOutputOperationAsync("Removing PDF password...", "Created unlocked PDF.", output, token =>
'@
$newUnlock = @'
        var output = AskSavePath("Save unlocked PDF", SuggestName(dialog.FileName, "unlocked"));
        if (output is null) return;
        if (_backgroundTasks is not null)
        {
            QueueUnlockBackground(dialog.FileName, password, output);
            return;
        }

        var success = await RunPdfOutputOperationAsync("Removing PDF password...", "Created unlocked PDF.", output, token =>
'@
Replace-Exact $windowCode $oldUnlock $newUnlock 'background unlock routing'

$smoke = Join-Path $SourceRoot 'tests\PdfRescue.SmokeTests\Program.cs'
$oldRegistrations = @'
await RunAsync("Queue executes one job", TestQueueAsync);
await RunAsync("Qpdf inspector maps warnings", TestInspectorAsync);
'@
$newRegistrations = @'
await RunAsync("Queue executes one job", TestQueueAsync);
await RunAsync("Queue accepts pre-queued job", TestPreQueuedJobAsync);
await RunAsync("Queue serializes multiple jobs", TestQueueSerializesAsync);
await RunAsync("Queued job can be cancelled", TestQueuedCancellationAsync);
await RunAsync("Qpdf inspector maps warnings", TestInspectorAsync);
'@
Replace-Exact $smoke $oldRegistrations $newRegistrations 'background queue smoke registrations'

$oldQueueTestEnd = @'
async Task TestInspectorAsync()
'@
$newQueueTests = @'
async Task TestPreQueuedJobAsync()
{
    await using var queue = new PdfJobQueue();
    var job = new PdfJob(PdfJobType.Compress, "Pre-queued test");
    job.TransitionTo(PdfJobState.Queued, "Queued by UI");
    var result = await queue.RunAsync(job, (_, _) => Task.FromResult(7));
    Assert(result == 7, "Pre-queued job should return its result.");
    Assert(job.State == PdfJobState.Completed, "Pre-queued job should complete normally.");
}

async Task TestQueueSerializesAsync()
{
    await using var queue = new PdfJobQueue();
    var firstJob = new PdfJob(PdfJobType.Compress, "First");
    var secondJob = new PdfJob(PdfJobType.Repair, "Second");
    var firstStarted = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
    var releaseFirst = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
    var order = new List<string>();

    var first = queue.RunAsync(firstJob, async (_, token) =>
    {
        lock (order) order.Add("first-start");
        firstStarted.TrySetResult(true);
        await releaseFirst.Task.WaitAsync(token);
        lock (order) order.Add("first-end");
        return 1;
    });

    await firstStarted.Task;
    var second = queue.RunAsync(secondJob, (_, _) =>
    {
        lock (order) order.Add("second-start");
        return Task.FromResult(2);
    });

    Assert(secondJob.State == PdfJobState.Queued, "Second job should remain queued while the first worker is occupied.");
    releaseFirst.TrySetResult(true);
    await Task.WhenAll(first, second);

    string[] sequence;
    lock (order) sequence = order.ToArray();
    Assert(Array.IndexOf(sequence, "first-end") < Array.IndexOf(sequence, "second-start"),
        "Second job must not start before the first job releases the single worker.");
}

async Task TestQueuedCancellationAsync()
{
    await using var queue = new PdfJobQueue();
    var firstJob = new PdfJob(PdfJobType.Compress, "Blocking first");
    var secondJob = new PdfJob(PdfJobType.Repair, "Cancel queued");
    var firstStarted = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
    var releaseFirst = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

    var first = queue.RunAsync(firstJob, async (_, token) =>
    {
        firstStarted.TrySetResult(true);
        await releaseFirst.Task.WaitAsync(token);
        return 1;
    });
    await firstStarted.Task;

    using var secondCts = new CancellationTokenSource();
    var second = queue.RunAsync(secondJob, (_, _) => Task.FromResult(2), secondCts.Token);
    Assert(secondJob.State == PdfJobState.Queued, "Second job should be queued before cancellation.");
    secondCts.Cancel();

    var cancelled = false;
    try { await second; }
    catch (OperationCanceledException) { cancelled = true; }
    Assert(cancelled, "Cancelling a queued job should surface cancellation.");
    Assert(secondJob.State == PdfJobState.Cancelled, "Cancelling while queued should move the job to Cancelled.");

    releaseFirst.TrySetResult(true);
    await first;
}

async Task TestInspectorAsync()
'@
Replace-Exact $smoke $oldQueueTestEnd $newQueueTests 'background queue smoke implementations'
