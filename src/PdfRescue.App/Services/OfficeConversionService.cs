using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Security;
using System.Text;
using System.Windows.Media.Imaging;
using PdfRescue.Infrastructure.Processes;

namespace PdfRescue.App.Services;

public sealed record PowerPointPage(byte[] PngBytes, int PixelWidth, int PixelHeight);

public sealed class OfficeConversionService
{
    public bool IsLibreOfficeAvailable => File.Exists(ResolveLibreOfficeExecutable());

    public Task ExportWordAsync(IReadOnlyList<string> pageTexts, string outputPath, CancellationToken token = default) =>
        Task.Run(() => WriteDocx(pageTexts, outputPath, token), token);

    public Task ExportExcelAsync(IReadOnlyList<string> pageTexts, string outputPath, CancellationToken token = default) =>
        Task.Run(() => WriteXlsx(pageTexts, outputPath, token), token);

    public Task ExportPowerPointAsync(IReadOnlyList<PowerPointPage> pages, string outputPath, CancellationToken token = default) =>
        Task.Run(() => WritePptx(pages, outputPath, token), token);

    public async Task ConvertOfficeToPdfAsync(string inputPath, string outputPath, CancellationToken token = default)
    {
        var input = Path.GetFullPath(inputPath);
        var output = Path.GetFullPath(outputPath);
        if (!File.Exists(input)) throw new FileNotFoundException("Office document was not found.", input);
        if (!output.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("The output file must use the .pdf extension.", nameof(outputPath));
        if (string.Equals(input, output, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Choose a different output file.");

        var soffice = ResolveLibreOfficeExecutable();
        if (!File.Exists(soffice))
            throw new InvalidOperationException("The bundled LibreOffice conversion engine is missing.");

        var temp = Path.Combine(Path.GetTempPath(), "AsantePDF", "office", Guid.NewGuid().ToString("N"));
        var profile = Path.Combine(temp, "profile");
        Directory.CreateDirectory(temp);
        Directory.CreateDirectory(profile);
        try
        {
            var profileUri = new Uri(profile + Path.DirectorySeparatorChar).AbsoluteUri;
            var start = new ProcessStartInfo(soffice)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WorkingDirectory = temp
            };
            start.ArgumentList.Add("--headless");
            start.ArgumentList.Add("--nologo");
            start.ArgumentList.Add("--nodefault");
            start.ArgumentList.Add("--nofirststartwizard");
            start.ArgumentList.Add($"-env:UserInstallation={profileUri}");
            start.ArgumentList.Add("--convert-to");
            start.ArgumentList.Add("pdf");
            start.ArgumentList.Add("--outdir");
            start.ArgumentList.Add(temp);
            start.ArgumentList.Add(input);

            using var process = Process.Start(start) ?? throw new InvalidOperationException("Could not start the bundled LibreOffice engine.");
            var stdout = process.StandardOutput.ReadToEndAsync();
            var stderr = process.StandardError.ReadToEndAsync();
            try
            {
                await process.WaitForExitAsync(token);
            }
            catch (OperationCanceledException)
            {
                await ExternalProcessCleanup.TerminateAndDrainAsync(
                    process, stdout, stderr);
                throw;
            }

            var outText = (await stdout).Trim();
            var errText = (await stderr).Trim();
            if (process.ExitCode != 0)
                throw new InvalidDataException($"LibreOffice conversion failed ({process.ExitCode}). {errText} {outText}".Trim());

            var expected = Path.Combine(temp, Path.GetFileNameWithoutExtension(input) + ".pdf");
            if (!File.Exists(expected))
            {
                var candidate = Directory.GetFiles(temp, "*.pdf").FirstOrDefault();
                if (candidate is null)
                    throw new InvalidDataException(string.IsNullOrWhiteSpace(errText + outText)
                        ? "LibreOffice did not produce a PDF."
                        : (errText + Environment.NewLine + outText).Trim());
                expected = candidate;
            }

            CommitTransactional(expected, output);
        }
        finally
        {
            try { Directory.Delete(temp, true); } catch { }
        }
    }

    public static byte[] EncodePng(BitmapSource bitmap)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var memory = new MemoryStream();
        encoder.Save(memory);
        return memory.ToArray();
    }

    private static void WriteDocx(IReadOnlyList<string> pageTexts, string outputPath, CancellationToken token)
    {
        var output = PrepareOutput(outputPath, ".docx");
        var temp = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var archive = ZipFile.Open(temp, ZipArchiveMode.Create))
            {
                WriteEntry(archive, "[Content_Types].xml", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                      <Default Extension="xml" ContentType="application/xml"/>
                      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
                    </Types>
                    """);
                WriteEntry(archive, "_rels/.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
                    </Relationships>
                    """);

                var body = new StringBuilder();
                for (var page = 0; page < pageTexts.Count; page++)
                {
                    token.ThrowIfCancellationRequested();
                    var lines = (pageTexts[page] ?? string.Empty).Replace("\r\n", "\n").Split('\n');
                    if (lines.Length == 0 || lines.All(string.IsNullOrWhiteSpace))
                        lines = ["[No text was recovered from this page]"];
                    foreach (var line in lines)
                    {
                        var escaped = Xml(line);
                        body.Append("<w:p><w:r><w:t xml:space=\"preserve\">").Append(escaped).Append("</w:t></w:r></w:p>");
                    }
                    if (page < pageTexts.Count - 1)
                        body.Append("<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>");
                }
                var document = $"""
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                      <w:body>{body}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080"/></w:sectPr></w:body>
                    </w:document>
                    """;
                WriteEntry(archive, "word/document.xml", document);
            }
            CommitTransactional(temp, output);
        }
        finally { try { if (File.Exists(temp)) File.Delete(temp); } catch { } }
    }

    private static void WriteXlsx(IReadOnlyList<string> pageTexts, string outputPath, CancellationToken token)
    {
        var output = PrepareOutput(outputPath, ".xlsx");
        var temp = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var archive = ZipFile.Open(temp, ZipArchiveMode.Create))
            {
                WriteEntry(archive, "[Content_Types].xml", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                      <Default Extension="xml" ContentType="application/xml"/>
                      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
                      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
                    </Types>
                    """);
                WriteEntry(archive, "_rels/.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
                    </Relationships>
                    """);
                WriteEntry(archive, "xl/workbook.xml", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <sheets><sheet name="Recovered PDF Text" sheetId="1" r:id="rId1"/></sheets>
                    </workbook>
                    """);
                WriteEntry(archive, "xl/_rels/workbook.xml.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
                    </Relationships>
                    """);

                var rows = new StringBuilder();
                var rowNumber = 1;
                for (var page = 0; page < pageTexts.Count; page++)
                {
                    token.ThrowIfCancellationRequested();
                    AppendInlineRow(rows, rowNumber++, $"Page {page + 1}");
                    foreach (var line in (pageTexts[page] ?? string.Empty).Replace("\r\n", "\n").Split('\n'))
                        if (!string.IsNullOrWhiteSpace(line)) AppendInlineRow(rows, rowNumber++, line);
                    rowNumber++;
                }
                var sheet = $"""
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>{rows}</sheetData></worksheet>
                    """;
                WriteEntry(archive, "xl/worksheets/sheet1.xml", sheet);
            }
            CommitTransactional(temp, output);
        }
        finally { try { if (File.Exists(temp)) File.Delete(temp); } catch { } }
    }

    private static void WritePptx(IReadOnlyList<PowerPointPage> pages, string outputPath, CancellationToken token)
    {
        if (pages.Count == 0) throw new ArgumentException("At least one page is required.", nameof(pages));
        var output = PrepareOutput(outputPath, ".pptx");
        var temp = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        const long slideCx = 9144000;
        const long slideCy = 6858000;
        try
        {
            using (var archive = ZipFile.Open(temp, ZipArchiveMode.Create))
            {
                var overrides = new StringBuilder();
                for (var i = 1; i <= pages.Count; i++)
                    overrides.Append($"<Override PartName=\"/ppt/slides/slide{i}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>");
                WriteEntry(archive, "[Content_Types].xml", $"""
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                      <Default Extension="xml" ContentType="application/xml"/>
                      <Default Extension="png" ContentType="image/png"/>
                      <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
                      <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
                      <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
                      <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
                      {overrides}
                    </Types>
                    """);
                WriteEntry(archive, "_rels/.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
                    </Relationships>
                    """);

                var slideIds = new StringBuilder();
                var presentationRels = new StringBuilder();
                presentationRels.Append("<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>");
                for (var i = 1; i <= pages.Count; i++)
                {
                    slideIds.Append($"<p:sldId id=\"{255 + i}\" r:id=\"rId{i + 1}\"/>");
                    presentationRels.Append($"<Relationship Id=\"rId{i + 1}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide{i}.xml\"/>");
                }
                WriteEntry(archive, "ppt/presentation.xml", $"""
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                      <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
                      <p:sldIdLst>{slideIds}</p:sldIdLst><p:sldSz cx="{slideCx}" cy="{slideCy}" type="screen4x3"/><p:notesSz cx="6858000" cy="9144000"/>
                    </p:presentation>
                    """);
                WriteEntry(archive, "ppt/_rels/presentation.xml.rels", $"""
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{presentationRels}</Relationships>
                    """);

                WriteEntry(archive, "ppt/slideMasters/slideMaster1.xml", SlideMasterXml());
                WriteEntry(archive, "ppt/slideMasters/_rels/slideMaster1.xml.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
                      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
                    </Relationships>
                    """);
                WriteEntry(archive, "ppt/slideLayouts/slideLayout1.xml", SlideLayoutXml());
                WriteEntry(archive, "ppt/slideLayouts/_rels/slideLayout1.xml.rels", """
                    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
                    </Relationships>
                    """);
                WriteEntry(archive, "ppt/theme/theme1.xml", ThemeXml());

                for (var i = 0; i < pages.Count; i++)
                {
                    token.ThrowIfCancellationRequested();
                    var page = pages[i];
                    var imageName = $"image{i + 1}.png";
                    WriteBinaryEntry(archive, $"ppt/media/{imageName}", page.PngBytes);
                    var (x, y, cx, cy) = Fit(page.PixelWidth, page.PixelHeight, slideCx, slideCy);
                    WriteEntry(archive, $"ppt/slides/slide{i + 1}.xml", SlideXml(i + 1, x, y, cx, cy));
                    WriteEntry(archive, $"ppt/slides/_rels/slide{i + 1}.xml.rels", $"""
                        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
                          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/{imageName}"/>
                        </Relationships>
                        """);
                }
            }
            CommitTransactional(temp, output);
        }
        finally { try { if (File.Exists(temp)) File.Delete(temp); } catch { } }
    }

    private static string ResolveLibreOfficeExecutable()
    {
        var root = Path.Combine(AppContext.BaseDirectory, "engines", "libreoffice", "program");
        foreach (var name in new[] { "soffice.com", "soffice.exe" })
        {
            var path = Path.Combine(root, name);
            if (File.Exists(path)) return path;
        }
        return Path.Combine(root, "soffice.exe");
    }

    private static string PrepareOutput(string outputPath, string extension)
    {
        var output = Path.GetFullPath(outputPath);
        if (!output.EndsWith(extension, StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException($"Output must use {extension}.", nameof(outputPath));
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        return output;
    }

    private static void CommitTransactional(string source, string output)
    {
        var staged = output + "." + Guid.NewGuid().ToString("N") + ".staged";
        File.Copy(source, staged, true);
        try
        {
            if (File.Exists(output)) File.Replace(staged, output, null, true);
            else File.Move(staged, output);
        }
        finally { try { if (File.Exists(staged)) File.Delete(staged); } catch { } }
    }

    private static void AppendInlineRow(StringBuilder rows, int row, string value) =>
        rows.Append("<row r=\"").Append(row).Append("\"><c r=\"A").Append(row).Append("\" t=\"inlineStr\"><is><t xml:space=\"preserve\">")
            .Append(Xml(value)).Append("</t></is></c></row>");

    private static void WriteEntry(ZipArchive archive, string name, string content)
    {
        var entry = archive.CreateEntry(name, CompressionLevel.Optimal);
        using var stream = entry.Open();
        using var writer = new StreamWriter(stream, new UTF8Encoding(false));
        writer.Write(content.Trim());
    }

    private static void WriteBinaryEntry(ZipArchive archive, string name, byte[] bytes)
    {
        var entry = archive.CreateEntry(name, CompressionLevel.Optimal);
        using var stream = entry.Open();
        stream.Write(bytes, 0, bytes.Length);
    }

    private static string Xml(string value) => SecurityElement.Escape(value) ?? string.Empty;

    private static (long X, long Y, long Cx, long Cy) Fit(int width, int height, long slideCx, long slideCy)
    {
        var scale = Math.Min((double)slideCx / Math.Max(1, width), (double)slideCy / Math.Max(1, height));
        var cx = (long)Math.Round(width * scale);
        var cy = (long)Math.Round(height * scale);
        return ((slideCx - cx) / 2, (slideCy - cy) / 2, cx, cy);
    }

    private static string SlideXml(int number, long x, long y, long cx, long cy) => $"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld><p:spTree>
            <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
            <p:pic><p:nvPicPr><p:cNvPr id="2" name="PDF page {number}"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>
          </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """;

    private static string SlideLayoutXml() => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sldLayout>
        """;

    private static string SlideMasterXml() => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld name="AsantePDF"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>
          <p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst>
        </p:sldMaster>
        """;

    private static string ThemeXml() => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="AsantePDF">
          <a:themeElements>
            <a:clrScheme name="AsantePDF"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="1F2937"/></a:dk2><a:lt2><a:srgbClr val="F3F4F6"/></a:lt2><a:accent1><a:srgbClr val="2563EB"/></a:accent1><a:accent2><a:srgbClr val="DC2626"/></a:accent2><a:accent3><a:srgbClr val="059669"/></a:accent3><a:accent4><a:srgbClr val="7C3AED"/></a:accent4><a:accent5><a:srgbClr val="D97706"/></a:accent5><a:accent6><a:srgbClr val="0891B2"/></a:accent6><a:hlink><a:srgbClr val="0000FF"/></a:hlink><a:folHlink><a:srgbClr val="800080"/></a:folHlink></a:clrScheme>
            <a:fontScheme name="AsantePDF"><a:majorFont><a:latin typeface="Segoe UI"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Segoe UI"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>
            <a:fmtScheme name="AsantePDF"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """;
}
