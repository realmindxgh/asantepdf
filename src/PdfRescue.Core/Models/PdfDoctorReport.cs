namespace PdfRescue.Core.Models;

public sealed record PdfDoctorReport(
    PdfInspectionResult Inspection,
    int HealthScore,
    IReadOnlyList<PdfDoctorIssue> Issues)
{
    public bool NeedsAttention => Issues.Any(i => i.Severity is PdfHealthSeverity.Warning or PdfHealthSeverity.Error);
}
