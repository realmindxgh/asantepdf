param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize-Text([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, (Normalize-Text $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize-Text ([IO.File]::ReadAllText($Path))
    $oldText = Normalize-Text $Old
    if (-not $text.Contains($oldText)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldText, (Normalize-Text $New)))
}

# 1) A safe, explicit existing-output preference.
$settingsService = Join-Path $SourceRoot 'src\PdfRescue.App\Services\AppSettingsService.cs'
$old = @'
public enum DefaultPageViewMode
{
    SinglePage,
    Continuous,
    TwoPage
}

public sealed record AppPreferences
'@
$new = @'
public enum DefaultPageViewMode
{
    SinglePage,
    Continuous,
    TwoPage
}

public enum ExistingOutputBehavior
{
    AskBeforeReplace,
    CreateUniqueCopy
}

public sealed record AppPreferences
'@
Replace-Exact $settingsService $old $new 'existing output enum'

$old = @'
    public string DefaultOutputFolder { get; init; } = string.Empty;
    public string OutputNamePattern { get; init; } = "{name}-{operation}";
    public bool RecoveryEnabled { get; init; } = true;
'@
$new = @'
    public string DefaultOutputFolder { get; init; } = string.Empty;
    public string OutputNamePattern { get; init; } = "{name}-{operation}";
    public ExistingOutputBehavior ExistingOutput { get; init; } = ExistingOutputBehavior.CreateUniqueCopy;
    public bool RecoveryEnabled { get; init; } = true;
'@
Replace-Exact $settingsService $old $new 'existing output preference'

$outputPolicy = Join-Path $SourceRoot 'src\PdfRescue.App\Services\OutputPathPolicy.cs'
if (Test-Path $outputPolicy) { throw 'OutputPathPolicy.cs already exists unexpectedly.' }
Write-Text $outputPolicy @'
using System.IO;
using System.Windows;

namespace PdfRescue.App.Services;

public static class OutputPathPolicy
{
    public static string? Resolve(Window owner, string path)
    {
        var full = Path.GetFullPath(path);
        if (!File.Exists(full)) return full;

        return AppSettingsService.Current.Preferences.ExistingOutput switch
        {
            ExistingOutputBehavior.CreateUniqueCopy => CreateUniquePath(full),
            _ => MessageBox.Show(
                    owner,
                    $"An output file named '{Path.GetFileName(full)}' already exists. Replace that output file?\n\nThe source document is not affected by this choice.",
                    "Existing output file",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question) == MessageBoxResult.Yes
                ? full
                : null
        };
    }

    private static string CreateUniquePath(string path)
    {
        var directory = Path.GetDirectoryName(path) ?? Environment.CurrentDirectory;
        var name = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);
        for (var index = 2; index < 10000; index++)
        {
            var candidate = Path.Combine(directory, $"{name} ({index}){extension}");
            if (!File.Exists(candidate)) return candidate;
        }
        return Path.Combine(directory, $"{name}-{Guid.NewGuid():N}{extension}");
    }
}
'@

$settingsWindow = Join-Path $SourceRoot 'src\PdfRescue.App\SettingsWindow.cs'
$old = @'
    private readonly TextBox _outputFolder = new();
    private readonly TextBox _outputPattern = new();
    private readonly CheckBox _recovery = new() { Content = "Keep crash-recovery state separate from originals" };
'@
$new = @'
    private readonly TextBox _outputFolder = new();
    private readonly TextBox _outputPattern = new();
    private readonly ComboBox _existingOutput = new();
    private readonly CheckBox _recovery = new() { Content = "Keep crash-recovery state separate from originals" };
'@
Replace-Exact $settingsWindow $old $new 'settings output behavior field'

$old = @'
        _outputFolder.Text = preferences.DefaultOutputFolder;
        _outputPattern.Text = preferences.OutputNamePattern;
        _recovery.IsChecked = preferences.RecoveryEnabled;
