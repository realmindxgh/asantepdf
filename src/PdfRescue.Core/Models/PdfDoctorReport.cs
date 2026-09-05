namespace PdfRescue.Core.Models;

public sealed record PdfDoctorReport(
    PdfInspectionResult Inspection,
    int HealthScore,
    IReadOnlyList<PdfDoctorIssue> Issues)
{
    public bool NeedsAttention => Issues.Any(i => i.Severity is PdfHealthSeverity.Warning or PdfHealthSeverity.Error);

    public string StatusLabel => Inspection.HasErrors ? "Damaged" : NeedsAttention ? "Attention Needed" : "Healthy";

    public string StatusDescription => Inspection.HasErrors
        ? "qpdf reported structural errors. Work from a copy and use Repair PDF."
        : NeedsAttention
            ? "The PDF is readable, but Doctor found issues worth reviewing."
            : "No serious structural problems were detected by the available checks.";
}
