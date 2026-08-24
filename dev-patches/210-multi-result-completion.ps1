param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
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
function Replace-Line([string]$Path, [string]$Prefix, [string]$Replacement, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $lines = $text.Split("`n")
    $matches = @(0..($lines.Length - 1) | Where-Object { $lines[$_].StartsWith($Prefix, [StringComparison]::Ordinal) })
    if ($matches.Count -ne 1) { throw "Expected one line for $Label in $Path, found $($matches.Count)" }
    $lines[$matches[0]] = $Replacement
    Write-Text $Path ([string]::Join("`n", $lines))
}

$dialogXaml = @'
<Window x:Class="PdfRescue.App.MultiResultDialog"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operation Results" Width="720" Height="620" MinWidth="620" MinHeight="520"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResizeWithGrip"
        Background="{StaticResource AppBackground}" Foreground="{StaticResource PrimaryTextBrush}">
    <Grid Margin="28">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <StackPanel>
            <TextBlock x:Name="TitleText" FontSize="25" FontWeight="SemiBold" />
            <TextBlock x:Name="SummaryText" Foreground="{StaticResource MutedTextBrush}" FontSize="13"
                       TextWrapping="Wrap" Margin="0,7,0,0" />
        </StackPanel>

        <Border Grid.Row="1" Style="{StaticResource PanelCardStyle}" Margin="0,20,0,0" Padding="15">
            <StackPanel>
                <TextBlock Text="SOURCE" Foreground="#6F8399" FontSize="10" FontWeight="SemiBold" />
                <TextBlock x:Name="SourceNameText" FontSize="14" FontWeight="SemiBold" Margin="0,5,0,0" />
                <TextBlock x:Name="SourcePathText" Foreground="{StaticResource MutedTextBrush}" FontSize="11"
                           TextTrimming="CharacterEllipsis" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" />
            </StackPanel>
        </Border>

        <Border Grid.Row="2" Style="{StaticResource PanelCardStyle}" Margin="0,10,0,0" Padding="15">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock Text="RESULT SET" Foreground="#6F8399" FontSize="10" FontWeight="SemiBold" />
                    <TextBlock x:Name="ResultFolderText" FontSize="13" FontWeight="SemiBold" Margin="0,5,0,0" TextTrimming="CharacterEllipsis" />
                </StackPanel>
                <Border Grid.Column="1" Background="#163251" CornerRadius="10" Padding="10,5" VerticalAlignment="Center" Margin="14,0,0,0">
                    <TextBlock x:Name="ResultCountText" Foreground="#7DB7FF" FontWeight="SemiBold" />
                </Border>
            </Grid>
        </Border>

        <TextBlock Grid.Row="3" Text="Select a result" FontSize="12" FontWeight="SemiBold" Margin="0,18,0,8" />

        <ListBox x:Name="ResultsList" Grid.Row="4" SelectionMode="Single" SelectionChanged="ResultsList_SelectionChanged"
                 Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            <ListBox.ItemContainerStyle>
                <Style TargetType="ListBoxItem">
                    <Setter Property="HorizontalContentAlignment" Value="Stretch" />
                    <Setter Property="Padding" Value="0" />
                    <Setter Property="Margin" Value="0,0,0,7" />
                </Style>
            </ListBox.ItemContainerStyle>
            <ListBox.ItemTemplate>
                <DataTemplate>
                    <Border Background="#122131" BorderBrush="#29425B" BorderThickness="1" CornerRadius="6" Padding="11">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <StackPanel>
                                <TextBlock Text="{Binding Name}" FontSize="13" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" />
                                <TextBlock Text="{Binding Path}" Foreground="{StaticResource MutedTextBrush}" FontSize="10" TextTrimming="CharacterEllipsis" />
                            </StackPanel>
                            <TextBlock Grid.Column="1" Text="{Binding SizeLabel}" Foreground="#7990A7" FontSize="10" VerticalAlignment="Center" Margin="12,0,0,0" />
                        </Grid>
                    </Border>
                </DataTemplate>
            </ListBox.ItemTemplate>
        </ListBox>

        <Grid Grid.Row="5" Margin="0,20,0,0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal">
                <Button x:Name="OpenSelectedButton" Style="{StaticResource PrimaryButtonStyle}" Content="Open Selected" Click="OpenSelected_Click" Padding="14,8" />
                <Button x:Name="SaveSelectedButton" Style="{StaticResource FlatButtonStyle}" Content="Save Selected As…" Click="SaveSelected_Click" Padding="13,8" />
                <Button Style="{StaticResource FlatButtonStyle}" Content="Open Folder" Click="OpenFolder_Click" Padding="13,8" />
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button x:Name="RunAgainButton" Style="{StaticResource FlatButtonStyle}" Content="Run Another" Click="RunAgain_Click" Padding="13,8" />
                <Button Style="{StaticResource FlatButtonStyle}" Content="Close" Click="Close_Click" Padding="13,8" />
            </StackPanel>
        </Grid>
    </Grid>