'@
$new = @'
        _outputFolder.Text = preferences.DefaultOutputFolder;
        _outputPattern.Text = preferences.OutputNamePattern;
        _existingOutput.ItemsSource = Enum.GetValues<ExistingOutputBehavior>();
        _existingOutput.SelectedItem = preferences.ExistingOutput;
        _recovery.IsChecked = preferences.RecoveryEnabled;
'@
Replace-Exact $settingsWindow $old $new 'settings output behavior initialization'

$old = @'
        AddField(content, "Default output folder", folderPanel, "Leave blank to choose each time.");
        AddField(content, "Output naming pattern", _outputPattern, "Use {name} and {operation} placeholders.");

        AddSection(content, "Updates");
'@
$new = @'
        AddField(content, "Default output folder", folderPanel, "Leave blank to choose each time.");
        AddField(content, "Output naming pattern", _outputPattern, "Use {name} and {operation} placeholders.");
        AddField(content, "If an output file already exists", _existingOutput,
            "CreateUniqueCopy never replaces an existing result. AskBeforeReplace requires an explicit confirmation before replacing an output file.");

        AddSection(content, "Updates");
'@
Replace-Exact $settingsWindow $old $new 'settings output behavior UI'

$old = @'
            DefaultOutputFolder = _outputFolder.Text,
            OutputNamePattern = _outputPattern.Text,
            RecoveryEnabled = _recovery.IsChecked == true,
'@
$new = @'
            DefaultOutputFolder = _outputFolder.Text,
            OutputNamePattern = _outputPattern.Text,
            ExistingOutput = _existingOutput.SelectedItem is ExistingOutputBehavior existingOutput
                ? existingOutput
                : ExistingOutputBehavior.CreateUniqueCopy,
            RecoveryEnabled = _recovery.IsChecked == true,
'@
Replace-Exact $settingsWindow $old $new 'settings output behavior save'

# 2) Route all normal Save-file choices through the same safe output policy.
$mainCode = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$old = @'
    private string? AskSaveFile(string title, string suggestedName, string filter, string defaultExtension)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = filter,
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = defaultExtension,
            OverwritePrompt = true
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }

    private string? AskSavePath(string title, string suggestedName)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = ".pdf",
            OverwritePrompt = true
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }
'@
$new = @'
    private string? AskSaveFile(string title, string suggestedName, string filter, string defaultExtension)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = filter,
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = defaultExtension,
            OverwritePrompt = false
        };
        if (dialog.ShowDialog(this) != true) return null;
        return OutputPathPolicy.Resolve(this, dialog.FileName);
    }

    private string? AskSavePath(string title, string suggestedName)
    {
        var dialog = new SaveFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            FileName = suggestedName,
            AddExtension = true,
            DefaultExt = ".pdf",
            OverwritePrompt = false
        };
        if (dialog.ShowDialog(this) != true) return null;
        return OutputPathPolicy.Resolve(this, dialog.FileName);
    }
'@
Replace-Exact $mainCode $old $new 'main save output policy'

