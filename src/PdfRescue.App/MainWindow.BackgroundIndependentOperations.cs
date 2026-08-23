using System.IO;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private void QueueMergeBackground(IReadOnlyList<string> inputs, string output)
    {
        if (_backgroundTasks is null) return;
        var capturedInputs = inputs.Select(Path.GetFullPath).ToArray();

        _backgroundTasks.Enqueue(PdfJobType.Merge, $"Merge {capturedInputs.Length:N0} PDFs", async (context, token) =>
        {
            context.ReportProgress(0.10, $"Preparing {capturedInputs.Length:N0} input PDFs...");
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.25, "Merging PDFs...");
            await _operations.MergeAsync(capturedInputs, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.96, $"Merged {capturedInputs.Length:N0} PDFs.");
            return output;
        });

        StatusText.Text = $"Merge queued in Task Center ({capturedInputs.Length:N0} PDFs). You can keep working.";
    }

    private void QueueOfficeToPdfBackground(string input, string output)
    {
        if (_backgroundTasks is null) return;
        var capturedInput = Path.GetFullPath(input);

        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Convert {Path.GetFileName(capturedInput)} to PDF", async (context, token) =>
        {
            context.ReportProgress(0.12, "Preparing Office conversion...");
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.25, "Converting Office document to PDF...");
            await _office.ConvertOfficeToPdfAsync(capturedInput, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.96, "PDF conversion complete.");
            return output;
        });

        StatusText.Text = "Office conversion queued in Task Center. You can keep working.";
    }
}