</Window>
'@
Write-Text (Join-Path $SourceRoot 'src\PdfRescue.App\MultiResultDialog.xaml') $dialogXaml

$dialogCode = @'
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace PdfRescue.App;

public enum MultiResultAction
{
    None,
    OpenSelected,
    SaveSelected,
    OpenFolder,
    RunAgain
}

public sealed record MultiResultItem(string Name, string Path, string SizeLabel);

public partial class MultiResultDialog : Window
{
    public MultiResultAction SelectedAction { get; private set; }
    public string? SelectedPath => (ResultsList.SelectedItem as MultiResultItem)?.Path;

    public MultiResultDialog(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        bool canRunAgain)
    {
        InitializeComponent();
        Title = title;
        TitleText.Text = title;
        SummaryText.Text = summary;
        SourceNameText.Text = Path.GetFileName(sourcePath);
        SourcePathText.Text = sourcePath;

        var paths = resultPaths
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (paths.Length == 0) throw new ArgumentException("At least one result is required.", nameof(resultPaths));

        var folder = Path.GetDirectoryName(paths[0]) ?? string.Empty;
        ResultFolderText.Text = folder;
        ResultFolderText.ToolTip = folder;
        ResultCountText.Text = $"{paths.Length:N0} file{(paths.Length == 1 ? string.Empty : "s")}";
        ResultsList.ItemsSource = paths.Select(path => new MultiResultItem(
            Path.GetFileName(path),
            path,
            File.Exists(path) ? FormatBytes(new FileInfo(path).Length) : "Unavailable")).ToArray();
        ResultsList.SelectedIndex = 0;
        RunAgainButton.IsEnabled = canRunAgain;
        RefreshSelectionActions();
    }

    private void ResultsList_SelectionChanged(object sender, SelectionChangedEventArgs e) => RefreshSelectionActions();

    private void RefreshSelectionActions()
    {
        var available = SelectedPath is { } path && File.Exists(path);
        OpenSelectedButton.IsEnabled = available;
        SaveSelectedButton.IsEnabled = available;
    }

    private void Complete(MultiResultAction action)
    {
        SelectedAction = action;
        DialogResult = true;
    }

    private void OpenSelected_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.OpenSelected);
    private void SaveSelected_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.SaveSelected);
    private void OpenFolder_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.OpenFolder);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.RunAgain);
    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private static string FormatBytes(long bytes)
    {
        if (bytes >= 1024L * 1024 * 1024) return $"{bytes / (1024d * 1024 * 1024):0.##} GB";
        if (bytes >= 1024L * 1024) return $"{bytes / (1024d * 1024):0.##} MB";
        if (bytes >= 1024L) return $"{bytes / 1024d:0.##} KB";
        return $"{bytes:N0} B";
    }
}
'@
Write-Text (Join-Path $SourceRoot 'src\PdfRescue.App\MultiResultDialog.xaml.cs') $dialogCode

$operations = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
Replace-Exact $operations @'
    private Task InvokeToolOnUiAsync(Action action)
