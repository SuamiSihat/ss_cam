using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows;

internal static class Program
{
    private const string ProductName     = "SuamiSihat Creative Assets Management";
    private const string PayloadResource = "SuamiSihat.Payload.Zip";
    private const string AppExeName      = "SS-CAM.exe";

    // Permanent install location for the native C# app
    private static readonly string InstallDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SuamiSihat", "SS-CAM", "app");

    [STAThread]
    private static int Main(string[] args)
    {
        bool smokeTest = HasArg(args, "--smoke-test");
        bool forceReinstall = HasArg(args, "--reinstall");

        string installedExe = Path.Combine(InstallDir, AppExeName);
        bool needsDeploy = forceReinstall || !File.Exists(installedExe);

        if (needsDeploy)
        {
            string tempDir = Path.Combine(Path.GetTempPath(),
                "SS-CAM-Setup-" + Guid.NewGuid().ToString("N"));

            try
            {
                // 1. Extract the payload ZIP
                Directory.CreateDirectory(tempDir);
                ExtractPayload(tempDir);

                // 2. Copy the compiled C# app from payload → install directory
                string appSrcDir = Path.Combine(tempDir, "installer", "app");
                if (!Directory.Exists(appSrcDir))
                {
                    MessageBox.Show(
                        "The v2.0 application bundle was not found in the installer payload.\n\n" +
                        "Expected: installer\\app\\\n\n" +
                        "Please re-download the installer.",
                        ProductName, MessageBoxButton.OK, MessageBoxImage.Error);
                    return 1;
                }

                if (!Directory.Exists(InstallDir))
                    Directory.CreateDirectory(InstallDir);

                foreach (string src in Directory.GetFiles(appSrcDir, "*", SearchOption.AllDirectories))
                {
                    string rel  = src.Substring(appSrcDir.Length).TrimStart(
                        Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                    string dest = Path.Combine(InstallDir, rel);
                    string dir  = Path.GetDirectoryName(dest);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                        Directory.CreateDirectory(dir);
                    File.Copy(src, dest, overwrite: true);
                }

                // 3. Copy brand kit payload alongside app (fonts, brand assets)
                string payloadSrc = Path.Combine(tempDir, "payload");
                if (Directory.Exists(payloadSrc))
                {
                    string payloadDest = Path.Combine(InstallDir, "payload");
                    CopyDir(payloadSrc, payloadDest);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Installation failed.\r\n\r\n" + ex.Message,
                    ProductName, MessageBoxButton.OK, MessageBoxImage.Error);
                return 1;
            }
            finally
            {
                DeleteDir(tempDir);
            }
        }

        // 4. Verify the exe exists
        if (!File.Exists(installedExe))
        {
            MessageBox.Show(
                "SS-CAM could not be found at:\r\n" + installedExe +
                "\r\n\r\nRun the installer again to repair the installation.",
                ProductName, MessageBoxButton.OK, MessageBoxImage.Error);
            return 1;
        }

        if (smokeTest)
        {
            MessageBox.Show("Smoke test OK.\r\nSS-CAM.exe: " + installedExe,
                ProductName, MessageBoxButton.OK, MessageBoxImage.Information);
            return 0;
        }

        // 5. Launch the native C# app
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName         = installedExe,
                UseShellExecute  = true,
                WorkingDirectory = InstallDir
            });
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show("Could not launch SS-CAM.\r\n\r\n" + ex.Message,
                ProductName, MessageBoxButton.OK, MessageBoxImage.Error);
            return 1;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static bool HasArg(string[] args, string flag)
    {
        return Array.Exists(args, delegate(string a) {
            return string.Equals(a, flag, StringComparison.OrdinalIgnoreCase);
        });
    }

    private static void ExtractPayload(string destination)
    {
        Assembly asm = Assembly.GetExecutingAssembly();
        using (Stream stream = asm.GetManifestResourceStream(PayloadResource))
        {
            if (stream == null)
                throw new InvalidOperationException("The embedded payload resource is missing.");
            string zip = Path.Combine(destination, "payload.zip");
            using (FileStream fs = File.Create(zip))
                stream.CopyTo(fs);
            ZipFile.ExtractToDirectory(zip, destination);
            File.Delete(zip);
        }
    }

    private static void CopyDir(string src, string dest)
    {
        if (!Directory.Exists(dest)) Directory.CreateDirectory(dest);
        foreach (string file in Directory.GetFiles(src, "*", SearchOption.AllDirectories))
        {
            string rel      = file.Substring(src.Length).TrimStart(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string destFile = Path.Combine(dest, rel);
            string destDir  = Path.GetDirectoryName(destFile);
            if (!string.IsNullOrEmpty(destDir) && !Directory.Exists(destDir))
                Directory.CreateDirectory(destDir);
            File.Copy(file, destFile, overwrite: true);
        }
    }

    private static void DeleteDir(string path)
    {
        for (int i = 0; i < 4; i++)
        {
            try
            {
                if (Directory.Exists(path)) Directory.Delete(path, true);
                return;
            }
            catch { Thread.Sleep(300); }
        }
    }
}
