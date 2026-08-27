param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function N([string]$Text) { return $Text.Replace("`r`n", "`n") }
function W([string]$Path,[string]$Text) {
  $parent = Split-Path -Parent $Path
  if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
  [IO.File]::WriteAllText($Path,(N $Text).Replace("`n","`r`n"),[Text.UTF8Encoding]::new($false))
}
function R([string]$Path,[string]$Old,[string]$New,[string]$Label) {
  $t=N([IO.File]::ReadAllText($Path)); $o=N $Old
  if(-not $t.Contains($o)){ throw "Target not found: $Label" }
  W $Path ($t.Replace($o,(N $New)))
}

# Installer: automatic Open With registration, no integration checkbox, no gratuitous restart,
# and VC++ only when the x64 runtime is not already installed.
$installer = Join-Path $SourceRoot 'installer\AsantePDF.iss'
W $installer @'
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
RestartApplications=no
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
Root: HKLM64; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "AsantePDF"; Flags: uninsdeletekey
Root: HKLM64; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""
Root: HKLM64; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing required Microsoft runtime..."; Flags: waituntilterminated; Check: not IsVCRuntimeInstalled
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AsantePDF"; Flags: nowait postinstall skipifsilent

[Code]
function IsVCRuntimeInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result := RegQueryDWordValue(
    HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed',
    Installed) and (Installed = 1);
end;

procedure InitializeWizard;
begin
  WizardForm.Color := $00F7F7F7;
  WizardForm.WelcomeLabel1.Caption := 'Install AsantePDF';
  WizardForm.WelcomeLabel2.Caption :=
    'A local-first PDF workspace for organising, converting, OCR, editing, signing, inspecting, repairing and processing PDF files.' + #13#10 + #13#10 +
    'Setup automatically integrates AsantePDF with Windows PDF Open With, and includes the local PDF, OCR and Office conversion engines required by AsantePDF.' + #13#10 +
    'Your documents stay on this computer during normal AsantePDF operations.';
end;
'@

# Batch processing: queue one Task Center job per source PDF so individual progress, failure,
# Retry and output actions are first-class instead of being hidden inside one foreground task.
$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$old = @'
        var folderDialog = new OpenFolderDialog
        {
            Title = "Choose batch output folder",
            Multiselect = false
        };
        if (folderDialog.ShowDialog(this) != true) return;

        IReadOnlyList<BatchPdfResult> results = Array.Empty<BatchPdfResult>();
'@
$new = @'
        var folderDialog = new OpenFolderDialog
        {
            Title = "Choose batch output folder",
            Multiselect = false
        };
        if (folderDialog.ShowDialog(this) != true) return;

        if (_backgroundTasks is not null)
        {
            var outputFolder = folderDialog.FolderName;
            var selectedOperation = operation.Value;
            foreach (var input in files.FileNames.Select(Path.GetFullPath))
            {
                var capturedInput = input;
                var jobType = selectedOperation switch
                {
                    BatchPdfOperation.CompressBalanced => PdfJobType.Compress,
                    BatchPdfOperation.Repair => PdfJobType.Repair,
                    _ => PdfJobType.Repair
                };
                var operationLabel = selectedOperation switch
                {
                    BatchPdfOperation.CompressBalanced => "Compress",
                    BatchPdfOperation.Repair => "Repair",
                    _ => "Optimize"
                };

                _backgroundTasks.Enqueue(
                    jobType,
                    $"{operationLabel} {Path.GetFileName(capturedInput)}",
                    async (context, token) =>
                    {
                        context.ReportProgress(0.08, $"Preparing {Path.GetFileName(capturedInput)}...");
                        var fileProgress = new Progress<(int Completed, int Total, string FileName)>(item =>
                        {
                            var fraction = item.Total <= 0 ? 0.15 : Math.Clamp(item.Completed / (double)item.Total, 0, 1);
                            context.ReportProgress(0.15 + fraction * 0.75,
                                $"{operationLabel}: {item.FileName}");
                        });
                        var one = await _batch.ProcessAsync(
                            [capturedInput],
                            outputFolder,
                            selectedOperation,
                            fileProgress,
                            token);
                        var result = one.Single();
                        if (!result.Success)
                            throw new InvalidOperationException(result.Error ?? $"{operationLabel} failed for {Path.GetFileName(capturedInput)}.");
                        context.ReportProgress(0.98, $"{operationLabel} complete.");
                        return result.OutputPath;
                    },
                    retryable: true,
                    sourcePath: capturedInput,
                    runAgainAction: () => InvokeToolOnUiAsync(() => BatchProcess_Click(this, new RoutedEventArgs())));
            }

            StatusText.Text = $"Queued {files.FileNames.Length:N0} PDF(s) in Task Center. Each file can be cancelled, retried or opened independently.";
            RefreshTaskCenterIndicator();
            return;
        }

        IReadOnlyList<BatchPdfResult> results = Array.Empty<BatchPdfResult>();
'@
R $main $old $new 'batch task center queue'

# High-DPI / narrow-window resilience and explicit Inspector collapse/restore.
$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$old = '        Title="AsantePDF" Height="940" Width="1600" MinHeight="720" MinWidth="1120" FontSize="14"'
$new = '        Title="AsantePDF" Height="940" Width="1600" MinHeight="500" MinWidth="880" FontSize="14"'
R $xaml $old $new 'responsive minimum window size'

$old = @'
                        <GridSplitter Grid.Column="3" Width="5" HorizontalAlignment="Stretch" Background="#172738" />

                        <Border Grid.Column="4" Background="#0C1723" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1,0,0,0">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel Margin="16">
                                    <Border x:Name="InspectorContextCard" Background="#101F2E" BorderBrush="#243D56" BorderThickness="1" CornerRadius="9" Padding="12" Margin="0,0,0,14">
