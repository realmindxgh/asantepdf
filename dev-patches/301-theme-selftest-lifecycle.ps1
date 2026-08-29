param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml.cs'
$text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
$old = @'
            if (e.Args.Length >= 2 && string.Equals(e.Args[0], "--selftest-theme", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunThemeRuntimeSelfTestAsync(e.Args[1]);
                return;
            }
'@
$new = @'
            if (e.Args.Length >= 2 && string.Equals(e.Args[0], "--selftest-theme", StringComparison.OrdinalIgnoreCase))
            {
                // ThemeRuntimeSelfTest intentionally creates and closes several windows.
                // With the product default OnMainWindowClose policy, the first hidden host
                // becomes Application.MainWindow and closing it terminates the process
                // before the whole-shell Light/Dark audit can run. Self-tests own their
                // lifetime explicitly and call Shutdown(...) with a meaningful exit code.
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                _ = RunThemeRuntimeSelfTestAsync(e.Args[1]);
                return;
            }
'@
$old = $old.Replace("`r`n", "`n")
$new = $new.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'Theme self-test startup anchor was not found.' }
$text = $text.Replace($old, $new)
[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
Write-Host 'Theme self-test now owns application shutdown explicitly.' -ForegroundColor Green
