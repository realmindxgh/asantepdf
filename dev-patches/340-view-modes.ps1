param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false)) }
function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=Normalize([IO.File]::ReadAllText($Path)); $o=Normalize $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; Write-Text $Path ($t.Replace($o,(Normalize $New))) }

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                <Button Style="{StaticResource FlatButtonStyle}" Click="FitPageShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="Fit Page" Padding="10,5" />
                            </StackPanel>
                            <Border Grid.Column="2" Background="#101D2A" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="7" Padding="4">
'@ @'
                                <Button Style="{StaticResource FlatButtonStyle}" Click="FitPageShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="Fit Page" Padding="10,5" />
                                <ComboBox x:Name="PageViewModeCombo" Width="128" Height="30" Margin="12,0,0,0"
                                          SelectionChanged="PageViewModeCombo_SelectionChanged"
                                          IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Document viewing mode">
                                    <ComboBoxItem Content="Single Page" />
                                    <ComboBoxItem Content="Continuous" />
                                    <ComboBoxItem Content="Two Page" />
                                </ComboBox>
                            </StackPanel>
                            <Border Grid.Column="2" Background="#101D2A" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="7" Padding="4">
'@ 'view-mode selector'

Replace-Exact $xaml @'
                            </ScrollViewer>

                            <Grid x:Name="SplitComparisonPanel" Visibility="Collapsed" Background="#0A1520" Panel.ZIndex="15">
'@ @'
                            </ScrollViewer>

                            <ListBox x:Name="ContinuousPagesList" Visibility="Collapsed" Background="Transparent" BorderThickness="0"
                                     SelectionMode="Single" SelectionChanged="ContinuousPagesList_SelectionChanged"
                                     ScrollViewer.HorizontalScrollBarVisibility="Auto" ScrollViewer.VerticalScrollBarVisibility="Auto"
                                     VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling">
                                <ListBox.ItemsPanel>
                                    <ItemsPanelTemplate><VirtualizingStackPanel /></ItemsPanelTemplate>
                                </ListBox.ItemsPanel>
                                <ListBox.ItemContainerStyle>
                                    <Style TargetType="ListBoxItem">
                                        <Setter Property="HorizontalContentAlignment" Value="Center" />
                                        <Setter Property="Background" Value="Transparent" />
                                        <Setter Property="BorderThickness" Value="0" />
                                        <Setter Property="Padding" Value="0" />
                                        <Setter Property="Margin" Value="0" />
                                    </Style>
                                </ListBox.ItemContainerStyle>
                                <ListBox.ItemTemplate>
                                    <DataTemplate>
                                        <Border x:Name="ContinuousPageCard" Margin="28,14" Padding="12" Background="White" BorderBrush="#3A4A59" BorderThickness="1" CornerRadius="3">
                                            <StackPanel>
                                                <TextBlock Text="{Binding Page.Label}" Foreground="#5D6875" FontSize="11" HorizontalAlignment="Center" Margin="0,0,0,8" />
                                                <Grid>
                                                    <Image Source="{Binding Bitmap}" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality"
                                                           Loaded="ContinuousPageImage_Loaded" Unloaded="ContinuousPageImage_Unloaded">
                                                        <Image.LayoutTransform><RotateTransform Angle="{Binding Page.Rotation}" /></Image.LayoutTransform>
                                                    </Image>
                                                    <TextBlock Text="Rendering page…" Foreground="#607080" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="12">
                                                        <TextBlock.Style>
                                                            <Style TargetType="TextBlock">
                                                                <Setter Property="Visibility" Value="Visible" />
                                                                <Style.Triggers><DataTrigger Binding="{Binding HasBitmap}" Value="True"><Setter Property="Visibility" Value="Collapsed" /></DataTrigger></Style.Triggers>
                                                            </Style>
                                                        </TextBlock.Style>
                                                    </TextBlock>
                                                </Grid>
                                            </StackPanel>
                                        </Border>
                                        <DataTemplate.Triggers>
                                            <DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                                <Setter TargetName="ContinuousPageCard" Property="BorderBrush" Value="#2D7DFF" />
                                                <Setter TargetName="ContinuousPageCard" Property="BorderThickness" Value="2" />
                                            </DataTrigger>
                                        </DataTemplate.Triggers>
                                    </DataTemplate>
                                </ListBox.ItemTemplate>
                            </ListBox>

                            <ScrollViewer x:Name="TwoPageScroll" Visibility="Collapsed" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
                                <Grid Margin="22" HorizontalAlignment="Center" VerticalAlignment="Top">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <Border Grid.Column="0" Margin="8" Padding="10" Background="White" BorderBrush="#3A4A59" BorderThickness="1" CornerRadius="3">
                                        <StackPanel>
                                            <TextBlock x:Name="TwoPageLeftLabel" Foreground="#5D6875" FontSize="11" HorizontalAlignment="Center" Margin="0,0,0,8" />
                                            <Image x:Name="TwoPageLeftImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                        </StackPanel>
                                    </Border>
                                    <Border x:Name="TwoPageRightCard" Grid.Column="1" Margin="8" Padding="10" Background="White" BorderBrush="#3A4A59" BorderThickness="1" CornerRadius="3">
                                        <StackPanel>
                                            <TextBlock x:Name="TwoPageRightLabel" Foreground="#5D6875" FontSize="11" HorizontalAlignment="Center" Margin="0,0,0,8" />
                                            <Image x:Name="TwoPageRightImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </ScrollViewer>

                            <Grid x:Name="SplitComparisonPanel" Visibility="Collapsed" Background="#0A1520" Panel.ZIndex="15">
