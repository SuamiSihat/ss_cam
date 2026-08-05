using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows;

internal static class Program
{
    private const string ProductName    = "SuamiSihat Creative Assets Management";
    private const string PayloadResource = "SuamiSihat.Payload.Zip";
    private const string AppFolderName  = "SuamiSihat";
    private const string AppExeName     = "SS-CAM.exe";

    [STAThread]
    private static int Main(string[] args)
    {
        bool smokeTest = Array.Exists(args, delegate(string a) {
            return string.Equals(a, "--smoke-test", StringComparison.OrdinalIgnoreCase);
        });

        bool forceInstall = Array.Exists(args, delegate(string a) {
            return string.Equals(a, "--install", StringComparison.OrdinalIgnoreCase) ||
                   string.Equals(a, "-InstallerMode", StringComparison.OrdinalIgnoreCase);
        });

        // Install directory: %LOCALAPPDATA%\SuamiSihat\SS-CAM
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string installDir   = Path.Combine(localAppData, AppFolderName, "SS-CAM", "app");
        string installedExe = Path.Combine(installDir, AppExeName);

        // ── Decide: first-time install or launch ──────────────────────────
        bool needsInstall = forceInstall || !File.Exists(installedExe);

        string temporaryRoot = null;

        if (needsInstall)
        {
            temporaryRoot = Path.Combine(
                Path.GetTempPath(),
                "SuamiSihatInstaller-" + Guid.NewGuid().ToString("N"));

            try
            {
                Directory.CreateDirectory(temporaryRoot);
                ExtractPayload(temporaryRoot);

                // First run: show the legacy PowerShell wizard for Brand Kit / font install
                string wizardPath = Path.Combine(temporaryRoot, "installer", "src", "Install-SuamiSihat-WPF.ps1");
                string appSrcDir  = Path.Combine(temporaryRoot, "installer", "app");

                // If the wizard exists, run it for setup (installs fonts, brand kit, shortcuts)
                if (File.Exists(wizardPath) && !smokeTest)
                {
                    string currentExePath = Process.GetCurrentProcess().MainModule.FileName;
                    string powershell = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.System),
                        "WindowsPowerShell", "v1.0", "powershell.exe");

                    ProcessStartInfo psInfo = new ProcessStartInfo
                    {
                        FileName = powershell,
                        Arguments =
                            "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " +
                            QuoteArg(wizardPath) +
                            " -InstallerMode" +
                            " -InstallerExePath " + QuoteArg(currentExePath),
                        WorkingDirectory = Path.GetDirectoryName(wizardPath),
                        UseShellExecute  = false,
                        CreateNoWindow   = true
                    };

                    using (Process ps = Process.Start(psInfo))
                    {
                        if (ps != null) ps.WaitForExit();
                    }
                }

                // Copy the new C# app to the permanent install location
                if (Directory.Exists(appSrcDir))
                {
                    if (!Directory.Exists(installDir))
                        Directory.CreateDirectory(installDir);

                    foreach (string srcFile in Directory.GetFiles(appSrcDir, "*", SearchOption.AllDirectories))
                    {
                        string relative = srcFile.Substring(appSrcDir.Length).TrimStart(Path.DirectorySeparatorChar);
                        string destFile = Path.Combine(installDir, relative);
                        string destDir  = Path.GetDirectoryName(destFile);
                        if (!Directory.Exists(destDir)) Directory.CreateDirectory(destDir);
                        File.Copy(srcFile, destFile, true);
                    }
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
                DeleteTempDir(temporaryRoot);
            }
        }

        // ── Launch the installed native C# app ───────────────────────────
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
            // Smoke test: just verify the exe exists and exits
            MessageBox.Show("Smoke test OK. SS-CAM.exe found at:\r\n" + installedExe,
                ProductName, MessageBoxButton.OK, MessageBoxImage.Information);
            return 0;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName         = installedExe,
                UseShellExecute  = true,
                WorkingDirectory = installDir
            });
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Could not launch SS-CAM.\r\n\r\n" + ex.Message,
                ProductName, MessageBoxButton.OK, MessageBoxImage.Error);
            return 1;
        }
    }

    private static void ExtractPayload(string destination)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream payload = assembly.GetManifestResourceStream(PayloadResource))
        {
            if (payload == null)
                throw new InvalidOperationException("The embedded payload is missing.");

            string archivePath = Path.Combine(destination, "payload.zip");
            using (FileStream archive = File.Create(archivePath))
                payload.CopyTo(archive);

            ZipFile.ExtractToDirectory(archivePath, destination);
            File.Delete(archivePath);
        }
    }

    private static string QuoteArg(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void DeleteTempDir(string path)
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
