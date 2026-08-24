param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
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

$coreModel = Join-Path $SourceRoot 'src\PdfRescue.Core\Models\PdfSecurityPermissions.cs'
Write-Text $coreModel @'
namespace PdfRescue.Core.Models;

public enum PdfPrintPermission
{
    None,
    LowResolution,
    Full
}

public enum PdfModifyPermission
{
    None,
    Assembly,
    Form,
    Annotate,
    All
}

public sealed record PdfSecurityPermissions(
    PdfPrintPermission Printing,
    PdfModifyPermission Modification,
    bool AllowExtraction)
{
    public static PdfSecurityPermissions FullyPermissive { get; } =
        new(PdfPrintPermission.Full, PdfModifyPermission.All, true);
}
'@

$interfacePath = Join-Path $SourceRoot 'src\PdfRescue.Core\Services\IPdfOperations.cs'
Replace-Exact $interfacePath @'
    Task ProtectAsync(string input, string userPassword, string ownerPassword, string output, CancellationToken cancellationToken = default);
'@ @'
    Task ProtectAsync(string input, string userPassword, string ownerPassword, string output, CancellationToken cancellationToken = default);
    Task ProtectWithPermissionsAsync(string input, string userPassword, string ownerPassword, PdfSecurityPermissions permissions, string output, CancellationToken cancellationToken = default);
'@ 'permission-aware protection interface'

$qpdfPath = Join-Path $SourceRoot 'src\PdfRescue.Infrastructure\Qpdf\QpdfOperations.cs'
Replace-Between $qpdfPath '    public Task ProtectAsync(' '    public Task DecryptAsync(' @'
    public Task ProtectAsync(
        string input,
        string userPassword,
        string ownerPassword,
        string output,
        CancellationToken cancellationToken = default) =>
        ProtectWithPermissionsAsync(
            input,
            userPassword,
            ownerPassword,
            PdfSecurityPermissions.FullyPermissive,
            output,
            cancellationToken);

    public Task ProtectWithPermissionsAsync(
        string input,
        string userPassword,
        string ownerPassword,
        PdfSecurityPermissions permissions,
        string output,
        CancellationToken cancellationToken = default)
    {
        ValidateInput(input);
        ValidateOutput(output);
        ValidateDistinctOutput(input, output);
        ArgumentNullException.ThrowIfNull(permissions);
        if (string.IsNullOrEmpty(userPassword))
            throw new ArgumentException("An opening password is required.", nameof(userPassword));
        if (string.IsNullOrEmpty(ownerPassword))
            throw new ArgumentException("An owner password is required.", nameof(ownerPassword));

        var print = permissions.Printing switch
        {
            PdfPrintPermission.None => "none",
            PdfPrintPermission.LowResolution => "low",
            _ => "full"
        };
        var modify = permissions.Modification switch
        {
            PdfModifyPermission.None => "none",
            PdfModifyPermission.Assembly => "assembly",
            PdfModifyPermission.Form => "form",
            PdfModifyPermission.Annotate => "annotate",
            _ => "all"
        };

        return RunSensitiveWriteAsync(
            [
                Path.GetFullPath(input),
                Path.GetFullPath(output),
                "--encrypt",
                $"--user-password={userPassword}",
                $"--owner-password={ownerPassword}",
                "--bits=256",
                $"--print={print}",
                $"--modify={modify}",
                $"--extract={(permissions.AllowExtraction ? "y" : "n")}",
                "--accessibility=y",
                "--"
            ],
            output,
            cancellationToken);
    }

'@ 'permission-aware qpdf protection'

$testPath = Join-Path $SourceRoot 'tests\PdfRescue.SmokeTests\Program.cs'
Replace-Exact $testPath @'
        await operations.ProtectAsync(input, "very secret", "owner secret", output);
'@ @'
        await operations.ProtectWithPermissionsAsync(
            input,
            "very secret",
            "owner secret",
            new PdfSecurityPermissions(PdfPrintPermission.LowResolution, PdfModifyPermission.Form, false),
            output);
