param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    Write-Text $Path $text
}
function Replace-Between([string]$Path, [string]$StartMarker, [string]$EndMarker, [string]$NewText, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Could not find start marker for $Label in $Path" }
    $end = $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
    if ($end -lt 0) { throw "Could not find end marker for $Label in $Path" }
    $text = $text.Remove($start, $end - $start).Insert($start, (Normalize $NewText))
    Write-Text $Path $text
}

$configuredPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ConfiguredTools.cs'
Replace-Between $configuredPath '    private async Task RunConfiguredPageImageExportAsync()' '    private static void SaveConfiguredBitmap' @'
    private async Task RunConfiguredPageImageExportAsync()
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export") is null) return;
        var source = _currentPdf!;
        var configuration = ToolConfigurationDialogs.ShowPageImageExport(this, source, Pages.Count);
        if (configuration is null) return;
        var directory = Path.GetDirectoryName(configuration.OutputBasePath)!;
        var stem = Path.GetFileNameWithoutExtension(configuration.OutputBasePath);
        var extension = configuration.Format == PageImageFormat.Png ? ".png" : ".jpg";
        var workingPages = configuration.PagePositions.Select(position => Pages[position - 1]).ToArray();
        var destinations = configuration.PagePositions
            .Select(position => Path.Combine(directory, $"{stem}-page-{position:000}{extension}"))
            .ToArray();

        await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
        {
            Directory.CreateDirectory(directory);
            var stagingDirectory = Path.Combine(directory, $".asantepdf-page-export-{Guid.NewGuid():N}");
            Directory.CreateDirectory(stagingDirectory);
            var staged = new string[workingPages.Length];
            try
            {
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(
                        i,
                        workingPages.Length + 1,
                        $"Rendering page {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], configuration.RenderWidth, token);
                    staged[i] = Path.Combine(stagingDirectory, $"page-{i + 1:000}{extension}");
                    SaveConfiguredBitmap(bitmap, staged[i], configuration.Format, configuration.JpegQuality);
                }

                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(
                    workingPages.Length,
                    workingPages.Length + 1,
                    $"Publishing {workingPages.Length:N0} page image(s)...");
                PublishStagedPageImages(staged, destinations, stagingDirectory);
                SetDeterminateProgress(workingPages.Length + 1, workingPages.Length + 1, "Page image export complete.");
            }
            finally
            {
                try { if (Directory.Exists(stagingDirectory)) Directory.Delete(stagingDirectory, true); } catch { }
            }
        });
    }

    private static void PublishStagedPageImages(
        IReadOnlyList<string> staged,
        IReadOnlyList<string> destinations,
        string stagingDirectory)
    {
        if (staged.Count != destinations.Count || staged.Count == 0)
            throw new ArgumentException("The staged page-image set is invalid.");
        if (destinations.Distinct(StringComparer.OrdinalIgnoreCase).Count() != destinations.Count)
            throw new InvalidOperationException("Two exported pages resolved to the same output path.");
        if (staged.Any(path => !File.Exists(path)))
            throw new IOException("A staged page image is missing. Nothing was published.");

        var backups = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var published = new List<string>(destinations.Count);
        try
        {
            for (var i = 0; i < staged.Count; i++)
            {
                var destination = destinations[i];
                if (File.Exists(destination))
                {
                    var backup = Path.Combine(stagingDirectory, $"backup-{i + 1:000}{Path.GetExtension(destination)}");
                    File.Move(destination, backup);
                    backups[destination] = backup;
                }

                File.Move(staged[i], destination);
                published.Add(destination);
            }
        }
        catch
        {
            foreach (var destination in published.AsEnumerable().Reverse())
            {
                try { if (File.Exists(destination)) File.Delete(destination); } catch { }
            }
            foreach (var pair in backups.Reverse())
            {
                try
                {
                    if (File.Exists(pair.Value)) File.Move(pair.Value, pair.Key, true);
                }
                catch { }
            }
            throw;
        }

        foreach (var backup in backups.Values)
        {
            try { if (File.Exists(backup)) File.Delete(backup); } catch { }
        }
    }

'@ 'transactional page-image export'

$tabsPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
Replace-Exact $tabsPath '        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>' '        _ = Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>' 'intentional dispatcher fire-and-forget discard'

Write-Host 'Item 17 cancellation cleanup and warning hardening applied.' -ForegroundColor Green
