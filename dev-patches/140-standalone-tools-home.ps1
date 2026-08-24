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

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShellPath @'
    private async Task<string?> SelectPdfForStandaloneToolAsync(string title)
    {
        var dialog = new OpenFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            CheckFileExists = true,
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != true) return null;
        await OpenPdfAsync(dialog.FileName);
        return _currentPdf;
    }
'@ @'
    private async Task<string?> SelectPdfForStandaloneToolAsync(string title)
    {
        var dialog = new OpenFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            CheckFileExists = true,
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != true) return null;

        var selectedPath = Path.GetFullPath(dialog.FileName);
        await OpenPdfAsync(selectedPath);
        return _currentPdf is not null &&
               string.Equals(Path.GetFullPath(_currentPdf), selectedPath, StringComparison.OrdinalIgnoreCase)
            ? _currentPdf
            : null;
    }
'@ 'standalone picker must return only the selected PDF'

Replace-Exact $productShellPath @'
    private async void HomeToWord_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Word") is not null)
            PdfToWord_Click(sender, e);
    }

    private async void RecentItem_Click(object sender, RoutedEventArgs e)
'@ @'
    private async void HomeToWord_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Word") is not null)
            PdfToWord_Click(sender, e);
    }

    private async void HomeRepair_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to repair") is not null)
            Repair_Click(sender, e);
    }

    private async void HomeOptimize_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to optimize for web viewing") is not null)
            Linearize_Click(sender, e);
    }

    private async void HomeProtect_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to protect with a password") is not null)
            Protect_Click(sender, e);
    }

    private void HomeUnlock_Click(object sender, RoutedEventArgs e) => Unlock_Click(sender, e);

    private async void HomeToExcel_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Excel") is not null)
            PdfToExcel_Click(sender, e);
    }

    private async void HomeToPowerPoint_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to PowerPoint") is not null)
            PdfToPowerPoint_Click(sender, e);
    }

    private void HomeOfficeToPdf_Click(object sender, RoutedEventArgs e) => OfficeToPdf_Click(sender, e);

    private async void HomeExportImages_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export as images") is not null)
            ExportPagesAsImages_Click(sender, e);
    }

    private async void HomeOcrText_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract with OCR") is not null)
            ExtractOcrText_Click(sender, e);
    }

    private async void RecentItem_Click(object sender, RoutedEventArgs e)
'@ 'complete standalone tool home handlers'

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath @'
                            </UniformGrid>

                            <StackPanel x:Name="HomeRecentSection" Margin="0,34,0,0">
'@ @'
                            </UniformGrid>

                            <TextBlock Text="More standalone tools" FontSize="19" FontWeight="SemiBold" Margin="0,30,0,2" />
                            <TextBlock Text="These workflows choose their own source file. You do not need to open a PDF first." Foreground="{StaticResource MutedTextBrush}" FontSize="13" Margin="0,0,0,10" />
                            <UniformGrid Columns="5" Margin="-6,0,-6,0">
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeRepair_Click"><StackPanel><Border Width="44" Height="44" Background="#704A17" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xE90F;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Repair PDF" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Repair structural problems without replacing the original." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeOptimize_Click"><StackPanel><Border Width="44" Height="44" Background="#17626F" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xE9D2;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Optimize for Web" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Create a fast-web-view copy of a PDF." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeProtect_Click"><StackPanel><Border Width="44" Height="44" Background="#71365D" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xE72E;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Protect PDF" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Add password protection to a chosen PDF." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeUnlock_Click"><StackPanel><Border Width="44" Height="44" Background="#6C3D2B" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xE785;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Unlock PDF" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Create an unlocked copy when you know the password." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeOfficeToPdf_Click"><StackPanel><Border Width="44" Height="44" Background="#374A83" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Office to PDF" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Convert Word, Excel or PowerPoint files to PDF." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeToExcel_Click"><StackPanel><Border Width="44" Height="44" Background="#176A48" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="X" FontWeight="Bold" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="PDF to Excel" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Recover PDF text into an Excel workbook." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeToPowerPoint_Click"><StackPanel><Border Width="44" Height="44" Background="#874625" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="P" FontWeight="Bold" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="PDF to PowerPoint" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Turn PDF pages into a PowerPoint presentation." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeExportImages_Click"><StackPanel><Border Width="44" Height="44" Background="#74407B" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="&#xEB9F;" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Export Page Images" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Export every PDF page as a numbered PNG image." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeOcrText_Click"><StackPanel><Border Width="44" Height="44" Background="#386029" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="TXT" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Extract OCR Text" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Read a scanned PDF and save its text as a local file." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                            </UniformGrid>

                            <StackPanel x:Name="HomeRecentSection" Margin="0,34,0,0">
'@ 'expose complete non-canvas standalone tools on Home'

Write-Host 'Standalone Home tool routing patch applied.' -ForegroundColor Green
