using System.IO;
using System.Windows.Media.Imaging;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async Task RunConfiguredProtectAsync()
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to protect") is null) return;
        var source = _currentPdf!;
        var configuration = ToolConfigurationDialogs.ShowProtect(this, source);
        if (configuration is null) return;

        var success = await RunPdfOutputOperationAsync("Protecting PDF...", "Created password-protected PDF.", configuration.OutputPath, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _operations.ProtectWithPermissionsAsync(
                    working,
                    configuration.UserPassword,
                    configuration.OwnerPassword,
                    configuration.Permissions,
                    configuration.OutputPath,
                    ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Protection complete", "A protected copy was created with the selected permissions. The source PDF was not overwritten.", source, configuration.OutputPath,
                () => Protect_Click(this, new System.Windows.RoutedEventArgs()));
    }

    private async Task RunConfiguredUnlockAsync()
    {
        var configuration = ToolConfigurationDialogs.ShowUnlock(this, _currentPdf);
        if (configuration is null) return;
        if (_backgroundTasks is not null)
        {
            QueueUnlockBackground(configuration.InputPath, configuration.Password, configuration.OutputPath);
            return;
        }
        var success = await RunPdfOutputOperationAsync("Removing PDF password...", "Created unlocked PDF.", configuration.OutputPath, token =>
            _operations.DecryptAsync(configuration.InputPath, configuration.Password, configuration.OutputPath, token));
        if (success)
            await ShowPdfResultWorkflowAsync("Unlock complete", "An unlocked copy was created. The protected source was left unchanged.", configuration.InputPath, configuration.OutputPath,
                () => Unlock_Click(this, new System.Windows.RoutedEventArgs()));
    }

    private async Task RunConfiguredOfficeToPdfAsync()
    {
        if (_busy) return;
        if (!_office.IsLibreOfficeAvailable)
        {
            System.Windows.MessageBox.Show(this, "The bundled Office conversion engine is unavailable.", "AsantePDF Convert", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Warning);
            return;
        }
        var configuration = ToolConfigurationDialogs.ShowOfficeToPdf(this);
        if (configuration is null) return;
        if (_backgroundTasks is not null)
        {
            QueueOfficeToPdfBackground(configuration.InputPath, configuration.OutputPath);
            return;
        }
        var success = await RunPdfOutputOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", configuration.OutputPath, token =>
            _office.ConvertOfficeToPdfAsync(configuration.InputPath, configuration.OutputPath, token));
        if (success)
            await ShowResultWorkflowAsync(
                "Office conversion complete",
                "A PDF copy was created from the Office source file.",
                configuration.InputPath,
                configuration.OutputPath,
                resultIsPdf: true,
                () => OfficeToPdf_Click(this, new System.Windows.RoutedEventArgs()));
    }

    private async Task RunConfiguredPdfConversionAsync(PdfConversionKind defaultKind)
    {
        if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to convert") is null) return;
        var source = _currentPdf!;
        if (defaultKind is PdfConversionKind.Word or PdfConversionKind.Excel && !_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        var configuration = ToolConfigurationDialogs.ShowPdfConversion(this, source, Pages.Count, _ocr.GetLanguageOptions(), defaultKind);
        if (configuration is null) return;
        if (configuration.Kind is PdfConversionKind.Word or PdfConversionKind.Excel && !_ocr.IsAvailable)
        {
            ShowOcrUnavailable();
            return;
        }

        if (_backgroundTasks is not null)
        {
            switch (configuration.Kind)
            {
                case PdfConversionKind.Excel:
                    QueueConfiguredPdfToExcelBackground(source, configuration);
                    break;
                case PdfConversionKind.PowerPoint:
                    QueueConfiguredPdfToPowerPointBackground(source, configuration);
                    break;
                default:
                    QueueConfiguredPdfToWordBackground(source, configuration);
                    break;
            }
            return;
        }

        var workingPages = configuration.PagePositions.Select(position => Pages[position - 1]).ToArray();
        if (configuration.Kind == PdfConversionKind.PowerPoint)
        {
            var powerPointSuccess = await RunPdfOutputOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", configuration.OutputPath, async token =>
            {
                var slides = new List<PowerPointPage>(workingPages.Length);
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(i, workingPages.Length, $"Rendering slide {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], configuration.RenderWidth, token);
                    slides.Add(new PowerPointPage(OfficeConversionService.EncodePng(bitmap), bitmap.PixelWidth, bitmap.PixelHeight));
                }
                await _office.ExportPowerPointAsync(slides, configuration.OutputPath, token);
                SetDeterminateProgress(workingPages.Length, workingPages.Length, "Finishing PowerPoint...");
            });
            if (powerPointSuccess)
                await ShowResultWorkflowAsync(
                    "PowerPoint export complete",
                    $"Created a presentation from {workingPages.Length:N0} selected PDF page(s).",
                    source,
                    configuration.OutputPath,
                    resultIsPdf: false,
                    () => PdfToPowerPoint_Click(this, new System.Windows.RoutedEventArgs()));
            return;
        }

        var texts = new List<string>(workingPages.Length);
        var success = await RunPdfOperationAsync(
            configuration.Kind == PdfConversionKind.Excel ? "Recovering PDF text for Excel..." : "Recovering PDF text for Word...",
            configuration.Kind == PdfConversionKind.Excel ? "Excel workbook created." : "Word document created.",
            async token =>
            {
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(i, workingPages.Length, $"Reading page {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                    var result = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                    texts.Add(result.Text);
                }
                if (configuration.Kind == PdfConversionKind.Excel)
                    await _office.ExportExcelAsync(texts, configuration.OutputPath, token);
                else
                    await _office.ExportWordAsync(texts, configuration.OutputPath, token);
            });
        if (success)
            await ShowResultWorkflowAsync(
                configuration.Kind == PdfConversionKind.Excel ? "Excel export complete" : "Word export complete",
                $"Created a {configuration.Kind} result from {workingPages.Length:N0} selected PDF page(s).",
                source,
                configuration.OutputPath,
                resultIsPdf: false,
                configuration.Kind == PdfConversionKind.Excel
                    ? () => PdfToExcel_Click(this, new System.Windows.RoutedEventArgs())
                    : () => PdfToWord_Click(this, new System.Windows.RoutedEventArgs()));
    }

    private void QueueConfiguredPdfToWordBackground(string source, PdfConversionDialogResult configuration) =>
        QueueConfiguredTextConversionBackground(source, configuration, PdfConversionKind.Word);

    private void QueueConfiguredPdfToExcelBackground(string source, PdfConversionDialogResult configuration) =>
        QueueConfiguredTextConversionBackground(source, configuration, PdfConversionKind.Excel);

    private void QueueConfiguredTextConversionBackground(string source, PdfConversionDialogResult configuration, PdfConversionKind kind)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot(configuration.PagePositions);
        var label = kind == PdfConversionKind.Excel ? "Excel" : "Word";
        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Export {Path.GetFileName(source)} to {label}", async (context, token) =>
        {
            var texts = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<string>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    context.ReportProgress(0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.70, $"Recognising page {page:N0} of {pageCount:N0} for {label}...");
                    var bitmap = await renderer.RenderAsync(page, 1800, ct);
                    var result = await RecognizeBackgroundPageAsync(bitmap, configuration.LanguageId, ct);
                    pages.Add(result.Text);
                }
                return (IReadOnlyList<string>)pages;
            });
            context.ReportProgress(0.88, $"Writing {label} output...");
            if (kind == PdfConversionKind.Excel)
                await _office.ExportExcelAsync(texts, configuration.OutputPath, token);
            else
                await _office.ExportWordAsync(texts, configuration.OutputPath, token);
            context.ReportProgress(0.98, $"{label} output created.");
            return configuration.OutputPath;
        }, sourcePath: source, runAgainAction: kind == PdfConversionKind.Excel
            ? () => InvokeToolOnUiAsync(() => PdfToExcel_Click(this, new System.Windows.RoutedEventArgs()))
            : () => InvokeToolOnUiAsync(() => PdfToWord_Click(this, new System.Windows.RoutedEventArgs())));
        StatusText.Text = $"{label} export queued in Task Center. You can keep working.";
    }

    private void QueueConfiguredPdfToPowerPointBackground(string source, PdfConversionDialogResult configuration)
    {
        if (_backgroundTasks is null) return;
        var snapshot = CaptureBackgroundPdfSnapshot(configuration.PagePositions);
        _backgroundTasks.Enqueue(PdfJobType.Convert, $"Export {Path.GetFileName(source)} to PowerPoint", async (context, token) =>
        {
            var slides = await WithBackgroundRendererAsync(snapshot, context, token, async (renderer, pageCount, ct) =>
            {
                var pages = new List<PowerPointPage>(pageCount);
                for (var page = 1; page <= pageCount; page++)
                {
                    ct.ThrowIfCancellationRequested();
                    context.ReportProgress(0.14 + (page - 1) / (double)Math.Max(1, pageCount) * 0.72, $"Rendering slide {page:N0} of {pageCount:N0}...");
                    var bitmap = await renderer.RenderAsync(page, configuration.RenderWidth, ct);
                    pages.Add(new PowerPointPage(OfficeConversionService.EncodePng(bitmap), bitmap.PixelWidth, bitmap.PixelHeight));
                }
                return (IReadOnlyList<PowerPointPage>)pages;
            });
            context.ReportProgress(0.90, "Writing PowerPoint presentation...");
            await _office.ExportPowerPointAsync(slides, configuration.OutputPath, token);
            context.ReportProgress(0.98, "PowerPoint presentation created.");
            return configuration.OutputPath;
        }, sourcePath: source, runAgainAction: () => InvokeToolOnUiAsync(() => PdfToPowerPoint_Click(this, new System.Windows.RoutedEventArgs())));
        StatusText.Text = "PowerPoint export queued in Task Center. You can keep working.";
    }

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

        var success = await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
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

        if (success)
            await ShowMultiResultWorkflowAsync(
                "Page export complete",
                $"Exported {destinations.Length:N0} page image(s). The source PDF was not modified.",
                source,
                destinations,
                () => ExportPagesAsImages_Click(this, new System.Windows.RoutedEventArgs()));
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
    private static void SaveConfiguredBitmap(BitmapSource bitmap, string path, PageImageFormat format, int jpegQuality)
    {
        BitmapEncoder encoder = format == PageImageFormat.Png
            ? new PngBitmapEncoder()
            : new JpegBitmapEncoder { QualityLevel = Math.Clamp(jpegQuality, 1, 100) };
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
        encoder.Save(stream);
    }
}