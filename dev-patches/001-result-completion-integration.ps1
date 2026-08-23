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
    Set-Content -Path $Path -Value ($text.Replace($oldNormalized, $newNormalized)) -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$taskXaml = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml'
$oldTaskActions = @'
                                <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Content="Cancel" Click="CancelTask_Click" IsEnabled="{Binding CanCancel}" Margin="18,0,0,0" Padding="12,6" VerticalAlignment="Center" />
'@
$newTaskActions = @'
                                <StackPanel Grid.Column="1" Margin="18,0,0,0" VerticalAlignment="Center">
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Open Result" Click="OpenOutput_Click"
                                            IsEnabled="{Binding CanOpenOutput}" ToolTip="{Binding OutputPath}" Padding="12,6" />
                                    <Button Style="{StaticResource FlatButtonStyle}" Content="Cancel" Click="CancelTask_Click"
                                            IsEnabled="{Binding CanCancel}" Padding="12,6" />
                                </StackPanel>
'@
Replace-Exact $taskXaml $oldTaskActions $newTaskActions 'Task Center output action'

$taskCode = Join-Path $SourceRoot 'src\PdfRescue.App\TaskCenterView.xaml.cs'
$oldEventAnchor = @'
    private readonly DispatcherTimer _elapsedTimer;

    public TaskCenterView(TaskCenterService service)
'@
$newEventAnchor = @'
    private readonly DispatcherTimer _elapsedTimer;

    public event Func<string, Task>? OpenOutputRequested;

    public TaskCenterView(TaskCenterService service)
'@
Replace-Exact $taskCode $oldEventAnchor $newEventAnchor 'Task Center output event'

$oldCancelMethod = @'
    private void CancelTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            item.RequestCancel();
    }
'@
$newCancelMethod = @'
    private async void OpenOutput_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: TaskCenterItem item } ||
            !item.CanOpenOutput || string.IsNullOrWhiteSpace(item.OutputPath))
            return;

        var handler = OpenOutputRequested;
        if (handler is not null) await handler(item.OutputPath);
    }

    private void CancelTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            item.RequestCancel();
    }
'@
Replace-Exact $taskCode $oldCancelMethod $newCancelMethod 'Task Center open-output handler'

$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$oldTaskInit = @'
        _homeContent = EmptyPanel.Child;
        _taskCenterView = new TaskCenterView(_taskCenterService);
        InitializeDocumentTabs();
'@
$newTaskInit = @'
        _homeContent = EmptyPanel.Child;
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        InitializeDocumentTabs();
'@
Replace-Exact $productShell $oldTaskInit $newTaskInit 'Task Center result opening wiring'

$windowPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$oldCompress = @'
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
'@
$newCompress = @'
    private async void Compress_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var profile = PromptCompressionProfile();
        if (profile is null) return;
        var output = AskSavePath("Save compressed PDF", SuggestName(source, "compressed"));
        if (output is null) return;

        long before = 0;
        long after = 0;
        string summary = "Compression completed.";
        var success = await RunPdfOutputOperationAsync("Compressing PDF...", "Compression completed.", output, async token =>
        {
            await RunAgainstWorkingLayoutAsync(async (working, ct) =>
            {
                before = new FileInfo(working).Length;
                await _operations.CompressAsync(working, profile.Value, output, ct);
            }, token);
            after = new FileInfo(output).Length;
            var delta = before - after;
            summary = delta > 0
                ? $"Saved {FormatBytes(delta)} ({(double)delta / Math.Max(1, before):P0}). Original {FormatBytes(before)}, result {FormatBytes(after)}."
                : $"The source was already efficiently encoded. Original {FormatBytes(before)}, result {FormatBytes(after)}.";
        });

        if (success)
            await ShowPdfResultWorkflowAsync("Compression complete", summary, source, output,
                () => Compress_Click(this, new RoutedEventArgs()));
    }
'@
Replace-Exact $windowPath $oldCompress $newCompress 'compression result workflow'

$oldRepair = @'
    private async void Repair_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save repaired PDF", SuggestName(_currentPdf, "repaired"));
        if (output is null) return;
        await RunPdfOperationAsync("Repairing PDF structure...", "Repaired PDF structure.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.RepairAsync(working, output, ct), token));
    }
'@
$newRepair = @'
    private async void Repair_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save repaired PDF", SuggestName(source, "repaired"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Repairing PDF structure...", "Repaired PDF structure.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.RepairAsync(working, output, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Repair complete", "A repaired copy was created. The original PDF was not overwritten.", source, output,
                () => Repair_Click(this, new RoutedEventArgs()));
    }
'@
Replace-Exact $windowPath $oldRepair $newRepair 'repair result workflow'

$oldLinearize = @'
    private async void Linearize_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var output = AskSavePath("Save web-optimized PDF", SuggestName(_currentPdf, "web"));
        if (output is null) return;
        await RunPdfOperationAsync("Optimizing PDF for web viewing...", "Created web-optimized PDF.", token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.LinearizeAsync(working, output, ct), token));
    }
'@
$newLinearize = @'
    private async void Linearize_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        var source = _currentPdf;
        var output = AskSavePath("Save web-optimized PDF", SuggestName(source, "web"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Optimizing PDF for web viewing...", "Created web-optimized PDF.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _operations.LinearizeAsync(working, output, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Web optimization complete", "A fast-web-view copy was created without replacing the original.", source, output,
                () => Linearize_Click(this, new RoutedEventArgs()));
    }
'@
Replace-Exact $windowPath $oldLinearize $newLinearize 'web optimization result workflow'

$oldUnlock = @'
        await RunPdfOperationAsync("Removing PDF password...", "Created unlocked PDF.", token =>
            _operations.DecryptAsync(dialog.FileName, password, output, token));
'@
$newUnlock = @'
        var success = await RunPdfOutputOperationAsync("Removing PDF password...", "Created unlocked PDF.", output, token =>
            _operations.DecryptAsync(dialog.FileName, password, output, token));
        if (success)
            await ShowPdfResultWorkflowAsync("Unlock complete", "An unlocked copy was created. The protected source was left unchanged.", dialog.FileName, output,
                () => Unlock_Click(this, new RoutedEventArgs()));
'@
Replace-Exact $windowPath $oldUnlock $newUnlock 'unlock result workflow'
