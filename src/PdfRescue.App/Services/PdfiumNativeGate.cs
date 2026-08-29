using PDFiumCore;

namespace PdfRescue.App.Services;

/// <summary>
/// PDFium is a process-global native library and is not safe for concurrent calls from
/// independent AsantePDF subsystems. Every direct PDFium entry point must hold this gate.
/// This prevents preview, thumbnail, search, outline, text and annotation work from racing
/// one another while a document is opening or closing.
/// </summary>
public static class PdfiumNativeGate
{
    private static readonly SemaphoreSlim Gate = new(1, 1);
    private static readonly object InitializationSync = new();
    private static bool _initialized;

    public static void EnsureInitialized()
    {
        if (_initialized) return;
        lock (InitializationSync)
        {
            if (_initialized) return;
            fpdfview.FPDF_InitLibrary();
            _initialized = true;
        }
    }

    public static async Task WaitAsync(CancellationToken token)
    {
        EnsureInitialized();
        await Gate.WaitAsync(token).ConfigureAwait(false);
    }

    public static void Wait(CancellationToken token = default)
    {
        EnsureInitialized();
        Gate.Wait(token);
    }

    public static IDisposable Enter(CancellationToken token = default)
    {
        Wait(token);
        return new Releaser();
    }

    public static void Release() => Gate.Release();

    private sealed class Releaser : IDisposable
    {
        private bool _released;
        public void Dispose()
        {
            if (_released) return;
            _released = true;
            Release();
        }
    }
}