# 3) Merge accepts dropped PDFs, and configured outputs use the central overwrite policy.
$toolDialogs = Join-Path $SourceRoot 'src\PdfRescue.App\ToolConfigurationDialogs.cs'
$old = @'
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
'@
$new = @'
        var list = new ListBox
        {
            ItemsSource = files,
            MinHeight = 245,
            MaxHeight = 300,
            BorderThickness = new Thickness(1),
            BorderBrush = BrushResource("BorderBrushSoft", Brushes.DimGray),
            Background = BrushResource("PanelBackground", Brushes.Black),
            Padding = new Thickness(6),
            AllowDrop = true
        };
        body.Children.Add(list);

        void MergeDragOver(object? _, DragEventArgs e)
        {
            var paths = e.Data.GetDataPresent(DataFormats.FileDrop)
                ? e.Data.GetData(DataFormats.FileDrop) as string[] ?? Array.Empty<string>()
                : Array.Empty<string>();
            e.Effects = paths.Any(path => File.Exists(path) && string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
                ? DragDropEffects.Copy
                : DragDropEffects.None;
            e.Handled = true;
        }

        void MergeDrop(object? _, DragEventArgs e)
        {
            if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
            var before = files.Count;
            foreach (var path in e.Data.GetData(DataFormats.FileDrop) as string[] ?? Array.Empty<string>()) AddPdf(files, path);
            if (files.Count > before) list.SelectedIndex = files.Count - 1;
            e.Handled = true;
        }

        window.AllowDrop = true;
        window.DragOver += MergeDragOver;
        window.Drop += MergeDrop;
        list.DragOver += MergeDragOver;
        list.Drop += MergeDrop;

        var orderHint = MutedText("Drop PDFs here or use Add PDFs. Top to bottom is the final PDF page order.");
'@
Replace-Exact $toolDialogs $old $new 'merge dialog drag drop'

$old = '                OverwritePrompt = true'
$new = '                OverwritePrompt = false'
$text = Normalize-Text ([IO.File]::ReadAllText($toolDialogs))
if (-not $text.Contains($old)) { throw 'Target not found: tool dialog overwrite prompt' }
Write-Text $toolDialogs ($text.Replace($old, $new))

$old = @'
            if (string.IsNullOrWhiteSpace(directory)) throw new InvalidDataException("The output folder is invalid.");
            return path;
'@
$new = @'
            if (string.IsNullOrWhiteSpace(directory)) throw new InvalidDataException("The output folder is invalid.");
            return OutputPathPolicy.Resolve(owner, path);
'@
Replace-Exact $toolDialogs $old $new 'configured output policy'

# 4) Give context menus coherent theme/focus/disabled treatment.
$appXaml = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml'
$old = @'
        <Style TargetType="ListBoxItem">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="HorizontalContentAlignment" Value="Stretch" />
            <Setter Property="Padding" Value="2" />
            <Setter Property="Margin" Value="4,3" />
        </Style>
    </Application.Resources>
'@
$new = @'
        <Style TargetType="ListBoxItem">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="HorizontalContentAlignment" Value="Stretch" />
            <Setter Property="Padding" Value="2" />
            <Setter Property="Margin" Value="4,3" />
        </Style>

        <Style TargetType="ContextMenu">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="Background" Value="{StaticResource PanelRaisedBrush}" />
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="4" />
        </Style>

        <Style TargetType="MenuItem">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="Background" Value="Transparent" />
            <Setter Property="Padding" Value="10,7" />
            <Setter Property="Margin" Value="1" />
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{StaticResource PanelHoverBrush}" />
                    <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.42" />
                </Trigger>
                <Trigger Property="IsKeyboardFocusWithin" Value="True">
                    <Setter Property="Background" Value="{StaticResource PanelHoverBrush}" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="Separator">
            <Setter Property="Background" Value="{StaticResource BorderBrushSoft}" />
            <Setter Property="Margin" Value="7,4" />
        </Style>
    </Application.Resources>
'@
Replace-Exact $appXaml $old $new 'context menu theme styles'

# 5) Complete About/Diagnostics with build, engine and license information.
$lifecycle = Join-Path $SourceRoot 'src\PdfRescue.App\LifecycleWindows.cs'
$old = @'
internal sealed class DiagnosticsWindow : Window
{
    private readonly TextBlock _updateStatus = new();
    private UpdateInfo? _availableUpdate;
'@
$new = @'
internal sealed class DiagnosticsWindow : Window
{
    private readonly TextBlock _updateStatus = new();
    private readonly TextBlock _engineStatus = new();
    private readonly TextBox _engineInfo = new();
    private UpdateInfo? _availableUpdate;
'@
Replace-Exact $lifecycle $old $new 'diagnostics engine fields'

$old = @'
        Width = 720;
        Height = 610;
'@
$new = @'
        Width = 760;
        Height = 780;
'@
Replace-Exact $lifecycle $old $new 'diagnostics window size'

$old = @'
        var version = UpdateService.CurrentVersion;
        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = $"Version {version}  •  Completely free  •  Local-first", Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 5, 0, 20) });

        var info = new StringBuilder();
        info.AppendLine($"Version: {version}");
        info.AppendLine($"Operating system: {Environment.OSVersion}");