'@ @'
    private async Task ShowMultiResultWorkflowAsync(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        Action runAgain)
    {
        var available = resultPaths
            .Where(path => !string.IsNullOrWhiteSpace(path) && File.Exists(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (available.Length == 0) return;

        var dialog = new MultiResultDialog(title, summary, sourcePath, available, runAgain is not null)
        {
            Owner = this
        };
        if (dialog.ShowDialog() != true) return;

        switch (dialog.SelectedAction)
        {
            case MultiResultAction.OpenSelected:
                if (dialog.SelectedPath is { } selected) await OpenTaskOutputAsync(selected);
                break;
            case MultiResultAction.SaveSelected:
                if (dialog.SelectedPath is { } saveSelected) SaveResultCopy(saveSelected);
                break;
            case MultiResultAction.OpenFolder:
                OpenContainingFolder(dialog.SelectedPath ?? available[0]);
                break;
            case MultiResultAction.RunAgain:
                await InvokeToolOnUiAsync(runAgain);
                break;
        }
    }

    private Task InvokeToolOnUiAsync(Action action)
'@ 'Shared multi-result workflow'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        if (success && outputs is not null)
            MessageBox.Show(this, $"Created {outputs.Count:N0} PDF file(s) in:\n\n{Path.GetDirectoryName(outputs[0])}", "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
'@ @'
        if (success && outputs is { Count: > 0 })
            await ShowMultiResultWorkflowAsync(
                "Split complete",
                $"Created {outputs.Count:N0} split PDF file(s). The source PDF was not overwritten.",
                source,
                outputs,
                () => Split_Click(this, new RoutedEventArgs()));
'@ 'Split multi-result completion'

$configured = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ConfiguredTools.cs'
Replace-Exact $configured @'
        await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
        {
'@ @'
        var success = await RunPdfOperationAsync("Exporting PDF pages as images...", "Page images exported.", async token =>
        {
'@ 'Page image export success capture'
Replace-Exact $configured @'
            }
        });
    }

    private static void PublishStagedPageImages(
'@ @'
            }
        });

        if (success)
            await ShowMultiResultWorkflowAsync(
                "Page export complete",
                $"Exported {destinations.Length:N0} page image(s). The source PDF was not modified.",
                source,
                destinations,
                () => ExportPagesAsImages_Click(this, new System.Windows.RoutedEventArgs()));
    }

    private static void PublishStagedPageImages(
'@ 'Page image multi-result completion'

$matrix = Join-Path $SourceRoot 'IMPLEMENTATION_MATRIX.md'
Replace-Line $matrix '| 19 |' '| 19 | Create proper completion workflows | IN PROGRESS | Foreground PDF transformations already distinguish ORIGINAL versus RESULT and offer Open in New Tab, safe Use Result Here, Open Folder, Save As, Run Another and Close. Background Task Center jobs now retain source metadata and a separate Run Another action; completed tasks open a proper result-options workflow instead of a dead-end Open Result button, including generic Save As for PDF/Word/Excel/PowerPoint/text outputs and safe current-tab replacement only for clean source-PDF tabs. Merge can label multiple sources without inventing a fake source path. Phase-A staged job `97403214120` and clean no-patch rerun `97403748273` passed exact .NET 10.0.202 Windows x64 Release with 0 warnings, 0 errors and all smoke tests on source `0b13016214a952945bbdb2cb9e81896fdf87c7f9`. Multi-output Split/page-image completion and true side-by-side comparison remain; comparison depends on master item 6 split view and is not yet credited. |' 'Matrix item 19 phase A'

$state = Join-Path $SourceRoot 'docs\PROJECT_STATE.md'
Replace-Exact $state '`db8f7a7af2dabb4e8e383e7d6a00b71bbed11f95`' '`0b13016214a952945bbdb2cb9e81896fdf87c7f9`' 'Project state latest clean source'
Replace-Exact $state @'
The existing foreground PDF result dialog already makes ORIGINAL versus RESULT explicit and provides Open in New Tab, safe Use Result Here, Open Folder, Save As/Copy, Run Another and Close. The remaining gap is shared completion treatment for background Task Center outputs and multi-output workflows. True side-by-side comparison depends on master item 6 split view and must not be credited before that feature exists.
'@ @'
The foreground PDF result dialog makes ORIGINAL versus RESULT explicit and provides Open in New Tab, safe Use Result Here, Open Folder, Save As, Run Another and Close. Phase A now extends that model to completed Task Center jobs: queued results retain source metadata, can reopen their originating tool, and open a generic result-options workflow for PDF and non-PDF outputs. Phase-A staged job `97403214120` and clean no-patch job `97403748273` both passed exact .NET 10.0.202 Windows x64 Release with 0 warnings, 0 errors and all smoke tests on source `0b13016214a952945bbdb2cb9e81896fdf87c7f9`.

The remaining gaps are multi-output Split/page-image completion and true side-by-side comparison. Comparison depends on master item 6 split view and must not be credited before that feature exists.
'@ 'Project state item19 phase A'

Push-Location $SourceRoot
try {
    git add -- IMPLEMENTATION_MATRIX.md docs/PROJECT_STATE.md
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage item-19 ledger updates.' }
}
finally { Pop-Location }

Write-Host 'Item 19 multi-output completion workflow applied.' -ForegroundColor Green
