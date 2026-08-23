using System.IO;
using System.Text;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async Task<T> WithBackgroundRendererAsync<T>(
        BackgroundPdfSnapshot snapshot,
        BackgroundTaskContext context,
        CancellationToken token,
        Func<IPdfRenderer, int, CancellationToken, Task<T>> work)
    {
        string? temporary = null;
        try
        {
            var prepared = await PrepareBackgroundSourceAsync(snapshot, context, token);
            temporary = prepared.TemporaryPath;

            context.ReportProgress(0.10, "Opening isolated PDF renderer...");
            using var renderer = PdfRendererFactory.CreateProduction();
            await renderer.OpenAsync(prepared.WorkingPath, token);
            token.ThrowIfCancellationRequested();
            var pageCount = checked((int)renderer.PageCount);
            if (pageCount < 1) throw new InvalidDataException("The queued PDF contains no readable pages.");
            return await work(renderer, pageCount, token);
        }
        finally
        {
            DeleteBackgroundTemporary(temporary);
        }
    }

    private Task<OcrPageResult> RecognizeBackgroundPageAsync(
        System.Windows.Media.Imaging.BitmapSource bitmap,
        CancellationToken token) =>
        _ocr.IsBundledTesseractAvailable
            ? _ocr.RecognizeWithBundledTesseractAsync(bitmap, token)
            : _ocr.RecognizeAsync(bitmap, token);

    private void QueuePdfToWordBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Export {Path.GetFileName(source)} to Word", async (context, token) =>
        {
            var texts = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<string>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    var progress = 0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.70;
                    context.ReportProgress(progress, $"Recognising page {page:N0} of {pageCount:N0} for Word...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    var result = await RecognizeBackgroundPageAsync(bitmap, ct);
                    pages.Add(result.Text);
                }
                return (IReadOnlyList<string>)pages;
            });

            context.ReportProgress(0.88, "Writing Word document...");
            await _office.ExportWordAsync(texts, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.98, "Word document created.");
            return output;
        });

        StatusText.Text = "Word export queued in Task Center. You can keep working.";
    }

    private void QueuePdfToExcelBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Export {Path.GetFileName(source)} to Excel", async (context, token) =>
        {
            var texts = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<string>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    var progress = 0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.70;
                    context.ReportProgress(progress, $"Recognising page {page:N0} of {pageCount:N0} for Excel...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    var result = await RecognizeBackgroundPageAsync(bitmap, ct);
                    pages.Add(result.Text);
                }
                return (IReadOnlyList<string>)pages;
            });

            context.ReportProgress(0.88, "Writing Excel workbook...");
            await _office.ExportExcelAsync(texts, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.98, "Excel workbook created.");
            return output;
        });

        StatusText.Text = "Excel export queued in Task Center. You can keep working.";
    }

    private void QueuePdfToPowerPointBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Export {Path.GetFileName(source)} to PowerPoint", async (context, token) =>
        {
            var slides = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<PowerPointPage>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    var progress = 0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.72;
                    context.ReportProgress(progress, $"Rendering slide {page:N0} of {pageCount:N0}...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    pages.Add(new PowerPointPage(
                        OfficeConversionService.EncodePng(bitmap),
                        bitmap.PixelWidth,
                        bitmap.PixelHeight));
                }
                return (IReadOnlyList<PowerPointPage>)pages;
            });

            context.ReportProgress(0.90, "Writing PowerPoint presentation...");
            await _office.ExportPowerPointAsync(slides, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.98, "PowerPoint presentation created.");
            return output;
        });

        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
    }

    private void QueueSearchableOcrPdfBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Ocr, $"OCR {Path.GetFileName(source)}", async (context, token) =>
        {
            var rasterPages = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<PdfRasterPage>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    var progress = 0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.72;
                    context.ReportProgress(progress, $"Recognising page {page:N0} of {pageCount:N0}...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    var recognized = await RecognizeBackgroundPageAsync(bitmap, ct);
                    pages.Add(ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, recognized.Words));
                }
                return (IReadOnlyList<PdfRasterPage>)pages;
            });

            context.ReportProgress(0.90, "Writing searchable PDF...");
            await ImagePdfBuilder.WriteAsync(rasterPages, output, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.98, "Searchable OCR PDF created.");
            return output;
        });

        StatusText.Text = "OCR queued in Task Center. You can keep working.";
    }

    private void QueueOcrTextBackground(string source, string output)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot();

        _backgroundTasks.Enqueue(PdfJobType.Ocr, $"Extract OCR text from {Path.GetFileName(source)}", async (context, token) =>
        {
            var text = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var builder = new StringBuilder();
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    var progress = 0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.72;
                    context.ReportProgress(progress, $"Recognising page {page:N0} of {pageCount:N0}...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    var recognized = await RecognizeBackgroundPageAsync(bitmap, ct);
                    if (page > 1) builder.AppendLine().AppendLine($"--- Page {page} ---").AppendLine();
                    builder.Append(recognized.Text);
                }
                return builder.ToString();
            });

            context.ReportProgress(0.92, "Writing OCR text file...");
            await File.WriteAllTextAsync(output, text, token);
            token.ThrowIfCancellationRequested();
            context.ReportProgress(0.98, "OCR text file created.");
            return output;
        });

        StatusText.Text = "OCR text extraction queued in Task Center. You can keep working.";
    }
}