'@ 'security smoke operation'
Replace-Exact $testPath @'
        Assert(runner.SensitiveArguments.Any(line => line == "--owner-password=owner secret"),
            "The temporary qpdf argument file should contain the owner password.");
'@ @'
        Assert(runner.SensitiveArguments.Any(line => line == "--owner-password=owner secret"),
            "The temporary qpdf argument file should contain the owner password.");
        Assert(runner.SensitiveArguments.Any(line => line == "--print=low"),
            "Protection should pass the selected printing permission through qpdf.");
        Assert(runner.SensitiveArguments.Any(line => line == "--modify=form"),
            "Protection should pass the selected modification permission through qpdf.");
        Assert(runner.SensitiveArguments.Any(line => line == "--extract=n"),
            "Protection should pass the selected extraction permission through qpdf.");
'@ 'security permission smoke assertions'

$configPath = Join-Path $SourceRoot 'src\PdfRescue.App\ToolConfigurationDialogs.cs'
Replace-Exact $configPath 'internal static class ToolConfigurationDialogs' 'internal static partial class ToolConfigurationDialogs' 'configuration dialog partial class'

$advancedConfigPath = Join-Path $SourceRoot 'src\PdfRescue.App\ToolConfigurationDialogs.Advanced.cs'
Write-Text $advancedConfigPath @'
using System.IO;
using System.Security.Cryptography;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

internal enum PdfConversionKind
{
    Word,
    Excel,
    PowerPoint
}

internal enum PageImageFormat
{
    Png,
    Jpeg
}

internal sealed record PdfConversionDialogResult(
    PdfConversionKind Kind,
    string LanguageId,
    IReadOnlyList<int> PagePositions,
    uint RenderWidth,
    string OutputPath);

internal sealed record PageImageExportDialogResult(
    PageImageFormat Format,
    IReadOnlyList<int> PagePositions,
    uint RenderWidth,
    int JpegQuality,
    string OutputBasePath);

internal sealed record ProtectDialogResult(
    string UserPassword,
    string OwnerPassword,
    PdfSecurityPermissions Permissions,
    string OutputPath);

internal sealed record UnlockDialogResult(string InputPath, string Password, string OutputPath);
internal sealed record OfficeToPdfDialogResult(string InputPath, string OutputPath);

internal static partial class ToolConfigurationDialogs
{
    private sealed record LabelValue<T>(string Label, T Value, string Detail = "")
    {
        public override string ToString() => Label;
    }

    public static PdfConversionDialogResult? ShowPdfConversion(
        Window owner,
        string sourcePath,
        int pageCount,
        IReadOnlyList<OcrLanguageOption> languages,
        PdfConversionKind defaultKind)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(owner, "Convert PDF", "Choose the output format and only the settings that apply to it.", 690, 680, out var body, out var actions);
        body.Children.Add(FieldLabel("Input PDF"));
        body.Children.Add(ReadOnlyPathBox($"{source}   •   {pageCount:N0} pages"));

        body.Children.Add(FieldLabel("Output format", 18));
        var format = CreateComboBox();
        var formats = new[]
        {
            new LabelValue<PdfConversionKind>("Word document (.docx)", PdfConversionKind.Word, "Recover page text with local OCR and preserve page breaks."),
            new LabelValue<PdfConversionKind>("Excel workbook (.xlsx)", PdfConversionKind.Excel, "Recover page text with local OCR into a simple workbook."),
            new LabelValue<PdfConversionKind>("PowerPoint presentation (.pptx)", PdfConversionKind.PowerPoint, "Render each selected PDF page as a slide image.")
        };
        format.ItemsSource = formats;
        format.SelectedIndex = Array.FindIndex(formats, item => item.Value == defaultKind);
        body.Children.Add(format);
        var formatNote = MutedText("");
        formatNote.Margin = new Thickness(0, 7, 0, 0);
        formatNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(formatNote);

