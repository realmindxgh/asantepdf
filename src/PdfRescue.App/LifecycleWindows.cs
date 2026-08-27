using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed class FirstLaunchWindow : Window
{
    public FirstLaunchWindow()
    {
        Title = "Welcome to AsantePDF";
        Width = 700;
        Height = Math.Min(640, Math.Max(500, SystemParameters.WorkArea.Height - 80));
        MinWidth = 600;
        MinHeight = 500;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new Grid { Margin = new Thickness(30, 26, 30, 24) };
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var content = new StackPanel { Margin = new Thickness(0, 0, 8, 0) };
        content.Children.Add(new TextBlock { Text = "Welcome to AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        content.Children.Add(new TextBlock
        {
            Text = "A free, local-first PDF workspace built for real document work.",
            FontSize = 15,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 7, 0, 24)
        });
        AddCard(content, "Free means free", "There is no Premium tier, subscription, feature lock or usage limit in AsantePDF.");
        AddCard(content, "Your files stay local", "Normal viewing, editing, OCR, conversion and PDF processing happen on this computer.");
        AddCard(content, "Start from Home", "Open a PDF, drag one into the window, or choose a standalone tool without opening a document first.");
        AddCard(content, "Your workspace can recover", "AsantePDF can remember normal sessions and separately keep a local crash-recovery snapshot for unsaved page-layout work.");

        var scroll = new ScrollViewer
        {
            Content = content,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        root.Children.Add(scroll);

        var footer = new Grid { Margin = new Thickness(0, 18, 0, 0) };
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var settingsNote = new TextBlock
        {
            Text = "Themes, privacy, recovery and defaults are available in Settings.",
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 18, 0)
        };
        footer.Children.Add(settingsNote);
        var start = new Button { Content = "Start using AsantePDF", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(18, 9, 18, 9) };
        start.Click += (_, _) => { DialogResult = true; Close(); };
        Grid.SetColumn(start, 1);
        footer.Children.Add(start);
        Grid.SetRow(footer, 1);
        root.Children.Add(footer);
        Content = root;
    }

    private static void AddCard(Panel root, string title, string description)
    {
        var card = new Border
        {
            Background = (Brush)Application.Current.Resources["PanelRaisedBrush"],
            BorderBrush = (Brush)Application.Current.Resources["BorderBrushSoft"],
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(8), Padding = new Thickness(14), Margin = new Thickness(0, 0, 0, 10)
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = title, FontWeight = FontWeights.SemiBold, FontSize = 15 });
        stack.Children.Add(new TextBlock { Text = description, TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 4, 0, 0) });
        card.Child = stack;
        root.Children.Add(card);
    }
}

internal sealed class RecoveryWindow : Window
{
    public RecoveryWindow(RecoverySnapshot snapshot)
    {
        Title = "Recover AsantePDF workspace";
        Width = 640;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF did not close normally", FontSize = 27, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "A local recovery snapshot is available. Restoring it can reopen the PDFs below, including unsaved page order/rotation state. Original PDF files are not modified by recovery.",
            TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 8, 0, 18)
        });

        var list = new ListBox { MaxHeight = 230, Margin = new Thickness(0, 0, 0, 18) };
        foreach (var document in snapshot.Documents)
            list.Items.Add($"{Path.GetFileName(document.Path)}  •  {(document.IsDirty ? "unsaved layout" : "saved state")}  •  page {document.SelectedPage:N0}");
        root.Children.Add(list);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        var fresh = new Button { Content = "Start fresh", Style = (Style)FindResource("FlatButtonStyle"), Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(0, 0, 10, 0) };
        fresh.Click += (_, _) => { DialogResult = false; Close(); };
        var restore = new Button { Content = "Restore workspace", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(16, 8, 16, 8) };
        restore.Click += (_, _) => { DialogResult = true; Close(); };
        buttons.Children.Add(fresh);
        buttons.Children.Add(restore);
        root.Children.Add(buttons);
        Content = root;
    }
}

internal sealed class AppErrorDialog : Window
{
    private AppErrorDialog(string title, string message, string technicalDetails)
    {
        Title = title;
        Width = 680;
        Height = 510;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new Grid { Margin = new Thickness(26) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var heading = new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold };
        root.Children.Add(heading);
        var summary = new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 8, 0, 14) };
        Grid.SetRow(summary, 1); root.Children.Add(summary);
        var details = new TextBox { Text = technicalDetails, IsReadOnly = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, FontFamily = new FontFamily("Consolas"), FontSize = 12 };
        Grid.SetRow(details, 2); root.Children.Add(details);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 14, 0, 0) };
        var copy = new Button { Content = "Copy details", Style = (Style)FindResource("FlatButtonStyle") };
        copy.Click += (_, _) => Clipboard.SetText(technicalDetails);
        var logs = new Button { Content = "Open logs", Style = (Style)FindResource("FlatButtonStyle") };
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        var close = new Button { Content = "Close", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        close.Click += (_, _) => Close();
        buttons.Children.Add(copy); buttons.Children.Add(logs); buttons.Children.Add(close);
        Grid.SetRow(buttons, 3); root.Children.Add(buttons);
        Content = root;
    }

    public static void Show(Window? owner, string title, string message, Exception exception)
    {
        var details = $"{DateTimeOffset.Now:O}\n{message}\n\n{exception}\n\nLog: {App.StartupLogPath}";
        var dialog = new AppErrorDialog(title, message, details);
        if (owner is not null && owner.IsVisible) dialog.Owner = owner;
        dialog.ShowDialog();
    }
}

