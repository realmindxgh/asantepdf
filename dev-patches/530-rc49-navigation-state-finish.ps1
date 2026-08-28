param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
function Read-Lf([string]$r){$p=Join-Path $SourceRoot $r;if(!(Test-Path $p)){throw "Missing $r"};[IO.File]::ReadAllText($p,$utf8).Replace("`r`n","`n")}
function Write-Lf([string]$r,[string]$t){$p=Join-Path $SourceRoot $r;[IO.File]::WriteAllText($p,$t.Replace("`r`n","`n"),$utf8)}
function Rx([string]$t,[string]$o,[string]$n,[string]$l){$t=$t.Replace("`r`n","`n");$o=$o.Replace("`r`n","`n");$n=$n.Replace("`r`n","`n");if(!$t.Contains($o)){throw "Anchor not found: $l"};$t.Replace($o,$n)}

$x='src/PdfRescue.App/MainWindow.xaml';$s=Read-Lf $x
$s=Rx $s '<Button Style="{StaticResource NavButtonStyle}" Click="HomeDoctor_Click">' '<Button x:Name="DoctorNavButton" Style="{StaticResource NavButtonStyle}" Click="HomeDoctor_Click">' 'Doctor nav name'
Write-Lf $x $s

$p='src/PdfRescue.App/MainWindow.ProductShell.cs';$s=Read-Lf $p
$s=$s.Replace('    private void HomeRecentNav_Click(object sender, RoutedEventArgs e)`n    {`n        ShowHomeContent();','    private void HomeRecentNav_Click(object sender, RoutedEventArgs e)`n    {`n        CloseTaskCenterDrawer();`n        ShowHomeContent();')
$s=$s.Replace('    private void HomeStarredNav_Click(object sender, RoutedEventArgs e)`n    {`n        ShowHomeContent();','    private void HomeStarredNav_Click(object sender, RoutedEventArgs e)`n    {`n        CloseTaskCenterDrawer();`n        ShowHomeContent();')
$oldClose=@'
    private void TaskCenterClose_Click(object sender, RoutedEventArgs e)
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
    }

    private void CloseTaskCenterDrawer()
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
    }
'@
$newClose=@'
    private void TaskCenterClose_Click(object sender, RoutedEventArgs e)
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
        SetPrimaryNavigationState(_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton);
    }

    private void CloseTaskCenterDrawer()
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
        SetPrimaryNavigationState(_currentPdf is null ? HomeNavButton : ActiveDocumentNavButton);
    }
'@
$s=Rx $s $oldClose $newClose 'Task Center close navigation restore'
$s=Rx $s 'foreach (var button in new[] { HomeNavButton, RecentNavButton, StarredNavButton, ToolsNavButton, ActiveDocumentNavButton, TaskCenterNavButton })' 'foreach (var button in new[] { HomeNavButton, RecentNavButton, StarredNavButton, ToolsNavButton, DoctorNavButton, ActiveDocumentNavButton, TaskCenterNavButton })' 'all primary nav buttons'
$oldDoctor=@'
    private async void HomeDoctor_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to inspect") is not null)
            Doctor_Click(sender, e);
    }
'@
$newDoctor=@'
    private async void HomeDoctor_Click(object sender, RoutedEventArgs e)
    {
        CloseTaskCenterDrawer();
        var fallback = _currentPdf is null ? HomeNavButton : ActiveDocumentNavButton;
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to inspect") is not null)
        {
            SetPrimaryNavigationState(DoctorNavButton);
            Doctor_Click(sender, e);
        }
        else
        {
            SetPrimaryNavigationState(fallback);
        }
    }
'@
$s=Rx $s $oldDoctor $newDoctor 'Doctor active nav workflow'
Write-Lf $p $s
Write-Host 'RC49 navigation-state acceptance finish staged.' -ForegroundColor Green
