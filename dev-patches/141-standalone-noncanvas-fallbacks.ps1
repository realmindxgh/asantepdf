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

function Replace-MethodGuard([string]$Path, [string]$Signature, [string]$OldGuard, [string]$NewGuard) {
    $old = "    $Signature`n    {`n        $OldGuard"
    $new = "    $Signature`n    {`n        $NewGuard"
    Replace-Exact $Path $old $new $Signature
}

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
$guards = @(
    @{ Signature='private async void Split_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to split") is null) return;' },
    @{ Signature='private async void Compress_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to compress") is null) return;' },
    @{ Signature='private async void Repair_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to repair") is null) return;' },
    @{ Signature='private async void Linearize_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to optimize for web viewing") is null) return;' },
    @{ Signature='private async void Protect_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to protect") is null) return;' },
    @{ Signature='private async void PdfToWord_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Word") is null) return;' },
    @{ Signature='private async void PdfToExcel_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Excel") is null) return;' },
    @{ Signature='private async void PdfToPowerPoint_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to PowerPoint") is null) return;' },
    @{ Signature='private async void ExportPagesAsImages_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export") is null) return;' },
    @{ Signature='private async void OcrPdf_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to OCR") is null) return;' },
    @{ Signature='private async void ExtractOcrText_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract") is null) return;' },
    @{ Signature='private async void Watermark_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to watermark") is null) return;' },
    @{ Signature='private async void PageNumbers_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to number") is null) return;' },
    @{ Signature='private async void HeaderFooter_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF for header/footer editing") is null) return;' },
    @{ Signature='private async void Metadata_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF whose metadata you want to edit") is null) return;' },
    @{ Signature='private async void StampImage_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to stamp with an image") is null) return;' },
    @{ Signature='private async void FillForm_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null || Pages.Count == 0) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF form to fill") is null) return;' },
    @{ Signature='private async void Doctor_Click(object sender, RoutedEventArgs e)'; Old='if (_currentPdf is null) return;'; New='if ((_currentPdf is null || Pages.Count == 0) && await SelectPdfForStandaloneToolAsync("Choose a PDF to inspect") is null) return;' }
)
foreach ($guard in $guards) {
    Replace-MethodGuard $mainPath $guard.Signature $guard.Old $guard.New
}

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShellPath @'
    private async void HomeOcrText_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract with OCR") is not null)
            ExtractOcrText_Click(sender, e);
    }

    private async void RecentItem_Click(object sender, RoutedEventArgs e)
'@ @'
    private async void HomeOcrText_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract with OCR") is not null)
            ExtractOcrText_Click(sender, e);
    }

    private async void HomeWatermark_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to watermark") is not null)
            Watermark_Click(sender, e);
    }

    private async void HomePageNumbers_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to add page numbers to") is not null)
            PageNumbers_Click(sender, e);
    }

    private async void HomeHeaderFooter_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF for header/footer editing") is not null)
            HeaderFooter_Click(sender, e);
    }

    private async void HomeMetadata_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose metadata you want to edit") is not null)
            Metadata_Click(sender, e);
    }

    private async void HomeStampImage_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to stamp with an image") is not null)
            StampImage_Click(sender, e);
    }

    private async void HomeFillForm_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF form to fill") is not null)
            FillForm_Click(sender, e);
    }

    private async void RecentItem_Click(object sender, RoutedEventArgs e)
'@ 'home finishing tool handlers'

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath @'
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeOcrText_Click"><StackPanel><Border Width="44" Height="44" Background="#386029" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="TXT" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Extract OCR Text" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Read a scanned PDF and save its text as a local file." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                            </UniformGrid>
'@ @'
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeOcrText_Click"><StackPanel><Border Width="44" Height="44" Background="#386029" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="TXT" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Extract OCR Text" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Read a scanned PDF and save its text as a local file." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeWatermark_Click"><StackPanel><Border Width="44" Height="44" Background="#345770" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="W" FontWeight="Bold" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Watermark" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Add a text watermark to a chosen PDF." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomePageNumbers_Click"><StackPanel><Border Width="44" Height="44" Background="#5E4D26" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="#" FontWeight="Bold" FontSize="19" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Page Numbers" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Add numbered page labels without opening first." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeHeaderFooter_Click"><StackPanel><Border Width="44" Height="44" Background="#4A416F" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="H/F" FontWeight="Bold" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Header &amp; Footer" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Add consistent header and footer text." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeMetadata_Click"><StackPanel><Border Width="44" Height="44" Background="#3F5C4A" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="i" FontWeight="Bold" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Edit Metadata" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Update title, author and PDF metadata." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeStampImage_Click"><StackPanel><Border Width="44" Height="44" Background="#70454D" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="IMG" FontWeight="Bold" FontSize="10" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Stamp Image" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Place an image stamp on a selected page number." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                                <Button Style="{StaticResource ToolCardStyle}" Click="HomeFillForm_Click"><StackPanel><Border Width="44" Height="44" Background="#375B6A" CornerRadius="10" HorizontalAlignment="Left"><TextBlock Text="FORM" FontWeight="Bold" FontSize="9" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><TextBlock Text="Fill PDF Form" FontWeight="SemiBold" FontSize="14" Margin="0,12,0,0"/><TextBlock Text="Choose a standard PDF form and fill its fields." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/></StackPanel></Button>
                            </UniformGrid>
'@ 'expose non-canvas finishing workflows on Home'

Write-Host 'Standalone non-canvas fallback patch applied.' -ForegroundColor Green
