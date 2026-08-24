namespace PdfRescue.Core.Models;

public sealed record PdfDoctorIssue(
    string Code,
    string Title,
    string Description,
    PdfHealthSeverity Severity,
    bool CanAutoFix = false,
    string Category = "Structure",
    string? ActionLabel = null);