'@ 'continuous and two-page surfaces'

$viewModes = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ViewModes.cs'
Write-Text $viewModes @'
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed class ContinuousPageViewItem : INotifyPropertyChanged
{
    private BitmapSource? _bitmap;
    public ContinuousPageViewItem(PdfPageItem page) => Page = page;
    public PdfPageItem Page { get; }
    public BitmapSource? Bitmap { get => _bitmap; set { if (ReferenceEquals(_bitmap, value)) return; _bitmap = value; OnPropertyChanged(); OnPropertyChanged(nameof(HasBitmap)); } }
    public bool HasBitmap => Bitmap is not null;
    public bool IsRealized { get; set; }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public partial class MainWindow
{
    private readonly ObservableCollection<ContinuousPageViewItem> _continuousPageItems = [];
    private readonly SemaphoreSlim _continuousRenderLock = new(1, 1);
    private readonly Dictionary<int, BitmapSource> _continuousRenderCache = new();
    private CancellationTokenSource? _pageViewCts;
    private DefaultPageViewMode _activePageViewMode = DefaultPageViewMode.SinglePage;
    private int _pageViewGeneration;
    private bool _syncingPageViewSelection;

    private bool IsSinglePageViewActive => _activePageViewMode == DefaultPageViewMode.SinglePage;

    private void InitializePageViewModes()
    {
        ContinuousPagesList.ItemsSource = _continuousPageItems;
        ContinuousPagesList.AddHandler(ScrollViewer.ScrollChangedEvent, new ScrollChangedEventHandler(ContinuousPagesList_ScrollChanged));
        Pages.CollectionChanged += (_, _) =>
        {
            if (_activePageViewMode == DefaultPageViewMode.Continuous) RebuildContinuousPageItems();
            else if (_activePageViewMode == DefaultPageViewMode.TwoPage && _currentPdf is not null) _ = RenderTwoPageAsync();
        };

        _activePageViewMode = AppSettingsService.Current.Preferences.DefaultPageView;
        _syncingPageViewSelection = true;
        PageViewModeCombo.SelectedIndex = (int)_activePageViewMode;
        _syncingPageViewSelection = false;
        ApplyPageViewVisibility();

        Closed += (_, _) =>
        {
            _pageViewCts?.Cancel();
            _pageViewCts?.Dispose();
            _continuousRenderLock.Dispose();
        };
    }

    private async void PageViewModeCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncingPageViewSelection || PageViewModeCombo.SelectedIndex < 0) return;
        var mode = (DefaultPageViewMode)Math.Clamp(PageViewModeCombo.SelectedIndex, 0, 2);
        await SetPageViewModeAsync(mode, persist: true);
    }

    private async Task SetPageViewModeAsync(DefaultPageViewMode mode, bool persist)
    {
        _activePageViewMode = mode;
        _pageViewGeneration++;
        _pageViewCts?.Cancel();
        _pageViewCts?.Dispose();
        _pageViewCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);

        if (persist)
        {
            var current = AppSettingsService.Current.Preferences;
            if (current.DefaultPageView != mode) AppSettingsService.Current.Save(current with { DefaultPageView = mode });
        }

        ApplyPageViewVisibility();
        await RefreshActivePageViewAsync(forceRerender: false);
        StatusText.Text = mode switch
        {
            DefaultPageViewMode.Continuous => "Continuous reading view.",
            DefaultPageViewMode.TwoPage => "Two-page reading view.",
            _ => "Single-page reading view."
        };
    }

    private void ApplyPageViewVisibility()
    {
        var hasDocument = _currentPdf is not null && Pages.Count > 0;
        if (!hasDocument)
        {
            PreviewScroll.Visibility = Visibility.Collapsed;
            ContinuousPagesList.Visibility = Visibility.Collapsed;
            TwoPageScroll.Visibility = Visibility.Collapsed;
            return;
        }
        if (SplitComparisonPanel?.Visibility == Visibility.Visible) return;

        PreviewScroll.Visibility = _activePageViewMode == DefaultPageViewMode.SinglePage ? Visibility.Visible : Visibility.Collapsed;
        ContinuousPagesList.Visibility = _activePageViewMode == DefaultPageViewMode.Continuous ? Visibility.Visible : Visibility.Collapsed;
        TwoPageScroll.Visibility = _activePageViewMode == DefaultPageViewMode.TwoPage ? Visibility.Visible : Visibility.Collapsed;
        if (!IsSinglePageViewActive)
        {
            SearchHighlightCanvas.Visibility = Visibility.Collapsed;
            TextSelectionCanvas.Visibility = Visibility.Collapsed;
            MarkupCanvas.Visibility = Visibility.Collapsed;
        }
    }

    private void HidePrimaryPageViews()
    {
        PreviewScroll.Visibility = Visibility.Collapsed;
        ContinuousPagesList.Visibility = Visibility.Collapsed;
        TwoPageScroll.Visibility = Visibility.Collapsed;
    }

    private async Task RefreshActivePageViewAsync(bool forceRerender = false)
    {
        if (_currentPdf is null || Pages.Count == 0) { ApplyPageViewVisibility(); return; }
        ApplyPageViewVisibility();
        switch (_activePageViewMode)
        {
            case DefaultPageViewMode.Continuous:
                if (forceRerender)
                {
                    _continuousRenderCache.Clear();
                    foreach (var item in _continuousPageItems) item.Bitmap = null;
                }
                RebuildContinuousPageItemsIfNeeded();
                SyncContinuousSelectionToPages(bringIntoView: true);
                await RenderRealizedContinuousPagesAsync();
                break;
            case DefaultPageViewMode.TwoPage:
                await RenderTwoPageAsync();
                break;
            default:
                if (PagesList.SelectedItem is PdfPageItem page) await RenderPreviewAsync(page);
                break;
        }
        UpdateZoomText();
    }

    private async Task RenderSelectedPageForActiveViewAsync(PdfPageItem page)
    {
        if (_currentPdf is null) return;
        switch (_activePageViewMode)
        {
            case DefaultPageViewMode.Continuous:
                if (!_syncingPageViewSelection) SyncContinuousSelectionToPages(bringIntoView: true);
                break;
            case DefaultPageViewMode.TwoPage:
                await RenderTwoPageAsync(page);
                break;
            default:
                await RenderPreviewAsync(page);
                break;
        }
    }

    private void RebuildContinuousPageItemsIfNeeded()
    {
        if (_continuousPageItems.Count != Pages.Count || _continuousPageItems.Where((item, index) => !ReferenceEquals(item.Page, Pages[index])).Any())
            RebuildContinuousPageItems();
    }

    private void RebuildContinuousPageItems()
    {
        var selected = PagesList.SelectedIndex;
        _continuousPageItems.Clear();
        foreach (var page in Pages) _continuousPageItems.Add(new ContinuousPageViewItem(page));
        if (selected >= 0 && selected < _continuousPageItems.Count)
        {
            _syncingPageViewSelection = true;
            ContinuousPagesList.SelectedIndex = selected;
            _syncingPageViewSelection = false;
        }
    }

    private async void ContinuousPageImage_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: ContinuousPageViewItem item }) return;
        item.IsRealized = true;
        await EnsureContinuousPageRenderedAsync(item);
    }

    private void ContinuousPageImage_Unloaded(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: ContinuousPageViewItem item }) item.IsRealized = false;
    }

    private async Task EnsureContinuousPageRenderedAsync(ContinuousPageViewItem item)
    {
        if (!item.IsRealized || _currentPdf is null || _activePageViewMode != DefaultPageViewMode.Continuous) return;
        if (_continuousRenderCache.TryGetValue(item.Page.SourcePageNumber, out var cached)) { item.Bitmap = cached; return; }
        var generation = _pageViewGeneration;
        var token = _pageViewCts?.Token ?? _lifetime.Token;
        await _continuousRenderLock.WaitAsync(token);
        try
        {
            if (!item.IsRealized || token.IsCancellationRequested || generation != _pageViewGeneration || _activePageViewMode != DefaultPageViewMode.Continuous) return;
            if (_continuousRenderCache.TryGetValue(item.Page.SourcePageNumber, out cached)) { item.Bitmap = cached; return; }
            var bitmap = await _renderer.RenderAsync(item.Page.SourcePageNumber, _previewWidth, token);
            token.ThrowIfCancellationRequested();
            if (!item.IsRealized || generation != _pageViewGeneration) return;
            item.Bitmap = bitmap;
            _continuousRenderCache[item.Page.SourcePageNumber] = bitmap;
            TrimContinuousRenderCache();
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { App.Log("Continuous page render failed: " + ex.Message); }
        finally { _continuousRenderLock.Release(); }
    }

    private void TrimContinuousRenderCache()
    {
        if (_continuousRenderCache.Count <= 18) return;
        var keep = _continuousPageItems.Where(item => item.IsRealized).Select(item => item.Page.SourcePageNumber).ToHashSet();
        foreach (var key in _continuousRenderCache.Keys.Where(key => !keep.Contains(key)).Take(_continuousRenderCache.Count - 18).ToArray())
        {
            _continuousRenderCache.Remove(key);
            foreach (var item in _continuousPageItems.Where(item => item.Page.SourcePageNumber == key && !item.IsRealized)) item.Bitmap = null;
        }
    }

    private async Task RenderRealizedContinuousPagesAsync()
    {
        await Dispatcher.InvokeAsync(() => ContinuousPagesList.UpdateLayout());
        foreach (var item in _continuousPageItems.Where(item => item.IsRealized).ToArray())
            await EnsureContinuousPageRenderedAsync(item);
    }

    private void ContinuousPagesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncingPageViewSelection || ContinuousPagesList.SelectedItem is not ContinuousPageViewItem item) return;
        var index = Pages.IndexOf(item.Page);
        if (index < 0 || index == PagesList.SelectedIndex) return;
        _syncingPageViewSelection = true;
        PagesList.SelectedIndex = index;
        PagesList.ScrollIntoView(item.Page);
        _syncingPageViewSelection = false;
    }

    private void SyncContinuousSelectionToPages(bool bringIntoView)
    {
        var index = PagesList.SelectedIndex;
        if (index < 0 || index >= _continuousPageItems.Count) return;
        _syncingPageViewSelection = true;
        ContinuousPagesList.SelectedIndex = index;
        if (bringIntoView) ContinuousPagesList.ScrollIntoView(_continuousPageItems[index]);
        _syncingPageViewSelection = false;
    }

    private void ContinuousPagesList_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (_activePageViewMode != DefaultPageViewMode.Continuous || _syncingPageViewSelection || e.VerticalChange == 0) return;
        var bestIndex = -1;
        var bestDistance = double.MaxValue;
        for (var i = 0; i < _continuousPageItems.Count; i++)
        {
            if (ContinuousPagesList.ItemContainerGenerator.ContainerFromIndex(i) is not ListBoxItem container || !container.IsVisible) continue;
            try
            {
                var y = container.TransformToAncestor(ContinuousPagesList).Transform(new Point(0, 0)).Y;
                if (y + container.ActualHeight < 0 || y > ContinuousPagesList.ActualHeight) continue;
                var distance = Math.Abs(y - 8);
                if (distance < bestDistance) { bestDistance = distance; bestIndex = i; }
            }
            catch { }
        }
        if (bestIndex < 0 || bestIndex == PagesList.SelectedIndex) return;
        _syncingPageViewSelection = true;
        PagesList.SelectedIndex = bestIndex;
        PagesList.ScrollIntoView(PagesList.SelectedItem);
        _syncingPageViewSelection = false;
        PersistWorkspacePosition();
    }

    private async Task RenderTwoPageAsync(PdfPageItem? first = null)
    {
        if (_currentPdf is null || Pages.Count == 0 || _activePageViewMode != DefaultPageViewMode.TwoPage) return;
        first ??= PagesList.SelectedItem as PdfPageItem ?? Pages[0];
        var leftIndex = Math.Max(0, Pages.IndexOf(first));
        var rightIndex = leftIndex + 1;
        var generation = ++_pageViewGeneration;
        _pageViewCts?.Cancel();
        _pageViewCts?.Dispose();
        _pageViewCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _pageViewCts.Token;
        try
        {
            var left = Pages[leftIndex];
            var leftBitmap = await _renderer.RenderAsync(left.SourcePageNumber, _previewWidth, token);
            if (generation != _pageViewGeneration) return;
            TwoPageLeftImage.Source = leftBitmap;
            TwoPageLeftImage.LayoutTransform = new RotateTransform(left.Rotation);
            TwoPageLeftLabel.Text = left.Label;

            if (rightIndex < Pages.Count)
            {
                var right = Pages[rightIndex];
                var rightBitmap = await _renderer.RenderAsync(right.SourcePageNumber, _previewWidth, token);
                if (generation != _pageViewGeneration) return;
                TwoPageRightImage.Source = rightBitmap;
                TwoPageRightImage.LayoutTransform = new RotateTransform(right.Rotation);
                TwoPageRightLabel.Text = right.Label;
                TwoPageRightCard.Visibility = Visibility.Visible;
            }
            else
            {
                TwoPageRightImage.Source = null;
                TwoPageRightLabel.Text = string.Empty;
                TwoPageRightCard.Visibility = Visibility.Collapsed;
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { App.Log("Two-page render failed: " + ex.Message); StatusText.Text = "Could not render the two-page view."; }
    }

    private uint CalculateFitWidthRenderWidth()
    {
        if (_activePageViewMode == DefaultPageViewMode.TwoPage)
        {
            var viewport = TwoPageScroll.ViewportWidth > 100 ? TwoPageScroll.ViewportWidth : TwoPageScroll.ActualWidth;
            return (uint)Math.Clamp((int)Math.Round((viewport - 100) / 2d), 320, 2000);
        }
        if (_activePageViewMode == DefaultPageViewMode.Continuous)
        {
            var viewport = ContinuousPagesList.ActualWidth;
            return (uint)Math.Clamp((int)Math.Round(viewport - 90), 360, 2000);
        }
        var single = PreviewScroll.ViewportWidth > 100 ? PreviewScroll.ViewportWidth : PreviewScroll.ActualWidth;
        return (uint)Math.Clamp((int)Math.Round(single - 80), 360, 2000);
    }
}
'@

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
'@ @'
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderSelectedPageForActiveViewAsync(page);
'@ 'active-view page rendering'

Replace-Exact $main @'
        if (PagesList.SelectedItem is PdfPageItem selected) await RenderPreviewAsync(selected);
'@ @'
        if (PagesList.SelectedItem is PdfPageItem selected) await RenderSelectedPageForActiveViewAsync(selected);
'@ 'rotation active-view rendering'

Replace-Exact $main @'
    private void FitWidth_Click(object sender, RoutedEventArgs e)
    {
        var viewport = PreviewScroll.ViewportWidth > 100 ? PreviewScroll.ViewportWidth : PreviewScroll.ActualWidth;
        _previewWidth = (uint)Math.Clamp((int)Math.Round(viewport - 80), 360, 2000);
        _ = RerenderSelectedPageAsync();
    }
'@ @'
    private void FitWidth_Click(object sender, RoutedEventArgs e)
    {
        _previewWidth = CalculateFitWidthRenderWidth();
        PersistWorkspacePosition();
        _ = RerenderSelectedPageAsync();
    }
'@ 'active view fit width'

Replace-Exact $main @'
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
    }
