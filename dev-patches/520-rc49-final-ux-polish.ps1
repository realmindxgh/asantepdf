param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
function Read-Lf([string]$relative) { $p=Join-Path $SourceRoot $relative; if(!(Test-Path $p)){throw "Missing $relative"}; return [IO.File]::ReadAllText($p,$utf8).Replace("`r`n","`n") }
function Write-Lf([string]$relative,[string]$text) { $p=Join-Path $SourceRoot $relative; $parent=Split-Path $p -Parent; New-Item -ItemType Directory -Force -Path $parent | Out-Null; [IO.File]::WriteAllText($p,$text.Replace("`r`n","`n"),$utf8) }
function Replace-Exact([string]$text,[string]$old,[string]$new,[string]$label) { $text=$text.Replace("`r`n","`n");$old=$old.Replace("`r`n","`n");$new=$new.Replace("`r`n","`n");if(!$text.Contains($old)){throw "Anchor not found: $label"};return $text.Replace($old,$new) }

# 1. Add restrained physical lift to interactive cards only.
$appPath='src/PdfRescue.App/App.xaml'; $app=Read-Lf $appPath
$anchor=@'
        <Style x:Key="ToolCardStyle" TargetType="Button" BasedOn="{StaticResource FlatButtonStyle}">
'@
$styles=@'
        <Style x:Key="CardLiftButtonStyle" TargetType="Button" BasedOn="{StaticResource FlatButtonStyle}">
            <Setter Property="RenderTransform"><Setter.Value><TranslateTransform Y="0" /></Setter.Value></Setter>
            <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="#000000" BlurRadius="12" ShadowDepth="0" Opacity="0" /></Setter.Value></Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="BorderBrush" Value="{StaticResource AccentBrush}" />
                </Trigger>
                <EventTrigger RoutedEvent="MouseEnter">
                    <BeginStoryboard HandoffBehavior="SnapshotAndReplace"><Storyboard>
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="-3" Duration="0:0:0.14" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.Opacity)" To="0.26" Duration="0:0:0.14" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.BlurRadius)" To="18" Duration="0:0:0.14" />
                    </Storyboard></BeginStoryboard>
                </EventTrigger>
                <EventTrigger RoutedEvent="MouseLeave">
                    <BeginStoryboard HandoffBehavior="SnapshotAndReplace"><Storyboard>
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="0" Duration="0:0:0.18" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.Opacity)" To="0" Duration="0:0:0.18" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.BlurRadius)" To="12" Duration="0:0:0.18" />
                    </Storyboard></BeginStoryboard>
                </EventTrigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="CardLiftBorderStyle" TargetType="Border" BasedOn="{StaticResource PanelCardStyle}">
            <Setter Property="RenderTransform"><Setter.Value><TranslateTransform Y="0" /></Setter.Value></Setter>
            <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="#000000" BlurRadius="12" ShadowDepth="0" Opacity="0" /></Setter.Value></Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True"><Setter Property="BorderBrush" Value="{StaticResource AccentBrush}" /></Trigger>
                <EventTrigger RoutedEvent="MouseEnter">
                    <BeginStoryboard HandoffBehavior="SnapshotAndReplace"><Storyboard>
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="-3" Duration="0:0:0.14" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.Opacity)" To="0.24" Duration="0:0:0.14" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.BlurRadius)" To="18" Duration="0:0:0.14" />
                    </Storyboard></BeginStoryboard>
                </EventTrigger>
                <EventTrigger RoutedEvent="MouseLeave">
                    <BeginStoryboard HandoffBehavior="SnapshotAndReplace"><Storyboard>
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="0" Duration="0:0:0.18" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.Opacity)" To="0" Duration="0:0:0.18" />
                        <DoubleAnimation Storyboard.TargetProperty="(UIElement.Effect).(DropShadowEffect.BlurRadius)" To="12" Duration="0:0:0.18" />
                    </Storyboard></BeginStoryboard>
                </EventTrigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="ToolCardStyle" TargetType="Button" BasedOn="{StaticResource CardLiftButtonStyle}">
'@
$app=Replace-Exact $app $anchor $styles 'card lift styles'
Write-Lf $appPath $app

