param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
function Read-Lf([string]$relative) { $p=Join-Path $SourceRoot $relative; if(!(Test-Path $p)){throw "Missing $relative"}; return [IO.File]::ReadAllText($p,$utf8).Replace("`r`n","`n") }
function Write-Lf([string]$relative,[string]$text) { $p=Join-Path $SourceRoot $relative; [IO.File]::WriteAllText($p,$text.Replace("`r`n","`n"),$utf8) }
function Replace-Exact([string]$text,[string]$old,[string]$new,[string]$label) { $text=$text.Replace("`r`n","`n");$old=$old.Replace("`r`n","`n");$new=$new.Replace("`r`n","`n");if(!$text.Contains($old)){throw "Anchor not found: $label"};return $text.Replace($old,$new) }

# Persistent active navigation state.
$appPath='src/PdfRescue.App/App.xaml'; $app=Read-Lf $appPath
$oldNav=@'
        <Style x:Key="NavButtonStyle" TargetType="Button" BasedOn="{StaticResource FlatButtonStyle}">
            <Setter Property="HorizontalContentAlignment" Value="Left" />
            <Setter Property="Padding" Value="14,10" />
            <Setter Property="Margin" Value="8,2" />
            <Setter Property="FontSize" Value="14" />
        </Style>
'@
$newNav=@'
        <Style x:Key="NavButtonStyle" TargetType="Button" BasedOn="{StaticResource FlatButtonStyle}">
            <Setter Property="HorizontalContentAlignment" Value="Left" />
            <Setter Property="Padding" Value="14,10" />
            <Setter Property="Margin" Value="8,2" />
            <Setter Property="FontSize" Value="14" />
            <Style.Triggers>
                <Trigger Property="Tag" Value="Active">
                    <Setter Property="Background" Value="{StaticResource PanelPressedBrush}" />
                    <Setter Property="BorderBrush" Value="{StaticResource AccentBrush}" />
                    <Setter Property="FontWeight" Value="SemiBold" />
                </Trigger>
            </Style.Triggers>
        </Style>
'@
$app=Replace-Exact $app $oldNav $newNav 'active navigation style'
Write-Lf $appPath $app

$xamlPath='src/PdfRescue.App/MainWindow.xaml'; $xaml=Read-Lf $xamlPath
$xaml=$xaml.Replace('<Border Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Width="520" Height="34"','<Border x:Name="TitleSearchContainer" Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Width="520" Height="34"')
$xaml=$xaml.Replace('<Button Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">`n                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE80F;"','<Button x:Name="HomeNavButton" Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">`n                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE80F;"')
$xaml=$xaml.Replace('<Button Style="{StaticResource NavButtonStyle}" Click="HomeRecentNav_Click">','<Button x:Name="RecentNavButton" Style="{StaticResource NavButtonStyle}" Click="HomeRecentNav_Click">')
$xaml=$xaml.Replace('<Button Style="{StaticResource NavButtonStyle}" Click="HomeStarredNav_Click"','<Button x:Name="StarredNavButton" Style="{StaticResource NavButtonStyle}" Click="HomeStarredNav_Click"')
$xaml=$xaml.Replace('<Button Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">`n                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE71D;"','<Button x:Name="ToolsNavButton" Style="{StaticResource NavButtonStyle}" Click="ToolsNav_Click">`n                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE71D;"')
$xaml=$xaml.Replace('<Button Style="{StaticResource NavButtonStyle}" Click="DocumentNav_Click"','<Button x:Name="ActiveDocumentNavButton" Style="{StaticResource NavButtonStyle}" Click="DocumentNav_Click"')
$xaml=$xaml.Replace('<Grid Margin="0,42,0,28">`n                                <Grid.ColumnDefinitions><ColumnDefinition Width="1.05*"/><ColumnDefinition Width="0.95*"/></Grid.ColumnDefinitions>','<Grid x:Name="HomeHeroGrid" Margin="0,42,0,28">`n                                <Grid.ColumnDefinitions><ColumnDefinition Width="1.05*"/><ColumnDefinition x:Name="HomeHeroArtColumn" Width="0.95*"/></Grid.ColumnDefinitions>')
$xaml=$xaml.Replace('<Border Grid.Column="1" Height="270" Margin="18,0" CornerRadius="20"','<Border x:Name="HomeHeroArt" Grid.Column="1" Height="270" Margin="18,0" CornerRadius="20"')
$xaml=$xaml.Replace('<UniformGrid Columns="7" Margin="-6,0,-6,0">','<UniformGrid x:Name="QuickToolsGrid" Columns="7" Margin="-6,0,-6,0">')
$xaml=$xaml.Replace('<UniformGrid Columns="5" Margin="-6,0,-6,0">','<UniformGrid x:Name="MoreToolsGrid" Columns="5" Margin="-6,0,-6,0">')
Write-Lf $xamlPath $xaml