        body.Children.Add(FieldLabel("Pages", 18));
        var allPages = CreateRadio($"All pages ({pageCount:N0})", true);
        var customPages = CreateRadio("Custom page range", false);
        allPages.GroupName = customPages.GroupName = "ConvertPageScope";
        body.Children.Add(allPages);
        body.Children.Add(customPages);
        var range = CreateTextBox(pageCount > 1 ? $"1-{pageCount}" : "1");
        range.Margin = new Thickness(24, 5, 0, 0);
        range.IsEnabled = false;
        range.Opacity = 0.55;
        body.Children.Add(range);
        var rangeHint = MutedText("Examples: 1-3,5,8-10. Page numbers follow the current working layout.");
        rangeHint.Margin = new Thickness(24, 5, 0, 0);
        rangeHint.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(rangeHint);
        customPages.Checked += (_, _) => { range.IsEnabled = true; range.Opacity = 1; };
        allPages.Checked += (_, _) => { range.IsEnabled = false; range.Opacity = 0.55; };

        body.Children.Add(FieldLabel("OCR language for Word / Excel", 18));
        var language = CreateComboBox();
        language.ItemsSource = languages;
        language.SelectedIndex = 0;
        body.Children.Add(language);
        var languageNote = MutedText(languages.FirstOrDefault()?.Detail ?? "Automatic local OCR.");
        languageNote.Margin = new Thickness(0, 7, 0, 0);
        languageNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(languageNote);
        language.SelectionChanged += (_, _) =>
        {
            if (language.SelectedItem is OcrLanguageOption selected) languageNote.Text = selected.Detail;
        };

        body.Children.Add(FieldLabel("PowerPoint render quality", 18));
        var quality = CreateComboBox();
        var qualities = new[]
        {
            new LabelValue<uint>("Standard · 1200 px", 1200, "Smaller presentation and faster export."),
            new LabelValue<uint>("High · 1800 px", 1800, "Good default for normal viewing and projection."),
            new LabelValue<uint>("Very high · 2400 px", 2400, "Sharper page images with a larger presentation file.")
        };
        quality.ItemsSource = qualities;
        quality.SelectedIndex = 1;
        body.Children.Add(quality);
        var qualityNote = MutedText(qualities[1].Detail);
        qualityNote.Margin = new Thickness(0, 7, 0, 0);
        qualityNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(qualityNote);
        quality.SelectionChanged += (_, _) =>
        {
            if (quality.SelectedItem is LabelValue<uint> selected) qualityNote.Text = selected.Detail;
        };

        body.Children.Add(FieldLabel("Output location", 18));
        var outputGrid = new Grid();
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var output = CreateTextBox(ConversionSuggestion(source, defaultKind));
        outputGrid.Children.Add(output);
        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        Grid.SetColumn(browse, 1);
        outputGrid.Children.Add(browse);
        body.Children.Add(outputGrid);

        void Refresh(bool resetPath)
        {
            var selected = format.SelectedItem as LabelValue<PdfConversionKind> ?? formats[0];
            formatNote.Text = selected.Detail;
            var textBased = selected.Value is PdfConversionKind.Word or PdfConversionKind.Excel;
            language.IsEnabled = textBased;
            language.Opacity = textBased ? 1 : 0.55;
            languageNote.Opacity = textBased ? 1 : 0.55;
            quality.IsEnabled = !textBased;
            quality.Opacity = textBased ? 0.55 : 1;
            qualityNote.Opacity = textBased ? 0.55 : 1;
            if (resetPath) output.Text = ConversionSuggestion(source, selected.Value);
        }
        format.SelectionChanged += (_, _) => Refresh(true);
        Refresh(false);

        browse.Click += (_, _) =>
        {
            var selected = (format.SelectedItem as LabelValue<PdfConversionKind>)?.Value ?? defaultKind;
            var (ext, filterText) = ConversionFileInfo(selected);
            var dialog = new SaveFileDialog
            {
                Title = "Save converted document",
                Filter = filterText,
                AddExtension = true,
                DefaultExt = ext,
                OverwritePrompt = true,
                FileName = Path.GetFileName(output.Text)
            };
            var dir = Path.GetDirectoryName(output.Text);
            if (!string.IsNullOrWhiteSpace(dir) && Directory.Exists(dir)) dialog.InitialDirectory = dir;
            if (dialog.ShowDialog(window) == true) output.Text = dialog.FileName;
        };

