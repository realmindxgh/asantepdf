using System.IO;

namespace PdfRescue.App.Services;

public static class ConversionSelfTest
{
    public static async Task RunAsync(string samplePdf, string outputDirectory)
    {
        if (!File.Exists(samplePdf)) throw new FileNotFoundException("Conversion sample PDF missing.", samplePdf);
        Directory.CreateDirectory(outputDirectory);
        using var renderer = PdfRendererFactory.CreateProduction();
        await renderer.OpenAsync(samplePdf);
        if (renderer.PageCount < 1) throw new InvalidDataException("Sample PDF has no pages.");
        var bitmap = await renderer.RenderAsync(1, 1200);

        var office = new OfficeConversionService();
        var text = new[] { "AsantePDF conversion self-test" };
        var docx = Path.Combine(outputDirectory, "conversion-test.docx");
        var xlsx = Path.Combine(outputDirectory, "conversion-test.xlsx");
        var pptx = Path.Combine(outputDirectory, "conversion-test.pptx");
        await office.ExportWordAsync(text, docx);
        await office.ExportExcelAsync(text, xlsx);
        await office.ExportPowerPointAsync(new[] { new PowerPointPage(OfficeConversionService.EncodePng(bitmap), bitmap.PixelWidth, bitmap.PixelHeight) }, pptx);
        AssertOutputs(docx, xlsx, pptx);
        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "conversion-selftest-pass.flag"), "pass");
    }

    private static void AssertOutputs(params string[] paths)
    {
        foreach (var path in paths)
            if (!File.Exists(path) || new FileInfo(path).Length < 200)
                throw new InvalidDataException($"Conversion output is missing or empty: {path}");
    }
}
