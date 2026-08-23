param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $text = Get-Content $Path -Raw
    if (-not $text.Contains($Old)) {
        throw "Could not apply $Description. Expected source text was not found in $Path."
    }
    $updated = $text.Replace($Old, $New)
    Set-Content -Path $Path -Value $updated -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$formPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\PdfFormService.cs'
Replace-Exact $formPath 'PdfDocumentOpenMode.ReadOnly' 'PdfDocumentOpenMode.Import' 'PDFsharp 6.2 form inspection mode'

$markupPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\PdfMarkupService.cs'
$oldRect = @'
                    page.CropBox = new PdfRectangle(
                        rect.X * page.Width.Point,
                        (1d - rect.Y - rect.Height) * page.Height.Point,
                        (rect.X + rect.Width) * page.Width.Point,
                        (1d - rect.Y) * page.Height.Point);
'@
$newRect = @'
                    page.CropBox = new PdfRectangle(
                        new XPoint(
                            rect.X * page.Width.Point,
                            (1d - rect.Y - rect.Height) * page.Height.Point),
                        new XPoint(
                            (rect.X + rect.Width) * page.Width.Point,
                            (1d - rect.Y) * page.Height.Point));
'@
Replace-Exact $markupPath $oldRect $newRect 'PDFsharp 6.2 crop rectangle construction'

$ocrPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\LocalOcrService.cs'
Replace-Exact $ocrPath 'encoder.Frames.Add(BitmapFrame.Create(bitmap));' 'encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmap));' 'WPF BitmapFrame disambiguation'

$windowPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$oldSecurity = @'
            var features = report.Inspection.Features ?? PdfFeatureSummary.Empty;
            InspectorSecurity.Text = report.Inspection.IsEncrypted
                ? string.IsNullOrWhiteSpace(features.EncryptionMethod) ? "Encrypted" : $"Encrypted · {features.EncryptionMethod}"
                : "Not encrypted";
'@
$newSecurity = @'
            InspectorSecurity.Text = report.Inspection.IsEncrypted ? "Encrypted" : "Not encrypted";
'@
Replace-Exact $windowPath $oldSecurity $newSecurity 'PDF Doctor security summary against current inspection model'

$oldFeatureMethod = @'
    private static string BuildFeatureSummary(PdfInspectionResult inspection)
    {
        var f = inspection.Features ?? PdfFeatureSummary.Empty;
        var items = new List<string>();
        if (f.HasForms) items.Add(f.HasXfa ? "XFA form" : "Form fields");
        if (f.HasAttachments) items.Add("Attachments");
        if (f.HasDigitalSignatures) items.Add("Digital signatures");
        if (f.HasAnnotations) items.Add("Annotations");
        if (f.HasOutlines) items.Add("Bookmarks/outlines");
        if (f.HasJavaScript) items.Add("JavaScript");
        if (f.HasOpenAction) items.Add("Open action");
        if (f.HasMetadata) items.Add("Metadata");
        if (f.HasEmbeddedFontPrograms) items.Add("Embedded fonts");
        if (f.IsLinearized) items.Add("Fast-web optimized");
        if (f.ImageCount > 0) items.Add($"{f.ImageCount:N0} images on {f.PagesWithImages:N0} page(s)");
        if (f.LikelyScanned) items.Add("Likely scanned/image-based");
        return items.Count == 0 ? "No special document features detected." : string.Join(" · ", items);
    }
'@
$newFeatureMethod = @'
    private static string BuildFeatureSummary(PdfInspectionResult inspection)
    {
        var items = new List<string>();
        if (inspection.PageCount > 0) items.Add($"{inspection.PageCount:N0} page(s)");
        if (!string.IsNullOrWhiteSpace(inspection.PdfVersion)) items.Add($"PDF {inspection.PdfVersion}");
        if (inspection.HasErrors) items.Add("Structural errors detected");
        else if (inspection.HasWarnings) items.Add("Structural warnings detected");
        else items.Add("Structure checks clean");
        return string.Join(" · ", items);
    }
'@
Replace-Exact $windowPath $oldFeatureMethod $newFeatureMethod 'PDF Doctor feature summary against current inspection model'

$globalJson = @'
{
  "sdk": {
    "version": "10.0.202",
    "rollForward": "disable",
    "allowPrerelease": false
  }
}
'@
Set-Content -Path (Join-Path $SourceRoot 'global.json') -Value $globalJson -Encoding UTF8 -NoNewline
Write-Host 'Pinned SDK selection to .NET 10.0.202 with roll-forward disabled.' -ForegroundColor Green
