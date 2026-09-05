using System.IO;
using PdfRescue.Core.Models;
using PdfRescue.Core.Services;
using PdfRescue.Infrastructure.Processes;
using PdfRescue.Infrastructure.Qpdf;

namespace PdfRescue.App.Services;

public static class FinalCandidateSelfTest
{
    public static async Task RunAsync(string samplePdf, string outputDirectory)
    {
        if (!File.Exists(samplePdf)) throw new FileNotFoundException("Final candidate sample PDF missing.", samplePdf);
        Directory.CreateDirectory(outputDirectory);

        var office = new OfficeConversionService();
        if (!office.IsLibreOfficeAvailable)
            throw new InvalidOperationException("Bundled LibreOffice is required for the 1.0 final-candidate gate.");

        var ocr = new LocalOcrService();
        if (!ocr.IsAvailable)
            throw new InvalidOperationException("No local OCR engine is available in the 1.0 final-candidate build.");
        if (!ocr.IsBundledTesseractAvailable)
            throw new InvalidOperationException("The bundled Tesseract OCR fallback is missing from the final-candidate build.");

        // Exercise the production renderer and OCR against the actual published/installed binary.
        byte[] stampPng;
        using (var renderer = PdfRendererFactory.CreateProduction())
        {
            await renderer.OpenAsync(samplePdf);
            if (renderer.PageCount < 1) throw new InvalidDataException("Sample PDF has no pages.");
            var bitmap = await renderer.RenderAsync(1, 1200);
            var recognized = await ocr.RecognizeAsync(bitmap);
            var bundledRecognized = await ocr.RecognizeWithBundledTesseractAsync(bitmap);
            await File.WriteAllTextAsync(Path.Combine(outputDirectory, "ocr-engine.txt"),
                $"available\ndefault-characters={recognized.Text.Length}\ndefault-words={recognized.Words.Count}\n" +
                $"bundled-tesseract-characters={bundledRecognized.Text.Length}\nbundled-tesseract-words={bundledRecognized.Words.Count}");
            if (bundledRecognized.Words.Count == 0 || bundledRecognized.Text.Length < 3)
                throw new InvalidDataException("Bundled Tesseract ran but did not recognize the release fixture.");

            var searchableOcrPdf = Path.Combine(outputDirectory, "searchable-ocr.pdf");
            await ImagePdfBuilder.WriteAsync(new[]
            {
                ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, bundledRecognized.Words)
            }, searchableOcrPdf);
            AssertFiles(200, searchableOcrPdf);

            stampPng = OfficeConversionService.EncodePng(bitmap);

            var word = Path.Combine(outputDirectory, "asantepdf-export.docx");
            var excel = Path.Combine(outputDirectory, "asantepdf-export.xlsx");
            var powerPoint = Path.Combine(outputDirectory, "asantepdf-export.pptx");
            var pageTexts = new[] { string.IsNullOrWhiteSpace(recognized.Text) ? "AsantePDF final candidate conversion test" : recognized.Text };
            await office.ExportWordAsync(pageTexts, word);
            await office.ExportExcelAsync(pageTexts, excel);
            await office.ExportPowerPointAsync(new[]
            {
                new PowerPointPage(stampPng, bitmap.PixelWidth, bitmap.PixelHeight)
            }, powerPoint);

            AssertFiles(250, word, excel, powerPoint);

            await office.ConvertOfficeToPdfAsync(word, Path.Combine(outputDirectory, "word-roundtrip.pdf"));
            await office.ConvertOfficeToPdfAsync(excel, Path.Combine(outputDirectory, "excel-roundtrip.pdf"));
            await office.ConvertOfficeToPdfAsync(powerPoint, Path.Combine(outputDirectory, "powerpoint-roundtrip.pdf"));
        }

        // Run the feature-family gates as part of the final gate, rather than leaving them optional.
        await ConversionSelfTest.RunAsync(samplePdf, Path.Combine(outputDirectory, "conversion"));
        await FinishingSelfTest.RunAsync(samplePdf, Path.Combine(outputDirectory, "finishing"));
        await MarkupSelfTest.RunAsync(samplePdf, Path.Combine(outputDirectory, "markup"));
        await FormsBatchSelfTest.RunAsync(samplePdf, Path.Combine(outputDirectory, "forms-batch"));

