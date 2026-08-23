param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    [IO.File]::WriteAllText($Path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath `
@'
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition x:Name="PagesColumn" Width="245" />
                            <ColumnDefinition Width="5" />
                            <ColumnDefinition Width="*" />
'@ `
@'
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition x:Name="PagesColumn" Width="245" MinWidth="180" MaxWidth="460" />
                            <ColumnDefinition x:Name="PagesSplitterColumn" Width="5" />
                            <ColumnDefinition Width="*" />
'@ 'bounded sidebar columns'

Replace-Exact $xamlPath `
@'
                        <Border Grid.Column="0" Background="#0C1723" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,1,0">
                            <Grid>
                                <Grid.RowDefinitions><RowDefinition Height="44"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="8,6">
                                    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                                    <Button Grid.Column="0" Style="{StaticResource FlatButtonStyle}" Click="PageModePages_Click" Content="Pages" Padding="7,5" />
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModeBookmarks_Click" Content="Bookmarks" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModeSearch_Click" Content="Search" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                </Grid>
'@ `
@'
                        <Border x:Name="PagesNavigationBorder" Grid.Column="0" Background="#0C1723" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,1,0">
                            <Grid>
                                <Grid.RowDefinitions><RowDefinition Height="44"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="8,6">
                                    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
                                    <Button Grid.Column="0" Style="{StaticResource FlatButtonStyle}" Click="PageModePages_Click" Content="Pages" Padding="5" />
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModeBookmarks_Click" Content="Bookmarks" Padding="5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModeSearch_Click" Content="Search" Padding="5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                    <Button Grid.Column="3" Style="{StaticResource FlatButtonStyle}" Click="CollapsePagesSidebar_Click" Content="‹" Padding="0" Margin="2,0,0,0" ToolTip="Collapse navigation sidebar" />
                                </Grid>
'@ 'sidebar collapse control'

Replace-Exact $xamlPath `
@'
                        <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Stretch" Background="#172738" />

                        <Grid Grid.Column="2" Background="#111C28">
'@ `
@'
                        <GridSplitter x:Name="PagesSplitter" Grid.Column="1" Width="5" HorizontalAlignment="Stretch" Background="#172738"
                                      ResizeDirection="Columns" ResizeBehavior="PreviousAndNext" Cursor="SizeWE" />

                        <Grid Grid.Column="2" Background="#111C28">
'@ 'explicit sidebar grid splitter'

Replace-Exact $xamlPath `
@'
                            </ScrollViewer>
                        </Grid>

                        <GridSplitter Grid.Column="3" Width="5" HorizontalAlignment="Stretch" Background="#172738" />
'@ `
@'
                            </ScrollViewer>
                            <Button x:Name="ExpandPagesSidebarButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="38"
                                    HorizontalAlignment="Left" VerticalAlignment="Top" Margin="8" Padding="0" Visibility="Collapsed" Panel.ZIndex="10"
                                    Click="ExpandPagesSidebar_Click" ToolTip="Show navigation sidebar" />
                        </Grid>

                        <GridSplitter Grid.Column="3" Width="5" HorizontalAlignment="Stretch" Background="#172738" />
'@ 'sidebar restore affordance'

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $mainPath `
@'
    private void TogglePages_Click(object sender, RoutedEventArgs e) =>
        PagesColumn.Width = PagesColumn.Width.Value == 0 ? new GridLength(230) : new GridLength(0);

    private void ToggleInspector_Click(object sender, RoutedEventArgs e) =>
'@ `
@'
    private double _lastPagesSidebarWidth = 245;

    private void TogglePages_Click(object sender, RoutedEventArgs e) =>
        SetPagesSidebarCollapsed(PagesColumn.Width.Value > 0);

    private void CollapsePagesSidebar_Click(object sender, RoutedEventArgs e) =>
        SetPagesSidebarCollapsed(true);

    private void ExpandPagesSidebar_Click(object sender, RoutedEventArgs e) =>
        SetPagesSidebarCollapsed(false);

    private void SetPagesSidebarCollapsed(bool collapsed)
    {
        if (collapsed)
        {
            var currentWidth = PagesColumn.ActualWidth > 0 ? PagesColumn.ActualWidth : PagesColumn.Width.Value;
            if (currentWidth >= 180) _lastPagesSidebarWidth = Math.Clamp(currentWidth, 180, 460);
            PagesColumn.MinWidth = 0;
            PagesColumn.Width = new GridLength(0);
            PagesSplitterColumn.Width = new GridLength(0);
            PagesNavigationBorder.Visibility = Visibility.Collapsed;
            PagesSplitter.Visibility = Visibility.Collapsed;
            ExpandPagesSidebarButton.Visibility = Visibility.Visible;
            return;
        }

        PagesColumn.MinWidth = 180;
        PagesColumn.MaxWidth = 460;
        PagesColumn.Width = new GridLength(Math.Clamp(_lastPagesSidebarWidth, 180, 460));
        PagesSplitterColumn.Width = new GridLength(5);
        PagesNavigationBorder.Visibility = Visibility.Visible;
        PagesSplitter.Visibility = Visibility.Visible;
        ExpandPagesSidebarButton.Visibility = Visibility.Collapsed;
    }

    private void ToggleInspector_Click(object sender, RoutedEventArgs e) =>
'@ 'sidebar collapse logic'

Write-Host 'Collapsible/resizable document sidebar development patch applied.' -ForegroundColor Green
