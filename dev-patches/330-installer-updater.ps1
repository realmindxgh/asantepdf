param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false)) }
function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=Normalize([IO.File]::ReadAllText($Path)); $o=Normalize $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; Write-Text $Path ($t.Replace($o,(Normalize $New))) }

$update = Join-Path $SourceRoot 'src\PdfRescue.App\Services\UpdateService.cs'
Write-Text $update @'
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace PdfRescue.App.Services;

public sealed record UpdateInfo(
    string Version,
    string ReleaseUrl,
    string? InstallerName,
    string? InstallerUrl,
    long? InstallerSizeBytes,
    DateTimeOffset? PublishedUtc,
    string Notes);

public static class UpdateService
{
    private const string LatestReleaseApi = "https://api.github.com/repos/realmindxgh/asantepdf/releases/latest";
    private static readonly HttpClient Client = CreateClient();

    public static string CurrentVersion => typeof(UpdateService).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
        .InformationalVersion?
        .Split('+', 2)[0] ?? "1.0.0";

    public static async Task<UpdateInfo?> CheckAsync(CancellationToken token = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, LatestReleaseApi);
        using var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(token);
        using var json = await JsonDocument.ParseAsync(stream, cancellationToken: token);
        var root = json.RootElement;
        var tag = root.TryGetProperty("tag_name", out var tagNode) ? tagNode.GetString() : null;
        var url = root.TryGetProperty("html_url", out var urlNode) ? urlNode.GetString() : null;
        var notes = root.TryGetProperty("body", out var bodyNode) ? bodyNode.GetString() ?? string.Empty : string.Empty;
        DateTimeOffset? published = null;
        if (root.TryGetProperty("published_at", out var dateNode) && DateTimeOffset.TryParse(dateNode.GetString(), out var parsed))
            published = parsed;
        if (string.IsNullOrWhiteSpace(tag) || string.IsNullOrWhiteSpace(url)) return null;

        string? installerName = null;
        string? installerUrl = null;
        long? installerSize = null;
        if (root.TryGetProperty("assets", out var assetsNode) && assetsNode.ValueKind == JsonValueKind.Array)
        {
            foreach (var asset in assetsNode.EnumerateArray())
            {
                var name = asset.TryGetProperty("name", out var nameNode) ? nameNode.GetString() : null;
                var download = asset.TryGetProperty("browser_download_url", out var downloadNode) ? downloadNode.GetString() : null;
                if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(download)) continue;
                if (!name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) continue;
                if (!name.Contains("AsantePDF", StringComparison.OrdinalIgnoreCase)) continue;

                installerName = name;
                installerUrl = download;
                if (asset.TryGetProperty("size", out var sizeNode) && sizeNode.TryGetInt64(out var bytes))
                    installerSize = bytes;
                break;
            }
        }

        return new UpdateInfo(tag.TrimStart('v', 'V'), url, installerName, installerUrl, installerSize, published, notes);
    }

    public static bool IsNewer(UpdateInfo update) => CompareVersions(update.Version, CurrentVersion) > 0;

    public static void OpenRelease(UpdateInfo update) =>
        Process.Start(new ProcessStartInfo(update.ReleaseUrl) { UseShellExecute = true });

    public static async Task<string> DownloadInstallerAsync(
        UpdateInfo update,
        IProgress<double>? progress = null,
        CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(update.InstallerUrl))
            throw new InvalidOperationException("This release does not provide an AsantePDF Windows installer asset.");

        var folder = Path.Combine(Path.GetTempPath(), "AsantePDF", "updates", update.Version);
        Directory.CreateDirectory(folder);
        var fileName = Path.GetFileName(string.IsNullOrWhiteSpace(update.InstallerName) ? "AsantePDF Setup.exe" : update.InstallerName);
        var destination = Path.Combine(folder, fileName);
        var staged = destination + ".part";
        try
        {
            if (File.Exists(staged)) File.Delete(staged);
            using var request = new HttpRequestMessage(HttpMethod.Get, update.InstallerUrl);
            using var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token);
            response.EnsureSuccessStatusCode();
            var length = response.Content.Headers.ContentLength ?? update.InstallerSizeBytes;
            await using var input = await response.Content.ReadAsStreamAsync(token);
            await using var output = new FileStream(staged, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
            var buffer = new byte[81920];
            long total = 0;
            while (true)
            {
                var read = await input.ReadAsync(buffer.AsMemory(0, buffer.Length), token);
                if (read == 0) break;
                await output.WriteAsync(buffer.AsMemory(0, read), token);
                total += read;
                if (length is > 0) progress?.Report(Math.Clamp((double)total / length.Value, 0, 1));
            }
            await output.FlushAsync(token);
            token.ThrowIfCancellationRequested();
            File.Move(staged, destination, true);
            progress?.Report(1);
            return destination;
        }
        catch
        {
            try { if (File.Exists(staged)) File.Delete(staged); } catch { }
            throw;
        }
    }

    public static void LaunchInstaller(string installerPath)
    {
        if (!File.Exists(installerPath)) throw new FileNotFoundException("The downloaded AsantePDF installer could not be found.", installerPath);
        Process.Start(new ProcessStartInfo(installerPath, "/CLOSEAPPLICATIONS /NORESTART")
        {
            UseShellExecute = true,
            Verb = "runas"
        });
    }

    private static int CompareVersions(string left, string right)
    {
        static Version Parse(string value)
        {
            var core = value.Trim().TrimStart('v', 'V').Split('-', 2)[0];
            return Version.TryParse(core, out var parsed) ? parsed : new Version(0, 0);
        }
        return Parse(left).CompareTo(Parse(right));
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AsantePDF-Windows/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }
}
'@