'@
$new = @'
        var version = UpdateService.CurrentVersion;
        var assembly = Assembly.GetEntryAssembly() ?? typeof(DiagnosticsWindow).Assembly;
        var informationalVersion = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? assembly.GetName().Version?.ToString()
            ?? version.ToString();
        var fileVersion = FileVersionInfo.GetVersionInfo(assembly.Location).FileVersion ?? "Unknown";
        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = $"Version {version}  •  Completely free  •  Local-first", Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 5, 0, 20) });

        var info = new StringBuilder();
        info.AppendLine("Product: AsantePDF PDF Toolkit");
        info.AppendLine($"Version: {version}");
        info.AppendLine($"Build / informational version: {informationalVersion}");
        info.AppendLine($"Executable file version: {fileVersion}");
        info.AppendLine("Product rights: AsantePDF contributors; third-party components retain their own copyrights and licenses.");
        info.AppendLine($"Operating system: {Environment.OSVersion}");
'@
Replace-Exact $lifecycle $old $new 'diagnostics build information'

$old = @'
        var box = new TextBox { Text = info.ToString(), IsReadOnly = true, FontFamily = new FontFamily("Consolas"), FontSize = 12, Height = 245, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        root.Children.Add(box);

        _updateStatus.Text = "Update status has not been checked.";
'@
$new = @'
        var box = new TextBox { Text = info.ToString(), IsReadOnly = true, FontFamily = new FontFamily("Consolas"), FontSize = 12, Height = 205, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        root.Children.Add(box);

        root.Children.Add(new TextBlock { Text = "Bundled/local engines", FontSize = 17, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 16, 0, 5) });
        _engineStatus.Text = "Reading engine versions…";
        _engineStatus.Foreground = (Brush)Application.Current.Resources["MutedTextBrush"];
        root.Children.Add(_engineStatus);
        _engineInfo.IsReadOnly = true;
        _engineInfo.FontFamily = new FontFamily("Consolas");
        _engineInfo.FontSize = 12;
        _engineInfo.Height = 125;
        _engineInfo.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        _engineInfo.Margin = new Thickness(0, 7, 0, 0);
        root.Children.Add(_engineInfo);

        root.Children.Add(new TextBlock
        {
            Text = "Third-party notices and licenses are included with AsantePDF as THIRD-PARTY-NOTICES.md. Bundled engines may also carry their upstream legal files inside their engine folders.",
            TextWrapping = TextWrapping.Wrap,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 12, 0, 0)
        });

        _updateStatus.Text = "Update status has not been checked.";
'@
Replace-Exact $lifecycle $old $new 'diagnostics engine UI'

$old = @'
        var logs = new Button { Content = "Open logs folder", Style = (Style)FindResource("FlatButtonStyle") };
        var copy = new Button { Content = "Copy diagnostics", Style = (Style)FindResource("FlatButtonStyle") };

        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
'@
$new = @'
        var logs = new Button { Content = "Open logs folder", Style = (Style)FindResource("FlatButtonStyle") };
        var notices = new Button { Content = "Third-party notices", Style = (Style)FindResource("FlatButtonStyle") };
        var copy = new Button { Content = "Copy diagnostics", Style = (Style)FindResource("FlatButtonStyle") };

        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
'@
Replace-Exact $lifecycle $old $new 'diagnostics notices button declaration'

$old = @'
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        copy.Click += (_, _) => Clipboard.SetText(info.ToString());
        actions.Children.Add(check); actions.Children.Add(install); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = root;

        async Task CheckUpdatesAsync()
