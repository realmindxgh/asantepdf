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