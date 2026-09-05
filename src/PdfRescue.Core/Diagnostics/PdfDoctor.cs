using PdfRescue.Core.Models;
using PdfRescue.Core.Services;

namespace PdfRescue.Core.Diagnostics;

public sealed class PdfDoctor(IPdfInspector inspector)
{
    private const long LargePdfBytes = 25L * 1024 * 1024;

    public async Task<PdfDoctorReport> DiagnoseAsync(string path, CancellationToken cancellationToken = default)
    {
        var inspection = await inspector.InspectAsync(path, cancellationToken).ConfigureAwait(false);
        var issues = new List<PdfDoctorIssue>();
        var score = 100;

        if (inspection.HasErrors)
        {
            issues.Add(new PdfDoctorIssue(
                "STRUCTURE_ERROR",
                "PDF structure needs repair",
                "The PDF engine found structural errors. Keep the original untouched and repair a working copy.",
                PdfHealthSeverity.Error,
                CanAutoFix: true,
                Category: "Structure",
                ActionLabel: "Repair PDF"));
            score -= 40;
        }

        if (inspection.HasWarnings)
        {
            issues.Add(new PdfDoctorIssue(
                "STRUCTURE_WARNING",
                "PDF contains recoverable warnings",
                "The document opened, but its internal structure is not fully clean.",
                PdfHealthSeverity.Warning,
                CanAutoFix: true,
                Category: "Structure",
                ActionLabel: "Repair PDF"));
            score -= 15;
        }

        if (inspection.IsEncrypted)
        {
            issues.Add(new PdfDoctorIssue(
                "ENCRYPTED",
                "Document is encrypted",
                "Some operations may require the document password before they can continue.",
                PdfHealthSeverity.Info,
                Category: "Security"));
        }

        if (inspection.FileSizeBytes >= LargePdfBytes)
        {
            issues.Add(new PdfDoctorIssue(
                "LARGE_FILE",
                "Large PDF",
                $"This file is {FormatBytes(inspection.FileSizeBytes)}. Compression may reduce storage and sharing size.",
                PdfHealthSeverity.Recommendation,
                CanAutoFix: true,
                Category: "Optimization",
                ActionLabel: "Compress PDF"));
            score -= 5;
        }

        if (inspection.PageCount >= 500)
        {
            issues.Add(new PdfDoctorIssue(
                "VERY_LONG_DOCUMENT",
                "Very long document",
                $"The document contains {inspection.PageCount:N0} pages. Heavy tasks should run as cancellable background jobs.",
                PdfHealthSeverity.Info,
                Category: "Performance"));
        }

        score = Math.Clamp(score, 0, 100);
        return new PdfDoctorReport(inspection, score, issues);
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        var value = (double)bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }

        return $"{value:0.#} {units[unit]}";
    }
}