# 2. Recent cards: lift, readable metadata, theme tokens.
$recentPath='src/PdfRescue.App/RecentFilesView.xaml'; $recent=Read-Lf $recentPath
$recent=$recent.Replace('Style="{StaticResource FlatButtonStyle}" Click="RecentOpen_Click"','Style="{StaticResource CardLiftButtonStyle}" Click="RecentOpen_Click"')
$recent=$recent.Replace('BorderBrush="#33495F"','BorderBrush="{StaticResource BorderBrushSoft}"')
$recent=$recent.Replace('Foreground="#6F8399" FontSize="11"','Foreground="{StaticResource MutedTextBrush}" FontSize="12"')
$recent=$recent.Replace('Foreground="#7890A8" FontSize="11"','Foreground="{StaticResource MutedTextBrush}" FontSize="12"')
$recent=$recent.Replace('Foreground="{StaticResource MutedTextBrush}" FontSize="11"','Foreground="{StaticResource MutedTextBrush}" FontSize="12"')
$recent=$recent.Replace('Text="{Binding PageCountLabel}" Foreground="{StaticResource MutedTextBrush}" FontSize="10"','Text="{Binding PageCountLabel}" Foreground="{StaticResource MutedTextBrush}" FontSize="11"')
$recent=$recent.Replace('Foreground="#627B94"','Foreground="{StaticResource MutedTextBrush}"')
Write-Lf $recentPath $recent

# 3. Task cards lift as units; task metadata no longer microscopic.
$taskPath='src/PdfRescue.App/TaskCenterView.xaml'; $task=Read-Lf $taskPath
$task=$task.Replace('<Border Style="{StaticResource PanelCardStyle}" Padding="16">','<Border Style="{StaticResource CardLiftBorderStyle}" Padding="16">')
$task=$task.Replace('FontSize="11"','FontSize="12"')
Write-Lf $taskPath $task

# 4. Make Settings, error and print dialogs work-area aware and scroll-safe.
$settingsPath='src/PdfRescue.App/SettingsWindow.cs'; $settings=Read-Lf $settingsPath
$oldSettings=@'
        Width = 650;
        Height = 760;
        MinWidth = 560;
        MinHeight = 620;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$newSettings=@'
        Width = Math.Min(650, Math.Max(560, SystemParameters.WorkArea.Width - 80));
        Height = Math.Min(760, Math.Max(540, SystemParameters.WorkArea.Height - 80));
        MinWidth = 520;
        MinHeight = 500;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$settings=Replace-Exact $settings $oldSettings $newSettings 'Settings DPI-safe window'
$settings=$settings.Replace('FontSize = 11, TextWrapping = TextWrapping.Wrap','FontSize = 12, TextWrapping = TextWrapping.Wrap')
Write-Lf $settingsPath $settings

$lifePath='src/PdfRescue.App/LifecycleWindows.cs'; $life=Read-Lf $lifePath
$oldError=@'
        Width = 680;
        Height = 510;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$newError=@'
        Width = Math.Min(680, Math.Max(560, SystemParameters.WorkArea.Width - 80));
        Height = Math.Min(510, Math.Max(420, SystemParameters.WorkArea.Height - 100));
        MinWidth = 520;
        MinHeight = 400;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$life=Replace-Exact $life $oldError $newError 'error dialog DPI-safe window'
Write-Lf $lifePath $life

$printPath='src/PdfRescue.App/PrintOptionsWindow.cs'; $print=Read-Lf $printPath
$oldPrint=@'
        Width = 520;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$newPrint=@'
        Width = Math.Min(520, Math.Max(460, SystemParameters.WorkArea.Width - 80));
        Height = Math.Min(470, Math.Max(420, SystemParameters.WorkArea.Height - 100));
        MinWidth = 440;
        MinHeight = 390;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$print=Replace-Exact $print $oldPrint $newPrint 'print options DPI-safe window'
$print=$print.Replace('FontSize = 11, Foreground','FontSize = 12, Foreground')
$print=$print.Replace('Content = content;','Content = new ScrollViewer { Content = content, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };')
Write-Lf $printPath $print

