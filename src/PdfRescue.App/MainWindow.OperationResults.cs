using System.Diagnostics;
using System.IO;
using System.Windows;
using Microsoft.Win32;

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

    private async Task OpenTaskOutputAsync(string path)
    {
        if (!File.Exists(path))
        {
            MessageBox.Show(this, "This task output is no longer available at its saved location.",
                "Task Center", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        await OpenPdfAsync(path);
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
        var dialog = new SaveFileDialog
        {
            Title = "Save a copy of the result",
            Filter = "PDF files (*.pdf)|*.pdf",
            FileName = Path.GetFileName(resultPath),
            DefaultExt = ".pdf",
            AddExtension = true,
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
