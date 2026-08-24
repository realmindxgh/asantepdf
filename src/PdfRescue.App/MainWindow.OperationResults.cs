using System.Diagnostics;
using System.IO;
using System.Windows;
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async Task<bool> RunPdfOutputOperationAsync(
        string status,
        string successStatus,
        string outputPath,
        Func<CancellationToken, Task> operation)
    {
        var success = await RunBusyAsync(status, async token =>
        {
            await operation(token);
            token.ThrowIfCancellationRequested();
            _taskCenterService.SetOutput(_activeTaskCenterItem, outputPath);
        });
        if (success) StatusText.Text = successStatus;
        return success;
    }

    private async Task ShowPdfResultWorkflowAsync(
        string operationTitle,
        string summary,
        string originalPath,
        string resultPath,
        Action? runAgain = null)
    {
        if (!File.Exists(resultPath))
        {
            MessageBox.Show(this, "The operation reported success, but its output file is no longer available.",
                operationTitle, MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var originalTab = FindOpenDocumentTab(originalPath);
        var canReplaceCurrent = originalTab is not null &&
            ReferenceEquals(originalTab, _activeDocumentTab) &&
            !originalTab.IsDirty;

        var dialog = new PdfResultDialog(
            operationTitle,
            summary,
            originalPath,
            resultPath,
            canReplaceCurrent,
            runAgain is not null)
        {
            Owner = this
        };

        if (dialog.ShowDialog() != true) return;

        switch (dialog.SelectedAction)
        {
            case PdfResultAction.OpenNewTab:
                await OpenPdfAsync(resultPath);
                break;

            case PdfResultAction.ReplaceCurrent:
                if (canReplaceCurrent && originalTab is not null)
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
                runAgain?.Invoke();
                break;
        }
    }

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

    private async Task ShowMultiResultWorkflowAsync(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        Action runAgain)
    {
        var available = resultPaths
            .Where(path => !string.IsNullOrWhiteSpace(path) && File.Exists(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (available.Length == 0) return;

        var dialog = new MultiResultDialog(title, summary, sourcePath, available, runAgain is not null)
        {
            Owner = this
        };
        if (dialog.ShowDialog() != true) return;

        switch (dialog.SelectedAction)
        {
            case MultiResultAction.OpenSelected:
                if (dialog.SelectedPath is { } selected) await OpenTaskOutputAsync(selected);
                break;
            case MultiResultAction.SaveSelected:
                if (dialog.SelectedPath is { } saveSelected) SaveResultCopy(saveSelected);
                break;
            case MultiResultAction.OpenFolder:
                OpenContainingFolder(dialog.SelectedPath ?? available[0]);
                break;
            case MultiResultAction.RunAgain:
                await InvokeToolOnUiAsync(runAgain);
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
    {
        if (!File.Exists(path))
        {
            MessageBox.Show(this, "This task output is no longer available at its saved location.",
                "Task Center", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        if (string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
        {
            await OpenPdfAsync(path);
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo(Path.GetFullPath(path))
            {
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            App.Log("Open task output failed: " + ex);
            MessageBox.Show(this,
                $"AsantePDF created the file, but Windows could not open it with its associated application.\n\n{ex.Message}",
                "Open Task Result", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private void OpenContainingFolder(string path)
    {
        try
        {
            if (!File.Exists(path)) return;
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"")
            {
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            App.Log("Open result folder failed: " + ex.Message);
        }
    }

    private void SaveResultCopy(string resultPath)
    {
        if (!File.Exists(resultPath)) return;
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
        if (dialog.ShowDialog(this) != true) return;

        try
        {
            if (string.Equals(Path.GetFullPath(dialog.FileName), Path.GetFullPath(resultPath), StringComparison.OrdinalIgnoreCase))
                return;
            File.Copy(resultPath, dialog.FileName, overwrite: true);
            StatusText.Text = $"Saved result copy as {Path.GetFileName(dialog.FileName)}.";
        }
        catch (Exception ex)
        {
            App.Log("Save result copy failed: " + ex);
            MessageBox.Show(this, ex.Message, "Save Result Copy", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }
}
