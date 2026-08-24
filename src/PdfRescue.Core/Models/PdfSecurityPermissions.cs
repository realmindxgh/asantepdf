namespace PdfRescue.Core.Models;

public enum PdfPrintPermission
{
    None,
    LowResolution,
    Full
}

public enum PdfModifyPermission
{
    None,
    Assembly,
    Form,
    Annotate,
    All
}

public sealed record PdfSecurityPermissions(
    PdfPrintPermission Printing,
    PdfModifyPermission Modification,
    bool AllowExtraction)
{
    public static PdfSecurityPermissions FullyPermissive { get; } =
        new(PdfPrintPermission.Full, PdfModifyPermission.All, true);
}