$productPath='src/PdfRescue.App/MainWindow.ProductShell.cs'; $product=Read-Lf $productPath
$product=$product.Replace('        RefreshProductShellMode();`n        _ = Dispatcher.BeginInvoke','        RefreshProductShellMode();`n        SetPrimaryNavigationState(_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton);`n        _ = Dispatcher.BeginInvoke')
$product=$product.Replace('        LoadHomeRecents();`n    }`n`n    private void HomeRecentNav_Click','        LoadHomeRecents();`n        SetPrimaryNavigationState(HomeNavButton);`n    }`n`n    private void ToolsNav_Click(object sender, RoutedEventArgs e)`n    {`n        HomeNav_Click(sender, e);`n        SetPrimaryNavigationState(ToolsNavButton);`n    }`n`n    private void HomeRecentNav_Click')
$product=$product.Replace('        HomeRecentSection.BringIntoView();`n    }`n`n    private void HomeStarredNav_Click','        HomeRecentSection.BringIntoView();`n        SetPrimaryNavigationState(RecentNavButton);`n    }`n`n    private void HomeStarredNav_Click')
$product=$product.Replace('        HomeRecentSection.BringIntoView();`n    }`n`n    private void RefreshTaskCenterIndicator','        HomeRecentSection.BringIntoView();`n        SetPrimaryNavigationState(StarredNavButton);`n    }`n`n    private void RefreshTaskCenterIndicator')
$oldTask=@'
        TaskCenterHost.Content = _taskCenterView;
        TaskCenterDrawer.Visibility = TaskCenterDrawer.Visibility == Visibility.Visible
            ? Visibility.Collapsed
            : Visibility.Visible;
'@
$newTask=@'
        TaskCenterHost.Content = _taskCenterView;
        TaskCenterDrawer.Visibility = TaskCenterDrawer.Visibility == Visibility.Visible
            ? Visibility.Collapsed
            : Visibility.Visible;
        SetPrimaryNavigationState(TaskCenterDrawer.Visibility == Visibility.Visible
            ? TaskCenterNavButton
            : (_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton));
'@
$product=Replace-Exact $product $oldTask $newTask 'Task Center active navigation'
$product=$product.Replace('        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;`n    }`n`n    private void CloseTaskCenterDrawer()','        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;`n        SetPrimaryNavigationState(_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton);`n    }`n`n    private void CloseTaskCenterDrawer()')
$product=$product.Replace('        EmptyPanel.Visibility = Visibility.Collapsed;`n        ApplyPageViewVisibility();','        EmptyPanel.Visibility = Visibility.Collapsed;`n        ApplyPageViewVisibility();`n        SetPrimaryNavigationState(ActiveDocumentNavButton);')
$navHelper=@'

    private void SetPrimaryNavigationState(Button active)
    {
        if (active is null) return;
        foreach (var button in new[] { HomeNavButton, RecentNavButton, StarredNavButton, ToolsNavButton, ActiveDocumentNavButton, TaskCenterNavButton })
            button.Tag = ReferenceEquals(button, active) ? "Active" : null;
    }
'@
$product=Replace-Exact $product '    private async void ResumeLastSession_Click(object sender, RoutedEventArgs e)' ($navHelper + "`n    private async void ResumeLastSession_Click(object sender, RoutedEventArgs e)") 'insert nav-state helper'
Write-Lf $productPath $product

# Responsive shell now covers Home, title search, Task Center and Inspector.
$responsive=@'
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
        Dispatcher.BeginInvoke(new Action(() => UpdateResponsiveLayout(ActualWidth)));
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

    private void MainWindow_ResponsiveSizeChanged(object sender, SizeChangedEventArgs e) => UpdateResponsiveLayout(e.NewSize.Width);

    private void UpdateResponsiveLayout(double width)
    {
        UpdateResponsiveInspector(width);
        UpdateResponsiveShell(width);
    }

    private void UpdateResponsiveShell(double width)
    {
        if (width <= 0) return;

        if (TitleSearchContainer is not null)
        {
            TitleSearchContainer.Visibility = width < 980 ? Visibility.Collapsed : Visibility.Visible;
            TitleSearchContainer.Width = width < 1200 ? 300 : width < 1450 ? 400 : 520;
        }

        var usable = Math.Max(420, width - 300);
        if (QuickToolsGrid is not null)
            QuickToolsGrid.Columns = usable >= 1220 ? 7 : usable >= 980 ? 5 : usable >= 760 ? 4 : 3;
        if (MoreToolsGrid is not null)
            MoreToolsGrid.Columns = usable >= 1080 ? 5 : usable >= 820 ? 4 : usable >= 620 ? 3 : 2;

        var showHeroArt = width >= 1180;
        if (HomeHeroArt is not null) HomeHeroArt.Visibility = showHeroArt ? Visibility.Visible : Visibility.Collapsed;
        if (HomeHeroArtColumn is not null)
            HomeHeroArtColumn.Width = showHeroArt ? new GridLength(0.95, GridUnitType.Star) : new GridLength(0);

        if (TaskCenterDrawer is not null)
        {
            var productWidth = Math.Max(520, width - 220);
            TaskCenterDrawer.Width = Math.Clamp(productWidth * 0.68, 520, 720);
        }
    }

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
            if (InspectorColumn.Width.Value > 0) _lastInspectorWidth = InspectorColumn.Width;
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
Write-Lf 'src/PdfRescue.App/MainWindow.ResponsiveLayout.cs' $responsive

