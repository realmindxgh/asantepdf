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
                            <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
'@ @'
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="CompareTabsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenSplitView_Click" IsEnabled="False" ToolTip="Compare two open PDFs side by side">
                                    <TextBlock Text="&#xE8A0;" FontFamily="Segoe MDL2 Assets" FontSize="16" />
                                </Button>
                                <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
                            </StackPanel>
'@ 'document-tab split-view button'

Replace-Exact $xaml @'
                            </ScrollViewer>
                            <Button x:Name="ExpandPagesSidebarButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="38"
'@ @'
                            </ScrollViewer>

                            <Grid x:Name="SplitComparisonPanel" Visibility="Collapsed" Background="#0A1520" Panel.ZIndex="15">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                    <RowDefinition Height="*" />
                                </Grid.RowDefinitions>
                                <Border Grid.Row="0" Background="#0D1A28" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1" Padding="10,8">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*" />
                                            <ColumnDefinition Width="Auto" />
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                            <TextBlock Text="Compare" FontWeight="SemiBold" FontSize="14" VerticalAlignment="Center" Margin="0,0,10,0" />
                                            <ComboBox x:Name="SplitLeftDocumentCombo" Width="220" DisplayMemberPath="DisplayTitle" SelectionChanged="SplitLeftDocumentCombo_SelectionChanged" ToolTip="Left PDF" />
                                            <TextBlock Text="↔" Foreground="{StaticResource MutedTextBrush}" VerticalAlignment="Center" Margin="8,0" />
                                            <ComboBox x:Name="SplitRightDocumentCombo" Width="220" DisplayMemberPath="DisplayTitle" SelectionChanged="SplitRightDocumentCombo_SelectionChanged" ToolTip="Right PDF" />
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                                            <CheckBox x:Name="SplitLinkedScrollCheck" Content="Linked scroll" VerticalAlignment="Center" Margin="6,0" Checked="SplitLinkedScrollCheck_Changed" Unchecked="SplitLinkedScrollCheck_Changed" />
                                            <CheckBox x:Name="SplitLinkedZoomCheck" Content="Sync zoom" VerticalAlignment="Center" Margin="6,0" Checked="SplitLinkedZoomCheck_Changed" Unchecked="SplitLinkedZoomCheck_Changed" />
                                            <Button Style="{StaticResource FlatButtonStyle}" Content="Align pages" Click="SplitAlignPages_Click" Padding="10,5" ToolTip="Align the right pane to the left page number" />
                                            <Button Style="{StaticResource FlatButtonStyle}" Content="Swap" Click="SplitSwap_Click" Padding="10,5" />
                                            <Button Style="{StaticResource FlatButtonStyle}" Content="Exit" Click="SplitExit_Click" Padding="10,5" />
                                        </StackPanel>
                                    </Grid>
                                </Border>
                                <Grid Grid.Row="1">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="5"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <Grid Grid.Column="0">
                                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                        <Border Grid.Row="0" Background="#0F1B29" Padding="8" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1">
                                            <Grid>
                                                <StackPanel Orientation="Horizontal">
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="‹" Width="32" Padding="0" Click="SplitLeftPrevious_Click" ToolTip="Previous page" />
                                                    <TextBox x:Name="SplitLeftPageBox" Width="52" Height="30" Margin="5,0" TextAlignment="Center" KeyDown="SplitLeftPageBox_KeyDown" ToolTip="Left page number" />
                                                    <TextBlock x:Name="SplitLeftPageCountText" Text="/ 0" VerticalAlignment="Center" Foreground="{StaticResource MutedTextBrush}" />
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="›" Width="32" Padding="0" Margin="5,0,0,0" Click="SplitLeftNext_Click" ToolTip="Next page" />
                                                </StackPanel>
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="−" Width="32" Padding="0" Click="SplitLeftZoomOut_Click" ToolTip="Zoom out left pane" />
                                                    <TextBlock x:Name="SplitLeftZoomText" Text="100%" Width="58" TextAlignment="Center" VerticalAlignment="Center" />
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="+" Width="32" Padding="0" Click="SplitLeftZoomIn_Click" ToolTip="Zoom in left pane" />
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <ScrollViewer x:Name="SplitLeftScroll" Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" ScrollChanged="SplitLeftScroll_ScrollChanged">
                                            <Border Margin="18" Background="White" BorderBrush="#3A4A59" BorderThickness="1" Padding="8" HorizontalAlignment="Center" VerticalAlignment="Top">
                                                <Image x:Name="SplitLeftImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                            </Border>
                                        </ScrollViewer>
                                    </Grid>
                                    <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Stretch" Background="#24364A" ResizeDirection="Columns" ResizeBehavior="PreviousAndNext" />
                                    <Grid Grid.Column="2">
                                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                        <Border Grid.Row="0" Background="#0F1B29" Padding="8" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1">
                                            <Grid>
                                                <StackPanel Orientation="Horizontal">
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="‹" Width="32" Padding="0" Click="SplitRightPrevious_Click" ToolTip="Previous page" />
                                                    <TextBox x:Name="SplitRightPageBox" Width="52" Height="30" Margin="5,0" TextAlignment="Center" KeyDown="SplitRightPageBox_KeyDown" ToolTip="Right page number" />
                                                    <TextBlock x:Name="SplitRightPageCountText" Text="/ 0" VerticalAlignment="Center" Foreground="{StaticResource MutedTextBrush}" />
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="›" Width="32" Padding="0" Margin="5,0,0,0" Click="SplitRightNext_Click" ToolTip="Next page" />
                                                </StackPanel>
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="−" Width="32" Padding="0" Click="SplitRightZoomOut_Click" ToolTip="Zoom out right pane" />
                                                    <TextBlock x:Name="SplitRightZoomText" Text="100%" Width="58" TextAlignment="Center" VerticalAlignment="Center" />
                                                    <Button Style="{StaticResource FlatButtonStyle}" Content="+" Width="32" Padding="0" Click="SplitRightZoomIn_Click" ToolTip="Zoom in right pane" />
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <ScrollViewer x:Name="SplitRightScroll" Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" ScrollChanged="SplitRightScroll_ScrollChanged">
                                            <Border Margin="18" Background="White" BorderBrush="#3A4A59" BorderThickness="1" Padding="8" HorizontalAlignment="Center" VerticalAlignment="Top">
                                                <Image x:Name="SplitRightImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                            </Border>
                                        </ScrollViewer>
                                    </Grid>
                                </Grid>
                            </Grid>

                            <Button x:Name="ExpandPagesSidebarButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="38"
