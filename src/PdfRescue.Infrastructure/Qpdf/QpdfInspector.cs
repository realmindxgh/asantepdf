using System.Text.Json;
using PdfRescue.Core.Models;
using PdfRescue.Core.Services;

namespace PdfRescue.Infrastructure.Qpdf;

public sealed class QpdfInspector(IExternalProcessRunner processRunner, string qpdfExecutable = "qpdf") : IPdfInspector
{
    public async Task<PdfInspectionResult> InspectAsync(string path, CancellationToken cancellationToken = default)
    {
        ValidatePdf(path);
        var fullPath = Path.GetFullPath(path);
        var fileInfo = new FileInfo(fullPath);

        var check = await processRunner.RunAsync(
            qpdfExecutable,
            [fullPath, "--check"],
            cancellationToken).ConfigureAwait(false);

        var messages = SplitMessages(check.StandardOutput, check.StandardError);
        var hasErrors = check.ExitCode == 2 || check.ExitCode is not (0 or 3);
        var hasWarnings = check.ExitCode == 3 || messages.Any(m => m.Contains("warning", StringComparison.OrdinalIgnoreCase));

        var pageResult = await processRunner.RunAsync(
            qpdfExecutable,
            [fullPath, "--show-npages"],
            cancellationToken).ConfigureAwait(false);
        EnsureInspectable(pageResult, "read page count");
        _ = int.TryParse(pageResult.StandardOutput.Trim(), out var pageCount);

        var jsonResult = await processRunner.RunAsync(
            qpdfExecutable,
            [fullPath, "--json", "--json-key=qpdf", "--json-stream-data=none"],
            cancellationToken).ConfigureAwait(false);
        EnsureInspectable(jsonResult, "read PDF metadata");
        var pdfVersion = ParsePdfVersion(jsonResult.StandardOutput);

        var encryptedResult = await processRunner.RunAsync(
            qpdfExecutable,
            [fullPath, "--is-encrypted"],
            cancellationToken).ConfigureAwait(false);
        var isEncrypted = encryptedResult.ExitCode == 0;

        return new PdfInspectionResult(
            fullPath,
            fileInfo.Length,
            pageCount,
            pdfVersion,
            isEncrypted,
            hasWarnings,
            hasErrors,
            messages);
    }

    private static string? ParsePdfVersion(string json)
    {
        using var document = JsonDocument.Parse(json);
        if (!document.RootElement.TryGetProperty("qpdf", out var qpdf) || qpdf.ValueKind != JsonValueKind.Array || qpdf.GetArrayLength() == 0)
            return null;

        var header = qpdf[0];
        return header.TryGetProperty("pdfversion", out var version) ? version.GetString() : null;
    }

    private static IReadOnlyList<string> SplitMessages(params string[] text)
        => text
            .SelectMany(value => value.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

    private static void EnsureInspectable(ProcessResult result, string operation)
    {
        if (result.ExitCode == 2 || result.ExitCode is not (0 or 3))
            throw new InvalidDataException($"qpdf could not {operation}. {result.StandardError}".Trim());
    }

    private static void ValidatePdf(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            throw new ArgumentException("PDF path is required.", nameof(path));
        if (!File.Exists(path))
            throw new FileNotFoundException("PDF file was not found.", path);
        if (!string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("The selected file is not a PDF.", nameof(path));
    }
}
