using System.IO;
using PdfRescue.Core.Services;
using PdfRescue.Infrastructure.Processes;
using PdfRescue.Infrastructure.Qpdf;

namespace PdfRescue.App.Services;

public static class FormsBatchSelfTest
{
    public static async Task RunAsync(string samplePdf, string outputDirectory)
    {
        if (!File.Exists(samplePdf)) throw new FileNotFoundException("Forms/batch sample PDF missing.", samplePdf);
        Directory.CreateDirectory(outputDirectory);

        var forms = new PdfFormService();
        var fields = forms.ReadFields(samplePdf);
        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "forms-field-count.txt"), fields.Count.ToString());

        IPdfOperations operations = new QpdfOperations(new ExternalProcessRunner(), QpdfLocator.Resolve());
        var batch = new BatchPdfService(operations);
        var batchDir = Path.Combine(outputDirectory, "batch");
        var results = await batch.ProcessAsync(new[] { samplePdf }, batchDir, BatchPdfOperation.Repair);
        if (results.Count != 1 || !results[0].Success || !File.Exists(results[0].OutputPath))
            throw new InvalidDataException("Batch PDF repair self-test failed.");

        await File.WriteAllTextAsync(Path.Combine(outputDirectory, "forms-batch-selftest-pass.flag"), "pass");
    }
}