        PdfConversionDialogResult? result = null;
        var run = CreateButton("Convert", true);
        run.Click += (_, _) =>
        {
            var selected = (format.SelectedItem as LabelValue<PdfConversionKind>)?.Value ?? defaultKind;
            int[] positions;
            if (customPages.IsChecked == true)
            {
                if (!PageScopeParser.TryParse(range.Text, pageCount, out positions, out var error))
                {
                    MessageBox.Show(window, error, "Convert PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
            }
            else positions = Enumerable.Range(1, pageCount).ToArray();

            var languageId = (language.SelectedItem as OcrLanguageOption)?.Id ?? "auto";
            var renderWidth = (quality.SelectedItem as LabelValue<uint>)?.Value ?? 1800u;
            var (extension, _) = ConversionFileInfo(selected);
            var outputPath = ValidateOutputPath(window, source, output.Text, extension);
            if (outputPath is null) return;
            result = new PdfConversionDialogResult(selected, languageId, positions, renderWidth, outputPath);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static PageImageExportDialogResult? ShowPageImageExport(Window owner, string sourcePath, int pageCount)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(owner, "Export Pages as Images", "Choose page scope, image format and render quality before exporting.", 660, 650, out var body, out var actions);
        body.Children.Add(FieldLabel("Input PDF"));
        body.Children.Add(ReadOnlyPathBox($"{source}   •   {pageCount:N0} pages"));

        body.Children.Add(FieldLabel("Pages", 18));
        var allPages = CreateRadio($"All pages ({pageCount:N0})", true);
        var custom = CreateRadio("Custom page range", false);
        allPages.GroupName = custom.GroupName = "ImageExportScope";
        body.Children.Add(allPages);
        body.Children.Add(custom);
        var range = CreateTextBox(pageCount > 1 ? $"1-{pageCount}" : "1");
        range.Margin = new Thickness(24, 5, 0, 0);
        range.IsEnabled = false;
        range.Opacity = 0.55;
        body.Children.Add(range);
        custom.Checked += (_, _) => { range.IsEnabled = true; range.Opacity = 1; };
        allPages.Checked += (_, _) => { range.IsEnabled = false; range.Opacity = 0.55; };

        body.Children.Add(FieldLabel("Image format", 18));
        var format = CreateComboBox();
        var formats = new[]
        {
            new LabelValue<PageImageFormat>("PNG · lossless", PageImageFormat.Png),
            new LabelValue<PageImageFormat>("JPEG · smaller files", PageImageFormat.Jpeg)
        };
        format.ItemsSource = formats;
        format.SelectedIndex = 0;
        body.Children.Add(format);

        body.Children.Add(FieldLabel("Render quality", 18));
        var render = CreateComboBox();
        var renders = new[]
        {
            new LabelValue<uint>("Standard · 1200 px", 1200),
            new LabelValue<uint>("High · 1800 px", 1800),
            new LabelValue<uint>("Very high · 2400 px", 2400)
        };
        render.ItemsSource = renders;
        render.SelectedIndex = 1;
        body.Children.Add(render);

        body.Children.Add(FieldLabel("JPEG quality", 18));
        var jpeg = CreateComboBox();
        var jpegChoices = new[]
        {
            new LabelValue<int>("Smaller · 75", 75),
            new LabelValue<int>("High · 90", 90),
            new LabelValue<int>("Maximum · 100", 100)
        };
        jpeg.ItemsSource = jpegChoices;
        jpeg.SelectedIndex = 1;
        body.Children.Add(jpeg);
        var jpegHint = MutedText("JPEG quality is ignored for PNG exports.");
        jpegHint.Margin = new Thickness(0, 6, 0, 0);
        body.Children.Add(jpegHint);

        body.Children.Add(FieldLabel("Output base file", 18));
        var outputGrid = new Grid();
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var output = CreateTextBox(Path.Combine(Path.GetDirectoryName(source)!, Path.GetFileNameWithoutExtension(source) + "-export.png"));
        outputGrid.Children.Add(output);
        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        Grid.SetColumn(browse, 1);
        outputGrid.Children.Add(browse);
        body.Children.Add(outputGrid);
        var naming = MutedText("AsantePDF appends the working page number, for example -page-002.png.");
        naming.Margin = new Thickness(0, 6, 0, 0);
        naming.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(naming);

        void RefreshFormat(bool resetPath)
        {
            var selected = (format.SelectedItem as LabelValue<PageImageFormat>)?.Value ?? PageImageFormat.Png;
            jpeg.IsEnabled = selected == PageImageFormat.Jpeg;
            jpeg.Opacity = jpeg.IsEnabled ? 1 : 0.55;
            jpegHint.Opacity = jpeg.IsEnabled ? 1 : 0.55;
            if (resetPath)
            {
                var ext = selected == PageImageFormat.Png ? ".png" : ".jpg";
                output.Text = Path.ChangeExtension(output.Text, ext);
            }
        }
        format.SelectionChanged += (_, _) => RefreshFormat(true);
        RefreshFormat(false);

        browse.Click += (_, _) =>
        {
            var selected = (format.SelectedItem as LabelValue<PageImageFormat>)?.Value ?? PageImageFormat.Png;
            var ext = selected == PageImageFormat.Png ? ".png" : ".jpg";
            var dialog = new SaveFileDialog
            {
                Title = "Choose image export base file",
                Filter = selected == PageImageFormat.Png ? "PNG image (*.png)|*.png" : "JPEG image (*.jpg)|*.jpg;*.jpeg",
                AddExtension = true,
                DefaultExt = ext,
                OverwritePrompt = false,
                FileName = Path.GetFileName(output.Text)
            };
            var dir = Path.GetDirectoryName(output.Text);
            if (!string.IsNullOrWhiteSpace(dir) && Directory.Exists(dir)) dialog.InitialDirectory = dir;
            if (dialog.ShowDialog(window) == true) output.Text = dialog.FileName;
        };

        PageImageExportDialogResult? result = null;
        var run = CreateButton("Export Images", true);
        run.Click += (_, _) =>
        {
            int[] positions;
            if (custom.IsChecked == true)
            {
                if (!PageScopeParser.TryParse(range.Text, pageCount, out positions, out var error))
                {
                    MessageBox.Show(window, error, "Export Pages", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
            }
            else positions = Enumerable.Range(1, pageCount).ToArray();

            var imageFormat = (format.SelectedItem as LabelValue<PageImageFormat>)?.Value ?? PageImageFormat.Png;
            var ext = imageFormat == PageImageFormat.Png ? ".png" : ".jpg";
            var outputPath = ValidateOutputPath(window, source, output.Text, ext);
            if (outputPath is null) return;
            result = new PageImageExportDialogResult(
                imageFormat,
                positions,
                (render.SelectedItem as LabelValue<uint>)?.Value ?? 1800u,
                (jpeg.SelectedItem as LabelValue<int>)?.Value ?? 90,
                outputPath);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static ProtectDialogResult? ShowProtect(Window owner, string sourcePath)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(owner, "Protect PDF", "Use 256-bit encryption and choose the permissions readers should enforce.", 660, 700, out var body, out var actions);
        body.Children.Add(FieldLabel("Input PDF"));
        body.Children.Add(ReadOnlyPathBox(source));

        body.Children.Add(FieldLabel("Opening password", 18));
        var user = new PasswordBox { MinHeight = 34, Padding = new Thickness(8, 5, 8, 5) };
        body.Children.Add(user);
        body.Children.Add(FieldLabel("Confirm opening password", 12));
        var confirm = new PasswordBox { MinHeight = 34, Padding = new Thickness(8, 5, 8, 5) };
        body.Children.Add(confirm);
        body.Children.Add(FieldLabel("Owner password · optional", 12));
        var ownerPassword = new PasswordBox { MinHeight = 34, Padding = new Thickness(8, 5, 8, 5) };
        body.Children.Add(ownerPassword);
        var ownerHint = MutedText("If left blank, AsantePDF generates a strong internal owner password. Passwords are passed to qpdf through a temporary argument file, not the normal process command line.");
        ownerHint.Margin = new Thickness(0, 6, 0, 0);
        ownerHint.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(ownerHint);

        body.Children.Add(FieldLabel("Printing", 18));
        var printing = CreateComboBox();
        printing.ItemsSource = new[]
        {
            new LabelValue<PdfPrintPermission>("Full printing", PdfPrintPermission.Full),
            new LabelValue<PdfPrintPermission>("Low-resolution printing only", PdfPrintPermission.LowResolution),
            new LabelValue<PdfPrintPermission>("No printing", PdfPrintPermission.None)
        };
        printing.SelectedIndex = 0;
        body.Children.Add(printing);

        body.Children.Add(FieldLabel("Document changes", 18));
        var modify = CreateComboBox();
        modify.ItemsSource = new[]
        {
            new LabelValue<PdfModifyPermission>("Allow all changes", PdfModifyPermission.All),
            new LabelValue<PdfModifyPermission>("Annotations, forms and signing", PdfModifyPermission.Annotate),
            new LabelValue<PdfModifyPermission>("Form filling and signing", PdfModifyPermission.Form),
            new LabelValue<PdfModifyPermission>("Page assembly only", PdfModifyPermission.Assembly),
            new LabelValue<PdfModifyPermission>("No document changes", PdfModifyPermission.None)
        };
        modify.SelectedIndex = 0;
        body.Children.Add(modify);

        var extraction = new CheckBox
        {
            Content = "Allow text and image extraction / copying",
            IsChecked = true,
            Margin = new Thickness(0, 16, 0, 0)
        };
        body.Children.Add(extraction);
        var permissionsNote = MutedText("Accessibility remains enabled. PDF permission restrictions depend on the PDF reader and may not be enforced by every application.");
        permissionsNote.Margin = new Thickness(0, 7, 0, 0);
        permissionsNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(permissionsNote);

        body.Children.Add(FieldLabel("Output PDF", 18));
        var output = CreatePathPicker(owner, "Save protected PDF", SuggestedSibling(source, "protected"), "PDF files (*.pdf)|*.pdf", ".pdf");
        body.Children.Add(output.Container);

        ProtectDialogResult? result = null;
        var run = CreateButton("Protect PDF", true);
        run.Click += (_, _) =>
        {
            if (string.IsNullOrEmpty(user.Password))
            {
                MessageBox.Show(window, "Enter an opening password.", "Protect PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            if (!string.Equals(user.Password, confirm.Password, StringComparison.Ordinal))
            {
                MessageBox.Show(window, "The opening passwords do not match.", "Protect PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            var outputPath = ValidateOutputPath(window, source, output.TextBox.Text, ".pdf");
            if (outputPath is null) return;
            var ownerValue = string.IsNullOrEmpty(ownerPassword.Password)
                ? Convert.ToHexString(RandomNumberGenerator.GetBytes(24))
                : ownerPassword.Password;
            result = new ProtectDialogResult(
                user.Password,
                ownerValue,
                new PdfSecurityPermissions(
                    (printing.SelectedItem as LabelValue<PdfPrintPermission>)?.Value ?? PdfPrintPermission.Full,
                    (modify.SelectedItem as LabelValue<PdfModifyPermission>)?.Value ?? PdfModifyPermission.All,
                    extraction.IsChecked == true),
                outputPath);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static UnlockDialogResult? ShowUnlock(Window owner, string? initialSource)
    {
        var window = CreateShell(owner, "Unlock PDF", "Choose the protected PDF, enter its password and save a separate unlocked copy.", 620, 520, out var body, out var actions);
        body.Children.Add(FieldLabel("Protected PDF"));
        var input = CreateOpenPathPicker(window, "Choose protected PDF", initialSource ?? string.Empty, "PDF files (*.pdf)|*.pdf");
        body.Children.Add(input.Container);
        body.Children.Add(FieldLabel("Current PDF password", 18));
        var password = new PasswordBox { MinHeight = 34, Padding = new Thickness(8, 5, 8, 5) };
        body.Children.Add(password);
        body.Children.Add(FieldLabel("Output PDF", 18));
        var initialOutput = !string.IsNullOrWhiteSpace(initialSource)
            ? SuggestedSibling(Path.GetFullPath(initialSource), "unlocked")
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "unlocked.pdf");
        var output = CreatePathPicker(owner, "Save unlocked PDF", initialOutput, "PDF files (*.pdf)|*.pdf", ".pdf");
        body.Children.Add(output.Container);

        UnlockDialogResult? result = null;
        var run = CreateButton("Unlock PDF", true);
        run.Click += (_, _) =>
        {
            var source = ValidateInputFile(window, input.TextBox.Text, ".pdf");
            if (source is null) return;
            if (string.IsNullOrEmpty(password.Password))
            {
                MessageBox.Show(window, "Enter the current PDF password.", "Unlock PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            var outputPath = ValidateOutputPath(window, source, output.TextBox.Text, ".pdf");
            if (outputPath is null) return;
            result = new UnlockDialogResult(source, password.Password, outputPath);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static OfficeToPdfDialogResult? ShowOfficeToPdf(Window owner)
    {
        var window = CreateShell(owner, "Office to PDF", "Choose an Office document and the PDF copy to create.", 620, 470, out var body, out var actions);
        body.Children.Add(FieldLabel("Office document"));
        const string filter = "Office documents|*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.odt;*.ods;*.odp;*.rtf|All files|*.*";
        var input = CreateOpenPathPicker(window, "Choose Office document", string.Empty, filter);
        body.Children.Add(input.Container);
        body.Children.Add(FieldLabel("Output PDF", 18));
        var output = CreatePathPicker(owner, "Save converted PDF", Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "converted.pdf"), "PDF files (*.pdf)|*.pdf", ".pdf");
        body.Children.Add(output.Container);
        input.TextBox.TextChanged += (_, _) =>
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(input.TextBox.Text))
                    output.TextBox.Text = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(input.TextBox.Text))!, Path.GetFileNameWithoutExtension(input.TextBox.Text) + ".pdf");
            }
            catch { }
        };

        OfficeToPdfDialogResult? result = null;
        var run = CreateButton("Convert to PDF", true);
        run.Click += (_, _) =>
        {
            var source = ValidateInputFile(window, input.TextBox.Text, null);
            if (source is null) return;
            var outputPath = NormalizeRequiredPath(window, output.TextBox.Text, ".pdf");
            if (outputPath is null) return;
            if (string.Equals(source, outputPath, StringComparison.OrdinalIgnoreCase))
            {
                MessageBox.Show(window, "Choose a different output file.", "Office to PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            result = new OfficeToPdfDialogResult(source, outputPath);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    private sealed record OpenPathPicker(Grid Container, TextBox TextBox);

    private static OpenPathPicker CreateOpenPathPicker(Window owner, string title, string initialPath, string filter)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var box = CreateTextBox(initialPath);
        grid.Children.Add(box);
        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        browse.Click += (_, _) =>
        {
            var dialog = new OpenFileDialog { Title = title, Filter = filter, CheckFileExists = true, Multiselect = false };
            var dir = string.IsNullOrWhiteSpace(box.Text) ? null : Path.GetDirectoryName(box.Text);
            if (!string.IsNullOrWhiteSpace(dir) && Directory.Exists(dir)) dialog.InitialDirectory = dir;
            if (dialog.ShowDialog(owner) == true) box.Text = dialog.FileName;
        };
        Grid.SetColumn(browse, 1);
        grid.Children.Add(browse);
        return new OpenPathPicker(grid, box);
    }

    private static string? ValidateInputFile(Window owner, string value, string? requiredExtension)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(value)) throw new FileNotFoundException("Choose an input file.");
            var path = Path.GetFullPath(value.Trim());
            if (!File.Exists(path)) throw new FileNotFoundException("The selected input file does not exist.", path);
            if (!string.IsNullOrWhiteSpace(requiredExtension) && !path.EndsWith(requiredExtension, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"The input must be a {requiredExtension} file.");
            return path;
        }
        catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException or IOException)
        {
            MessageBox.Show(owner, ex.Message, owner.Title, MessageBoxButton.OK, MessageBoxImage.Information);
            return null;
        }
    }

    private static string ConversionSuggestion(string source, PdfConversionKind kind)
    {
        var (extension, _) = ConversionFileInfo(kind);
        return Path.Combine(Path.GetDirectoryName(source)!, Path.GetFileNameWithoutExtension(source) + extension);
    }

    private static (string Extension, string Filter) ConversionFileInfo(PdfConversionKind kind) => kind switch
    {
        PdfConversionKind.Excel => (".xlsx", "Excel workbook (*.xlsx)|*.xlsx"),
        PdfConversionKind.PowerPoint => (".pptx", "PowerPoint presentation (*.pptx)|*.pptx"),
        _ => (".docx", "Word document (*.docx)|*.docx")
    };
}
'@

$handlersPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ConfiguredTools.cs'
Write-Text $handlersPath @'
using System.IO;
using System.Windows.Media.Imaging;
using PdfRescue.App.Services;
using PdfRescue.Core.Jobs;

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
'@

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Between $mainPath '    private async void Protect_Click' '    private async void OfficeToPdf_Click' @'
    private async void Protect_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredProtectAsync();

    private async void Unlock_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredUnlockAsync();

'@ 'protect/unlock configured handlers'
Replace-Between $mainPath '    private async void OfficeToPdf_Click' '    private async void PdfToWord_Click' @'
    private async void OfficeToPdf_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredOfficeToPdfAsync();

'@ 'Office-to-PDF configured handler'
Replace-Between $mainPath '    private async void PdfToWord_Click' '    private async Task<IReadOnlyList<string>> RecognizeWorkingPagesAsync' @'
    private async void PdfToWord_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredPdfConversionAsync(PdfConversionKind.Word);

    private async void PdfToExcel_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredPdfConversionAsync(PdfConversionKind.Excel);

    private async void PdfToPowerPoint_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredPdfConversionAsync(PdfConversionKind.PowerPoint);

'@ 'PDF conversion configured handlers'
Replace-Between $mainPath '    private async void ExportPagesAsImages_Click' '    private async void OcrPdf_Click' @'
    private async void ExportPagesAsImages_Click(object sender, RoutedEventArgs e) =>
        await RunConfiguredPageImageExportAsync();

'@ 'page-image export configured handler'
Replace-Between $mainPath '    private Window BuildPromptWindow' '    private sealed record PageState' @'
    private Window BuildPromptWindow(string title, string label, FrameworkElement control, out Button okButton)
    {
        var background = Application.Current.TryFindResource("AppBackground") as Brush ?? new SolidColorBrush(Color.FromRgb(9, 19, 31));
        var primary = Application.Current.TryFindResource("PrimaryTextBrush") as Brush ?? Brushes.White;
        var muted = Application.Current.TryFindResource("MutedTextBrush") as Brush ?? Brushes.LightGray;
        var window = new Window
        {
            Title = $"AsantePDF · {title}",
            Owner = this,
            Width = 480,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Background = background,
            Foreground = primary,
            ShowInTaskbar = false
        };
        var stack = new StackPanel { Margin = new Thickness(22) };
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 20,
            FontWeight = FontWeights.SemiBold,
            Foreground = primary,
            Margin = new Thickness(0, 0, 0, 6)
        });
        stack.Children.Add(new TextBlock
        {
            Text = label,
            Foreground = muted,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 12)
        });
        stack.Children.Add(control);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 8, 0, 0) };
        var cancel = new Button { Content = "Cancel", IsCancel = true, MinWidth = 88, Margin = new Thickness(4, 0, 0, 0) };
        okButton = new Button { Content = "OK", IsDefault = true, MinWidth = 88, Margin = new Thickness(4, 0, 0, 0) };
        if (Application.Current.TryFindResource("FlatButtonStyle") is Style flat) cancel.Style = flat;
        if (Application.Current.TryFindResource("PrimaryButtonStyle") is Style primaryStyle) okButton.Style = primaryStyle;
        buttons.Children.Add(cancel);
        buttons.Children.Add(okButton);
        stack.Children.Add(buttons);
        window.Content = stack;
        return window;
    }

'@ 'dark reusable prompt shell'

Write-Host 'Advanced configuration dialogs, conversion/export scope, security permissions and modal styling applied.' -ForegroundColor Green
