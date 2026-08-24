param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference='Stop'
function N([string]$s){$s.Replace("`r`n","`n")}
function W([string]$p,[string]$s){[IO.File]::WriteAllText($p,(N $s).Replace("`n","`r`n"),[Text.UTF8Encoding]::new($false))}
function R([string]$p,[string]$old,[string]$new,[string]$label){$t=N([IO.File]::ReadAllText($p));$o=N $old;$n=N $new;if(-not $t.Contains($o)){throw "Target not found: $label"};W $p ($t.Replace($o,$n))}

$results=Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
R $results @'
    private async Task ShowPdfResultWorkflowAsync(
        string operationTitle,
        string summary,
        string originalPath,
        string resultPath,
        Action? runAgain = null)
    {
        if (!File.Exists(resultPath))
        {
            MessageBox.Show(this, "The operation reported success, but its output file is no longer available.",
                operationTitle, MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var originalTab = FindOpenDocumentTab(originalPath);
        var canReplaceCurrent = originalTab is not null &&
            ReferenceEquals(originalTab, _activeDocumentTab) &&
            !originalTab.IsDirty;

        var dialog = new PdfResultDialog(
            operationTitle,
            summary,
            originalPath,
            resultPath,
            canReplaceCurrent,
            runAgain is not null)
        {
            Owner = this
        };

        if (dialog.ShowDialog() != true) return;

        switch (dialog.SelectedAction)
        {
            case PdfResultAction.OpenNewTab:
                await OpenPdfAsync(resultPath);
                break;

            case PdfResultAction.ReplaceCurrent:
                if (canReplaceCurrent && originalTab is not null)
                {
                    await OpenPdfAsync(resultPath);
                    if (DocumentTabs.Contains(originalTab))
                        await CloseDocumentTabAsync(originalTab);
                }
                break;

            case PdfResultAction.OpenFolder:
                OpenContainingFolder(resultPath);
                break;

            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;

            case PdfResultAction.RunAgain:
                runAgain?.Invoke();
                break;
        }
    }
'@ @'
    private Task ShowPdfResultWorkflowAsync(
        string operationTitle,
        string summary,
        string originalPath,
        string resultPath,
        Action? runAgain = null) =>
        ShowResultWorkflowAsync(operationTitle, summary, originalPath, resultPath, resultIsPdf: true, runAgain);

    private async Task ShowResultWorkflowAsync(
        string operationTitle,
        string summary,
        string? originalPath,
        string resultPath,
        bool resultIsPdf,
        Action? runAgain = null,
        string? sourceLabel = null)
    {
        if (!File.Exists(resultPath))
        {
            MessageBox.Show(this, "The operation reported success, but its output file is no longer available.",
                operationTitle, MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var originalTab = resultIsPdf && !string.IsNullOrWhiteSpace(originalPath)
            ? FindOpenDocumentTab(originalPath)
            : null;
        var canReplaceCurrent = originalTab is not null &&
            ReferenceEquals(originalTab, _activeDocumentTab) &&
            !originalTab.IsDirty;
        var runAgainAction = runAgain;

        var dialog = new PdfResultDialog(
            operationTitle,
            summary,
            originalPath,
            resultPath,
            canReplaceCurrent,
            runAgainAction is not null,
            resultIsPdf,
            sourceLabel)
        {
            Owner = this
        };

        if (dialog.ShowDialog() != true) return;
        switch (dialog.SelectedAction)
        {
            case PdfResultAction.OpenNewTab:
                await OpenTaskOutputAsync(resultPath);
                break;
            case PdfResultAction.ReplaceCurrent:
                if (resultIsPdf && canReplaceCurrent && originalTab is not null)
                {
                    await OpenPdfAsync(resultPath);
                    if (DocumentTabs.Contains(originalTab))
                        await CloseDocumentTabAsync(originalTab);
                }
                break;
            case PdfResultAction.OpenFolder:
                OpenContainingFolder(resultPath);
                break;
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
                if (runAgainAction is not null)
                    await InvokeToolOnUiAsync(runAgainAction);
                break;
        }
    }
'@ 'generic foreground result workflow'

$main=Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
R $main @'
        await RunPdfOperationAsync("Extracting pages...", "Extracted selected pages.", async token =>
        {
            var transforms = selected.OrderBy(p => p.Position)
                .Select(p => new PdfPageTransform(p.SourcePageNumber, p.Rotation))
                .ToArray();
            await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, output, token);
        });
'@ @'
        var source = _currentPdf;
        var success = await RunPdfOutputOperationAsync("Extracting pages...", "Extracted selected pages.", output, async token =>
        {
            var transforms = selected.OrderBy(p => p.Position)
                .Select(p => new PdfPageTransform(p.SourcePageNumber, p.Rotation))
                .ToArray();
            await _operations.ApplyPageLayoutAsync(source, transforms, output, token);
        });
        if (success)
            await ShowPdfResultWorkflowAsync(
                "Extraction complete",
                $"Created a PDF containing {selected.Count:N0} selected page(s). The source PDF was not modified.",
                source,
                output,
                () => ExtractSelected_Click(this, new RoutedEventArgs()));
'@ 'extract selected completion'
R $main @'
        await RunPdfOperationAsync("Merging PDFs...", $"Merged {inputs.Length:N0} PDFs.", token => _operations.MergeAsync(inputs, output, token));
'@ @'
        var success = await RunPdfOutputOperationAsync("Merging PDFs...", $"Merged {inputs.Length:N0} PDFs.", output, token => _operations.MergeAsync(inputs, output, token));
        if (success)
            await ShowResultWorkflowAsync(
                "Merge complete",
                $"Merged {inputs.Length:N0} source PDFs into one result.",
                inputs[0],
                output,
                resultIsPdf: true,
                () => Merge_Click(this, new RoutedEventArgs()),
                $"{inputs.Length:N0} source PDFs");
'@ 'foreground merge completion'
R $main @'
        await RunPdfOperationAsync(
            "Building PDF from images...",
            "Image PDF created.",
            token => ImagePdfBuilder.CreateFromImageFilesAsync(dialog.FileNames, output, token));
'@ @'
        var success = await RunPdfOutputOperationAsync(
            "Building PDF from images...",
            "Image PDF created.",
            output,
            token => ImagePdfBuilder.CreateFromImageFilesAsync(dialog.FileNames, output, token));
        if (success)
            await ShowResultWorkflowAsync(
                "Image PDF complete",
                $"Created a PDF from {dialog.FileNames.Length:N0} source image(s).",
                dialog.FileNames[0],
                output,
                resultIsPdf: true,
                () => ImagesToPdf_Click(this, new RoutedEventArgs()),
                $"{dialog.FileNames.Length:N0} source images");
'@ 'images to PDF completion'
R $main @'
            await RunPdfOperationAsync("Running local OCR...", "Searchable OCR PDF created.", async token =>
            {
                var rasterPages = new List<PdfRasterPage>(workingPages.Length);
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(i, workingPages.Length, $"OCR page {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                    var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                    rasterPages.Add(ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, recognized.Words));
                }
                SetDeterminateProgress(workingPages.Length, workingPages.Length, "Writing searchable PDF...");
                await ImagePdfBuilder.WriteAsync(rasterPages, configuration.OutputPath, token);
            });
            return;
'@ @'
            var success = await RunPdfOutputOperationAsync("Running local OCR...", "Searchable OCR PDF created.", configuration.OutputPath, async token =>
            {
                var rasterPages = new List<PdfRasterPage>(workingPages.Length);
                for (var i = 0; i < workingPages.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    SetDeterminateProgress(i, workingPages.Length, $"OCR page {i + 1:N0} of {workingPages.Length:N0}...");
                    var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                    var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                    rasterPages.Add(ImagePdfBuilder.BitmapToJpegPage(bitmap, 88, recognized.Words));
                }
                SetDeterminateProgress(workingPages.Length, workingPages.Length, "Writing searchable PDF...");
                await ImagePdfBuilder.WriteAsync(rasterPages, configuration.OutputPath, token);
            });
            if (success)
                await ShowPdfResultWorkflowAsync(
                    "OCR complete",
                    $"Created a searchable PDF from {workingPages.Length:N0} selected page(s). The source PDF was not overwritten.",
                    source,
                    configuration.OutputPath,
                    () => OcrPdf_Click(this, new RoutedEventArgs()));
            return;
'@ 'foreground searchable OCR completion'
R $main @'
        await RunPdfOperationAsync("Extracting text with local OCR...", "OCR text extracted.", async token =>
        {
            var output = new System.Text.StringBuilder();
            for (var i = 0; i < workingPages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, workingPages.Length, $"Reading page {i + 1:N0} of {workingPages.Length:N0}...");
                var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                if (i > 0)
                    output.AppendLine().AppendLine($"--- Page {configuration.PagePositions[i]} ---").AppendLine();
                output.Append(recognized.Text);
            }
            await File.WriteAllTextAsync(configuration.OutputPath, output.ToString(), token);
        });
'@ @'
        var textSuccess = await RunPdfOutputOperationAsync("Extracting text with local OCR...", "OCR text extracted.", configuration.OutputPath, async token =>
        {
            var output = new System.Text.StringBuilder();
            for (var i = 0; i < workingPages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                SetDeterminateProgress(i, workingPages.Length, $"Reading page {i + 1:N0} of {workingPages.Length:N0}...");
                var bitmap = await RenderWorkingPageAsync(workingPages[i], 1800, token);
                var recognized = await _ocr.RecognizeAsync(bitmap, configuration.LanguageId, token);
                if (i > 0)
                    output.AppendLine().AppendLine($"--- Page {configuration.PagePositions[i]} ---").AppendLine();
                output.Append(recognized.Text);
            }
            await File.WriteAllTextAsync(configuration.OutputPath, output.ToString(), token);
        });
        if (textSuccess)
            await ShowResultWorkflowAsync(
                "OCR text extraction complete",
                $"Recovered local OCR text from {workingPages.Length:N0} selected page(s).",
                source,
                configuration.OutputPath,
                resultIsPdf: false,
                () => ExtractOcrText_Click(this, new RoutedEventArgs()));
'@ 'foreground OCR text completion'

$finish=@(
@('Watermark', 'await RunPdfOperationAsync("Adding watermark...", "Watermark added.", token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddWatermarkAsync(working, output, text, ct), token));', 'var success = await RunPdfOutputOperationAsync("Adding watermark...", "Watermark added.", output, token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddWatermarkAsync(working, output, text, ct), token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Watermark complete", "A watermarked copy was created. The source PDF was not overwritten.", source, output,\n                () => Watermark_Click(this, new RoutedEventArgs()));'),
@('Page numbers', 'await RunPdfOperationAsync("Adding page numbers...", "Page numbers added.", token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddPageNumbersAsync(working, output, prefix, start.Value, ct), token));', 'var success = await RunPdfOutputOperationAsync("Adding page numbers...", "Page numbers added.", output, token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddPageNumbersAsync(working, output, prefix, start.Value, ct), token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Page numbering complete", "A numbered copy was created. The source PDF was not overwritten.", source, output,\n                () => PageNumbers_Click(this, new RoutedEventArgs()));'),
@('Header/footer', 'await RunPdfOperationAsync("Adding header and footer...", "Header/footer added.", token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddHeaderFooterAsync(working, output, values.Value.Header, values.Value.Footer, ct), token));', 'var success = await RunPdfOutputOperationAsync("Adding header and footer...", "Header/footer added.", output, token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.AddHeaderFooterAsync(working, output, values.Value.Header, values.Value.Footer, ct), token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Header/footer complete", "A copy with the requested header and footer was created. The source PDF was not overwritten.", source, output,\n                () => HeaderFooter_Click(this, new RoutedEventArgs()));'),
@('Metadata', 'await RunPdfOperationAsync("Updating PDF metadata...", "Metadata updated.", token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.UpdateMetadataAsync(working, output, metadata, ct), token));', 'var success = await RunPdfOutputOperationAsync("Updating PDF metadata...", "Metadata updated.", output, token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.UpdateMetadataAsync(working, output, metadata, ct), token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Metadata update complete", "A copy with updated metadata was created. The source PDF was not overwritten.", source, output,\n                () => Metadata_Click(this, new RoutedEventArgs()));'),
@('Stamp image', 'await RunPdfOperationAsync("Stamping image...", "Image/signature stamp added.", token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.StampImageAsync(working, output, imageDialog.FileName, page.Value, ct), token));', 'var success = await RunPdfOutputOperationAsync("Stamping image...", "Image/signature stamp added.", output, token =>\n            RunAgainstWorkingLayoutAsync((working, ct) => _finishing.StampImageAsync(working, output, imageDialog.FileName, page.Value, ct), token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Image stamp complete", "A stamped copy was created. The source PDF was not overwritten.", source, output,\n                () => StampImage_Click(this, new RoutedEventArgs()));'),
@('Fill form', 'await RunPdfOperationAsync("Filling PDF form...", "Form fields filled.", token =>\n            _forms.FillAsync(source, output, values, token));', 'var success = await RunPdfOutputOperationAsync("Filling PDF form...", "Form fields filled.", output, token =>\n            _forms.FillAsync(source, output, values, token));\n        if (success)\n            await ShowPdfResultWorkflowAsync("Form filling complete", "A filled copy was created. The source PDF was not overwritten.", source, output,\n                () => FillForm_Click(this, new RoutedEventArgs()));')
)
foreach($x in $finish){R $main (($x[1]).Replace('\n',"`n")) (($x[2]).Replace('\n',"`n")) $x[0]}

$config=Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ConfiguredTools.cs'
R $config @'
        await RunPdfOperationAsync("Converting Office document to PDF...", "Office document converted to PDF.", token =>
            _office.ConvertOfficeToPdfAsync(configuration.InputPath, configuration.OutputPath, token));
'@ @'
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
'@ 'foreground office conversion completion'
R $config @'
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
'@ @'
            var success = await RunPdfOutputOperationAsync("Rendering PDF pages for PowerPoint...", "PowerPoint presentation created.", configuration.OutputPath, async token =>
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
            if (success)
                await ShowResultWorkflowAsync(
                    "PowerPoint export complete",
                    $"Created a presentation from {workingPages.Length:N0} selected PDF page(s).",
                    source,
                    configuration.OutputPath,
                    resultIsPdf: false,
                    () => PdfToPowerPoint_Click(this, new System.Windows.RoutedEventArgs()));
            return;
'@ 'foreground powerpoint completion'
R $config @'
        _ = success;
'@ @'
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
'@ 'foreground word excel completion'

Write-Host 'Foreground single-result completion migration applied.'