'@ @'
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
        await RefreshActivePageViewAsync();
    }
'@ 'refresh preferred view after open'

$product = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $product @'
        InitializeDocumentNavigationMetadata();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@ @'
        InitializeDocumentNavigationMetadata();
        InitializePageViewModes();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@ 'initialize page view modes'

Replace-Exact $product @'
    private void DocumentNav_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        EmptyPanel.Visibility = Visibility.Collapsed;
        PreviewScroll.Visibility = Visibility.Visible;
    }
'@ @'
    private void DocumentNav_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        EmptyPanel.Visibility = Visibility.Collapsed;
        ApplyPageViewVisibility();
    }
'@ 'document nav active view'

Replace-Exact $product @'
    private void FitPageShell_Click(object sender, RoutedEventArgs e)
    {
        if (PreviewImage.Source is not System.Windows.Media.Imaging.BitmapSource bitmap) return;
'@ @'
    private void FitPageShell_Click(object sender, RoutedEventArgs e)
    {
        if (!IsSinglePageViewActive)
        {
            _previewWidth = CalculateFitWidthRenderWidth();
            PersistWorkspacePosition();
            _ = RerenderSelectedPageAsync();
            return;
        }
        if (PreviewImage.Source is not System.Windows.Media.Imaging.BitmapSource bitmap) return;
'@ 'fit page non-single behavior'

Replace-Exact $product @'
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderPreviewAsync(page);
'@ @'
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderSelectedPageForActiveViewAsync(page);
'@ 'recent resume active view'

$tabs = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
Replace-Exact $tabs @'
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderPreviewAsync(page);
'@ @'
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderSelectedPageForActiveViewAsync(page);
'@ 'tab restore active view'

Replace-Exact $tabs @'
        ShowHomeContent();
        UpdateCommandStates();
    }
'@ @'
        ShowHomeContent();
        ApplyPageViewVisibility();
        UpdateCommandStates();
    }
