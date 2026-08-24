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

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                        <Button Style="{StaticResource PrimaryButtonStyle}" Click="Doctor_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" HorizontalAlignment="Left" Content="Run PDF Doctor" Margin="0,4,0,10" />
'@ @'
                                        <Button Style="{StaticResource PrimaryButtonStyle}" Click="Doctor_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" HorizontalAlignment="Left" Margin="0,4,0,10">
                                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                                <TextBlock Text="&#xE83D;" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,8,0" />
                                                <TextBlock Text="Run PDF Doctor" />
                                            </StackPanel>
                                        </Button>
'@ 'doctor run button icon'

$code = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $code @'
            HealthStatusText.Text = "Not analysed yet";
            HealthText.Text = string.Empty;
            HealthSummaryText.Text = "Run PDF Doctor to check structure, security and optimization signals.";
'@ @'
            HealthStatusText.Text = "Not analysed yet";
            HealthStatusText.Foreground = (Brush)FindResource("MutedTextBrush");
            HealthText.Text = string.Empty;
            HealthSummaryText.Text = "Run PDF Doctor to check structure, security and optimization signals.";
'@ 'doctor status reset styling'

Write-Host 'PDF Doctor launch affordance and status reset polished.' -ForegroundColor Green
& cmd /c exit 0
