namespace PdfRescue.Core.Models;

public sealed record PdfPageTransform(int SourcePageNumber, int RotationClockwise = 0)
{
    public int NormalizedRotation => ((RotationClockwise % 360) + 360) % 360;
}