# Task Center summary wraps naturally in the new drawer instead of crushing six columns.
$taskPath='src/PdfRescue.App/TaskCenterView.xaml'; $task=Read-Lf $taskPath
$start=$task.IndexOf('        <Grid Grid.Row="1" Margin="24,0,24,16">',[StringComparison]::Ordinal)
if($start -lt 0){throw 'Task Center summary start not found'}
$endMarker='        <Grid Grid.Row="2" Margin="24,0,24,24">'
$end=$task.IndexOf($endMarker,$start,[StringComparison]::Ordinal)
if($end -lt 0){throw 'Task Center summary end not found'}
$summary=@'
        <WrapPanel Grid.Row="1" Margin="24,0,24,16">
            <Border Style="{StaticResource PanelCardStyle}" Width="112" Margin="0,0,8,8" Padding="12"><StackPanel><TextBlock Text="Running" Foreground="{StaticResource MutedTextBrush}" FontSize="12"/><TextBlock x:Name="RunningCount" Text="0" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel></Border>
            <Border Style="{StaticResource PanelCardStyle}" Width="112" Margin="0,0,8,8" Padding="12"><StackPanel><TextBlock Text="Queued" Foreground="{StaticResource MutedTextBrush}" FontSize="12"/><TextBlock x:Name="QueuedCount" Text="0" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel></Border>
            <Border Style="{StaticResource PanelCardStyle}" Width="112" Margin="0,0,8,8" Padding="12"><StackPanel><TextBlock Text="Completed" Foreground="{StaticResource MutedTextBrush}" FontSize="12"/><TextBlock x:Name="CompletedCount" Text="0" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel></Border>
            <Border Style="{StaticResource PanelCardStyle}" Width="112" Margin="0,0,8,8" Padding="12"><StackPanel><TextBlock Text="Failed" Foreground="{StaticResource MutedTextBrush}" FontSize="12"/><TextBlock x:Name="FailedCount" Text="0" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel></Border>
            <Border Style="{StaticResource PanelCardStyle}" Width="112" Margin="0,0,8,8" Padding="12"><StackPanel><TextBlock Text="Cancelled" Foreground="{StaticResource MutedTextBrush}" FontSize="12"/><TextBlock x:Name="CancelledCount" Text="0" FontSize="22" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel></Border>
            <ComboBox x:Name="FilterCombo" Width="190" Height="36" Margin="0,8,0,8" VerticalAlignment="Center" SelectionChanged="FilterCombo_SelectionChanged">
                <ComboBoxItem Content="All tasks" /><ComboBoxItem Content="Running / queued" /><ComboBoxItem Content="Completed" /><ComboBoxItem Content="Failed" /><ComboBoxItem Content="Cancelled" />
            </ComboBox>
        </WrapPanel>

'@
$task=$task.Substring(0,$start)+$summary+$task.Substring($end)
Write-Lf $taskPath $task

# Diagnostics window must also remain usable at elevated scaling.
$lifePath='src/PdfRescue.App/LifecycleWindows.cs'; $life=Read-Lf $lifePath
$life=$life.Replace('        Width = 760;`n        Height = 780;`n        WindowStartupLocation = WindowStartupLocation.CenterOwner;','        Width = 760;`n        Height = Math.Min(780, Math.Max(560, SystemParameters.WorkArea.Height - 80));`n        MinHeight = 520;`n        MinWidth = 620;`n        ResizeMode = ResizeMode.CanResizeWithGrip;`n        WindowStartupLocation = WindowStartupLocation.CenterOwner;')
$life=$life.Replace('        Width = 640;`n        Height = 470;`n        ResizeMode = ResizeMode.NoResize;','        Width = 640;`n        Height = Math.Min(500, Math.Max(430, SystemParameters.WorkArea.Height - 100));`n        MinHeight = 420;`n        MinWidth = 560;`n        ResizeMode = ResizeMode.CanResizeWithGrip;')
Write-Lf $lifePath $life

Write-Host 'RC49 UX acceptance round 2 staged successfully.' -ForegroundColor Green
