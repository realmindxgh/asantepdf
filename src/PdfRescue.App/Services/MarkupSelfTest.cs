using System.IO;

namespace PdfRescue.App.Services;

public static class MarkupSelfTest
{
    public static async Task RunAsync(string samplePdf, string outputDirectory)
    {
        if (!File.Exists(samplePdf)) throw new FileNotFoundException("Markup sample PDF missing.", samplePdf);
        Directory.CreateDirectory(outputDirectory);
        var service = new PdfMarkupService();
        var area = new NormalizedPdfRect(0.15, 0.18, 0.35, 0.18);
        var highlight = Path.Combine(outputDirectory, "highlight.pdf");
        var text = Path.Combine(outputDirectory, "text.pdf");
        var rectangle = Path.Combine(outputDirectory, "rectangle.pdf");
        var ellipse = Path.Combine(outputDirectory, "ellipse.pdf");
        var crop = Path.Combine(outputDirectory, "crop.pdf");
        await service.AddHighlightAsync(samplePdf, highlight, 1, area);
        await service.AddTextAsync(samplePdf, text, 1, 0.15, 0.20, "AsantePDF test");
        await service.AddRectangleAsync(samplePdf, rectangle, 1, area);
        await service.AddEllipseAsync(samplePdf, ellipse, 1, area);
        await service.CropPageAsync(samplePdf, crop, 1, new NormalizedPdfRect(0.05, 0.05, 0.9, 0.9));
        AssertOutputs(highlight, text, rectangle, ellipse, crop);
        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "markup-selftest-pass.flag"), "pass");
    }

    private static void AssertOutputs(params string[] paths)
    {
        foreach (var path in paths)
            if (!File.Exists(path) || new FileInfo(path).Length < 200)
                throw new InvalidDataException($"Markup output is missing or empty: {path}");
    }
}
