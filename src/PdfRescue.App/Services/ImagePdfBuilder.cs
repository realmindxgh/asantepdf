using System.IO;
using System.Windows.Media.Imaging;
using PdfSharp.Drawing;
using PdfSharp.Pdf;

namespace PdfRescue.App.Services;

/// <summary>
/// Pixel-space OCR placement produced by the local OCR engines.
/// Coordinates are measured against the raster bitmap supplied to OCR.
/// </summary>
public sealed record OcrWordPlacement(
    string Text,
    double X,
    double Y,
    double Width,
    double Height);

/// <summary>
/// One raster page ready to be written to a PDF. The JPEG bytes and source
/// pixel dimensions are kept together so an OCR text layer can be mapped
/// back onto the page without guessing at DPI.
/// </summary>
public sealed record PdfRasterPage(
    byte[] JpegBytes,
    int PixelWidth,
    int PixelHeight,
    IReadOnlyList<OcrWordPlacement> Words);

/// <summary>
/// Builds ordinary image PDFs and searchable raster PDFs locally with
/// PDFsharp. Output is staged and only committed after a complete PDF has
/// been written successfully.
/// </summary>
public static class ImagePdfBuilder
{
    private const double LongSidePoints = 842d;

    public static Task CreateFromImageFilesAsync(
        IReadOnlyList<string> imagePaths,
        string outputPath,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(imagePaths);
        if (imagePaths.Count == 0)
            throw new ArgumentException("Choose at least one image.", nameof(imagePaths));

        return Task.Run(
            () => WriteImageFilesCore(imagePaths, outputPath, cancellationToken),
            cancellationToken);
    }

    public static PdfRasterPage BitmapToJpegPage(
        BitmapSource bitmap,
        int quality,
        IReadOnlyList<OcrWordPlacement>? words = null)
    {
        ArgumentNullException.ThrowIfNull(bitmap);
        if (bitmap.PixelWidth < 1 || bitmap.PixelHeight < 1)
            throw new ArgumentException("Bitmap has invalid dimensions.", nameof(bitmap));

        var encoder = new JpegBitmapEncoder
        {
            QualityLevel = Math.Clamp(quality, 1, 100)
        };
        encoder.Frames.Add(BitmapFrame.Create(bitmap));

        using var memory = new MemoryStream();
        encoder.Save(memory);
        return new PdfRasterPage(
            memory.ToArray(),
            bitmap.PixelWidth,
            bitmap.PixelHeight,
            words?.ToArray() ?? Array.Empty<OcrWordPlacement>());
    }

    public static Task WriteAsync(
        IReadOnlyList<PdfRasterPage> pages,
        string outputPath,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(pages);
        return Task.Run(
            () => WriteCore(pages, outputPath, cancellationToken),
            cancellationToken);
    }

