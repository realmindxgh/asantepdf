param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
function Read-Lf([string]$relative) { $p=Join-Path $SourceRoot $relative; if(!(Test-Path $p)){throw "Missing $relative"}; [IO.File]::ReadAllText($p,$utf8).Replace("`r`n","`n") }
function Write-Lf([string]$relative,[string]$text) { $p=Join-Path $SourceRoot $relative; [IO.File]::WriteAllText($p,$text.Replace("`r`n","`n"),$utf8) }
function Replace-One([string]$text,[string]$old,[string]$new,[string]$label) { $old=$old.Replace("`r`n","`n");$new=$new.Replace("`r`n","`n"); if(!$text.Contains($old)){throw "Anchor not found: $label"}; $i=$text.IndexOf($old,[StringComparison]::Ordinal); return $text.Substring(0,$i)+$new+$text.Substring($i+$old.Length) }

# Add the responsive element names with real multiline anchors. The following 510 carrier can then safely
# replace the responsive partial without depending on PowerShell single-quoted newline escapes.
$xamlPath='src/PdfRescue.App/MainWindow.xaml'; $xaml=Read-Lf $xamlPath
$homeOld=@'
                        <Button Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE80F;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Home"/></StackPanel>
                        </Button>
'@
$homeNew=@'
                        <Button x:Name="HomeNavButton" Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE80F;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Home"/></StackPanel>
                        </Button>
'@
$xaml=Replace-One $xaml $homeOld $homeNew 'Home nav name'
$toolsOld=@'
                        <Button Style="{StaticResource NavButtonStyle}" Click="HomeNav_Click">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Tools"/></StackPanel>
                        </Button>
'@
$toolsNew=@'
                        <Button x:Name="ToolsNavButton" Style="{StaticResource NavButtonStyle}" Click="ToolsNav_Click">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Tools"/></StackPanel>
                        </Button>
'@
$xaml=Replace-One $xaml $toolsOld $toolsNew 'Tools nav name'
$heroOld=@'
                            <Grid Margin="0,42,0,28">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="1.05*"/><ColumnDefinition Width="0.95*"/></Grid.ColumnDefinitions>
'@
$heroNew=@'
                            <Grid x:Name="HomeHeroGrid" Margin="0,42,0,28">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="1.05*"/><ColumnDefinition x:Name="HomeHeroArtColumn" Width="0.95*"/></Grid.ColumnDefinitions>
'@
$xaml=Replace-One $xaml $heroOld $heroNew 'Home hero responsive column'
Write-Lf $xamlPath $xaml

# Apply the ProductShell navigation-state edits that were expressed with literal newline escapes in carrier 510.
$productPath='src/PdfRescue.App/MainWindow.ProductShell.cs'; $p=Read-Lf $productPath
$old=@'
        RefreshResumeCommandState();
        RefreshProductShellMode();
        _ = Dispatcher.BeginInvoke
'@
$new=@'
        RefreshResumeCommandState();
        RefreshProductShellMode();
        SetPrimaryNavigationState(_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton);
        _ = Dispatcher.BeginInvoke
'@
$p=Replace-One $p $old $new 'initial active navigation'
$homeBlock=@'
    private void HomeNav_Click(object sender, RoutedEventArgs e)
    {
        CloseTaskCenterDrawer();
        PersistWorkspacePosition(immediate: true);
        ShowHomeContent();
        _recentFilesView?.SetPinnedOnly(false);
        LoadHomeRecents();
    }

    private void HomeRecentNav_Click
'@
$homeReplacement=@'
    private void HomeNav_Click(object sender, RoutedEventArgs e)
    {
        CloseTaskCenterDrawer();
        PersistWorkspacePosition(immediate: true);
        ShowHomeContent();
        _recentFilesView?.SetPinnedOnly(false);
        LoadHomeRecents();
        SetPrimaryNavigationState(HomeNavButton);
    }

    private void ToolsNav_Click(object sender, RoutedEventArgs e)
    {
        HomeNav_Click(sender, e);
        SetPrimaryNavigationState(ToolsNavButton);
    }

    private void HomeRecentNav_Click
'@
$p=Replace-One $p $homeBlock $homeReplacement 'Home/Tools navigation state'
$recentOld=@'
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
    }

    private void HomeStarredNav_Click
'@
$recentNew=@'
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
        SetPrimaryNavigationState(RecentNavButton);
    }

    private void HomeStarredNav_Click
'@
$p=Replace-One $p $recentOld $recentNew 'Recent navigation state'
$starOld=@'
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
    }

    private void RefreshTaskCenterIndicator()
'@
$starNew=@'
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
        SetPrimaryNavigationState(StarredNavButton);
    }

    private void RefreshTaskCenterIndicator()
'@
$p=Replace-One $p $starOld $starNew 'Starred navigation state'
$docOld=@'
        EmptyPanel.Visibility = Visibility.Collapsed;
        ApplyPageViewVisibility();
    }
'@
$docNew=@'
        EmptyPanel.Visibility = Visibility.Collapsed;
        ApplyPageViewVisibility();
        SetPrimaryNavigationState(ActiveDocumentNavButton);
    }
'@
$p=Replace-One $p $docOld $docNew 'Document navigation state'
Write-Lf $productPath $p

# Make other fixed-size lifecycle windows DPI-safe now, independent of carrier 510's literal-newline replacements.
$lifePath='src/PdfRescue.App/LifecycleWindows.cs'; $life=Read-Lf $lifePath
$recoveryOld=@'
        Width = 640;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$recoveryNew=@'
        Width = 640;
        Height = Math.Min(500, Math.Max(430, SystemParameters.WorkArea.Height - 100));
        MinHeight = 420;
        MinWidth = 560;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$life=Replace-One $life $recoveryOld $recoveryNew 'Recovery DPI-safe size'
$diagOld=@'
        Width = 760;
        Height = 780;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$diagNew=@'
        Width = 760;
        Height = Math.Min(780, Math.Max(560, SystemParameters.WorkArea.Height - 80));
        MinHeight = 520;
        MinWidth = 620;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
'@
$life=Replace-One $life $diagOld $diagNew 'Diagnostics DPI-safe size'
Write-Lf $lifePath $life
Write-Host 'Responsive UX anchors prepared successfully.' -ForegroundColor Green