$lifecycle = Join-Path $SourceRoot 'src\PdfRescue.App\LifecycleWindows.cs'
Replace-Exact $lifecycle @'
        var actions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Left };
        var release = new Button { Content = "Open update page", Style = (Style)FindResource("FlatButtonStyle"), IsEnabled = false };
        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
        var check = new Button { Content = "Check for updates", Style = (Style)FindResource("PrimaryButtonStyle") };
        check.Click += async (_, _) => await CheckUpdatesAsync();
        var logs = new Button { Content = "Open logs folder", Style = (Style)FindResource("FlatButtonStyle") };
        logs.Click += (_, _) => { Directory.CreateDirectory(App.LogDirectory); Process.Start(new ProcessStartInfo(App.LogDirectory) { UseShellExecute = true }); };
        var copy = new Button { Content = "Copy diagnostics", Style = (Style)FindResource("FlatButtonStyle") };
        copy.Click += (_, _) => Clipboard.SetText(info.ToString());
        actions.Children.Add(check); actions.Children.Add(release); actions.Children.Add(logs); actions.Children.Add(copy);
        root.Children.Add(actions);
        Content = root;

        async Task CheckUpdatesAsync()
        {
            _updateStatus.Text = "Checking GitHub Releases…";
            try
            {
                var update = await UpdateService.CheckAsync();
                if (update is null)
                {
                    _updateStatus.Text = "No release information was returned.";
                    return;
                }
                _availableUpdate = update;
                if (UpdateService.IsNewer(update))
                {
                    _updateStatus.Text = $"AsantePDF {update.Version} is available. The update page will open in your browser so you can review and install it.";
                    release.IsEnabled = true;
                }
                else
                {
                    _updateStatus.Text = $"You are up to date. Latest release: {update.Version}.";
                    release.IsEnabled = false;
                }
            }
            catch (Exception ex)
            {
                App.Log("Update check failed: " + ex);
                _updateStatus.Text = "Could not check for updates. Your current installation is unchanged.";
            }
        }
'@ @'
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
'@ 'diagnostics update workflow'

$installer = Join-Path $SourceRoot 'installer\AsantePDF.iss'
Write-Text $installer @'
#define MyAppName "AsantePDF"
#define MyAppVersion "1.0.0"
#ifndef MyAppDisplayVersion
  #define MyAppDisplayVersion "1.0.0-rc10"
#endif
#define MyAppPublisher "RealMindX Education Ltd"
#define MyAppExeName "AsantePDF.exe"
#ifndef SourceDir
  #define SourceDir "..\dist\app"
#endif

[Setup]
AppId={{B6CFF511-70ED-4D05-A54F-5D11E9D8B4D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppDisplayVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://realmindxgh.com
AppSupportURL=https://realmindxgh.com
DefaultDirName={autopf}\AsantePDF
DefaultGroupName=AsantePDF
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\dist\installer
OutputBaseFilename=AsantePDF Setup
SetupIconFile=..\assets\asantepdf.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
DisableWelcomePage=no
CloseApplications=yes
RestartApplications=yes
RestartIfNeededByRun=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Local-first PDF workspace for Windows
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\prereqs\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\AsantePDF"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\AsantePDF"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "AsantePDF"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing required Microsoft runtime..."; Flags: waituntilterminated; Check: NeedsVCRuntime
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AsantePDF"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsVCRuntime: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) and (Installed = 1) then
    Result := False;
end;

procedure InitializeWizard;
begin
  WizardForm.Color := $00F7F7F7;
  WizardForm.WelcomeLabel1.Caption := 'Install AsantePDF';
  WizardForm.WelcomeLabel2.Caption :=
    'A local-first PDF workspace for organising, converting, OCR, editing, signing, inspecting, repairing and processing PDF files.' + #13#10 + #13#10 +
    'Setup includes the local PDF, OCR and Office conversion engines required by AsantePDF.' + #13#10 +
    'Your documents stay on this computer during normal AsantePDF operations.';
end;
'@

Write-Host 'Installer and in-app update workflow staged.' -ForegroundColor Green