    private static void WriteImageFilesCore(
        IReadOnlyList<string> imagePaths,
        string outputPath,
        CancellationToken token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(outputPath);
        var output = Path.GetFullPath(outputPath);
        if (!string.Equals(Path.GetExtension(output), ".pdf", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Image PDF output must use a .pdf filename.", nameof(outputPath));

        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        var tempDir = Path.Combine(
            Path.GetTempPath(), "AsantePDF", "image-pdf", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDir);
        var staged = Path.Combine(tempDir, "staged.pdf");

        try
        {
            using (var document = new PdfDocument())
            {
                foreach (var imagePath in imagePaths)
                {
                    token.ThrowIfCancellationRequested();
                    if (string.IsNullOrWhiteSpace(imagePath) || !File.Exists(imagePath))
                        throw new FileNotFoundException("Image file was not found.", imagePath);

                    using var image = XImage.FromFile(Path.GetFullPath(imagePath));
                    if (image.PixelWidth < 1 || image.PixelHeight < 1)
                        throw new InvalidDataException($"Image has invalid dimensions: {imagePath}");

                    var (pageWidth, pageHeight) = PageSizeFor(image.PixelWidth, image.PixelHeight);
                    var page = document.AddPage();
                    page.Width = XUnit.FromPoint(pageWidth);
                    page.Height = XUnit.FromPoint(pageHeight);
                    using var graphics = XGraphics.FromPdfPage(page);
                    graphics.DrawImage(image, 0, 0, pageWidth, pageHeight);
                }

                token.ThrowIfCancellationRequested();
                document.Save(staged);
            }

            token.ThrowIfCancellationRequested();
            ValidateStagedOutput(staged);
            CommitTransactional(staged, output);
        }
        finally
        {
            try { Directory.Delete(tempDir, true); } catch { }
        }
    }

    private static void WriteCore(
        IReadOnlyList<PdfRasterPage> pages,
        string outputPath,
        CancellationToken token)
    {
        if (pages.Count == 0)
            throw new ArgumentException("A PDF must contain at least one page.", nameof(pages));
        ArgumentException.ThrowIfNullOrWhiteSpace(outputPath);

        var output = Path.GetFullPath(outputPath);
        if (!string.Equals(Path.GetExtension(output), ".pdf", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Image PDF output must use a .pdf filename.", nameof(outputPath));

        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        var tempDir = Path.Combine(
            Path.GetTempPath(), "AsantePDF", "image-pdf", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDir);
        var staged = Path.Combine(tempDir, "staged.pdf");

        try
        {
            using (var document = new PdfDocument())
            {
                for (var index = 0; index < pages.Count; index++)
                {
                    token.ThrowIfCancellationRequested();
                    var raster = pages[index];
                    ValidateRasterPage(raster, index);

                    var jpegPath = Path.Combine(tempDir, $"page-{index + 1:0000}.jpg");
                    File.WriteAllBytes(jpegPath, raster.JpegBytes);

                    using var image = XImage.FromFile(jpegPath);
                    var (pageWidth, pageHeight) = PageSizeFor(raster.PixelWidth, raster.PixelHeight);
                    var page = document.AddPage();
                    page.Width = XUnit.FromPoint(pageWidth);
                    page.Height = XUnit.FromPoint(pageHeight);

                    using var graphics = XGraphics.FromPdfPage(page);
                    graphics.DrawImage(image, 0, 0, pageWidth, pageHeight);
                    DrawSearchableTextLayer(graphics, raster, pageWidth, pageHeight);
                }

                token.ThrowIfCancellationRequested();
                document.Save(staged);
            }

            token.ThrowIfCancellationRequested();
            ValidateStagedOutput(staged);
            CommitTransactional(staged, output);
        }
        finally
        {
            try { Directory.Delete(tempDir, true); } catch { }
        }
    }

    private static void DrawSearchableTextLayer(
        XGraphics graphics,
        PdfRasterPage raster,
        double pageWidth,
        double pageHeight)
    {
        if (raster.Words.Count == 0)
            return;

        var scaleX = pageWidth / raster.PixelWidth;
        var scaleY = pageHeight / raster.PixelHeight;
        // Alpha 1/255 is effectively invisible while retaining real text
        // operators in the PDF content stream for search/copy/indexing.
        var hiddenBrush = new XSolidBrush(XColor.FromArgb(1, 0, 0, 0));
        var fonts = new Dictionary<int, XFont>();

        foreach (var word in raster.Words)
        {
            if (string.IsNullOrWhiteSpace(word.Text) ||
                word.Width <= 0 || word.Height <= 0)
                continue;

            var x = Math.Clamp(word.X * scaleX, 0d, pageWidth);
            var y = Math.Clamp(word.Y * scaleY, 0d, pageHeight);
            var height = Math.Max(1d, word.Height * scaleY);
            var fontSize = Math.Clamp(height * 0.82d, 4d, 72d);
            var fontKey = Math.Clamp((int)Math.Round(fontSize * 2d), 8, 144);
            if (!fonts.TryGetValue(fontKey, out var font))
            {
                font = new XFont("Segoe UI", fontKey / 2d, XFontStyleEx.Regular);
                fonts.Add(fontKey, font);
            }

            var actualFontSize = fontKey / 2d;
            var baseline = Math.Clamp(y + height * 0.84d, actualFontSize, pageHeight);
            graphics.DrawString(word.Text, font, hiddenBrush, new XPoint(x, baseline));
        }
    }

    private static (double Width, double Height) PageSizeFor(int pixelWidth, int pixelHeight)
    {
        if (pixelWidth < 1 || pixelHeight < 1)
            throw new ArgumentOutOfRangeException(nameof(pixelWidth), "Image dimensions must be positive.");

        var ratio = pixelWidth / (double)pixelHeight;
        return ratio >= 1d
            ? (LongSidePoints, Math.Max(1d, LongSidePoints / ratio))
            : (Math.Max(1d, LongSidePoints * ratio), LongSidePoints);
    }

    private static void ValidateStagedOutput(string staged)
    {
        if (!File.Exists(staged) || new FileInfo(staged).Length < 100)
            throw new InvalidDataException("PDFsharp did not produce a valid image PDF output.");
    }

    private static void ValidateRasterPage(PdfRasterPage page, int index)
    {
        if (page.JpegBytes is null || page.JpegBytes.Length < 4)
            throw new InvalidDataException($"Raster page {index + 1} contains no JPEG data.");
        if (page.PixelWidth < 1 || page.PixelHeight < 1)
            throw new InvalidDataException($"Raster page {index + 1} has invalid dimensions.");
    }

    private static void CommitTransactional(string staged, string output)
    {
        if (File.Exists(output))
        {
            var replacement = output + "." + Guid.NewGuid().ToString("N") + ".replace";
            File.Copy(staged, replacement, true);
            try
            {
                File.Replace(replacement, output, null, true);
            }
            finally
            {
                try { if (File.Exists(replacement)) File.Delete(replacement); } catch { }
            }
        }
        else
        {
            File.Move(staged, output);
        }
    }
}