'@
$new = @'
                        <GridSplitter x:Name="InspectorSplitter" Grid.Column="3" Width="5" HorizontalAlignment="Stretch" Background="#172738" />

                        <Border x:Name="InspectorBorder" Grid.Column="4" Background="#0C1723" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1,0,0,0">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel Margin="16">
                                    <Grid Margin="0,0,0,10">
                                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <TextBlock Text="Inspector" FontSize="15" FontWeight="SemiBold" VerticalAlignment="Center" />
                                        <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="30" Padding="0"
                                                Click="CollapseInspector_Click" ToolTip="Collapse Inspector" AutomationProperties.Name="Collapse Inspector" />
                                    </Grid>
                                    <Border x:Name="InspectorContextCard" Background="#101F2E" BorderBrush="#243D56" BorderThickness="1" CornerRadius="9" Padding="12" Margin="0,0,0,14">
'@
R $xaml $old $new 'collapsible inspector shell'

$old = @'
                            <Button x:Name="ExpandPagesSidebarButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="38"
                                    HorizontalAlignment="Left" VerticalAlignment="Top" Margin="8" Padding="0" Visibility="Collapsed" Panel.ZIndex="10"
                                    Click="ExpandPagesSidebar_Click" ToolTip="Show navigation sidebar" />
                        </Grid>
'@
$new = @'
                            <Button x:Name="ExpandPagesSidebarButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="38"
                                    HorizontalAlignment="Left" VerticalAlignment="Top" Margin="8" Padding="0" Visibility="Collapsed" Panel.ZIndex="10"
                                    Click="ExpandPagesSidebar_Click" ToolTip="Show navigation sidebar" />
                            <Button x:Name="ExpandInspectorButton" Style="{StaticResource FlatButtonStyle}" Content="‹" Width="30" Height="38"
                                    HorizontalAlignment="Right" VerticalAlignment="Top" Margin="8" Padding="0" Visibility="Collapsed" Panel.ZIndex="10"
                                    Click="ExpandInspector_Click" ToolTip="Show Inspector" AutomationProperties.Name="Show Inspector" />
                        </Grid>
'@
R $xaml $old $new 'inspector restore button'

$responsive = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ResponsiveLayout.cs'
if (Test-Path $responsive) { throw 'MainWindow.ResponsiveLayout.cs already exists unexpectedly.' }
W $responsive @'
using System.Windows;

namespace PdfRescue.App;

public partial class MainWindow
{
    private GridLength _lastInspectorWidth = new(310);
    private bool _inspectorUserCollapsed;
    private bool _inspectorAutoCollapsed;
    private bool _responsiveLayoutInitialized;

    private void InitializeResponsiveLayout()
    {
        if (_responsiveLayoutInitialized) return;
        _responsiveLayoutInitialized = true;
        SizeChanged += MainWindow_ResponsiveSizeChanged;
        Dispatcher.BeginInvoke(new Action(() => UpdateResponsiveInspector(ActualWidth)));
    }

    private void CollapseInspector_Click(object sender, RoutedEventArgs e)
    {
        _inspectorUserCollapsed = true;
        _inspectorAutoCollapsed = false;
        SetInspectorCollapsed(true);
    }

    private void ExpandInspector_Click(object sender, RoutedEventArgs e)
    {
        _inspectorUserCollapsed = false;
        _inspectorAutoCollapsed = false;
        SetInspectorCollapsed(false);
    }

    private void MainWindow_ResponsiveSizeChanged(object sender, SizeChangedEventArgs e) =>
        UpdateResponsiveInspector(e.NewSize.Width);

    private void UpdateResponsiveInspector(double width)
    {
        if (InspectorColumn is null || InspectorBorder is null || InspectorSplitter is null || ExpandInspectorButton is null) return;

        if (width > 0 && width < 1180 && InspectorColumn.Width.Value > 0 && !_inspectorUserCollapsed)
        {
            _inspectorAutoCollapsed = true;
            SetInspectorCollapsed(true);
            return;
        }

        if (width >= 1320 && _inspectorAutoCollapsed && !_inspectorUserCollapsed)
        {
            _inspectorAutoCollapsed = false;
            SetInspectorCollapsed(false);
        }
    }

    private void SetInspectorCollapsed(bool collapsed)
    {
        if (collapsed)
        {
            if (InspectorColumn.Width.Value > 0)
                _lastInspectorWidth = InspectorColumn.Width;
            InspectorColumn.Width = new GridLength(0);
            InspectorBorder.Visibility = Visibility.Collapsed;
            InspectorSplitter.Visibility = Visibility.Collapsed;
            ExpandInspectorButton.Visibility = Visibility.Visible;
        }
        else
        {
            var width = _lastInspectorWidth.IsAbsolute ? _lastInspectorWidth.Value : 310;
            InspectorColumn.Width = new GridLength(Math.Clamp(width, 260, 460));
            InspectorBorder.Visibility = Visibility.Visible;
            InspectorSplitter.Visibility = Visibility.Visible;
            ExpandInspectorButton.Visibility = Visibility.Collapsed;
        }
    }
}
'@

$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$old = @'
        InitializeDocumentNavigationMetadata();
        InitializePageViewModes();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@
$new = @'
        InitializeDocumentNavigationMetadata();
        InitializePageViewModes();
        InitializeResponsiveLayout();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@
R $productShell $old $new 'responsive layout initialization'

Write-Host 'Installer, batch Task Center and responsive Inspector batch staged.' -ForegroundColor Green
exit 0
