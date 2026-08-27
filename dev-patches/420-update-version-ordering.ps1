param([Parameter(Mandatory = $true)][string]$SourceRoot)

$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\UpdateService.cs'
$text = [System.IO.File]::ReadAllText($path)

$oldCall = '    public static bool IsNewer(UpdateInfo update) => CompareVersions(update.Version, CurrentVersion) > 0;'
$newCall = '    public static bool IsNewer(UpdateInfo update) => CompareReleaseVersions(update.Version, CurrentVersion) > 0;'
if (-not $text.Contains($oldCall)) { throw 'UpdateService IsNewer source fragment was not found.' }
$text = $text.Replace($oldCall, $newCall)

$oldMethodName = '    private static int CompareVersions(string left, string right)'
if (-not $text.Contains($oldMethodName)) { throw 'UpdateService comparison method was not found.' }

$newComparison = @'
    private static int CompareReleaseVersions(string left, string right)
    {
        var core = CompareCoreVersions(left, right);
        if (core != 0) return core;

        var leftPre = ParsePrerelease(left);
        var rightPre = ParsePrerelease(right);
        if (leftPre.IsStable && rightPre.IsStable) return 0;
        if (leftPre.IsStable) return 1;
        if (rightPre.IsStable) return -1;

        var rank = leftPre.Rank.CompareTo(rightPre.Rank);
        if (rank != 0) return rank;
        var number = leftPre.Number.CompareTo(rightPre.Number);
        if (number != 0) return number;
        return string.Compare(leftPre.Label, rightPre.Label, StringComparison.OrdinalIgnoreCase);
    }

    private static (bool IsStable, int Rank, int Number, string Label) ParsePrerelease(string value)
    {
        var normalized = value.Trim().TrimStart('v', 'V');
        var dash = normalized.IndexOf('-');
        if (dash < 0 || dash == normalized.Length - 1)
            return (true, int.MaxValue, int.MaxValue, string.Empty);

        var label = normalized[(dash + 1)..].Split('+', 2)[0].Trim().ToLowerInvariant();
        var rank = label.StartsWith("rc", StringComparison.Ordinal) ? 4
            : label.StartsWith("preview", StringComparison.Ordinal) ? 3
            : label.StartsWith("beta", StringComparison.Ordinal) ? 2
            : label.StartsWith("alpha", StringComparison.Ordinal) ? 1
            : 0;
        var digits = new string(label.SkipWhile(ch => !char.IsDigit(ch)).TakeWhile(char.IsDigit).ToArray());
        var number = int.TryParse(digits, out var parsed) ? parsed : 0;
        return (false, rank, number, label);
    }

'@
$text = $text.Replace($oldMethodName, $newComparison + '    private static int CompareCoreVersions(string left, string right)')

[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host 'Staged stable/prerelease-aware update version ordering.' -ForegroundColor Green
