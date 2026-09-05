using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Windows.Media.Imaging;
using Windows.Globalization;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;
using PdfRescue.Infrastructure.Processes;

namespace PdfRescue.App.Services;

public sealed record OcrPageResult(string Text, IReadOnlyList<OcrWordPlacement> Words);
public sealed record OcrLanguageOption(string Id, string Label, string Detail)
{
    public override string ToString() => Label;
}

public sealed class LocalOcrService
{
    private static string TesseractExe => Path.Combine(AppContext.BaseDirectory, "engines", "tesseract", "tesseract.exe");

    public bool IsBundledTesseractAvailable =>
        File.Exists(TesseractExe) &&
        File.Exists(Path.Combine(AppContext.BaseDirectory, "engines", "tesseract", "tessdata", "eng.traineddata"));

    public bool IsAvailable => OcrEngine.TryCreateFromUserProfileLanguages() is not null || IsBundledTesseractAvailable;

    public IReadOnlyList<OcrLanguageOption> GetLanguageOptions()
    {
        var options = new List<OcrLanguageOption>
        {
            new("auto", "Automatic", "Use the best local recognizer available for this computer. Background OCR keeps the bundled English engine as the deterministic fallback when available.")
        };

        foreach (var language in OcrEngine.AvailableRecognizerLanguages
                     .OrderBy(language => language.DisplayName, StringComparer.CurrentCultureIgnoreCase)
                     .ThenBy(language => language.LanguageTag, StringComparer.OrdinalIgnoreCase))
        {
            options.Add(new OcrLanguageOption(
                "windows:" + language.LanguageTag,
                $"{language.DisplayName} ({language.LanguageTag})",
                "Use the Windows OCR recognizer installed for this language."));
        }

        if (IsBundledTesseractAvailable)
        {
            options.Add(new OcrLanguageOption(
                "tesseract:eng",
                "English · bundled Tesseract",
                "Use AsantePDF's bundled English OCR data directly. This works even when Windows has no English OCR pack installed."));
        }

        return options
            .GroupBy(option => option.Id, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .ToArray();
    }

    public Task<OcrPageResult> RecognizeWithBundledTesseractAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
    {
        if (!IsBundledTesseractAvailable)
            throw new InvalidOperationException("The bundled Tesseract OCR engine or English trained data is missing.");
        return RecognizeWithTesseractAsync(bitmap, cancellationToken);
    }

    public async Task<OcrPageResult> RecognizeAsync(BitmapSource bitmap, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var engine = OcrEngine.TryCreateFromUserProfileLanguages();
        if (engine is not null)
        {
            try
            {
                return await RecognizeWithWindowsAsync(engine, bitmap, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch when (IsBundledTesseractAvailable)
            {
                return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
            }
        }
        if (IsBundledTesseractAvailable)
            return await RecognizeWithTesseractAsync(bitmap, cancellationToken);
        throw new InvalidOperationException("No local OCR engine is available. AsantePDF could not find Windows OCR or its bundled Tesseract fallback.");
    }

    public async Task<OcrPageResult> RecognizeAsync(
        BitmapSource bitmap,
        string? languageId,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (string.IsNullOrWhiteSpace(languageId) || string.Equals(languageId, "auto", StringComparison.OrdinalIgnoreCase))
            return await RecognizeAsync(bitmap, cancellationToken);

        if (string.Equals(languageId, "tesseract:eng", StringComparison.OrdinalIgnoreCase))
            return await RecognizeWithBundledTesseractAsync(bitmap, cancellationToken);

        const string windowsPrefix = "windows:";
        if (languageId.StartsWith(windowsPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var tag = languageId[windowsPrefix.Length..];
            var language = OcrEngine.AvailableRecognizerLanguages.FirstOrDefault(candidate =>
                string.Equals(candidate.LanguageTag, tag, StringComparison.OrdinalIgnoreCase));
            if (language is null)
                throw new InvalidOperationException($"Windows OCR language '{tag}' is no longer installed.");

            var engine = OcrEngine.TryCreateFromLanguage(language);
            if (engine is null)
                throw new InvalidOperationException($"Windows could not create an OCR recognizer for '{language.DisplayName}'.");
            return await RecognizeWithWindowsAsync(engine, bitmap, cancellationToken);
        }

        throw new InvalidOperationException("The selected OCR language is not available on this computer.");
    }

    private static async Task<OcrPageResult> RecognizeWithWindowsAsync(OcrEngine engine, BitmapSource bitmap, CancellationToken token)
    {
        var png = EncodePng(bitmap);
        using var random = new InMemoryRandomAccessStream();
        using (var writer = new DataWriter(random.GetOutputStreamAt(0)))
        {
            writer.WriteBytes(png);
            await writer.StoreAsync();
            await writer.FlushAsync();
            writer.DetachStream();
        }
        random.Seek(0);
        var decoder = await Windows.Graphics.Imaging.BitmapDecoder.CreateAsync(random);
        using var softwareBitmap = await decoder.GetSoftwareBitmapAsync(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Ignore);
        token.ThrowIfCancellationRequested();
        var result = await engine.RecognizeAsync(softwareBitmap);
        token.ThrowIfCancellationRequested();
        var words = new List<OcrWordPlacement>();
        foreach (var line in result.Lines)
            foreach (var word in line.Words)
            {
                var rect = word.BoundingRect;
                words.Add(new OcrWordPlacement(word.Text, rect.X, rect.Y, rect.Width, rect.Height));
            }
        return new OcrPageResult(result.Text ?? string.Empty, words);
    }

    private static async Task<OcrPageResult> RecognizeWithTesseractAsync(BitmapSource bitmap, CancellationToken token)
    {
        var tempDir = Path.Combine(Path.GetTempPath(), "AsantePDF", "ocr", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDir);
        var input = Path.Combine(tempDir, "page.png");
        try
        {
            await File.WriteAllBytesAsync(input, EncodePng(bitmap), token);
            var psi = new ProcessStartInfo(TesseractExe)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            psi.ArgumentList.Add(input);
            psi.ArgumentList.Add("stdout");
            psi.ArgumentList.Add("-l");
            psi.ArgumentList.Add("eng");
            psi.ArgumentList.Add("tsv");
            using var process = Process.Start(psi) ?? throw new InvalidOperationException("Could not start bundled Tesseract OCR.");
            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();
            try { await process.WaitForExitAsync(token); }
            catch (OperationCanceledException)
            {
                await ExternalProcessCleanup.TerminateAndDrainAsync(
                    process, stdoutTask, stderrTask);
                throw;
            }
            var tsv = await stdoutTask;
            var stderr = await stderrTask;
            if (process.ExitCode != 0)
                throw new InvalidDataException($"Tesseract OCR failed ({process.ExitCode}). {stderr}".Trim());

            var words = new List<OcrWordPlacement>();
            var text = new StringBuilder();
            var lastLine = -1;
            foreach (var row in tsv.Replace("\r\n", "\n").Split('\n').Skip(1))
            {
                if (string.IsNullOrWhiteSpace(row)) continue;
                var cols = row.Split('\t');
                if (cols.Length < 12 || cols[0] != "5" || string.IsNullOrWhiteSpace(cols[11])) continue;
                if (!double.TryParse(cols[6], NumberStyles.Float, CultureInfo.InvariantCulture, out var left) ||
                    !double.TryParse(cols[7], NumberStyles.Float, CultureInfo.InvariantCulture, out var top) ||
                    !double.TryParse(cols[8], NumberStyles.Float, CultureInfo.InvariantCulture, out var width) ||
                    !double.TryParse(cols[9], NumberStyles.Float, CultureInfo.InvariantCulture, out var height)) continue;
                _ = int.TryParse(cols[4], out var lineNo);
                if (text.Length > 0) text.Append(lineNo != lastLine ? Environment.NewLine : " ");
                text.Append(cols[11]);
                lastLine = lineNo;
                words.Add(new OcrWordPlacement(cols[11], left, top, width, height));
            }
            return new OcrPageResult(text.ToString(), words);
        }
        finally { try { Directory.Delete(tempDir, true); } catch { } }
    }

    private static byte[] EncodePng(BitmapSource bitmap)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmap));
        using var memory = new MemoryStream();
        encoder.Save(memory);
        return memory.ToArray();
    }
}