# 5. Final shell polish: ribbon overflow, small-width page/search controls, status contrast.
$xamlPath='src/PdfRescue.App/MainWindow.xaml'; $xaml=Read-Lf $xamlPath
$ribbonMarker='                    <!-- Grouped command ribbon -->'
$ribbonAt=$xaml.IndexOf($ribbonMarker,[StringComparison]::Ordinal)
if($ribbonAt -lt 0){throw 'Ribbon marker not found'}
$ribbonScroll='<ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">'
$ribbonScrollAt=$xaml.IndexOf($ribbonScroll,$ribbonAt,[StringComparison]::Ordinal)
if($ribbonScrollAt -lt 0){throw 'Ribbon ScrollViewer not found'}
$xaml=$xaml.Remove($ribbonScrollAt,$ribbonScroll.Length).Insert($ribbonScrollAt,'<ScrollViewer x:Name="RibbonScrollViewer" HorizontalScrollBarVisibility="Visible" VerticalScrollBarVisibility="Disabled" PreviewMouseWheel="RibbonScrollViewer_PreviewMouseWheel" ToolTip="Scroll horizontally to see more commands">')
$xaml=$xaml.Replace('<TextBlock Text="Previous" Margin="5,0,0,0" VerticalAlignment="Center"/>','<TextBlock x:Name="PreviousPageLabel" Text="Previous" Margin="5,0,0,0" VerticalAlignment="Center"/>')
$xaml=$xaml.Replace('<TextBlock Text="Next" Margin="0,0,5,0" VerticalAlignment="Center"/>','<TextBlock x:Name="NextPageLabel" Text="Next" Margin="0,0,5,0" VerticalAlignment="Center"/>')
$xaml=$xaml.Replace('<Border Grid.Column="2" Background="{StaticResource PanelRaisedBrush}" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="7" Padding="4">','<Border x:Name="DocumentSearchContainer" Grid.Column="2" Background="{StaticResource PanelRaisedBrush}" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="7" Padding="4">')
$xaml=$xaml.Replace('Foreground="#41566C"','Foreground="{StaticResource MutedTextBrush}"')
$xaml=$xaml.Replace('Foreground="#6282A1"','Foreground="{StaticResource MutedTextBrush}"')
$xaml=$xaml.Replace('x:Name="TaskCenterActiveCountText" Text="0" Foreground="White" FontSize="11"','x:Name="TaskCenterActiveCountText" Text="0" Foreground="White" FontSize="12"')
Write-Lf $xamlPath $xaml

# 6. Extend responsive shell and ribbon mouse-wheel affordance.
$responsivePath='src/PdfRescue.App/MainWindow.ResponsiveLayout.cs'; $responsive=Read-Lf $responsivePath
$oldResponsive=@'
        if (TaskCenterDrawer is not null)
        {
            var productWidth = Math.Max(520, width - 220);
            TaskCenterDrawer.Width = Math.Clamp(productWidth * 0.68, 520, 720);
        }
    }
'@
$newResponsive=@'
        if (TaskCenterDrawer is not null)
        {
            var productWidth = Math.Max(520, width - 220);
            TaskCenterDrawer.Width = Math.Clamp(productWidth * 0.68, 520, 720);
        }

        var compactNavigation = width < 1120;
        if (PreviousPageLabel is not null) PreviousPageLabel.Visibility = compactNavigation ? Visibility.Collapsed : Visibility.Visible;
        if (NextPageLabel is not null) NextPageLabel.Visibility = compactNavigation ? Visibility.Collapsed : Visibility.Visible;
        if (PageViewModeCombo is not null) PageViewModeCombo.Width = width < 1120 ? 108 : width < 1320 ? 118 : 128;
        if (DocumentSearchBox is not null) DocumentSearchBox.Width = width < 1040 ? 118 : width < 1280 ? 155 : 205;
        if (DocumentSearchContainer is not null) DocumentSearchContainer.Margin = width < 1040 ? new Thickness(4, 0, 0, 0) : new Thickness(0);
    }

    private void RibbonScrollViewer_PreviewMouseWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
    {
        if (RibbonScrollViewer is null) return;
        var step = e.Delta > 0 ? -240 : 240;
        RibbonScrollViewer.ScrollToHorizontalOffset(Math.Max(0, RibbonScrollViewer.HorizontalOffset + step));
        e.Handled = true;
    }
'@
$responsive=Replace-Exact $responsive $oldResponsive $newResponsive 'responsive page/search and ribbon scroll'
Write-Lf $responsivePath $responsive

Write-Host 'RC49 final UX polish staged successfully.' -ForegroundColor Green
