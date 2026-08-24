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

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath @'
                        <Button Style="{StaticResource NavButtonStyle}" Click="TaskCenterNav_Click" ToolTip="View running and completed PDF tasks">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Task Center"/></StackPanel>
                        </Button>
'@ @'
                        <Button x:Name="TaskCenterNavButton" Style="{StaticResource NavButtonStyle}" Click="TaskCenterNav_Click" ToolTip="View running and completed PDF tasks">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="28" />
                                    <ColumnDefinition Width="*" />
                                    <ColumnDefinition Width="Auto" />
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column="0" Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" VerticalAlignment="Center" />
                                <TextBlock Grid.Column="1" Text="Task Center" VerticalAlignment="Center" />
                                <Border x:Name="TaskCenterActiveBadge" Grid.Column="2" MinWidth="24" Height="22" Margin="10,0,0,0"
                                        Padding="6,0" CornerRadius="11" Background="#1F63A8" Visibility="Collapsed"
                                        VerticalAlignment="Center" ToolTip="Running and queued tasks">
                                    <TextBlock x:Name="TaskCenterActiveCountText" Text="0" Foreground="White" FontSize="11" FontWeight="SemiBold"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" />
                                </Border>
                            </Grid>
                        </Button>
'@ 'Task Center active badge'

$productPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productPath @'
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
'@ @'
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.OpenOutputRequested += OpenTaskOutputAsync;
        _taskCenterService.Changed += (_, _) => RefreshTaskCenterIndicator();
        RefreshTaskCenterIndicator();
'@ 'Task Center indicator subscription'

Replace-Exact $productPath @'
    private void TaskCenterNav_Click(object sender, RoutedEventArgs e)
    {
        PersistWorkspacePosition(immediate: true);
        if (_taskCenterView is null) return;
        EmptyPanel.Child = _taskCenterView;
        EmptyPanel.Visibility = Visibility.Visible;
    }
'@ @'
    private void RefreshTaskCenterIndicator()
    {
        if (TaskCenterActiveBadge is null || TaskCenterActiveCountText is null || TaskCenterNavButton is null) return;
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(RefreshTaskCenterIndicator);
            return;
        }

        var counts = _taskCenterService.GetCounts();
        var active = counts.Running + counts.Queued;
        TaskCenterActiveCountText.Text = active > 99 ? "99+" : active.ToString("N0");
        TaskCenterActiveBadge.Visibility = active > 0 ? Visibility.Visible : Visibility.Collapsed;
        TaskCenterNavButton.ToolTip = active > 0
            ? $"Task Center · {counts.Running:N0} running, {counts.Queued:N0} queued"
            : counts.Failed > 0
                ? $"Task Center · {counts.Failed:N0} failed task(s) need attention"
                : "View running and completed PDF tasks";
    }

    private void TaskCenterNav_Click(object sender, RoutedEventArgs e)
    {
        PersistWorkspacePosition(immediate: true);
        if (_taskCenterView is null) return;
        EmptyPanel.Child = _taskCenterView;
        EmptyPanel.Visibility = Visibility.Visible;
    }
'@ 'Task Center live indicator refresh'

Write-Host 'Task Center live active-task indicator applied.' -ForegroundColor Green
