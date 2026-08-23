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

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$oldTaskButton = '<Button Style="{StaticResource NavButtonStyle}" IsEnabled="False" ToolTip="Task Center foundation is part of the master-upgrade branch">'
$newTaskButton = '<Button Style="{StaticResource NavButtonStyle}" Click="TaskCenterNav_Click" ToolTip="View running and completed PDF tasks">'
Replace-Exact $xamlPath $oldTaskButton $newTaskButton 'Task Center navigation command'

$windowPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'

$oldProgress = @'
        StatusText.Text = status;
    }

    private async void Doctor_Click
'@
$newProgress = @'
        StatusText.Text = status;
        if (_activeTaskCenterItem is not null)
            _taskCenterService.ReportProgress(_activeTaskCenterItem, completed / (double)Math.Max(1, total), status);
    }

    private async void Doctor_Click
'@
Replace-Exact $windowPath $oldProgress $newProgress 'determinate Task Center progress'

$oldStart = @'
        _activeOperationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        StatusText.Text = status;
'@
$newStart = @'
        _activeOperationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        _activeTaskCenterItem = _taskCenterService.Start(status, () => _activeOperationCts?.Cancel());
        StatusText.Text = status;
'@
Replace-Exact $windowPath $oldStart $newStart 'Task Center operation start'

$oldComplete = @'
            await operation(_activeOperationCts.Token);
            return true;
'@
$newComplete = @'
            await operation(_activeOperationCts.Token);
            _taskCenterService.Complete(_activeTaskCenterItem);
            return true;
'@
Replace-Exact $windowPath $oldComplete $newComplete 'Task Center completion'

$oldCancel = @'
        catch (OperationCanceledException)
        {
            StatusText.Text = "Operation cancelled.";
'@
$newCancel = @'
        catch (OperationCanceledException)
        {
            _taskCenterService.Cancel(_activeTaskCenterItem);
            StatusText.Text = "Operation cancelled.";
'@
Replace-Exact $windowPath $oldCancel $newCancel 'Task Center cancellation'

$oldFailure = @'
        catch (Exception ex)
        {
            App.Log($"Operation failed [{status}]: {ex}");
'@
$newFailure = @'
        catch (Exception ex)
        {
            _taskCenterService.Fail(_activeTaskCenterItem, ex);
            App.Log($"Operation failed [{status}]: {ex}");
'@
Replace-Exact $windowPath $oldFailure $newFailure 'Task Center failure capture'

$oldCleanup = @'
            _activeOperationCts = null;
            _busy = false;
'@
$newCleanup = @'
            _activeOperationCts = null;
            _activeTaskCenterItem = null;
            _busy = false;
'@
Replace-Exact $windowPath $oldCleanup $newCleanup 'Task Center active-item cleanup'