'@
$new = @'
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        notices.Click += (_, _) => OpenThirdPartyNotices();
        copy.Click += (_, _) => Clipboard.SetText(info.ToString() + Environment.NewLine + _engineInfo.Text);
        actions.Children.Add(check); actions.Children.Add(install); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(notices); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = new ScrollViewer { Content = root, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        Loaded += async (_, _) => await LoadEngineInformationAsync();

        async Task CheckUpdatesAsync()
'@
Replace-Exact $lifecycle $old $new 'diagnostics actions and load hook'

$old = @'
        }
    }
}
'@
$new = @'
        }
    }

    private async Task LoadEngineInformationAsync()
    {
        try
        {
            var text = await Task.Run(BuildEngineInformation);
            _engineInfo.Text = text;
            _engineStatus.Text = "Engine information loaded from this installation.";
        }
        catch (Exception ex)
        {
            App.Log("Could not read engine diagnostics: " + ex);
            _engineStatus.Text = "Some engine version information could not be read.";
            _engineInfo.Text = ex.Message;
        }
    }

    private static string BuildEngineInformation()
    {
        var result = new StringBuilder();
        var pdfiumAssembly = typeof(PDFiumCore.fpdfview).Assembly;
        var pdfiumVersion = pdfiumAssembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? pdfiumAssembly.GetName().Version?.ToString()
            ?? "Unknown";
        result.AppendLine($"PDFium / PDFiumCore: {pdfiumVersion}");

        var manifest = Path.Combine(AppContext.BaseDirectory, "engines", "ENGINE-VERSIONS.txt");
        if (File.Exists(manifest))
        {
            foreach (var line in File.ReadLines(manifest).Where(line => !string.IsNullOrWhiteSpace(line) && !line.StartsWith("Generated:", StringComparison.OrdinalIgnoreCase)))
                result.AppendLine(line.Trim());
        }
        else
        {
            result.AppendLine("qpdf: " + ProbeExecutable(QpdfLocator.Resolve(), "--version"));
            result.AppendLine("Tesseract OCR: " + ProbeExecutable(Path.Combine(AppContext.BaseDirectory, "engines", "tesseract", "tesseract.exe"), "--version"));
            var soffice = Path.Combine(AppContext.BaseDirectory, "engines", "libreoffice", "program", "soffice.com");
            if (!File.Exists(soffice)) soffice = Path.Combine(AppContext.BaseDirectory, "engines", "libreoffice", "program", "soffice.exe");
            result.AppendLine("LibreOffice: " + ProbeExecutable(soffice, "--headless", "--version"));
        }
        result.AppendLine($".NET runtime: {Environment.Version}");
        return result.ToString().TrimEnd();
    }

    private static string ProbeExecutable(string executable, params string[] arguments)
    {
        try
        {
            if ((executable.Contains(Path.DirectorySeparatorChar) || executable.Contains(Path.AltDirectorySeparatorChar)) && !File.Exists(executable))
                return "Not present in this installation";
            var start = new ProcessStartInfo(executable)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            foreach (var argument in arguments) start.ArgumentList.Add(argument);
            using var process = Process.Start(start);
            if (process is null) return "Could not start";
            if (!process.WaitForExit(4000))
            {
                try { process.Kill(true); } catch { }
                return "Version probe timed out";
            }
            var output = (process.StandardOutput.ReadToEnd() + Environment.NewLine + process.StandardError.ReadToEnd())
                .Replace("\r\n", "\n")
                .Split('\n', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                .FirstOrDefault();
            return process.ExitCode == 0 && !string.IsNullOrWhiteSpace(output) ? output : $"Unavailable (exit {process.ExitCode})";
        }
        catch (Exception ex)
        {
            return "Unavailable: " + ex.Message;
        }
    }

    private void OpenThirdPartyNotices()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "THIRD-PARTY-NOTICES.md");
        if (!File.Exists(path))
        {
            MessageBox.Show(this, "Third-party notices were not found beside this application build.", "Third-party notices", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }
}
'@
# Replace only the final DiagnosticsWindow class ending, not earlier window classes.
$text = Normalize-Text ([IO.File]::ReadAllText($lifecycle))
$marker = Normalize-Text $old
$position = $text.LastIndexOf($marker, [StringComparison]::Ordinal)
if ($position -lt 0) { throw 'Target not found: diagnostics class tail' }
$text = $text.Substring(0, $position) + (Normalize-Text $new) + $text.Substring($position + $marker.Length)
Write-Text $lifecycle $text

