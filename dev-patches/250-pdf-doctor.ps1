param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$issue = Join-Path $SourceRoot 'src\PdfRescue.Core\Models\PdfDoctorIssue.cs'
Replace-Exact $issue @'
public sealed record PdfDoctorIssue(
    string Code,
    string Title,
    string Description,
    PdfHealthSeverity Severity,
    bool CanAutoFix = false);
'@ @'
public sealed record PdfDoctorIssue(
    string Code,
    string Title,
    string Description,
    PdfHealthSeverity Severity,
    bool CanAutoFix = false,
    string Category = "Structure",
    string? ActionLabel = null);
'@ 'doctor issue metadata'

$doctor = Join-Path $SourceRoot 'src\PdfRescue.Core\Diagnostics\PdfDoctor.cs'
Replace-Exact $doctor @'
                PdfHealthSeverity.Error,
                CanAutoFix: true));
'@ @'
                PdfHealthSeverity.Error,
                CanAutoFix: true,
                Category: "Structure",
                ActionLabel: "Repair PDF"));
'@ 'doctor structure error action'
Replace-Exact $doctor @'
                PdfHealthSeverity.Warning,
                CanAutoFix: true));
'@ @'
                PdfHealthSeverity.Warning,
                CanAutoFix: true,
                Category: "Structure",
                ActionLabel: "Repair PDF"));
'@ 'doctor structure warning action'
Replace-Exact $doctor @'
                "Some operations may require the document password before they can continue.",
                PdfHealthSeverity.Info));
'@ @'
                "Some operations may require the document password before they can continue.",
                PdfHealthSeverity.Info,
                Category: "Security"));
'@ 'doctor security category'
Replace-Exact $doctor @'
                PdfHealthSeverity.Recommendation,
                CanAutoFix: true));
'@ @'
                PdfHealthSeverity.Recommendation,
                CanAutoFix: true,
                Category: "Optimization",
                ActionLabel: "Compress PDF"));
'@ 'doctor large file action'
Replace-Exact $doctor @'
                $"The document contains {inspection.PageCount:N0} pages. Heavy tasks should run as cancellable background jobs.",
                PdfHealthSeverity.Info));
'@ @'
                $"The document contains {inspection.PageCount:N0} pages. Heavy tasks should run as cancellable background jobs.",
                PdfHealthSeverity.Info,
                Category: "Performance"));
'@ 'doctor long document category'

$report = Join-Path $SourceRoot 'src\PdfRescue.Core\Models\PdfDoctorReport.cs'
Replace-Exact $report @'
{
    public bool NeedsAttention => Issues.Any(i => i.Severity is PdfHealthSeverity.Warning or PdfHealthSeverity.Error);
}
'@ @'
{
    public bool NeedsAttention => Issues.Any(i => i.Severity is PdfHealthSeverity.Warning or PdfHealthSeverity.Error);

    public string StatusLabel => Inspection.HasErrors ? "Damaged" : NeedsAttention ? "Attention Needed" : "Healthy";

    public string StatusDescription => Inspection.HasErrors
        ? "qpdf reported structural errors. Work from a copy and use Repair PDF."
        : NeedsAttention
            ? "The PDF is readable, but Doctor found issues worth reviewing."
            : "No serious structural problems were detected by the available checks.";
}
'@ 'doctor health status'

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                        <TextBlock x:Name="HealthText" Text="Not analysed yet" FontSize="19" FontWeight="SemiBold" Margin="0,14,0,4" />
                                        <Button Style="{StaticResource PrimaryButtonStyle}" Click="Doctor_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" HorizontalAlignment="Left" Content="Run PDF Doctor" Margin="0,8,0,10" />
                                        <ItemsControl x:Name="FindingsList" Margin="0,4,0,10" />
                                        <TextBlock Text="Recommendations appear only when diagnosis supports them." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" />
'@ @'
                                        <Grid Margin="0,14,0,4">
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                            <TextBlock x:Name="HealthStatusText" Text="Not analysed yet" FontSize="19" FontWeight="SemiBold" />
                                            <TextBlock x:Name="HealthText" Grid.Column="1" Text="" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource MutedTextBrush}" VerticalAlignment="Center" />
                                        </Grid>
                                        <TextBlock x:Name="HealthSummaryText" Text="Run PDF Doctor to check structure, security and optimization signals." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,8" />
                                        <Button Style="{StaticResource PrimaryButtonStyle}" Click="Doctor_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" HorizontalAlignment="Left" Content="Run PDF Doctor" Margin="0,4,0,10" />
                                        <ItemsControl x:Name="FindingsList" Margin="0,4,0,10">
                                            <ItemsControl.ItemTemplate>
                                                <DataTemplate>
                                                    <Border Background="#101F2E" BorderBrush="#243D56" BorderThickness="1" CornerRadius="7" Padding="10" Margin="0,0,0,7">
                                                        <StackPanel>
                                                            <Grid>
                                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                                <StackPanel>
                                                                    <TextBlock Text="{Binding Category}" Foreground="#7192B1" FontSize="10" FontWeight="SemiBold" />
                                                                    <TextBlock Text="{Binding Title}" FontWeight="SemiBold" Margin="0,2,0,0" TextWrapping="Wrap" />
                                                                </StackPanel>
                                                                <Button Grid.Column="1" Content="{Binding ActionLabel}" Tag="{Binding Code}" Click="DoctorIssueAction_Click"
                                                                        Padding="8,4" Margin="8,0,0,0">
                                                                    <Button.Style>
                                                                        <Style TargetType="Button" BasedOn="{StaticResource FlatButtonStyle}">
                                                                            <Setter Property="Visibility" Value="Collapsed" />
                                                                            <Style.Triggers>
                                                                                <DataTrigger Binding="{Binding CanAutoFix}" Value="True">
                                                                                    <Setter Property="Visibility" Value="Visible" />
                                                                                </DataTrigger>
                                                                            </Style.Triggers>
                                                                        </Style>
                                                                    </Button.Style>
                                                                </Button>
                                                            </Grid>
                                                            <TextBlock Text="{Binding Description}" Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,7,0,0" />
                                                        </StackPanel>
                                                    </Border>
                                                </DataTemplate>
                                            </ItemsControl.ItemTemplate>
                                        </ItemsControl>
                                        <TextBlock Text="Engine details" Foreground="{StaticResource MutedTextBrush}" FontSize="12" FontWeight="SemiBold" Margin="0,4,0,5" />
                                        <ItemsControl x:Name="DoctorMessagesList" Margin="0,0,0,8">
                                            <ItemsControl.ItemTemplate>
                                                <DataTemplate>
                                                    <TextBlock Text="•  {Binding}" Foreground="#7E92A8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,4" />
                                                </DataTemplate>
                                            </ItemsControl.ItemTemplate>
                                        </ItemsControl>
                                        <TextBlock Text="Recommendations appear only when diagnosis supports them." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" />