        var stampPath = Path.Combine(outputDirectory, "rendered-stamp.png");
        await File.WriteAllBytesAsync(stampPath, stampPng);

        var imageImportPdf = Path.Combine(outputDirectory, "image-import.pdf");
        await ImagePdfBuilder.CreateFromImageFilesAsync(new[] { stampPath }, imageImportPdf);

        var finishing = new PdfFinishingService();
        await finishing.StampImageAsync(samplePdf, Path.Combine(outputDirectory, "image-stamp.pdf"), stampPath, 1);

        var markup = new PdfMarkupService();
        var area = new NormalizedPdfRect(0.12, 0.15, 0.42, 0.22);
        await markup.StampImageAsync(samplePdf, Path.Combine(outputDirectory, "image-overlay.pdf"), 1, area, stampPath);
        await markup.PermanentRedactAsync(samplePdf, Path.Combine(outputDirectory, "permanent-redaction.pdf"), 1,
            new NormalizedPdfRect(0.10, 0.10, 0.34, 0.12));

        // Exercise the real bundled qpdf executable through the same operations layer used by the UI.
        IPdfOperations operations = new QpdfOperations(new ExternalProcessRunner(), QpdfLocator.Resolve());
        var merge = Path.Combine(outputDirectory, "qpdf-merge.pdf");
        var extract = Path.Combine(outputDirectory, "qpdf-extract.pdf");
        var reorder = Path.Combine(outputDirectory, "qpdf-reorder.pdf");
        var rotate = Path.Combine(outputDirectory, "qpdf-rotate.pdf");
        var compress = Path.Combine(outputDirectory, "qpdf-compress.pdf");
        var repair = Path.Combine(outputDirectory, "qpdf-repair.pdf");
        var linearized = Path.Combine(outputDirectory, "qpdf-linearized.pdf");
        var protectedPdf = Path.Combine(outputDirectory, "qpdf-protected.pdf");
        var decrypted = Path.Combine(outputDirectory, "qpdf-decrypted.pdf");

        await operations.MergeAsync(new[] { samplePdf, samplePdf }, merge);
        await operations.ExtractAsync(merge, "1", extract);
        await operations.ReorderAsync(merge, new[] { 2, 1 }, reorder);
        await operations.RotateAsync(samplePdf, 90, "1", rotate);
        await operations.CompressAsync(samplePdf, PdfCompressionProfile.Balanced, compress);
        await operations.RepairAsync(samplePdf, repair);
        await operations.LinearizeAsync(samplePdf, linearized);
        await operations.ProtectAsync(samplePdf, "AsantePDF-Test-User-2026", "AsantePDF-Test-Owner-2026", protectedPdf);
        await operations.DecryptAsync(protectedPdf, "AsantePDF-Test-User-2026", decrypted);

        var splitDirectory = Path.Combine(outputDirectory, "qpdf-split");
        Directory.CreateDirectory(splitDirectory);
        var splitOutputs = await operations.SplitAsync(merge, 1, Path.Combine(splitDirectory, "split.pdf"));
        if (splitOutputs.Count < 2 || splitOutputs.Any(path => !File.Exists(path)))
            throw new InvalidDataException("Real qpdf split gate did not produce the expected page files.");

        AssertFiles(200,
            Path.Combine(outputDirectory, "word-roundtrip.pdf"),
            Path.Combine(outputDirectory, "excel-roundtrip.pdf"),
            Path.Combine(outputDirectory, "powerpoint-roundtrip.pdf"),
            Path.Combine(outputDirectory, "searchable-ocr.pdf"),
            imageImportPdf,
            Path.Combine(outputDirectory, "image-stamp.pdf"),
            Path.Combine(outputDirectory, "image-overlay.pdf"),
            Path.Combine(outputDirectory, "permanent-redaction.pdf"),
            merge, extract, reorder, rotate, compress, repair, linearized, protectedPdf, decrypted);

        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "final-candidate-pass.flag"), "pass");
    }

    private static void AssertFiles(long minimumBytes, params string[] paths)
    {
        foreach (var path in paths)
        {
            if (!File.Exists(path) || new FileInfo(path).Length < minimumBytes)
                throw new InvalidDataException($"Final candidate output missing or empty: {path}");
        }
    }
}