internal sealed class DiagnosticsWindow : Window
{
    private readonly TextBlock _updateStatus = new();
    private readonly TextBlock _engineStatus = new();
    private readonly TextBox _engineInfo = new();
    private UpdateInfo? _availableUpdate;

    public DiagnosticsWindow()
    {
        Title = "About & Diagnostics — AsantePDF";
        Width = 760;
        Height = 780;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

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
        info.AppendLine($"Runtime: {Environment.Version}");
        info.AppendLine($"Process architecture: {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}");
        info.AppendLine($"64-bit process: {Environment.Is64BitProcess}");
        info.AppendLine($"Install/base folder: {AppContext.BaseDirectory}");
        info.AppendLine($"Logs: {App.LogDirectory}");
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
        _updateStatus.TextWrapping = TextWrapping.Wrap;
        _updateStatus.Foreground = (Brush)Application.Current.Resources["MutedTextBrush"];
        _updateStatus.Margin = new Thickness(0, 16, 0, 8);
        root.Children.Add(_updateStatus);

        var actions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Left };
        var check = new Button { Content = "Check for updates", Style = (Style)FindResource("PrimaryButtonStyle") };
        var install = new Button { Content = "Download & install update", Style = (Style)FindResource("PrimaryButtonStyle"), IsEnabled = false };
        var release = new Button { Content = "View release page", Style = (Style)FindResource("FlatButtonStyle"), IsEnabled = false };
        var logs = new Button { Content = "Open logs folder", Style = (Style)FindResource("FlatButtonStyle") };
        var notices = new Button { Content = "Third-party notices", Style = (Style)FindResource("FlatButtonStyle") };
        var copy = new Button { Content = "Copy diagnostics", Style = (Style)FindResource("FlatButtonStyle") };

        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
        check.Click += async (_, _) => await CheckUpdatesAsync();
        install.Click += async (_, _) =>
        {
            if (_availableUpdate?.InstallerUrl is null) return;
            var choice = MessageBox.Show(this,
                $"Download AsantePDF {_availableUpdate.Version} and start its Windows installer?\n\nThe installer will be visible and Windows may ask for administrator approval. Your settings and session data are kept outside the application folder and are not removed by an upgrade.",
                "Install AsantePDF update", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (choice != MessageBoxResult.Yes) return;

            install.IsEnabled = false;
            check.IsEnabled = false;
            try
            {
                var progress = new Progress<double>(value => _updateStatus.Text = $"Downloading AsantePDF {_availableUpdate.Version}… {value:P0}");
                var installerPath = await UpdateService.DownloadInstallerAsync(_availableUpdate, progress);
                _updateStatus.Text = "Download complete. Starting the AsantePDF installer…";
                UpdateService.LaunchInstaller(installerPath);
                Application.Current.Shutdown();
            }
            catch (Exception ex)
            {
                App.Log("Update download/install failed: " + ex);
                _updateStatus.Text = "The update was not installed. Your current AsantePDF installation is unchanged.";
                install.IsEnabled = _availableUpdate?.InstallerUrl is not null;
                check.IsEnabled = true;
            }
        };
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        notices.Click += (_, _) => OpenThirdPartyNotices();
        copy.Click += (_, _) => Clipboard.SetText(info.ToString() + Environment.NewLine + _engineInfo.Text);
        actions.Children.Add(check); actions.Children.Add(install); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(notices); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = new ScrollViewer { Content = root, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        Loaded += async (_, _) => await LoadEngineInformationAsync();

        async Task CheckUpdatesAsync()
        {
            check.IsEnabled = false;
            install.IsEnabled = false;
            release.IsEnabled = false;
            _updateStatus.Text = "Checking GitHub Releases…";
            try
            {
                var update = await UpdateService.CheckAsync();
                if (update is null)
                {
                    _availableUpdate = null;
                    _updateStatus.Text = "No public AsantePDF release has been published yet. This installation is unchanged.";
                    return;
                }
                _availableUpdate = update;
                release.IsEnabled = true;
                if (UpdateService.IsNewer(update))
                {
                    install.IsEnabled = update.InstallerUrl is not null;
                    _updateStatus.Text = update.InstallerUrl is not null
                        ? $"AsantePDF {update.Version} is available. You can review the release or download and start the signed Windows installer from here."
                        : $"AsantePDF {update.Version} is available, but this release does not expose a Windows installer asset. Open the release page for details.";
                }
                else
                {
                    _updateStatus.Text = $"You are up to date. Latest release: {update.Version}.";
                }
            }
            catch (Exception ex)
            {
                App.Log("Update check failed: " + ex);
                _updateStatus.Text = "Could not check for updates. Your current installation is unchanged.";
            }
            finally
            {
                check.IsEnabled = true;
            }
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