'@ 'split-view workspace'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        RedoButton.IsEnabled = available && _redo.Count > 0;
        RedoMenuItem.IsEnabled = available && _redo.Count > 0;
        UpdateDocumentTitleDirtyIndicator();
        UpdateInspectorContext();
'@ @'
        RedoButton.IsEnabled = available && _redo.Count > 0;
        RedoMenuItem.IsEnabled = available && _redo.Count > 0;
        CompareTabsButton.IsEnabled = available && DocumentTabs.Count >= 2;
        UpdateDocumentTitleDirtyIndicator();
        UpdateInspectorContext();
'@ 'split-view command availability'

$tabs = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
Replace-Exact $tabs @'
        RememberClosedDocumentTab(tab);
        DocumentTabs.Remove(tab);

        if (!active) return true;
'@ @'
        RememberClosedDocumentTab(tab);
        DocumentTabs.Remove(tab);
        if (DocumentTabs.Count < 2 && SplitComparisonPanel.Visibility == Visibility.Visible)
            ExitSplitViewCore();

        if (!active) return true;
'@ 'split-view closes when fewer than two tabs remain'

$dialogXaml = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml'
Replace-Exact $dialogXaml @'
            <Button x:Name="OpenNewTabButton" Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
            <Button Style="{StaticResource FlatButtonStyle}" Click="OpenFolder_Click" Content="Open Folder" Padding="13,8" />
