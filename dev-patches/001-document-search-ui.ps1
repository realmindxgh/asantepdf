param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $text = (Get-Content $Path -Raw).Replace("`r`n", "`n")
    $oldNormalized = $Old.Replace("`r`n", "`n")
    $newNormalized = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldNormalized)) {
        throw "Could not apply $Description. Expected source text was not found in $Path."
    }
    $updated = $text.Replace($oldNormalized, $newNormalized)
    Set-Content -Path $Path -Value $updated -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$tabs = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'

$oldToolbarSearch = @'
                            <TextBox Grid.Column="2" Width="235" IsReadOnly="True" IsEnabled="False" Text="Search in document" ToolTip="Full document search is tracked in master item 12" />
'@
$newToolbarSearch = @'
                            <Border Grid.Column="2" Background="#101D2A" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="7" Padding="4">
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBox x:Name="DocumentSearchBox" Width="205" Height="29" VerticalContentAlignment="Center"
                                             ToolTip="Search the active PDF (Ctrl+F)" KeyDown="DocumentSearchBox_KeyDown" />
                                    <Button x:Name="SearchPreviousButton" Style="{StaticResource FlatButtonStyle}" Content="‹" Width="30" Height="29"
                                            Padding="3" IsEnabled="False" ToolTip="Previous match" Click="SearchPrevious_Click" />
                                    <Button x:Name="SearchNextButton" Style="{StaticResource FlatButtonStyle}" Content="›" Width="30" Height="29"
                                            Padding="3" IsEnabled="False" ToolTip="Next match" Click="SearchNext_Click" />
                                    <TextBlock x:Name="SearchCountText" Width="62" TextAlignment="Center" VerticalAlignment="Center"
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="11" />
                                    <Button x:Name="SearchClearButton" Style="{StaticResource FlatButtonStyle}" Content="×" Width="30" Height="29"
                                            Padding="3" IsEnabled="False" ToolTip="Clear search" Click="SearchClear_Click" />
                                </StackPanel>
                            </Border>
'@
Replace-Exact $xaml $oldToolbarSearch $newToolbarSearch 'live document search toolbar'

$oldSearchModeButton = @'
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModePlaceholder_Click" Content="Search" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
'@
$newSearchModeButton = @'
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModeSearch_Click" Content="Search" Padding="7,5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
'@
Replace-Exact $xaml $oldSearchModeButton $newSearchModeButton 'search sidebar mode button'

$oldNavigationPlaceholder = @'
                                <StackPanel x:Name="NavigationPlaceholder" Grid.Row="1" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18">
                                    <TextBlock Text="Navigation view" FontWeight="SemiBold" HorizontalAlignment="Center" />
                                    <TextBlock Text="Bookmarks and full search results are being built on this navigation shell." TextWrapping="Wrap" TextAlignment="Center" Foreground="{StaticResource MutedTextBrush}" FontSize="12" Margin="0,6,0,0" />
                                </StackPanel>
'@
$newNavigationPlaceholder = @'
                                <StackPanel x:Name="NavigationPlaceholder" Grid.Row="1" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18">
                                    <TextBlock Text="Bookmarks" FontWeight="SemiBold" HorizontalAlignment="Center" />
                                    <TextBlock Text="PDF outline and bookmark navigation are still being built." TextWrapping="Wrap" TextAlignment="Center" Foreground="{StaticResource MutedTextBrush}" FontSize="12" Margin="0,6,0,0" />
                                </StackPanel>
                                <Grid x:Name="SearchResultsPanel" Grid.Row="1" Visibility="Collapsed">
                                    <ListBox x:Name="SearchResultsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             SelectionChanged="SearchResultsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                        <ListBox.ItemTemplate>
                                            <DataTemplate>
                                                <Border Background="#122131" BorderBrush="#29425B" BorderThickness="1" CornerRadius="6" Padding="9" Margin="0,0,0,6">
                                                    <StackPanel>
                                                        <TextBlock Text="{Binding PageLabel}" Foreground="#72B5FF" FontSize="11" FontWeight="SemiBold" />
                                                        <TextBlock Text="{Binding Snippet}" TextWrapping="Wrap" FontSize="12" Margin="0,5,0,0" />
                                                    </StackPanel>
                                                </Border>
                                            </DataTemplate>
                                        </ListBox.ItemTemplate>
                                    </ListBox>
                                    <TextBlock x:Name="SearchEmptyText" Text="Enter text above or press Ctrl+F to search this PDF."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18" />
                                </Grid>
'@
Replace-Exact $xaml $oldNavigationPlaceholder $newNavigationPlaceholder 'search results sidebar'

$oldPreviewLayers = @'
                                        <Image x:Name="PreviewImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
'@
$newPreviewLayers = @'
                                        <Image x:Name="PreviewImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
                                        <Canvas x:Name="SearchHighlightCanvas" Background="Transparent" Visibility="Collapsed" IsHitTestVisible="False" />
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
'@
Replace-Exact $xaml $oldPreviewLayers $newPreviewLayers 'search highlight overlay'

$oldOpenCommit = @'
            _currentPdf = fullPath;
            _documentGeneration++;
'@
$newOpenCommit = @'
            _currentPdf = fullPath;
            ResetDocumentSearchForDocumentChange();
            _documentGeneration++;
'@
Replace-Exact $main $oldOpenCommit $newOpenCommit 'search reset on document activation'

$oldPreviewRefresh = @'
            PageStatusText.Text = $"Page {page.Position:N0} of {Pages.Count:N0}";
            UpdateZoomText();
'@
$newPreviewRefresh = @'
            PageStatusText.Text = $"Page {page.Position:N0} of {Pages.Count:N0}";
            UpdateZoomText();
            RefreshDocumentSearchHighlights(page);
'@
Replace-Exact $main $oldPreviewRefresh $newPreviewRefresh 'search highlight refresh after page render'

$oldShortcutBlock = @'
        else if (ctrl && e.Key == Key.O) { OpenPdf_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@
$newShortcutBlock = @'
        else if (ctrl && e.Key == Key.O) { OpenPdf_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && e.Key == Key.F) { FocusDocumentSearch(); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@
Replace-Exact $main $oldShortcutBlock $newShortcutBlock 'Ctrl+F document search shortcut'

$oldPageModes = @'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        NavigationPlaceholder.Visibility = Visibility.Collapsed;
    }

    private void PageModePlaceholder_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Collapsed;
        NavigationPlaceholder.Visibility = Visibility.Visible;
    }
'@
$newPageModes = @'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        NavigationPlaceholder.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
    }

    private void PageModePlaceholder_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        NavigationPlaceholder.Visibility = Visibility.Visible;
    }
'@
Replace-Exact $productShell $oldPageModes $newPageModes 'search-aware navigation sidebar modes'

$oldLastTabClear = @'
        _savedLayoutBaseline = null;
        PreviewImage.Source = null;
        DocumentTitle.Text = "No document open";
'@
$newLastTabClear = @'
        _savedLayoutBaseline = null;
        PreviewImage.Source = null;
        ResetDocumentSearchForDocumentChange();
        DocumentTitle.Text = "No document open";
'@
Replace-Exact $tabs $oldLastTabClear $newLastTabClear 'clear search when last tab closes'
