param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    [IO.File]::WriteAllText($Path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'

# Workflows that already capture a source path: make the post-picker invariant explicit.
foreach ($method in @('Compress_Click','Repair_Click','Linearize_Click','PdfToWord_Click','PdfToExcel_Click','PdfToPowerPoint_Click','OcrPdf_Click','ExtractOcrText_Click')) {
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $signature = "private async void $method(object sender, RoutedEventArgs e)"
    $start = $text.IndexOf($signature, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Could not find method $method" }
    $sourceIndex = $text.IndexOf('        var source = _currentPdf;', $start, [StringComparison]::Ordinal)
    if ($sourceIndex -lt 0) { throw "Could not find nullable source capture in $method" }
    $nextMethod = $text.IndexOf("`n    private ", $start + $signature.Length, [StringComparison]::Ordinal)
    if ($nextMethod -ge 0 -and $sourceIndex -gt $nextMethod) { throw "Source capture search escaped $method" }
    $text = $text.Remove($sourceIndex, '        var source = _currentPdf;'.Length).Insert($sourceIndex, '        var source = _currentPdf!;')
    [IO.File]::WriteAllText($path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

Replace-Exact $path @'
    private async void Split_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to split") is null) return;
        var pagesPerFile = PromptForPositiveInt("Split PDF", "Pages per output file:", 1);
        if (pagesPerFile is null) return;
        var outputBase = AskSavePath("Choose split output base name", SuggestName(_currentPdf, "part"));
'@ @'
    private async void Split_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to split") is null) return;
        var source = _currentPdf!;
        var pagesPerFile = PromptForPositiveInt("Split PDF", "Pages per output file:", 1);
        if (pagesPerFile is null) return;
        var outputBase = AskSavePath("Choose split output base name", SuggestName(source, "part"));
'@ 'split source capture'

Replace-Exact $path @'
    private async void Protect_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to protect") is null) return;
        var passwords = PromptProtectionPasswords();
        if (passwords is null) return;
        var output = AskSavePath("Save password-protected PDF", SuggestName(_currentPdf, "protected"));
'@ @'
    private async void Protect_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to protect") is null) return;
        var source = _currentPdf!;
        var passwords = PromptProtectionPasswords();
        if (passwords is null) return;
        var output = AskSavePath("Save password-protected PDF", SuggestName(source, "protected"));
'@ 'protect source capture'

Replace-Exact $path @'
    private async void ExportPagesAsImages_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export") is null) return;
        var imageDialog = new SaveFileDialog
        {
            Title = "Choose page image destination",
            Filter = "PNG image (*.png)|*.png",
            FileName = Path.GetFileNameWithoutExtension(_currentPdf) + "-page-001.png",
'@ @'
    private async void ExportPagesAsImages_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export") is null) return;
        var source = _currentPdf!;
        var imageDialog = new SaveFileDialog
        {
            Title = "Choose page image destination",
            Filter = "PNG image (*.png)|*.png",
            FileName = Path.GetFileNameWithoutExtension(source) + "-page-001.png",
'@ 'page image export source capture'

Replace-Exact $path @'
    private async void Watermark_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to watermark") is null) return;
        var text = PromptText("Add Watermark", "Watermark text:", "CONFIDENTIAL");
        if (string.IsNullOrWhiteSpace(text)) return;
        var output = AskSavePath("Save watermarked PDF", SuggestName(_currentPdf, "watermarked"));
'@ @'
    private async void Watermark_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to watermark") is null) return;
        var source = _currentPdf!;
        var text = PromptText("Add Watermark", "Watermark text:", "CONFIDENTIAL");
        if (string.IsNullOrWhiteSpace(text)) return;
        var output = AskSavePath("Save watermarked PDF", SuggestName(source, "watermarked"));
'@ 'watermark source capture'

Replace-Exact $path @'
    private async void PageNumbers_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to number") is null) return;
        var prefix = PromptText("Add Page Numbers", "Text before the number (optional):", "Page ");
        if (prefix is null) return;
        var start = PromptForPositiveInt("Add Page Numbers", "Starting number:", 1);
        if (start is null) return;
        var output = AskSavePath("Save numbered PDF", SuggestName(_currentPdf, "numbered"));
'@ @'
    private async void PageNumbers_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to number") is null) return;
        var source = _currentPdf!;
        var prefix = PromptText("Add Page Numbers", "Text before the number (optional):", "Page ");
        if (prefix is null) return;
        var start = PromptForPositiveInt("Add Page Numbers", "Starting number:", 1);
        if (start is null) return;
        var output = AskSavePath("Save numbered PDF", SuggestName(source, "numbered"));
'@ 'page numbers source capture'

Replace-Exact $path @'
    private async void HeaderFooter_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF for header/footer editing") is null) return;
        var values = PromptHeaderFooter();
        if (values is null) return;
        var output = AskSavePath("Save PDF with header/footer", SuggestName(_currentPdf, "header-footer"));
'@ @'
    private async void HeaderFooter_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF for header/footer editing") is null) return;
        var source = _currentPdf!;
        var values = PromptHeaderFooter();
        if (values is null) return;
        var output = AskSavePath("Save PDF with header/footer", SuggestName(source, "header-footer"));
'@ 'header footer source capture'

Replace-Exact $path @'
    private async void Metadata_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose metadata you want to edit") is null) return;
        var metadata = PromptMetadata();
        if (metadata is null) return;
        var output = AskSavePath("Save PDF with updated metadata", SuggestName(_currentPdf, "metadata"));
'@ @'
    private async void Metadata_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose metadata you want to edit") is null) return;
        var source = _currentPdf!;
        var metadata = PromptMetadata();
        if (metadata is null) return;
        var output = AskSavePath("Save PDF with updated metadata", SuggestName(source, "metadata"));
'@ 'metadata source capture'

Replace-Exact $path @'
    private async void StampImage_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to stamp with an image") is null) return;
        var imageDialog = new OpenFileDialog
'@ @'
    private async void StampImage_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to stamp with an image") is null) return;
        var source = _currentPdf!;
        var imageDialog = new OpenFileDialog
'@ 'stamp source capture declaration'
Replace-Exact $path '        var output = AskSavePath("Save stamped PDF", SuggestName(_currentPdf, "stamped"));' '        var output = AskSavePath("Save stamped PDF", SuggestName(source, "stamped"));' 'stamp source use'

Replace-Exact $path @'
    private async void FillForm_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF form to fill") is null) return;
        if (HasLayoutChanges())
'@ @'
    private async void FillForm_Click(object sender, RoutedEventArgs e)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF form to fill") is null) return;
        var source = _currentPdf!;
        if (HasLayoutChanges())
'@ 'form source capture declaration'
Replace-Exact $path '            fields = _forms.ReadFields(_currentPdf);' '            fields = _forms.ReadFields(source);' 'form read source'
Replace-Exact $path '        var output = AskSavePath("Save filled form", SuggestName(_currentPdf, "filled"));' '        var output = AskSavePath("Save filled form", SuggestName(source, "filled"));' 'form output source'
Replace-Exact $path '            _forms.FillAsync(_currentPdf, output, values, token));' '            _forms.FillAsync(source, output, values, token));' 'form fill source'

Write-Host 'Standalone source nullability hardening applied.' -ForegroundColor Green
