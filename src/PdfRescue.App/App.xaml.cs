using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Threading;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class App : Application
{
    public static string LogDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AsantePDF", "Logs");

    public static string StartupLogPath => Path.Combine(LogDirectory, "startup.log");
    public static string WindowReadyPath => Path.Combine(LogDirectory, "window-ready.flag");

    protected override void OnStartup(StartupEventArgs e)
    {
        Directory.CreateDirectory(LogDirectory);
        TryDelete(WindowReadyPath);
        Log("AsantePDF WPF startup entered.");
        Log($"OS: {Environment.OSVersion}");
        Log($"Runtime: {Environment.Version}");
        Log($"Base directory: {AppContext.BaseDirectory}");

        DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            Log("Unhandled AppDomain exception: " + args.ExceptionObject);
        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            Log("Unobserved task exception: " + args.Exception);
            args.SetObserved();
        };

        try
        {
            base.OnStartup(e);

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-conversions", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunConversionSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-finishing", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunFinishingSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-markup", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunMarkupSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-forms-batch", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunFormsBatchSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-final", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunFinalCandidateSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            var window = new MainWindow();
            MainWindow = window;
            window.Loaded += (_, _) =>
            {
                try
                {
                    File.WriteAllText(WindowReadyPath, DateTimeOffset.Now.ToString("O"), Encoding.UTF8);
                    Log("Main window loaded and ready flag written.");
                }
                catch (Exception ex)
                {
                    Log("Could not write ready flag: " + ex);
                }
            };
            window.Show();

            var pdfArgument = e.Args.FirstOrDefault(a =>
                a.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase) && File.Exists(a));
            if (pdfArgument is not null)
                _ = window.OpenPdfFromCommandLineAsync(pdfArgument);
        }
        catch (Exception ex)
        {
            Log("Fatal startup exception: " + ex);
            MessageBox.Show(
                "AsantePDF could not start. A diagnostic log was written to:\n\n" + StartupLogPath,
                "AsantePDF",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(-1);
        }
    }

    private async Task RunConversionSelfTestAsync(string samplePdf, string outputDirectory)
    {
        try
        {
            Log("Conversion self-test started.");
            await ConversionSelfTest.RunAsync(samplePdf, outputDirectory);
            Log("Conversion self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Conversion self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "conversion-selftest-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(2);
        }
    }

    private async Task RunFinishingSelfTestAsync(string samplePdf, string outputDirectory)
    {
        try
        {
            Log("Finishing self-test started.");
            await FinishingSelfTest.RunAsync(samplePdf, outputDirectory);
            Log("Finishing self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Finishing self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "finishing-selftest-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(3);
        }
    }

    private async Task RunMarkupSelfTestAsync(string samplePdf, string outputDirectory)
    {
        try
        {
            Log("Markup self-test started.");
            await MarkupSelfTest.RunAsync(samplePdf, outputDirectory);
            Log("Markup self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Markup self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "markup-selftest-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(4);
        }
    }

    private async Task RunFormsBatchSelfTestAsync(string samplePdf, string outputDirectory)
    {
        try
        {
            Log("Forms/batch self-test started.");
            await FormsBatchSelfTest.RunAsync(samplePdf, outputDirectory);
            Log("Forms/batch self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Forms/batch self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "forms-batch-selftest-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(5);
        }
    }

    private async Task RunFinalCandidateSelfTestAsync(string samplePdf, string outputDirectory)
    {
        try
        {
            Log("Final candidate self-test started.");
            await FinalCandidateSelfTest.RunAsync(samplePdf, outputDirectory);
            Log("Final candidate self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Final candidate self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "final-candidate-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(6);
        }
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        Log("Dispatcher exception: " + e.Exception);
        MessageBox.Show(
            "AsantePDF encountered an unexpected error. Details were written to:\n\n" + StartupLogPath,
            "AsantePDF",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }

    public static void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(LogDirectory);
            File.AppendAllText(StartupLogPath, $"[{DateTimeOffset.Now:O}] {message}{Environment.NewLine}");
        }
        catch { }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { }
    }
}
