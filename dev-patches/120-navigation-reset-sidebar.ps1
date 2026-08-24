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

$path = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NavigationMetadata.cs'
Replace-Exact $path @'
        AnnotationsList.ItemsSource = null;
        AttachmentsList.ItemsSource = null;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SaveAttachmentButton.Visibility = Visibility.Collapsed;
'@ @'
        AnnotationsList.ItemsSource = null;
        AttachmentsList.ItemsSource = null;
        PagesList.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SaveAttachmentButton.Visibility = Visibility.Collapsed;
'@ 'restore a non-empty sidebar after document replacement'

Write-Host 'Sidebar document-reset hardening patch applied.' -ForegroundColor Green
