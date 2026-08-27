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

$dialogXaml = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml'
Replace-Exact $dialogXaml @'
            <Button x:Name="OpenNewTabButton" Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
            <Button Style="{StaticResource FlatButtonStyle}" Click="OpenFolder_Click" Content="Open Folder" Padding="13,8" />
'@ @'
            <Button x:Name="OpenNewTabButton" Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
            <Button x:Name="CompareButton" Style="{StaticResource FlatButtonStyle}" Click="Compare_Click" Content="Compare with Original" Padding="13,8" ToolTip="Open the original and result side by side" />
            <Button Style="{StaticResource FlatButtonStyle}" Click="OpenFolder_Click" Content="Open Folder" Padding="13,8" />
'@ 'result comparison button'

$dialogCode = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml.cs'
Replace-Exact $dialogCode @'
    SaveCopy,
    RunAgain
'@ @'
    SaveCopy,
    Compare,
    RunAgain
'@ 'result comparison enum'
Replace-Exact $dialogCode @'
        OpenNewTabButton.Content = resultIsPdf ? "Open in New Tab" : "Open Result";
        RunAgainButton.IsEnabled = canRunAgain;
'@ @'
        OpenNewTabButton.Content = resultIsPdf ? "Open in New Tab" : "Open Result";
        CompareButton.Visibility = resultIsPdf ? Visibility.Visible : Visibility.Collapsed;
        CompareButton.IsEnabled = resultIsPdf && !string.IsNullOrWhiteSpace(originalPath) && File.Exists(originalPath);
        RunAgainButton.IsEnabled = canRunAgain;
'@ 'result comparison availability'
Replace-Exact $dialogCode @'
    private void SaveCopy_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.SaveCopy);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.RunAgain);
'@ @'
    private void SaveCopy_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.SaveCopy);
    private void Compare_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.Compare);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.RunAgain);
'@ 'result comparison click handler'

$results = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
Replace-Exact $results @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
                if (runAgainAction is not null)
                    await InvokeToolOnUiAsync(runAgainAction);
                break;
'@ @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.Compare:
                if (resultIsPdf && !string.IsNullOrWhiteSpace(originalPath))
                    await OpenResultComparisonAsync(originalPath, resultPath);
                break;
            case PdfResultAction.RunAgain:
                if (runAgainAction is not null)
                    await InvokeToolOnUiAsync(runAgainAction);
                break;
'@ 'foreground result comparison'

Replace-Exact $results @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
                await item.RequestRunAgainAsync();
                break;
'@ @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.Compare:
                if (isPdf && !string.IsNullOrWhiteSpace(sourcePath))
                    await OpenResultComparisonAsync(sourcePath, resultPath);
                break;
            case PdfResultAction.RunAgain:
                await item.RequestRunAgainAsync();
                break;
'@ 'task result comparison'

Write-Host 'Result-to-original comparison workflow staged.' -ForegroundColor Green
& cmd /c exit 0