'@ 'doctor inspector result panel'

$code = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $code @'
            InspectorFeatures.Text = "Run PDF Doctor to inspect";
            HealthText.Text = "Not checked";
            FindingsList.ItemsSource = null;
'@ @'
            InspectorFeatures.Text = "Run PDF Doctor to inspect";
            HealthStatusText.Text = "Not analysed yet";
            HealthText.Text = string.Empty;
            HealthSummaryText.Text = "Run PDF Doctor to check structure, security and optimization signals.";
            DoctorMessagesList.ItemsSource = null;
            FindingsList.ItemsSource = null;
'@ 'doctor reset state'
Replace-Exact $code @'
            if (report is null) throw new InvalidOperationException("PDF Doctor did not return a report.");
            HealthText.Text = $"{report.HealthScore}% health";
            InspectorVersion.Text = report.Inspection.PdfVersion ?? "Unknown";
            InspectorSecurity.Text = report.Inspection.IsEncrypted ? "Encrypted" : "Not encrypted";
            InspectorFeatures.Text = BuildFeatureSummary(report.Inspection);
            FindingsList.ItemsSource = report.Issues.Count == 0
                ? new[] { "No structural problems detected." }
                : report.Issues.Select(i => $"{i.Title}\n{i.Description}").ToArray();
            StatusText.Text = report.NeedsAttention
                ? "PDF Doctor found issues that may need attention."
                : "PDF Doctor found no serious structural issues.";
'@ @'
            if (report is null) throw new InvalidOperationException("PDF Doctor did not return a report.");
            HealthStatusText.Text = report.StatusLabel;
            HealthText.Text = $"{report.HealthScore}%";
            HealthSummaryText.Text = report.StatusDescription;
            HealthStatusText.Foreground = report.StatusLabel switch
            {
                "Damaged" => new SolidColorBrush(Color.FromRgb(255, 98, 104)),
                "Attention Needed" => new SolidColorBrush(Color.FromRgb(244, 184, 72)),
                _ => new SolidColorBrush(Color.FromRgb(98, 212, 111))
            };
            InspectorVersion.Text = report.Inspection.PdfVersion ?? "Unknown";
            InspectorSecurity.Text = report.Inspection.IsEncrypted ? "Encrypted" : "Not encrypted";
            InspectorFeatures.Text = BuildFeatureSummary(report.Inspection);
            FindingsList.ItemsSource = report.Issues;
            DoctorMessagesList.ItemsSource = report.Inspection.Messages;
            StatusText.Text = report.NeedsAttention
                ? "PDF Doctor found issues that may need attention."
                : "PDF Doctor found no serious structural issues.";
'@ 'doctor richer report binding'

$needle = @'
    private void ZoomIn_Click(object sender, RoutedEventArgs e)
'@
$insert = @'
    private void DoctorIssueAction_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string code }) return;

        switch (code)
        {
            case "STRUCTURE_ERROR":
            case "STRUCTURE_WARNING":
                Repair_Click(this, new RoutedEventArgs());
                break;
            case "LARGE_FILE":
                Compress_Click(this, new RoutedEventArgs());
                break;
        }
    }

    private void ZoomIn_Click(object sender, RoutedEventArgs e)
'@
Replace-Exact $code $needle $insert 'doctor contextual action handler'

$tests = Join-Path $SourceRoot 'tests\PdfRescue.SmokeTests\Program.cs'
Replace-Exact $tests @'
        Assert(report.HealthScore == 85, "A structural warning should currently cost 15 health points.");
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING"), "Doctor should surface the structural warning.");
'@ @'
        Assert(report.HealthScore == 85, "A structural warning should currently cost 15 health points.");
        Assert(report.StatusLabel == "Attention Needed", "A structural warning should produce an Attention Needed health state.");
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING"), "Doctor should surface the structural warning.");
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING" && i.Category == "Structure" && i.ActionLabel == "Repair PDF"), "Structural warnings should expose a repair action.");
'@ 'doctor health smoke assertions'

Write-Host 'PDF Doctor richer health, findings, engine details and contextual actions staged.' -ForegroundColor Green
& cmd /c exit 0