'@ @'
            <Button x:Name="OpenNewTabButton" Style="{StaticResource PrimaryButtonStyle}" Click="OpenNewTab_Click" Content="Open in New Tab" Padding="16,8" />
            <Button x:Name="CompareButton" Style="{StaticResource FlatButtonStyle}" Click="Compare_Click" Content="Compare with Original" Padding="13,8" ToolTip="Open original and result side by side" />
            <Button Style="{StaticResource FlatButtonStyle}" Click="OpenFolder_Click" Content="Open Folder" Padding="13,8" />
'@ 'result compare button'

$dialogCode = Join-Path $SourceRoot 'src\PdfRescue.App\PdfResultDialog.xaml.cs'
Replace-Exact $dialogCode @'
    SaveCopy,
    RunAgain
'@ @'
    SaveCopy,
    Compare,
    RunAgain
'@ 'result compare enum'
Replace-Exact $dialogCode @'
        OpenNewTabButton.Content = resultIsPdf ? "Open in New Tab" : "Open Result";
        RunAgainButton.IsEnabled = canRunAgain;
'@ @'
        OpenNewTabButton.Content = resultIsPdf ? "Open in New Tab" : "Open Result";
        CompareButton.Visibility = resultIsPdf ? Visibility.Visible : Visibility.Collapsed;
        CompareButton.IsEnabled = resultIsPdf && !string.IsNullOrWhiteSpace(originalPath) && File.Exists(originalPath);
        RunAgainButton.IsEnabled = canRunAgain;
'@ 'result compare availability'
Replace-Exact $dialogCode @'
    private void SaveCopy_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.SaveCopy);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.RunAgain);
'@ @'
    private void SaveCopy_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.SaveCopy);
    private void Compare_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.Compare);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.RunAgain);
'@ 'result compare handler'

$results = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.OperationResults.cs'
Replace-Exact $results @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
'@ @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.Compare:
                if (resultIsPdf && !string.IsNullOrWhiteSpace(originalPath))
                    await OpenResultComparisonAsync(originalPath, resultPath);
                break;
            case PdfResultAction.RunAgain:
'@ 'foreground result compare workflow'
Replace-Exact $results @'
            case PdfResultAction.SaveCopy:
                SaveResultCopy(resultPath);
                break;
            case PdfResultAction.RunAgain:
                await item.RequestRunAgainAsync();
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
'@ 'task result compare workflow'

$split = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.SplitView.cs'
$splitContent = @'
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace PdfRescue.App;

public partial class MainWindow
{
    private IPdfRenderer? _splitLeftRenderer;
    private IPdfRenderer? _splitRightRenderer;
    private CancellationTokenSource? _splitLeftCts;
    private CancellationTokenSource? _splitRightCts;
    private DocumentTabSession? _splitLeftTab;
    private DocumentTabSession? _splitRightTab;
    private int _splitLeftPage = 1;
    private int _splitRightPage = 1;
    private uint _splitLeftRenderWidth = 900;
    private uint _splitRightRenderWidth = 900;
    private bool _splitUpdatingSelection;
    private bool _splitSyncingScroll;
    private bool _splitLifecycleHooked;

    private bool SplitLinkedScroll => SplitLinkedScrollCheck?.IsChecked == true;
    private bool SplitLinkedZoom => SplitLinkedZoomCheck?.IsChecked == true;

    private async void OpenSplitView_Click(object sender, RoutedEventArgs e) => await OpenSplitViewAsync();

