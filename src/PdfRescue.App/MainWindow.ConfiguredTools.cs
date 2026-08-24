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
        await RunPdfOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", token =>
            _office.ConvertOfficeToPdfAsync(configuration.InputPath, configuration.OutputPath, token));
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
            await RunPdfOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", async token =>
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
        _ = success;
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
        });
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
        });
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

        await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
        {
            Directory.CreateDirectory(directory);
            for (var i = 0; i < workingPages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                var workingPosition = configuration.PagePositions[i];
                SetDeterminateProgress(i, workingPages.Length, $"Exporting page {i + 1:N0} of {workingPages.Length:N0}...");
                var bitmap = await RenderWorkingPageAsync(workingPages[i], configuration.RenderWidth, token);
                var path = Path.Combine(directory, $"{stem}-page-{workingPosition:000}{extension}");
                SaveConfiguredBitmap(bitmap, path, configuration.Format, configuration.JpegQuality);
            }
            SetDeterminateProgress(workingPages.Length, workingPages.Length, "Finishing page export...");
        });
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