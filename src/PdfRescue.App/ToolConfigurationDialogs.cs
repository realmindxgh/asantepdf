using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

internal enum SplitRuleMode
{
    FixedChunks,
    ExplicitGroups
}

internal sealed record CompressionDialogResult(PdfCompressionProfile Profile, string OutputPath);
internal sealed record SplitDialogResult(
    SplitRuleMode Mode,
    int PagesPerFile,
    IReadOnlyList<string> PageGroups,
    string OutputBase);
internal sealed record MergeDialogResult(IReadOnlyList<string> Files, string OutputPath);
internal enum OcrOutputKind
{
    SearchablePdf,
    PlainText
}
internal sealed record OcrDialogResult(
    OcrOutputKind OutputKind,
    string LanguageId,
    IReadOnlyList<int> PagePositions,
    string OutputPath);

internal static class ToolConfigurationDialogs
{
    private sealed record CompressionChoice(PdfCompressionProfile Profile, string Label, string Description)
    {
        public override string ToString() => Label;
    }

    public static CompressionDialogResult? ShowCompression(Window owner, string sourcePath)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(
            owner,
            "Compress PDF",
            "Choose a compression profile and output copy. The original PDF will not be overwritten.",
            610,
            500,
            out var body,
            out var actions);

        body.Children.Add(FieldLabel("Source PDF"));
        body.Children.Add(ReadOnlyPathBox(source));
        body.Children.Add(FieldLabel("Compression profile", top: 18));

        var choices = new[]
        {
            new CompressionChoice(PdfCompressionProfile.Lossless, "Lossless", "Recompress streams and tidy structure without deliberately reducing image quality."),
            new CompressionChoice(PdfCompressionProfile.Balanced, "Balanced", "Optimize images at about 75% JPEG quality. Good default for everyday documents."),
            new CompressionChoice(PdfCompressionProfile.Strong, "Strong", "Use more aggressive image optimization at about 55% JPEG quality for smaller files.")
        };
        var profile = CreateComboBox();
        profile.ItemsSource = choices;
        profile.SelectedIndex = 1;
        body.Children.Add(profile);

        var description = MutedText(choices[1].Description);
        description.Margin = new Thickness(0, 7, 0, 0);
        description.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(description);
        profile.SelectionChanged += (_, _) =>
        {
            if (profile.SelectedItem is CompressionChoice selected)
                description.Text = selected.Description;
        };

        body.Children.Add(FieldLabel("Output PDF", top: 18));
        var output = CreatePathPicker(
            owner,
            "Save compressed PDF",
            SuggestedSibling(source, "compressed"),
            "PDF files (*.pdf)|*.pdf",
            ".pdf");
        body.Children.Add(output.Container);