'@ 'last-tab view cleanup'

$split = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.SplitView.cs'
Replace-Exact $split @'
        SplitComparisonPanel.Visibility = Visibility.Visible;
        PreviewScroll.Visibility = Visibility.Collapsed;
        EmptyPanel.Visibility = Visibility.Collapsed;
'@ @'
        SplitComparisonPanel.Visibility = Visibility.Visible;
        HidePrimaryPageViews();
        EmptyPanel.Visibility = Visibility.Collapsed;
'@ 'split hides all primary page views'

Replace-Exact $split @'
        SplitComparisonPanel.Visibility = Visibility.Collapsed;
        if (_currentPdf is not null) PreviewScroll.Visibility = Visibility.Visible;
        StatusText.Text = "Ready.";
'@ @'
        SplitComparisonPanel.Visibility = Visibility.Collapsed;
        if (_currentPdf is not null) ApplyPageViewVisibility();
        StatusText.Text = "Ready.";
'@ 'split restores active page view'

$settings = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Settings.cs'
Replace-Exact $settings @'
        if (_currentPdf is null) _previewWidth = dialog.SavedPreferences.DefaultRenderWidth;
        UpdateThemeToggleState();
'@ @'
        if (_currentPdf is null) _previewWidth = dialog.SavedPreferences.DefaultRenderWidth;
        _syncingPageViewSelection = true;
        PageViewModeCombo.SelectedIndex = (int)dialog.SavedPreferences.DefaultPageView;
        _syncingPageViewSelection = false;
        _ = SetPageViewModeAsync(dialog.SavedPreferences.DefaultPageView, persist: false);
        UpdateThemeToggleState();
'@ 'settings applies page view'

Write-Host 'Real continuous and two-page viewing modes staged.' -ForegroundColor Green
