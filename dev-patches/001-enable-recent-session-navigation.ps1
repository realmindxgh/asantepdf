param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$target = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
$text = (Get-Content $target -Raw).Replace("`r`n", "`n")

function Replace-Exact([string]$Old, [string]$New, [string]$Description) {
    if (-not $script:text.Contains($Old)) {
        throw "Could not apply $Description. Expected XAML was not found."
    }
    $script:text = $script:text.Replace($Old, $New)
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$oldStarred = @'
                        <Button Style="{StaticResource NavButtonStyle}" IsEnabled="False" ToolTip="Pinned documents will appear here in the Recent-files upgrade">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE734;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Starred"/></StackPanel>
                        </Button>
'@
$newStarred = @'
                        <Button Style="{StaticResource NavButtonStyle}" Click="HomeStarredNav_Click" ToolTip="Show pinned recent documents">
                            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE734;" FontFamily="Segoe MDL2 Assets" Width="28"/><TextBlock Text="Starred"/></StackPanel>
                        </Button>
'@
Replace-Exact $oldStarred $newStarred 'Starred recent-files navigation'

$oldResume = @'
                                <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" IsEnabled="False" ToolTip="Session recovery is tracked in master item 4" Padding="16,9">
                                    <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE823;" FontFamily="Segoe MDL2 Assets" Foreground="#4D9BFF"/><TextBlock Text="Resume Last Session" Margin="8,0,0,0"/></StackPanel>
                                </Button>
'@
$newResume = @'
                                <Button x:Name="ResumeSessionButton" Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="ResumeLastSession_Click" IsEnabled="False" ToolTip="Restore the last available document, page and zoom position" Padding="16,9">
                                    <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE823;" FontFamily="Segoe MDL2 Assets" Foreground="#4D9BFF"/><TextBlock Text="Resume Last Session" Margin="8,0,0,0"/></StackPanel>
                                </Button>
'@
Replace-Exact $oldResume $newResume 'Resume Last Session command'

Set-Content -Path $target -Value $text -Encoding UTF8 -NoNewline
