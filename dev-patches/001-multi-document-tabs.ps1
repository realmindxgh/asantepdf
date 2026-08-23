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

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$oldTabs = @'
                    <!-- Document tabs -->
                    <Border Grid.Row="0" Background="#0B1724" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Stretch">
                                <Border Background="#132236" BorderBrush="#2D7DFF" BorderThickness="0,2,0,0" MinWidth="250" Padding="14,0" Margin="8,0,0,0">
                                    <Grid>
                                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <TextBlock x:Name="DocumentTitle" Text="No document open" VerticalAlignment="Center" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" />
                                        <TextBlock Grid.Column="1" Text="×" Margin="12,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource MutedTextBrush}" />
                                        <TextBlock x:Name="DocumentMeta" Visibility="Collapsed" />
                                    </Grid>
                                </Border>
                                <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
                            </StackPanel>
                        </Grid>
                    </Border>
'@
$newTabs = @'
                    <!-- Document tabs -->
                    <Border Grid.Row="0" Background="#0B1724" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1">
                        <Grid>
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <ListBox x:Name="DocumentTabsList" Grid.Column="0" SelectionMode="Single"
                                     SelectionChanged="DocumentTabsList_SelectionChanged"
                                     PreviewMouseLeftButtonDown="DocumentTabsList_PreviewMouseLeftButtonDown"
                                     PreviewMouseMove="DocumentTabsList_PreviewMouseMove"
                                     PreviewMouseDown="DocumentTabsList_PreviewMouseDown"
                                     AllowDrop="True" DragOver="DocumentTabsList_DragOver" Drop="DocumentTabsList_Drop"
                                     ScrollViewer.HorizontalScrollBarVisibility="Auto" ScrollViewer.VerticalScrollBarVisibility="Disabled"
                                     Margin="8,0,0,0">
                                <ListBox.ItemsPanel>
                                    <ItemsPanelTemplate><StackPanel Orientation="Horizontal" /></ItemsPanelTemplate>
                                </ListBox.ItemsPanel>
                                <ListBox.ItemContainerStyle>
                                    <Style TargetType="ListBoxItem">
                                        <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
                                        <Setter Property="Background" Value="Transparent" />
                                        <Setter Property="BorderBrush" Value="Transparent" />
                                        <Setter Property="BorderThickness" Value="0,2,0,0" />
                                        <Setter Property="Padding" Value="0" />
                                        <Setter Property="Margin" Value="0" />
                                        <Setter Property="HorizontalContentAlignment" Value="Stretch" />
                                        <Style.Triggers>
                                            <Trigger Property="IsSelected" Value="True">
                                                <Setter Property="Background" Value="#132236" />
                                                <Setter Property="BorderBrush" Value="#2D7DFF" />
                                            </Trigger>
                                        </Style.Triggers>
                                    </Style>
                                </ListBox.ItemContainerStyle>
                                <ListBox.ItemTemplate>
                                    <DataTemplate>
                                        <Grid MinWidth="190" MaxWidth="280" Height="40" Margin="4,0">
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                            <TextBlock Text="{Binding DisplayTitle}" VerticalAlignment="Center" FontWeight="SemiBold"
                                                       TextTrimming="CharacterEllipsis" Margin="10,0,4,0" ToolTip="{Binding Path}" />
                                            <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Content="×"
                                                    Click="DocumentTabClose_Click" Width="30" Height="28" Padding="0" Margin="2,0,4,0"
                                                    ToolTip="Close tab (Ctrl+W)" />
                                        </Grid>
                                    </DataTemplate>
                                </ListBox.ItemTemplate>
                            </ListBox>
                            <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
                            <TextBlock x:Name="DocumentTitle" Text="No document open" Visibility="Collapsed" />
                            <TextBlock x:Name="DocumentMeta" Visibility="Collapsed" />
                        </Grid>
                    </Border>
'@
Replace-Exact $xamlPath $oldTabs $newTabs 'multi-document tab strip'

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$oldInit = @'
        _homeContent = EmptyPanel.Child;
        _taskCenterView = new TaskCenterView(_taskCenterService);

        _recentFilesView = new RecentFilesView();
