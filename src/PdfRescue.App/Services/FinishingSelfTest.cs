using System.IO;

namespace PdfRescue.App.Services;

public static class FinishingSelfTest
{
    public static async Task RunAsync(string samplePdf, string outputDirectory)
    {
        if (!File.Exists(samplePdf)) throw new FileNotFoundException("Finishing sample PDF missing.", samplePdf);
        Directory.CreateDirectory(outputDirectory);
        var service = new PdfFinishingService();
        var watermark = Path.Combine(outputDirectory, "watermark.pdf");
        var numbers = Path.Combine(outputDirectory, "page-numbers.pdf");
        var headerFooter = Path.Combine(outputDirectory, "header-footer.pdf");
        var metadata = Path.Combine(outputDirectory, "metadata.pdf");
        await service.AddWatermarkAsync(samplePdf, watermark, "ASANTEPDF TEST");
        await service.AddPageNumbersAsync(samplePdf, numbers, "Page ", 1);
        await service.AddHeaderFooterAsync(samplePdf, headerFooter, "AsantePDF", "Release candidate self-test");
        await service.UpdateMetadataAsync(samplePdf, metadata, new PdfMetadataValues("AsantePDF Test", "AsantePDF", "Finishing test", "pdf,asantepdf,test"));
        AssertOutputs(watermark, numbers, headerFooter, metadata);
        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "finishing-selftest-pass.flag"), "pass");
    }

    private static void AssertOutputs(params string[] paths)
    {
        foreach (var path in paths)
            if (!File.Exists(path) || new FileInfo(path).Length < 200)
                throw new InvalidDataException($"Finishing output is missing or empty: {path}");
    }
}
