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
        Width = 650;
        Height = 520;
        MinWidth = 560;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new StackPanel { Margin = new Thickness(34) };
        root.Children.Add(new TextBlock { Text = "Welcome to AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "A free, local-first PDF workspace built for real document work.",
            FontSize = 15,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 7, 0, 26)
        });
        AddCard(root, "Free means free", "There is no Premium tier, subscription, feature lock or usage limit in AsantePDF.");
        AddCard(root, "Your files stay local", "Normal viewing, editing, OCR, conversion and PDF processing happen on this computer.");
        AddCard(root, "Start from Home", "Open a PDF, drag one into the window, or choose a standalone tool without opening a document first.");
        AddCard(root, "Your workspace can recover", "AsantePDF can remember normal sessions and separately keep a local crash-recovery snapshot for unsaved page-layout work.");

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        var settings = new Button { Content = "You can change themes and privacy in Settings", IsEnabled = false, Style = (Style)FindResource("FlatButtonStyle"), Margin = new Thickness(0, 0, 10, 0) };
        var start = new Button { Content = "Start using AsantePDF", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(18, 9, 18, 9) };
        start.Click += (_, _) => { DialogResult = true; Close(); };
        buttons.Children.Add(settings);
        buttons.Children.Add(start);
        root.Children.Add(buttons);
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
    private UpdateInfo? _availableUpdate;

    public DiagnosticsWindow()
    {
        Title = "About & Diagnostics — AsantePDF";
        Width = 720;
        Height = 610;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var version = UpdateService.CurrentVersion;
        var root = new StackPanel { Margin = new Thickness(30) };
        root.Children.Add(new TextBlock { Text = "AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = $"Version {version}  •  Completely free  •  Local-first", Foreground = (Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 5, 0, 20) });

        var info = new StringBuilder();
        info.AppendLine($"Version: {version}");
        info.AppendLine($"Operating system: {Environment.OSVersion}");
        info.AppendLine($"Runtime: {Environment.Version}");
        info.AppendLine($"Process architecture: {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}");
        info.AppendLine($"64-bit process: {Environment.Is64BitProcess}");
        info.AppendLine($"Install/base folder: {AppContext.BaseDirectory}");
        info.AppendLine($"Logs: {App.LogDirectory}");
        var box = new TextBox { Text = info.ToString(), IsReadOnly = true, FontFamily = new FontFamily("Consolas"), FontSize = 12, Height = 245, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        root.Children.Add(box);

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
        copy.Click += (_, _) => Clipboard.SetText(info.ToString());
        actions.Children.Add(check); actions.Children.Add(install); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = root;

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
}