'@
$newInit = @'
        _homeContent = EmptyPanel.Child;
        _taskCenterView = new TaskCenterView(_taskCenterService);
        InitializeDocumentTabs();

        _recentFilesView = new RecentFilesView();
'@
Replace-Exact $productShellPath $oldInit $newInit 'document-tab initialization'

$windowPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$oldOpenStart = @'
    private async Task OpenPdfAsync(string path)
    {
        if (_busy || !File.Exists(path)) return;
        if (!await ConfirmDocumentReplacementAsync("opening another PDF")) return;

        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = null;

        var fullPath = Path.GetFullPath(path);
'@
$newOpenStart = @'
    private async Task OpenPdfAsync(string path)
    {
        if (_busy || !File.Exists(path)) return;
        var fullPath = Path.GetFullPath(path);
        if (await TryActivateExistingDocumentTabAsync(fullPath)) return;
        if (!_productShellInitialized && !await ConfirmDocumentReplacementAsync("opening another PDF")) return;

        _thumbnailCts?.Cancel();
        _thumbnailCts?.Dispose();
        _thumbnailCts = null;
'@
Replace-Exact $windowPath $oldOpenStart $newOpenStart 'tab-aware PDF opening'

$oldOpenFinish = @'
        if (!opened || _currentPdf is null) return;

        AddRecentDocument(_currentPdf);
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
'@
$newOpenFinish = @'
        if (!opened || _currentPdf is null) return;

        await SynchronizeDocumentTabAfterOpenAsync(_currentPdf);
        AddRecentDocument(_currentPdf);
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
'@
Replace-Exact $windowPath $oldOpenFinish $newOpenFinish 'tab state synchronization after open'

$oldDirty = @'
        var fileName = Path.GetFileName(_currentPdf);
        DocumentTitle.Text = HasUnsavedLayoutChanges() ? fileName + " *" : fileName;
'@
$newDirty = @'
        var fileName = Path.GetFileName(_currentPdf);
        DocumentTitle.Text = HasUnsavedLayoutChanges() ? fileName + " *" : fileName;
        UpdateActiveDocumentTabDirtyState();
'@
Replace-Exact $windowPath $oldDirty $newDirty 'per-tab dirty indicator'

$oldCloseCondition = @'
        if (_closeAfterConfirmation) return;
        if (!_busy && !HasUnsavedLayoutChanges()) return;
'@
$newCloseCondition = @'
        if (_closeAfterConfirmation) return;
        if (!_busy && !HasUnsavedLayoutChanges() && !HasInactiveDirtyDocumentTabs()) return;
'@
Replace-Exact $windowPath $oldCloseCondition $newCloseCondition 'multi-tab close protection condition'

$oldCloseConfirm = @'
            if (!await ConfirmDocumentReplacementAsync("closing AsantePDF")) return;

            _closeAfterConfirmation = true;
'@
$newCloseConfirm = @'
            if (!await ConfirmDocumentReplacementAsync("closing AsantePDF")) return;
            if (!ConfirmDiscardInactiveDirtyTabsForExit()) return;

            _closeAfterConfirmation = true;
'@
Replace-Exact $windowPath $oldCloseConfirm $newCloseConfirm 'inactive dirty-tab exit confirmation'

$oldKeyboard = @'
        if (ctrl && e.Key == Key.O) { OpenPdf_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@
$newKeyboard = @'
        if (ctrl && e.Key == Key.Tab) { _ = ActivateAdjacentDocumentTabAsync(shift); e.Handled = true; }
        else if (ctrl && e.Key == Key.W) { if (_activeDocumentTab is not null) _ = CloseDocumentTabAsync(_activeDocumentTab); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.T) { _ = ReopenLastClosedDocumentTabAsync(); e.Handled = true; }
        else if (ctrl && e.Key == Key.O) { OpenPdf_Click(sender, new RoutedEventArgs()); e.Handled = true; }
        else if (ctrl && shift && e.Key == Key.S) { SaveAs_Click(sender, new RoutedEventArgs()); e.Handled = true; }
'@
Replace-Exact $windowPath $oldKeyboard $newKeyboard 'multi-document keyboard shortcuts'