# 6) Ship an always-visible notice file in build/publish output.
$project = Join-Path $SourceRoot 'src\PdfRescue.App\PdfRescue.App.csproj'
$old = @'
  <ItemGroup>
    <Compile Remove="Preview\**\*.cs" />
    <Compile Remove="ViewModels\**\*.cs" />
  </ItemGroup>
</Project>
'@
$new = @'
  <ItemGroup>
    <Compile Remove="Preview\**\*.cs" />
    <Compile Remove="ViewModels\**\*.cs" />
  </ItemGroup>
  <ItemGroup>
    <None Include="..\..\THIRD-PARTY-NOTICES.md" Link="THIRD-PARTY-NOTICES.md" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
'@
Replace-Exact $project $old $new 'third party notice publish item'

$noticesPath = Join-Path $SourceRoot 'THIRD-PARTY-NOTICES.md'
Write-Text $noticesPath @'
# AsantePDF Third-Party Notices

AsantePDF is completely free. It uses and, in Windows release builds, may bundle open-source components whose copyrights and licenses remain with their respective authors.

This notice is a practical attribution index. Where a bundled component includes its own LICENSE, NOTICE, COPYING, README, or legal-information files, those upstream files remain authoritative and should be redistributed with that component.

## PDFium

AsantePDF uses PDFium for PDF rendering, text geometry, search, outlines and native annotation operations. PDFium is distributed under a BSD-style license. Its source tree also contains third-party components under their own licenses.

Upstream: https://pdfium.googlesource.com/pdfium/
License: https://pdfium.googlesource.com/pdfium/+/refs/heads/main/LICENSE

## PDFiumCore

AsantePDF uses the PDFiumCore .NET bindings package. PDFiumCore is published under Apache License 2.0 and packages PDFium native binaries/bindings for supported platforms.

Upstream: https://github.com/Dtronix/PDFiumCore
Package: https://www.nuget.org/packages/PDFiumCore

## qpdf

AsantePDF bundles qpdf for structural inspection, repair, page operations, security and optimization workflows. Current qpdf releases are licensed under Apache License 2.0. qpdf distributions may contain additional components with their own notices.

Upstream: https://qpdf.readthedocs.io/
License: https://qpdf.readthedocs.io/en/stable/license.html

## Tesseract OCR

AsantePDF bundles Tesseract OCR and English trained data as a local OCR fallback. Tesseract source code is licensed under Apache License 2.0. Tesseract depends on other packages, including Leptonica, that use their own open-source licenses.

Upstream: https://github.com/tesseract-ocr/tesseract
License: https://github.com/tesseract-ocr/tesseract/blob/main/LICENSE

## LibreOffice

AsantePDF release builds bundle LibreOffice for local Office-document-to-PDF conversion. LibreOffice is made available under Mozilla Public License 2.0 and includes many third-party components under additional open-source licenses. The legal files within the bundled LibreOffice installation are the authoritative detailed component notices.

Upstream licensing information: https://www.libreoffice.org/licenses/

## PDFsharp

AsantePDF uses PDFsharp-WPF for PDF construction and related document workflows. PDFsharp is published under the MIT License.

Upstream licensing information: https://docs.pdfsharp.net/General/License/License.html

## Microsoft / .NET and Windows APIs

AsantePDF is built on .NET for Windows and uses Windows platform APIs. Microsoft components are governed by the license terms that accompany the relevant .NET runtime, SDK, Windows installation, redistributables and NuGet packages.

## No transfer of third-party rights

The AsantePDF name and application code do not replace, remove, or relicense third-party copyrights. Nothing in this file grants rights beyond the terms supplied by each upstream project.
'@

Write-Host 'Final 49-item contract gap batch staged.' -ForegroundColor Green
