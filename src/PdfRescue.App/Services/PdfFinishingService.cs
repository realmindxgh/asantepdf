using System.IO;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;

namespace PdfRescue.App.Services;

public sealed record PdfMetadataValues(string Title, string Author, string Subject, string Keywords);

public sealed class PdfFinishingService
{
    public Task AddWatermarkAsync(string inputPath, string outputPath, string text, CancellationToken token = default) =>
        ModifyAsync(inputPath, outputPath, document =>
        {
            if (string.IsNullOrWhiteSpace(text)) throw new ArgumentException("Watermark text cannot be empty.", nameof(text));
            var font = new XFont("Segoe UI", 40, XFontStyleEx.Bold);
            var brush = new XSolidBrush(XColor.FromArgb(58, 80, 80, 80));
            foreach (var page in document.Pages)
            {
                token.ThrowIfCancellationRequested();
                using var gfx = XGraphics.FromPdfPage(page, XGraphicsPdfPageOptions.Append);
                var state = gfx.Save();
                gfx.TranslateTransform(page.Width.Point / 2d, page.Height.Point / 2d);
                gfx.RotateTransform(-35);
                gfx.DrawString(text.Trim(), font, brush,
                    new XRect(-page.Width.Point / 2d, -45, page.Width.Point, 90),
                    XStringFormats.Center);
                gfx.Restore(state);
            }
        }, token);

    public Task AddPageNumbersAsync(string inputPath, string outputPath, string prefix, int startNumber, CancellationToken token = default) =>
        ModifyAsync(inputPath, outputPath, document =>
        {
            if (startNumber < 1) throw new ArgumentOutOfRangeException(nameof(startNumber));
            var font = new XFont("Segoe UI", 10, XFontStyleEx.Regular);
            for (var i = 0; i < document.Pages.Count; i++)
            {
                token.ThrowIfCancellationRequested();
                var page = document.Pages[i];
                using var gfx = XGraphics.FromPdfPage(page, XGraphicsPdfPageOptions.Append);
                gfx.DrawString($"{prefix}{startNumber + i}", font, XBrushes.DimGray,
                    new XRect(24, page.Height.Point - 31, page.Width.Point - 48, 18),
                    XStringFormats.Center);
            }
        }, token);

    public Task AddHeaderFooterAsync(string inputPath, string outputPath, string header, string footer, CancellationToken token = default) =>
        ModifyAsync(inputPath, outputPath, document =>
        {
            var font = new XFont("Segoe UI", 9, XFontStyleEx.Regular);
            foreach (var page in document.Pages)
            {
                token.ThrowIfCancellationRequested();
                using var gfx = XGraphics.FromPdfPage(page, XGraphicsPdfPageOptions.Append);
                if (!string.IsNullOrWhiteSpace(header))
                    gfx.DrawString(header.Trim(), font, XBrushes.DimGray,
                        new XRect(28, 16, page.Width.Point - 56, 18), XStringFormats.Center);
                if (!string.IsNullOrWhiteSpace(footer))
                    gfx.DrawString(footer.Trim(), font, XBrushes.DimGray,
                        new XRect(28, page.Height.Point - 31, page.Width.Point - 56, 18), XStringFormats.Center);
            }
        }, token);

    public Task UpdateMetadataAsync(string inputPath, string outputPath, PdfMetadataValues metadata, CancellationToken token = default) =>
        ModifyAsync(inputPath, outputPath, document =>
        {
            document.Info.Title = metadata.Title?.Trim() ?? string.Empty;
            document.Info.Author = metadata.Author?.Trim() ?? string.Empty;
            document.Info.Subject = metadata.Subject?.Trim() ?? string.Empty;
            document.Info.Keywords = metadata.Keywords?.Trim() ?? string.Empty;
        }, token);

    public Task StampImageAsync(string inputPath, string outputPath, string imagePath, int pageNumber, CancellationToken token = default) =>
        ModifyAsync(inputPath, outputPath, document =>
        {
            if (!File.Exists(imagePath)) throw new FileNotFoundException("Stamp image was not found.", imagePath);
            if (pageNumber < 1 || pageNumber > document.Pages.Count) throw new ArgumentOutOfRangeException(nameof(pageNumber));
            token.ThrowIfCancellationRequested();
            var page = document.Pages[pageNumber - 1];
            using var image = XImage.FromFile(imagePath);
            using var gfx = XGraphics.FromPdfPage(page, XGraphicsPdfPageOptions.Append);

            const double maxWidth = 180;
            const double maxHeight = 90;
            var scale = Math.Min(maxWidth / image.PixelWidth, maxHeight / image.PixelHeight);
            scale = Math.Min(scale, 1d);
            var width = Math.Max(1d, image.PixelWidth * scale);
            var height = Math.Max(1d, image.PixelHeight * scale);
            var x = Math.Max(24d, page.Width.Point - width - 36d);
            var y = Math.Max(24d, page.Height.Point - height - 42d);
            gfx.DrawImage(image, x, y, width, height);
        }, token);

    private static Task ModifyAsync(
        string inputPath,
        string outputPath,
        Action<PdfDocument> edit,
        CancellationToken token)
    {
        return Task.Run(() =>
        {
            var input = Path.GetFullPath(inputPath);
            var output = Path.GetFullPath(outputPath);
            ValidatePaths(input, output);
            token.ThrowIfCancellationRequested();

            var staged = output + "." + Guid.NewGuid().ToString("N") + ".staged.pdf";
            try
            {
                using var document = PdfReader.Open(input, PdfDocumentOpenMode.Modify);
                edit(document);
                token.ThrowIfCancellationRequested();
                document.Save(staged);
                token.ThrowIfCancellationRequested();
                Commit(staged, output);
            }
            finally
            {
                TryDelete(staged);
            }
        }, token);
    }

    private static void ValidatePaths(string input, string output)
    {
        if (!File.Exists(input)) throw new FileNotFoundException("PDF was not found.", input);
        if (string.Equals(input, output, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Choose a different output file. AsantePDF never overwrites the source PDF.");
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
    }

    private static void Commit(string staged, string output)
    {
        if (File.Exists(output))
        {
            var replacement = output + "." + Guid.NewGuid().ToString("N") + ".replace";
            File.Copy(staged, replacement, true);
            try { File.Replace(replacement, output, null, true); }
            finally { TryDelete(replacement); }
        }
        else
        {
            File.Move(staged, output);
        }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { }
    }
}