    private async Task OpenSplitViewAsync(DocumentTabSession? preferredLeft = null, DocumentTabSession? preferredRight = null)
    {
        if (DocumentTabs.Count < 2)
        {
            MessageBox.Show(this, "Open at least two PDFs before starting comparison.", "Compare PDFs", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        EnsureSplitLifecycle();
        CaptureActiveDocumentTabState();

        var left = preferredLeft ?? _activeDocumentTab ?? DocumentTabs[0];
        var right = preferredRight ?? DocumentTabs.First(tab => !ReferenceEquals(tab, left));
        if (ReferenceEquals(left, right))
            right = DocumentTabs.First(tab => !ReferenceEquals(tab, left));

        _splitUpdatingSelection = true;
        try
        {
            SplitLeftDocumentCombo.ItemsSource = DocumentTabs;
            SplitRightDocumentCombo.ItemsSource = DocumentTabs;
            SplitLeftDocumentCombo.SelectedItem = left;
            SplitRightDocumentCombo.SelectedItem = right;
        }
        finally { _splitUpdatingSelection = false; }

        SplitComparisonPanel.Visibility = Visibility.Visible;
        PreviewScroll.Visibility = Visibility.Collapsed;
        EmptyPanel.Visibility = Visibility.Collapsed;

        await LoadSplitPaneAsync(true, left);
        await LoadSplitPaneAsync(false, right);
        StatusText.Text = $"Comparing {left.Name} with {right.Name}.";
    }

    private async Task OpenResultComparisonAsync(string originalPath, string resultPath)
    {
        if (!File.Exists(originalPath) || !File.Exists(resultPath)) return;

        await OpenPdfAsync(originalPath);
        var original = FindOpenDocumentTab(originalPath);
        await OpenPdfAsync(resultPath);
        var result = FindOpenDocumentTab(resultPath);
        if (original is null || result is null || ReferenceEquals(original, result)) return;

        await OpenSplitViewAsync(original, result);
    }

    private void EnsureSplitLifecycle()
    {
        if (_splitLifecycleHooked) return;
        _splitLifecycleHooked = true;
        Closed += (_, _) =>
        {
            _splitLeftCts?.Cancel();
            _splitRightCts?.Cancel();
            _splitLeftCts?.Dispose();
            _splitRightCts?.Dispose();
            _splitLeftRenderer?.Dispose();
            _splitRightRenderer?.Dispose();
        };
    }

    private async Task LoadSplitPaneAsync(bool left, DocumentTabSession tab)
    {
        if (!File.Exists(tab.Path)) return;

        var cts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        if (left)
        {
            _splitLeftCts?.Cancel();
            _splitLeftCts?.Dispose();
            _splitLeftCts = cts;
            _splitLeftRenderer ??= PdfRendererFactory.CreateProduction();
            _splitLeftTab = tab;
            await _splitLeftRenderer.OpenAsync(tab.Path, cts.Token);
            _splitLeftPage = Math.Clamp(tab.SelectedPage, 1, checked((int)_splitLeftRenderer.PageCount));
            await RenderSplitPaneAsync(true, cts.Token);
        }
        else
        {
            _splitRightCts?.Cancel();
            _splitRightCts?.Dispose();
            _splitRightCts = cts;
            _splitRightRenderer ??= PdfRendererFactory.CreateProduction();
            _splitRightTab = tab;
            await _splitRightRenderer.OpenAsync(tab.Path, cts.Token);
            _splitRightPage = Math.Clamp(tab.SelectedPage, 1, checked((int)_splitRightRenderer.PageCount));
            await RenderSplitPaneAsync(false, cts.Token);
        }
    }

    private async Task RenderSplitPaneAsync(bool left, CancellationToken token)
    {
        try
        {
            if (left)
            {
                if (_splitLeftRenderer is null || _splitLeftRenderer.PageCount == 0) return;
                _splitLeftPage = Math.Clamp(_splitLeftPage, 1, checked((int)_splitLeftRenderer.PageCount));
                var bitmap = await _splitLeftRenderer.RenderAsync(_splitLeftPage, _splitLeftRenderWidth, token);
                token.ThrowIfCancellationRequested();
                SplitLeftImage.Source = bitmap;
                SplitLeftPageBox.Text = _splitLeftPage.ToString();
                SplitLeftPageCountText.Text = $"/ {_splitLeftRenderer.PageCount:N0}";
                SplitLeftZoomText.Text = FormatSplitZoom(_splitLeftRenderWidth);
            }
            else
            {
                if (_splitRightRenderer is null || _splitRightRenderer.PageCount == 0) return;
                _splitRightPage = Math.Clamp(_splitRightPage, 1, checked((int)_splitRightRenderer.PageCount));
                var bitmap = await _splitRightRenderer.RenderAsync(_splitRightPage, _splitRightRenderWidth, token);
                token.ThrowIfCancellationRequested();
                SplitRightImage.Source = bitmap;
                SplitRightPageBox.Text = _splitRightPage.ToString();
                SplitRightPageCountText.Text = $"/ {_splitRightRenderer.PageCount:N0}";
                SplitRightZoomText.Text = FormatSplitZoom(_splitRightRenderWidth);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Split-view render failed: " + ex);
            StatusText.Text = "One comparison pane could not be rendered.";
        }
    }

    private static string FormatSplitZoom(uint width)
    {
        var percent = Math.Clamp((int)Math.Round(width / 9d), 40, 260);
        return $"{percent}%";
    }

    private async void SplitLeftDocumentCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_splitUpdatingSelection || SplitLeftDocumentCombo.SelectedItem is not DocumentTabSession tab) return;
        if (ReferenceEquals(tab, _splitRightTab))
        {
            var alternate = DocumentTabs.FirstOrDefault(item => !ReferenceEquals(item, tab));
            if (alternate is null) return;
            _splitUpdatingSelection = true;
            SplitRightDocumentCombo.SelectedItem = alternate;
            _splitUpdatingSelection = false;
            await LoadSplitPaneAsync(false, alternate);
        }
        await LoadSplitPaneAsync(true, tab);
    }

    private async void SplitRightDocumentCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_splitUpdatingSelection || SplitRightDocumentCombo.SelectedItem is not DocumentTabSession tab) return;
        if (ReferenceEquals(tab, _splitLeftTab))
        {
            var alternate = DocumentTabs.FirstOrDefault(item => !ReferenceEquals(item, tab));
            if (alternate is null) return;
            _splitUpdatingSelection = true;
            SplitLeftDocumentCombo.SelectedItem = alternate;
            _splitUpdatingSelection = false;
            await LoadSplitPaneAsync(true, alternate);
        }
        await LoadSplitPaneAsync(false, tab);
    }

    private async void SplitLeftPrevious_Click(object sender, RoutedEventArgs e)
    {
        if (_splitLeftRenderer is null) return;
        _splitLeftPage = Math.Max(1, _splitLeftPage - 1);
        await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
    }

    private async void SplitLeftNext_Click(object sender, RoutedEventArgs e)
    {
        if (_splitLeftRenderer is null) return;
        _splitLeftPage = Math.Min(checked((int)_splitLeftRenderer.PageCount), _splitLeftPage + 1);
        await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
    }

    private async void SplitRightPrevious_Click(object sender, RoutedEventArgs e)
    {
        if (_splitRightRenderer is null) return;
        _splitRightPage = Math.Max(1, _splitRightPage - 1);
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private async void SplitRightNext_Click(object sender, RoutedEventArgs e)
    {
        if (_splitRightRenderer is null) return;
        _splitRightPage = Math.Min(checked((int)_splitRightRenderer.PageCount), _splitRightPage + 1);
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private async void SplitLeftPageBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || _splitLeftRenderer is null) return;
        if (int.TryParse(SplitLeftPageBox.Text, out var page))
        {
            _splitLeftPage = Math.Clamp(page, 1, checked((int)_splitLeftRenderer.PageCount));
            await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
        }
        e.Handled = true;
    }

    private async void SplitRightPageBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || _splitRightRenderer is null) return;
        if (int.TryParse(SplitRightPageBox.Text, out var page))
        {
            _splitRightPage = Math.Clamp(page, 1, checked((int)_splitRightRenderer.PageCount));
            await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
        }
        e.Handled = true;
    }

    private async void SplitLeftZoomOut_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(true, -120);
    private async void SplitLeftZoomIn_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(true, 120);
    private async void SplitRightZoomOut_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(false, -120);
    private async void SplitRightZoomIn_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(false, 120);

    private async Task ChangeSplitZoomAsync(bool left, int delta)
    {
        if (left)
        {
            _splitLeftRenderWidth = (uint)Math.Clamp((long)_splitLeftRenderWidth + delta, 360, 2400);
            if (SplitLinkedZoom) _splitRightRenderWidth = _splitLeftRenderWidth;
            await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
            if (SplitLinkedZoom) await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
        }
        else
        {
            _splitRightRenderWidth = (uint)Math.Clamp((long)_splitRightRenderWidth + delta, 360, 2400);
            if (SplitLinkedZoom) _splitLeftRenderWidth = _splitRightRenderWidth;
            await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
            if (SplitLinkedZoom) await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
        }
    }

    private void SplitLinkedScrollCheck_Changed(object sender, RoutedEventArgs e) { }

    private async void SplitLinkedZoomCheck_Changed(object sender, RoutedEventArgs e)
    {
        if (!SplitLinkedZoom || SplitComparisonPanel.Visibility != Visibility.Visible) return;
        _splitRightRenderWidth = _splitLeftRenderWidth;
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private void SplitLeftScroll_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (!SplitLinkedScroll || _splitSyncingScroll || e.VerticalChange == 0 && e.HorizontalChange == 0) return;
        SyncSplitScroll(SplitLeftScroll, SplitRightScroll);
    }

    private void SplitRightScroll_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (!SplitLinkedScroll || _splitSyncingScroll || e.VerticalChange == 0 && e.HorizontalChange == 0) return;
        SyncSplitScroll(SplitRightScroll, SplitLeftScroll);
    }

    private void SyncSplitScroll(ScrollViewer source, ScrollViewer target)
    {
        _splitSyncingScroll = true;
        try
        {
            var vRatio = source.ScrollableHeight <= 0 ? 0 : source.VerticalOffset / source.ScrollableHeight;
            var hRatio = source.ScrollableWidth <= 0 ? 0 : source.HorizontalOffset / source.ScrollableWidth;
            target.ScrollToVerticalOffset(vRatio * target.ScrollableHeight);
            target.ScrollToHorizontalOffset(hRatio * target.ScrollableWidth);
        }
        finally { _splitSyncingScroll = false; }
    }

    private async void SplitAlignPages_Click(object sender, RoutedEventArgs e)
    {
        if (_splitRightRenderer is null) return;
        _splitRightPage = Math.Clamp(_splitLeftPage, 1, checked((int)_splitRightRenderer.PageCount));
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private async void SplitSwap_Click(object sender, RoutedEventArgs e)
    {
        if (_splitLeftTab is null || _splitRightTab is null) return;
        var left = _splitLeftTab;
        var right = _splitRightTab;
        var leftPage = _splitLeftPage;
        var rightPage = _splitRightPage;
        var leftZoom = _splitLeftRenderWidth;
        var rightZoom = _splitRightRenderWidth;

        _splitUpdatingSelection = true;
        SplitLeftDocumentCombo.SelectedItem = right;
        SplitRightDocumentCombo.SelectedItem = left;
        _splitUpdatingSelection = false;

        await LoadSplitPaneAsync(true, right);
        await LoadSplitPaneAsync(false, left);
        _splitLeftPage = Math.Clamp(rightPage, 1, checked((int)(_splitLeftRenderer?.PageCount ?? 1)));
        _splitRightPage = Math.Clamp(leftPage, 1, checked((int)(_splitRightRenderer?.PageCount ?? 1)));
        _splitLeftRenderWidth = rightZoom;
        _splitRightRenderWidth = leftZoom;
        await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private void SplitExit_Click(object sender, RoutedEventArgs e) => ExitSplitViewCore();

    private void ExitSplitViewCore()
    {
        if (SplitComparisonPanel is null) return;
        SplitComparisonPanel.Visibility = Visibility.Collapsed;
        if (_currentPdf is not null)
            PreviewScroll.Visibility = Visibility.Visible;
        StatusText.Text = "Ready.";
    }
}
'@
Write-Text $split $splitContent

Write-Host 'Split-view comparison and completion compare workflow staged.' -ForegroundColor Green
& cmd /c exit 0