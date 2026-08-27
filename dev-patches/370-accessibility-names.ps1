param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
function N([string]$Text) { $Text.Replace("`r`n", "`n") }
function W([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,(N $Text).Replace("`n","`r`n"),[Text.UTF8Encoding]::new($false)) }
function R([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=N([IO.File]::ReadAllText($Path)); $o=N $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; W $Path ($t.Replace($o,(N $New))) }
$x = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'

R $x @'
                        <TextBox x:Name="HomeSearchBox" Grid.Column="1" Background="Transparent" BorderThickness="0" Padding="0"
                                 TextChanged="HomeSearchBox_TextChanged" VerticalContentAlignment="Center" ToolTip="Search recent files" />
'@ @'
                        <TextBox x:Name="HomeSearchBox" Grid.Column="1" Background="Transparent" BorderThickness="0" Padding="0"
                                 TextChanged="HomeSearchBox_TextChanged" VerticalContentAlignment="Center" ToolTip="Search recent files"
                                 AutomationProperties.Name="Search recent PDF files" AutomationProperties.HelpText="Search the recent-files list. Shortcut Ctrl+K." />
'@ 'home search accessibility'

R $x @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="About, diagnostics and updates" Click="About_Click"><TextBlock Text="?" FontSize="17" /></Button>
                    <Button x:Name="ThemeToggleButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" Click="ThemeToggle_Click" ToolTip="Switch theme">
'@ @'
                    <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="About, diagnostics and updates" Click="About_Click"
                            AutomationProperties.Name="About, diagnostics and updates"><TextBlock Text="?" FontSize="17" /></Button>
                    <Button x:Name="ThemeToggleButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" Click="ThemeToggle_Click" ToolTip="Switch theme"
                            AutomationProperties.Name="Switch light or dark theme" AutomationProperties.HelpText="Immediately toggles between light and dark appearance.">
'@ 'titlebar about theme accessibility'

R $x @'
                    <Button x:Name="SettingsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Settings" Click="Settings_Click"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="16" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MinimizeWindow_Click" ToolTip="Minimize"><TextBlock Text="&#xE921;" FontFamily="Segoe MDL2 Assets" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MaximizeWindow_Click" ToolTip="Maximize"><TextBlock Text="&#xE922;" FontFamily="Segoe MDL2 Assets" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="CloseWindow_Click" ToolTip="Close"><TextBlock Text="&#xE8BB;" FontFamily="Segoe MDL2 Assets" /></Button>
'@ @'
                    <Button x:Name="SettingsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="0" ToolTip="Settings" Click="Settings_Click"
                            AutomationProperties.Name="Settings"><TextBlock Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="16" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MinimizeWindow_Click" ToolTip="Minimize"
                            AutomationProperties.Name="Minimize AsantePDF window"><TextBlock Text="&#xE921;" FontFamily="Segoe MDL2 Assets" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MaximizeWindow_Click" ToolTip="Maximize"
                            AutomationProperties.Name="Maximize or restore AsantePDF window"><TextBlock Text="&#xE922;" FontFamily="Segoe MDL2 Assets" /></Button>
                    <Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="CloseWindow_Click" ToolTip="Close"
                            AutomationProperties.Name="Close AsantePDF window"><TextBlock Text="&#xE8BB;" FontFamily="Segoe MDL2 Assets" /></Button>
'@ 'window command accessibility'

R $x @'
                            <ListBox x:Name="DocumentTabsList" Grid.Column="0" SelectionMode="Single"
                                     SelectionChanged="DocumentTabsList_SelectionChanged"
'@ @'
                            <ListBox x:Name="DocumentTabsList" Grid.Column="0" SelectionMode="Single"
                                     AutomationProperties.Name="Open PDF document tabs" AutomationProperties.HelpText="Select a PDF tab. Ctrl+Tab changes tabs and Ctrl+W closes the active tab."
                                     SelectionChanged="DocumentTabsList_SelectionChanged"
'@ 'document tabs accessibility'

R $x @'
                                            <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Content="×"
                                                    Click="DocumentTabClose_Click" Width="30" Height="28" Padding="0" Margin="2,0,4,0"
                                                    ToolTip="Close tab (Ctrl+W)" />
'@ @'
                                            <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Content="×"
                                                    Click="DocumentTabClose_Click" Width="30" Height="28" Padding="0" Margin="2,0,4,0"
                                                    ToolTip="Close tab (Ctrl+W)" AutomationProperties.Name="Close this PDF tab" />
'@ 'tab close accessibility'

R $x @'
                                <Button x:Name="CompareTabsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenSplitView_Click" IsEnabled="False" ToolTip="Compare two open PDFs side by side">
'@ @'
                                <Button x:Name="CompareTabsButton" Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenSplitView_Click" IsEnabled="False" ToolTip="Compare two open PDFs side by side"
                                        AutomationProperties.Name="Compare two open PDFs side by side">
'@ 'compare accessibility'

R $x @'
                                <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
'@ @'
                                <Button Style="{StaticResource FlatButtonStyle}" Width="42" Margin="2,3" Click="OpenPdf_Click" ToolTip="Open another PDF"
                                        AutomationProperties.Name="Open another PDF"><TextBlock Text="+" FontSize="23" /></Button>
'@ 'open another accessibility'

R $x @'
                                <TextBox x:Name="PageNumberBox" Width="48" Height="30" TextAlignment="Center" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" KeyDown="PageNumberBox_KeyDown" Margin="7,0,4,0" />
'@ @'
                                <TextBox x:Name="PageNumberBox" Width="48" Height="30" TextAlignment="Center" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" KeyDown="PageNumberBox_KeyDown" Margin="7,0,4,0"
                                         AutomationProperties.Name="Current page number" AutomationProperties.HelpText="Enter a page number and press Enter to jump to that page." />
'@ 'page number accessibility'

R $x @'
                                <Button x:Name="ZoomButton" Style="{StaticResource FlatButtonStyle}" Click="ActualSizeShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="100%" MinWidth="66" Padding="7,4" />
'@ @'
                                <Button x:Name="ZoomButton" Style="{StaticResource FlatButtonStyle}" Click="ActualSizeShell_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" Content="100%" MinWidth="66" Padding="7,4"
                                        AutomationProperties.Name="Zoom percentage and actual size" AutomationProperties.HelpText="Shows current zoom. Activate to return to 100 percent." />
'@ 'zoom accessibility'

R $x @'
                                <ComboBox x:Name="PageViewModeCombo" Width="128" Height="30" Margin="12,0,0,0"
                                          SelectionChanged="PageViewModeCombo_SelectionChanged"
                                          IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Document viewing mode">
'@ @'
                                <ComboBox x:Name="PageViewModeCombo" Width="128" Height="30" Margin="12,0,0,0"
                                          SelectionChanged="PageViewModeCombo_SelectionChanged"
                                          IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Document viewing mode"
                                          AutomationProperties.Name="PDF viewing mode" AutomationProperties.HelpText="Choose Single Page, Continuous, or Two Page view.">
'@ 'page view accessibility'

R $x @'
                                    <TextBox x:Name="DocumentSearchBox" Width="205" Height="29" VerticalContentAlignment="Center"
                                             ToolTip="Search the active PDF (Ctrl+F)" KeyDown="DocumentSearchBox_KeyDown" />
'@ @'
                                    <TextBox x:Name="DocumentSearchBox" Width="205" Height="29" VerticalContentAlignment="Center"
                                             ToolTip="Search the active PDF (Ctrl+F)" KeyDown="DocumentSearchBox_KeyDown"
                                             AutomationProperties.Name="Search active PDF" AutomationProperties.HelpText="Type text and press Enter. Shortcut Ctrl+F." />
'@ 'document search accessibility'

R $x @'
                                    <Button Grid.Column="5" Style="{StaticResource FlatButtonStyle}" Click="CollapsePagesSidebar_Click" Content="‹" Padding="0" Margin="2,0,0,0" ToolTip="Collapse navigation sidebar" />
'@ @'
                                    <Button Grid.Column="5" Style="{StaticResource FlatButtonStyle}" Click="CollapsePagesSidebar_Click" Content="‹" Padding="0" Margin="2,0,0,0" ToolTip="Collapse navigation sidebar"
                                            AutomationProperties.Name="Collapse document navigation sidebar" />
'@ 'collapse sidebar accessibility'

R $x @'
                                <ListBox x:Name="PagesList" Grid.Row="1" SelectionMode="Extended" SelectionChanged="PagesList_SelectionChanged"
                                         AllowDrop="True" PreviewMouseLeftButtonDown="PagesList_PreviewMouseLeftButtonDown"
'@ @'
                                <ListBox x:Name="PagesList" Grid.Row="1" SelectionMode="Extended" SelectionChanged="PagesList_SelectionChanged"
                                         AutomationProperties.Name="PDF page thumbnails" AutomationProperties.HelpText="Select, multi-select, reorder, rotate, duplicate, extract or delete PDF pages."
                                         AllowDrop="True" PreviewMouseLeftButtonDown="PagesList_PreviewMouseLeftButtonDown"
'@ 'pages list accessibility'

R $x @'
                                    <TreeView x:Name="OutlineTree" Background="Transparent" BorderThickness="0" Margin="6"
                                              SelectedItemChanged="OutlineTree_SelectedItemChanged"
'@ @'
                                    <TreeView x:Name="OutlineTree" Background="Transparent" BorderThickness="0" Margin="6"
                                              AutomationProperties.Name="PDF bookmarks and outline"
                                              SelectedItemChanged="OutlineTree_SelectedItemChanged"
'@ 'outline accessibility'

R $x @'
                                    <ListBox x:Name="SearchResultsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             SelectionChanged="SearchResultsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ @'
                                    <ListBox x:Name="SearchResultsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             AutomationProperties.Name="PDF search results"
                                             SelectionChanged="SearchResultsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ 'search results accessibility'

R $x @'
                                    <ListBox x:Name="AnnotationsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             SelectionChanged="AnnotationsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ @'
                                    <ListBox x:Name="AnnotationsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             AutomationProperties.Name="PDF comments and annotations"
                                             SelectionChanged="AnnotationsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ 'annotations list accessibility'

R $x @'
                                    <ListBox x:Name="AttachmentsList" Grid.Row="0" Background="Transparent" BorderThickness="0" Margin="6"
                                             ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ @'
                                    <ListBox x:Name="AttachmentsList" Grid.Row="0" Background="Transparent" BorderThickness="0" Margin="6"
                                             AutomationProperties.Name="Embedded PDF attachments"
                                             ScrollViewer.HorizontalScrollBarVisibility="Disabled">
'@ 'attachments accessibility'

R $x @'
                            <ScrollViewer x:Name="PreviewScroll" Visibility="Collapsed" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
'@ @'
                            <ScrollViewer x:Name="PreviewScroll" Visibility="Collapsed" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto"
                                          AutomationProperties.Name="Single-page PDF document view">
'@ 'preview scroll accessibility'

R $x @'
                                        <Image x:Name="PreviewImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality" />
'@ @'
                                        <Image x:Name="PreviewImage" Stretch="None" RenderOptions.BitmapScalingMode="HighQuality"
                                               AutomationProperties.Name="Current rendered PDF page" />
'@ 'preview image accessibility'

R $x @'
                                        <Canvas x:Name="TextSelectionCanvas" Background="Transparent" Visibility="Collapsed" IsHitTestVisible="False" Focusable="True" Cursor="IBeam"
                                                MouseLeftButtonDown="TextSelectionCanvas_MouseLeftButtonDown"
'@ @'
                                        <Canvas x:Name="TextSelectionCanvas" Background="Transparent" Visibility="Collapsed" IsHitTestVisible="False" Focusable="True" Cursor="IBeam"
                                                AutomationProperties.Name="Selectable PDF text layer" AutomationProperties.HelpText="Drag across text to select it, then press Ctrl+C or use annotation commands."
                                                MouseLeftButtonDown="TextSelectionCanvas_MouseLeftButtonDown"
'@ 'text selection accessibility'

R $x @'
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
                                                MouseLeftButtonDown="MarkupCanvas_MouseLeftButtonDown" MouseMove="MarkupCanvas_MouseMove" MouseLeftButtonUp="MarkupCanvas_MouseLeftButtonUp">
'@ @'
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
                                                AutomationProperties.Name="PDF annotation and editing canvas"
                                                MouseLeftButtonDown="MarkupCanvas_MouseLeftButtonDown" MouseMove="MarkupCanvas_MouseMove" MouseLeftButtonUp="MarkupCanvas_MouseLeftButtonUp">
'@ 'markup canvas accessibility'

R $x @'
                            <ListBox x:Name="ContinuousPagesList" Visibility="Collapsed" Background="Transparent" BorderThickness="0"
                                     SelectionMode="Single" SelectionChanged="ContinuousPagesList_SelectionChanged"
'@ @'
                            <ListBox x:Name="ContinuousPagesList" Visibility="Collapsed" Background="Transparent" BorderThickness="0"
                                     AutomationProperties.Name="Continuous PDF reading view"
                                     SelectionMode="Single" SelectionChanged="ContinuousPagesList_SelectionChanged"
'@ 'continuous view accessibility'

Write-Host 'Screen-reader accessibility metadata staged.' -ForegroundColor Green
