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
Replace-Exact $windowPath `
    '        StatusText.Text = status;`n    }`n`n    private async void Doctor_Click' `
    '        StatusText.Text = status;`n        if (_activeTaskCenterItem is not null)`n            _taskCenterService.ReportProgress(_activeTaskCenterItem, completed / (double)Math.Max(1, total), status);`n    }`n`n    private async void Doctor_Click' `
    'determinate Task Center progress'

Replace-Exact $windowPath `
    '        _activeOperationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);`n        StatusText.Text = status;' `
    '        _activeOperationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);`n        _activeTaskCenterItem = _taskCenterService.Start(status, () => _activeOperationCts?.Cancel());`n        StatusText.Text = status;' `
    'Task Center operation start'

Replace-Exact $windowPath `
    '            await operation(_activeOperationCts.Token);`n            return true;' `
    '            await operation(_activeOperationCts.Token);`n            _taskCenterService.Complete(_activeTaskCenterItem);`n            return true;' `
    'Task Center completion'

Replace-Exact $windowPath `
    '        catch (OperationCanceledException)`n        {`n            StatusText.Text = "Operation cancelled.";' `
    '        catch (OperationCanceledException)`n        {`n            _taskCenterService.Cancel(_activeTaskCenterItem);`n            StatusText.Text = "Operation cancelled.";' `
    'Task Center cancellation'

Replace-Exact $windowPath `
    '        catch (Exception ex)`n        {`n            App.Log($"Operation failed [{status}]: {ex}");' `
    '        catch (Exception ex)`n        {`n            _taskCenterService.Fail(_activeTaskCenterItem, ex);`n            App.Log($"Operation failed [{status}]: {ex}");' `
    'Task Center failure capture'

Replace-Exact $windowPath `
    '            _activeOperationCts = null;`n            _busy = false;' `
    '            _activeOperationCts = null;`n            _activeTaskCenterItem = null;`n            _busy = false;' `
    'Task Center active-item cleanup'
