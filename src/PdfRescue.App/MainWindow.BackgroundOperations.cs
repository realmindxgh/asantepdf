using System.IO;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private sealed record BackgroundPdfSnapshot(
        string SourcePath,
        PdfPageTransform[] Layout,
        bool HasLayoutChanges);

    private BackgroundPdfSnapshot CaptureBackgroundPdfSnapshot()
    {
        if (_currentPdf is null || Pages.Count == 0)
            throw new InvalidOperationException("No PDF is open.");

        return new BackgroundPdfSnapshot(
            _currentPdf,
            Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray(),
            HasLayoutChanges());
    }

    private async Task<(string WorkingPath, string? TemporaryPath)> PrepareBackgroundSourceAsync(
        BackgroundPdfSnapshot snapshot,
        BackgroundTaskContext context,
        CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        if (!snapshot.HasLayoutChanges)
            return (snapshot.SourcePath, null);

        var tempDirectory = Path.Combine(Path.GetTempPath(), "AsantePDF", "background-layouts");
        Directory.CreateDirectory(tempDirectory);
        var temporaryPath = Path.Combine(tempDirectory, Guid.NewGuid().ToString("N") + ".pdf");

        context.ReportProgress(0.08, "Preparing the queued page layout...");
        await _operations.ApplyPageLayoutAsync(snapshot.SourcePath, snapshot.Layout, temporaryPath, token);
        token.ThrowIfCancellationRequested();
        context.ReportProgress(0.20, "Page layout snapshot prepared.");
        return (temporaryPath, temporaryPath);
    }

    private static void DeleteBackgroundTemporary(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        try { if (File.Exists(path)) File.Delete(path); }
        catch { }
    }

    private void QueueCompressionBackground(string source, PdfCompressionProfile profile, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Compress, $"Compress {Path.GetFileName(source)}", async (context, token) =>
        {
            string? temporary = null;
            try
            {
                var prepared = await PrepareBackgroundSourceAsync(snapshot, context, token);
                temporary = prepared.TemporaryPath;
                var before = new FileInfo(prepared.WorkingPath).Length;
                context.ReportProgress(0.30, "Compressing PDF...");
                await _operations.CompressAsync(prepared.WorkingPath, profile, output, token);
                token.ThrowIfCancellationRequested();
                var after = new FileInfo(output).Length;
                var delta = before - after;
                var stage = delta > 0
                    ? $"Compression complete. Saved {FormatBytes(delta)}."
                    : "Compression complete. Source was already efficiently encoded.";
                context.ReportProgress(0.96, stage);
                return output;
            }
            finally
            {
                DeleteBackgroundTemporary(temporary);
            }
        });

        StatusText.Text = "Compression queued in Task Center. You can keep working.";
    }

    private void QueueRepairBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Repair, $"Repair {Path.GetFileName(source)}", async (context, token) =>
        {
            string? temporary = null;
            try
            {
                var prepared = await PrepareBackgroundSourceAsync(snapshot, context, token);
                temporary = prepared.TemporaryPath;
                context.ReportProgress(0.30, "Repairing PDF structure...");
                await _operations.RepairAsync(prepared.WorkingPath, output, token);
                token.ThrowIfCancellationRequested();
                context.ReportProgress(0.96, "Repaired copy created.");
                return output;
            }
            finally
            {
                DeleteBackgroundTemporary(temporary);
            }
        });

        StatusText.Text = "Repair queued in Task Center. You can keep working.";
    }

    private void QueueLinearizeBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Repair, $"Optimize {Path.GetFileName(source)} for web", async (context, token) =>
        {
            string? temporary = null;
            try
            {
                var prepared = await PrepareBackgroundSourceAsync(snapshot, context, token);
                temporary = prepared.TemporaryPath;
                context.ReportProgress(0.30, "Optimizing PDF for fast web viewing...");
                await _operations.LinearizeAsync(prepared.WorkingPath, output, token);
                token.ThrowIfCancellationRequested();
                context.ReportProgress(0.96, "Web-optimized copy created.");
                return output;
            }
            finally
            {
                DeleteBackgroundTemporary(temporary);
            }
        });

        StatusText.Text = "Web optimization queued in Task Center. You can keep working.";
    }

    private void QueueUnlockBackground(string source, string password, string output)
    {
        if (_backgroundTasks is null) return;

        _backgroundTasks.Enqueue(PdfJobType.Edit, $"Unlock {Path.GetFileName(source)}", async (context, token) =>
        {
            context.ReportProgress(0.20, "Removing PDF password...");
            await _operations.DecryptAsync(source, password, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.96, "Unlocked copy created.");
            return output;
        }, retryable: false);

        StatusText.Text = "Unlock queued in Task Center. You can keep working.";
    }
}