        CompressionDialogResult? result = null;
        var run = CreateButton("Compress PDF", primary: true);
        run.Click += (_, _) =>
        {
            if (profile.SelectedItem is not CompressionChoice selected) return;
            var path = ValidateOutputPath(window, source, output.TextBox.Text, ".pdf");
            if (path is null) return;
            result = new CompressionDialogResult(selected.Profile, path);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static SplitDialogResult? ShowSplit(Window owner, string sourcePath, int pageCount)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(
            owner,
            "Split PDF",
            "Split into fixed-size chunks, or define explicit page groups. Outputs are prepared before they are published.",
            660,
            620,
            out var body,
            out var actions);

        body.Children.Add(FieldLabel("Source PDF"));
        body.Children.Add(ReadOnlyPathBox($"{source}   •   {pageCount:N0} pages"));
        body.Children.Add(FieldLabel("Split rule", top: 18));

        var fixedMode = CreateRadio("Fixed-size chunks", isChecked: true);
        var groupsMode = CreateRadio("Explicit page groups", isChecked: false);
        fixedMode.GroupName = "SplitMode";
        groupsMode.GroupName = "SplitMode";
        body.Children.Add(fixedMode);
        body.Children.Add(groupsMode);

        var chunkPanel = new StackPanel { Margin = new Thickness(24, 5, 0, 0) };
        chunkPanel.Children.Add(MutedText("Pages per output file"));
        var pagesPerFile = CreateTextBox("1");
        pagesPerFile.Width = 110;
        pagesPerFile.HorizontalAlignment = HorizontalAlignment.Left;
        chunkPanel.Children.Add(pagesPerFile);
        body.Children.Add(chunkPanel);

        var groupsPanel = new StackPanel { Margin = new Thickness(24, 5, 0, 0), IsEnabled = false, Opacity = 0.55 };
        groupsPanel.Children.Add(MutedText("Separate output groups with semicolons. Example: 1-3; 4-6; 8,10"));
        var groups = CreateTextBox(pageCount >= 6 ? "1-3; 4-6" : $"1-{Math.Max(1, pageCount)}");
        groups.Margin = new Thickness(0, 6, 0, 0);
        groupsPanel.Children.Add(groups);
        body.Children.Add(groupsPanel);

        void RefreshMode()
        {
            var explicitMode = groupsMode.IsChecked == true;
            chunkPanel.IsEnabled = !explicitMode;
            chunkPanel.Opacity = explicitMode ? 0.55 : 1;
            groupsPanel.IsEnabled = explicitMode;
            groupsPanel.Opacity = explicitMode ? 1 : 0.55;
        }
        fixedMode.Checked += (_, _) => RefreshMode();
        groupsMode.Checked += (_, _) => RefreshMode();

        body.Children.Add(FieldLabel("Output base name", top: 18));
        var output = CreatePathPicker(
            owner,
            "Choose split output base name",
            SuggestedSibling(source, "part"),
            "PDF files (*.pdf)|*.pdf",
            ".pdf");
        body.Children.Add(output.Container);
        var note = MutedText("Fixed chunks use the PDF engine's numbered output. Explicit groups are published as -01, -02, and so on.");
        note.TextWrapping = TextWrapping.Wrap;
        note.Margin = new Thickness(0, 7, 0, 0);
        body.Children.Add(note);

        SplitDialogResult? result = null;
        var run = CreateButton("Split PDF", primary: true);
        run.Click += (_, _) =>
        {
            var outputPath = ValidateOutputPath(window, source, output.TextBox.Text, ".pdf");
            if (outputPath is null) return;

            if (groupsMode.IsChecked == true)
            {
                var parsed = ParsePageGroups(groups.Text, pageCount, out var error);
                if (parsed is null)
                {
                    MessageBox.Show(window, error, "Split PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                result = new SplitDialogResult(SplitRuleMode.ExplicitGroups, 0, parsed, outputPath);
            }
            else
            {
                if (!int.TryParse(pagesPerFile.Text.Trim(), out var value) || value < 1)
                {
                    MessageBox.Show(window, "Pages per file must be a whole number greater than zero.", "Split PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                result = new SplitDialogResult(SplitRuleMode.FixedChunks, value, Array.Empty<string>(), outputPath);
            }
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static MergeDialogResult? ShowMerge(Window owner, IReadOnlyList<string>? initialFiles = null)
    {
        var files = new ObservableCollection<string>();
        foreach (var path in initialFiles ?? Array.Empty<string>())
            AddPdf(files, path);

        var window = CreateShell(
            owner,
            "Merge PDFs",
            "Add PDFs, put them in the exact order you want, then choose the merged output file.",
            720,
            650,
            out var body,
            out var actions);

        var toolbar = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 8) };
        var add = CreateButton("Add PDFs…");
        var remove = CreateButton("Remove");
        var up = CreateButton("Move Up");
        var down = CreateButton("Move Down");
        toolbar.Children.Add(add);
        toolbar.Children.Add(remove);
        toolbar.Children.Add(up);
        toolbar.Children.Add(down);
        body.Children.Add(toolbar);

        var list = new ListBox
        {
            ItemsSource = files,
            MinHeight = 245,
            MaxHeight = 300,
            BorderThickness = new Thickness(1),
            BorderBrush = BrushResource("BorderBrushSoft", Brushes.DimGray),
            Background = BrushResource("PanelBackground", Brushes.Black),
            Padding = new Thickness(6)
        };
        body.Children.Add(list);
        var orderHint = MutedText("Top to bottom is the final PDF page order.");
        orderHint.Margin = new Thickness(0, 6, 0, 0);
        body.Children.Add(orderHint);

        add.Click += (_, _) =>
        {
            var dialog = new OpenFileDialog
            {
                Title = "Add PDFs to merge",
                Filter = "PDF files (*.pdf)|*.pdf",
                Multiselect = true,
                CheckFileExists = true
            };
            if (dialog.ShowDialog(window) != true) return;
            foreach (var path in dialog.FileNames) AddPdf(files, path);
            if (list.SelectedIndex < 0 && files.Count > 0) list.SelectedIndex = files.Count - 1;
        };
        remove.Click += (_, _) =>
        {
            if (list.SelectedItem is not string selected) return;
            var index = list.SelectedIndex;
            files.Remove(selected);
            if (files.Count > 0) list.SelectedIndex = Math.Min(index, files.Count - 1);
        };
        up.Click += (_, _) => MoveSelected(files, list, -1);
        down.Click += (_, _) => MoveSelected(files, list, 1);

        body.Children.Add(FieldLabel("Output PDF", top: 16));
        var defaultOutput = files.Count > 0
            ? Path.Combine(Path.GetDirectoryName(files[0])!, "merged.pdf")
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "merged.pdf");
        var output = CreatePathPicker(owner, "Save merged PDF", defaultOutput, "PDF files (*.pdf)|*.pdf", ".pdf");
        body.Children.Add(output.Container);

        MergeDialogResult? result = null;
        var run = CreateButton("Merge PDFs", primary: true);
        run.Click += (_, _) =>
        {
            var valid = files.Where(File.Exists)
                .Where(path => string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (valid.Length < 2)
            {
                MessageBox.Show(window, "Add at least two different PDF files.", "Merge PDFs", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var path = NormalizeRequiredPath(window, output.TextBox.Text, ".pdf");
            if (path is null) return;
            if (valid.Any(input => string.Equals(Path.GetFullPath(input), path, StringComparison.OrdinalIgnoreCase)))
            {
                MessageBox.Show(window, "The merged output must be a different file from every source PDF.", "Merge PDFs", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            result = new MergeDialogResult(valid, path);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    public static OcrDialogResult? ShowOcr(
        Window owner,
        string sourcePath,
        int pageCount,
        IReadOnlyList<PdfRescue.App.Services.OcrLanguageOption> languageOptions,
        OcrOutputKind defaultOutputKind)
    {
        var source = Path.GetFullPath(sourcePath);
        var window = CreateShell(
            owner,
            "OCR PDF",
            "Choose the recognizer, page scope and local output you actually need. All OCR stays on this computer.",
            680,
            650,
            out var body,
            out var actions);

        body.Children.Add(FieldLabel("Input PDF"));
        body.Children.Add(ReadOnlyPathBox($"{source}   •   {pageCount:N0} pages"));

        body.Children.Add(FieldLabel("OCR language", top: 18));
        var language = CreateComboBox();
        language.ItemsSource = languageOptions;
        language.SelectedIndex = 0;
        body.Children.Add(language);
        var languageDetail = MutedText(languageOptions.FirstOrDefault()?.Detail ?? "No OCR language information is available.");
        languageDetail.TextWrapping = TextWrapping.Wrap;
        languageDetail.Margin = new Thickness(0, 7, 0, 0);
        body.Children.Add(languageDetail);
        language.SelectionChanged += (_, _) =>
        {
            if (language.SelectedItem is PdfRescue.App.Services.OcrLanguageOption option)
                languageDetail.Text = option.Detail;
        };

        body.Children.Add(FieldLabel("Pages", top: 18));
        var allPages = CreateRadio($"All pages ({pageCount:N0})", isChecked: true);
        var customPages = CreateRadio("Custom page range", isChecked: false);
        allPages.GroupName = "OcrPageScope";
        customPages.GroupName = "OcrPageScope";
        body.Children.Add(allPages);
        body.Children.Add(customPages);
        var range = CreateTextBox(pageCount > 1 ? $"1-{pageCount}" : "1");
        range.Margin = new Thickness(24, 5, 0, 0);
        range.IsEnabled = false;
        range.Opacity = 0.55;
        body.Children.Add(range);
        var rangeHint = MutedText("Examples: 1-3,5,8-10. Page numbers refer to the current working page layout.");
        rangeHint.Margin = new Thickness(24, 5, 0, 0);
        rangeHint.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(rangeHint);
        customPages.Checked += (_, _) => { range.IsEnabled = true; range.Opacity = 1; };
        allPages.Checked += (_, _) => { range.IsEnabled = false; range.Opacity = 0.55; };

        body.Children.Add(FieldLabel("Output", top: 18));
        var outputKind = CreateComboBox();
        outputKind.ItemsSource = new[] { "Searchable PDF", "Plain text (.txt)" };
        outputKind.SelectedIndex = defaultOutputKind == OcrOutputKind.SearchablePdf ? 0 : 1;
        body.Children.Add(outputKind);
        var outputNote = MutedText(string.Empty);
        outputNote.Margin = new Thickness(0, 7, 0, 0);
        outputNote.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(outputNote);

        var initialKind = defaultOutputKind;
        string Suggested(OcrOutputKind kind) => kind == OcrOutputKind.SearchablePdf
            ? SuggestedSibling(source, "searchable")
            : Path.Combine(Path.GetDirectoryName(source)!, Path.GetFileNameWithoutExtension(source) + "-ocr.txt");

        body.Children.Add(FieldLabel("Output location", top: 14));
        var outputGrid = new Grid();
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        outputGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var outputBox = CreateTextBox(Suggested(initialKind));
        outputGrid.Children.Add(outputBox);
        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        browse.Click += (_, _) =>
        {
            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            var extension = kind == OcrOutputKind.SearchablePdf ? ".pdf" : ".txt";
            var dialog = new SaveFileDialog
            {
                Title = kind == OcrOutputKind.SearchablePdf ? "Save searchable OCR PDF" : "Save OCR text",
                Filter = kind == OcrOutputKind.SearchablePdf ? "PDF files (*.pdf)|*.pdf" : "Text files (*.txt)|*.txt",
                AddExtension = true,
                DefaultExt = extension,
                OverwritePrompt = true,
                FileName = Path.GetFileName(outputBox.Text)
            };
            var directory = Path.GetDirectoryName(outputBox.Text);
            if (!string.IsNullOrWhiteSpace(directory) && Directory.Exists(directory)) dialog.InitialDirectory = directory;
            if (dialog.ShowDialog(window) == true) outputBox.Text = dialog.FileName;
        };
        Grid.SetColumn(browse, 1);
        outputGrid.Children.Add(browse);
        body.Children.Add(outputGrid);

        void RefreshOutputKind(bool replacePath)
        {
            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            outputNote.Text = kind == OcrOutputKind.SearchablePdf
                ? "Creates a new PDF containing the selected pages with a searchable text layer over their raster image."
                : "Recognises the selected pages and writes their text to a UTF-8 text file.";
            if (replacePath) outputBox.Text = Suggested(kind);
        }
        outputKind.SelectionChanged += (_, _) => RefreshOutputKind(replacePath: true);
        RefreshOutputKind(replacePath: false);

        OcrDialogResult? result = null;
        var run = CreateButton("Run OCR", primary: true);
        run.Click += (_, _) =>
        {
            if (language.SelectedItem is not PdfRescue.App.Services.OcrLanguageOption languageOption)
            {
                MessageBox.Show(window, "Choose an OCR language.", "OCR PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            int[] positions;
            if (customPages.IsChecked == true)
            {
                if (!PageScopeParser.TryParse(range.Text, pageCount, out positions, out var error))
                {
                    MessageBox.Show(window, error, "OCR PDF", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
            }
            else
            {
                positions = Enumerable.Range(1, pageCount).ToArray();
            }

            var kind = outputKind.SelectedIndex == 0 ? OcrOutputKind.SearchablePdf : OcrOutputKind.PlainText;
            var extension = kind == OcrOutputKind.SearchablePdf ? ".pdf" : ".txt";
            var path = ValidateOutputPath(window, source, outputBox.Text, extension);
            if (path is null) return;
            result = new OcrDialogResult(kind, languageOption.Id, positions, path);
            window.DialogResult = true;
        };
        AddFooter(actions, window, run);
        return window.ShowDialog() == true ? result : null;
    }

    private static Window CreateShell(
        Window owner,
        string title,
        string subtitle,
        double width,
        double height,
        out StackPanel body,
        out StackPanel actions)
    {
        var window = new Window
        {
            Owner = owner,
            Title = $"AsantePDF · {title}",
            Width = width,
            Height = height,
            MinWidth = Math.Min(width, 520),
            MinHeight = Math.Min(height, 420),
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.CanResizeWithGrip,
            ShowInTaskbar = false,
            Background = BrushResource("AppBackground", new SolidColorBrush(Color.FromRgb(9, 19, 31))),
            Foreground = BrushResource("PrimaryTextBrush", Brushes.White)
        };

        var root = new Grid { Margin = new Thickness(22) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new StackPanel { Margin = new Thickness(0, 0, 0, 16) };
        header.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 23,
            FontWeight = FontWeights.SemiBold,
            Foreground = BrushResource("PrimaryTextBrush", Brushes.White)
        });
        var subtitleText = MutedText(subtitle);
        subtitleText.FontSize = 13;
        subtitleText.TextWrapping = TextWrapping.Wrap;
        subtitleText.Margin = new Thickness(0, 6, 0, 0);
        header.Children.Add(subtitleText);
        Grid.SetRow(header, 0);
        root.Children.Add(header);

        body = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
        var scroll = new ScrollViewer
        {
            Content = body,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        Grid.SetRow(scroll, 1);
        root.Children.Add(scroll);

        actions = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0)
        };
        Grid.SetRow(actions, 2);
        root.Children.Add(actions);

        window.Content = root;
        return window;
    }

    private static void AddFooter(StackPanel actions, Window window, Button run)
    {
        var cancel = CreateButton("Cancel");
        cancel.IsCancel = true;
        cancel.Click += (_, _) => window.DialogResult = false;
        run.IsDefault = true;
        actions.Children.Add(cancel);
        actions.Children.Add(run);
    }

    private static Button CreateButton(string text, bool primary = false)
    {
        var button = new Button { Content = text, Margin = new Thickness(4, 0, 0, 0), MinWidth = 92 };
        if (Application.Current.TryFindResource(primary ? "PrimaryButtonStyle" : "FlatButtonStyle") is Style style)
            button.Style = style;
        return button;
    }

    private static TextBox CreateTextBox(string text) => new()
    {
        Text = text,
        MinHeight = 34,
        VerticalContentAlignment = VerticalAlignment.Center
    };

    private static TextBox ReadOnlyPathBox(string text) => new()
    {
        Text = text,
        IsReadOnly = true,
        MinHeight = 34,
        VerticalContentAlignment = VerticalAlignment.Center,
        ToolTip = text
    };

    private static ComboBox CreateComboBox() => new()
    {
        MinHeight = 36,
        Padding = new Thickness(8, 5, 8, 5),
        Foreground = BrushResource("PrimaryTextBrush", Brushes.White),
        Background = BrushResource("PanelRaisedBrush", Brushes.DarkSlateGray),
        BorderBrush = BrushResource("BorderBrushSoft", Brushes.Gray)
    };

    private static RadioButton CreateRadio(string text, bool isChecked) => new()
    {
        Content = text,
        IsChecked = isChecked,
        Foreground = BrushResource("PrimaryTextBrush", Brushes.White),
        Margin = new Thickness(0, 3, 0, 3),
        FontSize = 14
    };

    private static TextBlock FieldLabel(string text, double top = 0) => new()
    {
        Text = text,
        FontSize = 13,
        FontWeight = FontWeights.SemiBold,
        Foreground = BrushResource("PrimaryTextBrush", Brushes.White),
        Margin = new Thickness(0, top, 0, 7)
    };

    private static TextBlock MutedText(string text) => new()
    {
        Text = text,
        Foreground = BrushResource("MutedTextBrush", Brushes.LightGray),
        FontSize = 12
    };

    private sealed record PathPicker(Grid Container, TextBox TextBox);

    private static PathPicker CreatePathPicker(Window owner, string title, string initialPath, string filter, string defaultExtension)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var box = CreateTextBox(initialPath);
        box.ToolTip = initialPath;
        Grid.SetColumn(box, 0);
        grid.Children.Add(box);

        var browse = CreateButton("Browse…");
        browse.Margin = new Thickness(8, 0, 0, 0);
        browse.Click += (_, _) =>
        {
            var current = box.Text.Trim();
            var dialog = new SaveFileDialog
            {
                Title = title,
                Filter = filter,
                AddExtension = true,
                DefaultExt = defaultExtension,
                OverwritePrompt = true,
                FileName = string.IsNullOrWhiteSpace(current) ? "output" + defaultExtension : Path.GetFileName(current)
            };
            var directory = string.IsNullOrWhiteSpace(current) ? null : Path.GetDirectoryName(current);
            if (!string.IsNullOrWhiteSpace(directory) && Directory.Exists(directory))
                dialog.InitialDirectory = directory;
            if (dialog.ShowDialog(owner) == true) box.Text = dialog.FileName;
        };
        Grid.SetColumn(browse, 1);
        grid.Children.Add(browse);
        return new PathPicker(grid, box);
    }

    private static string SuggestedSibling(string source, string suffix)
    {
        var directory = Path.GetDirectoryName(source)!;
        var name = Path.GetFileNameWithoutExtension(source);
        return Path.Combine(directory, $"{name}-{suffix}.pdf");
    }

    private static string? ValidateOutputPath(Window owner, string source, string value, string extension)
    {
        var path = NormalizeRequiredPath(owner, value, extension);
        if (path is null) return null;
        if (string.Equals(Path.GetFullPath(source), path, StringComparison.OrdinalIgnoreCase))
        {
            MessageBox.Show(owner, "Choose a different output file. AsantePDF will not overwrite the source PDF.", owner.Title, MessageBoxButton.OK, MessageBoxImage.Information);
            return null;
        }
        return path;
    }

    private static string? NormalizeRequiredPath(Window owner, string value, string extension)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            MessageBox.Show(owner, "Choose an output file.", owner.Title, MessageBoxButton.OK, MessageBoxImage.Information);
            return null;
        }
        try
        {
            var path = Path.GetFullPath(value.Trim());
            if (!path.EndsWith(extension, StringComparison.OrdinalIgnoreCase)) path += extension;
            var directory = Path.GetDirectoryName(path);
            if (string.IsNullOrWhiteSpace(directory)) throw new InvalidDataException("The output folder is invalid.");
            return path;
        }
        catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException or InvalidDataException)
        {
            MessageBox.Show(owner, "The output path is invalid. " + ex.Message, owner.Title, MessageBoxButton.OK, MessageBoxImage.Information);
            return null;
        }
    }

    private static IReadOnlyList<string>? ParsePageGroups(string text, int pageCount, out string error)
    {
        error = string.Empty;
        var rawGroups = text.Split(';', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        if (rawGroups.Length == 0)
        {
            error = "Enter at least one page group, for example 1-3; 4-6; 8,10.";
            return null;
        }

        var result = new List<string>(rawGroups.Length);
        foreach (var rawGroup in rawGroups)
        {
            var pages = new List<int>();
            var seen = new HashSet<int>();
            foreach (var token in rawGroup.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
            {
                var dash = token.IndexOf('-');
                if (dash < 0)
                {
                    if (!int.TryParse(token, out var page) || page < 1 || page > pageCount)
                    {
                        error = $"'{token}' is not a valid page number from 1 to {pageCount:N0}.";
                        return null;
                    }
                    if (seen.Add(page)) pages.Add(page);
                    continue;
                }

                if (token.IndexOf('-', dash + 1) >= 0 ||
                    !int.TryParse(token[..dash].Trim(), out var start) ||
                    !int.TryParse(token[(dash + 1)..].Trim(), out var end) ||
                    start < 1 || end < start || end > pageCount)
                {
                    error = $"'{token}' is not a valid ascending page range within 1 to {pageCount:N0}.";
                    return null;
                }
                for (var page = start; page <= end; page++)
                    if (seen.Add(page)) pages.Add(page);
            }

            if (pages.Count == 0)
            {
                error = $"Page group '{rawGroup}' is empty.";
                return null;
            }
            result.Add(string.Join(',', pages));
        }
        return result;
    }

    private static void AddPdf(ObservableCollection<string> files, string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path) ||
            !string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase)) return;
        var full = Path.GetFullPath(path);
        if (!files.Contains(full, StringComparer.OrdinalIgnoreCase)) files.Add(full);
    }

    private static void MoveSelected(ObservableCollection<string> files, ListBox list, int delta)
    {
        var index = list.SelectedIndex;
        if (index < 0) return;
        var target = index + delta;
        if (target < 0 || target >= files.Count) return;
        files.Move(index, target);
        list.SelectedIndex = target;
        list.ScrollIntoView(files[target]);
    }

    private static Brush BrushResource(string key, Brush fallback) =>
        Application.Current.TryFindResource(key) as Brush ?? fallback;
}