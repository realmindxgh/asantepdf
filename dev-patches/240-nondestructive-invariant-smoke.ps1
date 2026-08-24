param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$tests = Join-Path $SourceRoot 'tests\PdfRescue.SmokeTests\Program.cs'
Replace-Exact $tests @'
await RunAsync("Transactional write preserves destination on failure", TestTransactionalWriteSafetyAsync);
await RunAsync("Compression profile uses expected qpdf options", TestCompressionAsync);
'@ @'
await RunAsync("Transactional write preserves destination on failure", TestTransactionalWriteSafetyAsync);
await RunAsync("Source PDF overwrite is rejected", TestSourceOverwriteRejectedAsync);
await RunAsync("Compression profile uses expected qpdf options", TestCompressionAsync);
'@ 'register source-overwrite smoke test'

Replace-Exact $tests @'
async Task TestPageLayoutAsync()
{
'@ @'
async Task TestSourceOverwriteRejectedAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-source-guard-{Guid.NewGuid():N}.pdf");
    var original = new byte[] { 9, 8, 7, 6 };
    await File.WriteAllBytesAsync(input, original);
    try
    {
        var runner = new RecordingQpdfRunner();
        var operations = new QpdfOperations(runner);
        var rejected = false;
        try
        {
            await operations.CompressAsync(input, PdfCompressionProfile.Balanced, input);
        }
        catch (ArgumentException ex) when (ex.Message.Contains("different output file", StringComparison.OrdinalIgnoreCase))
        {
            rejected = true;
        }

        Assert(rejected, "A transformation must reject using the source PDF as its own output.");
        Assert(runner.Calls.Count == 0, "The PDF engine must not start when source and output paths are identical.");
        Assert((await File.ReadAllBytesAsync(input)).SequenceEqual(original),
            "Rejecting a source/output collision must leave the source bytes unchanged.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
    }
}

async Task TestPageLayoutAsync()
{
'@ 'source-overwrite smoke test implementation'

Write-Host 'Non-destructive source/output invariant smoke test added.' -ForegroundColor Green
& cmd /c exit 0
