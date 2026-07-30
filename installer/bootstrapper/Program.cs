using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    private const string ProductName = "SuamiSihat Creative Assets Management";
    private const string PayloadResource = "SuamiSihat.Payload.Zip";

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        string temporaryRoot = Path.Combine(
            Path.GetTempPath(),
            "SuamiSihatDesignerAssetsInstaller-" + Guid.NewGuid().ToString("N"));

        try
        {
            Directory.CreateDirectory(temporaryRoot);
            ExtractPayload(temporaryRoot);

            string wizardPath = Path.Combine(
                temporaryRoot,
                "installer",
                "src",
                "Install-SuamiSihat-GUI.ps1");

            if (!File.Exists(wizardPath))
            {
                throw new FileNotFoundException("The embedded setup wizard is missing.", wizardPath);
            }

            string systemDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System);
            string powershell = Path.Combine(
                systemDirectory,
                "WindowsPowerShell",
                "v1.0",
                "powershell.exe");

            bool smokeTest = Array.Exists(
                args,
                delegate(string argument)
                {
                    return string.Equals(argument, "--smoke-test", StringComparison.OrdinalIgnoreCase);
                });

            bool forceInstaller = Array.Exists(
                args,
                delegate(string argument)
                {
                    return string.Equals(argument, "--installer", StringComparison.OrdinalIgnoreCase) ||
                           string.Equals(argument, "-InstallerMode", StringComparison.OrdinalIgnoreCase);
                });

            string installedExe = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "SuamiSihat",
                "SuamiSihat Creative Assets Management",
                "SS-CAM.exe");

            string currentExePath = Process.GetCurrentProcess().MainModule.FileName;
            string installedExeDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "SuamiSihat");

            bool isInstalledLocation = !string.IsNullOrEmpty(currentExePath) &&
                currentExePath.StartsWith(installedExeDir, StringComparison.OrdinalIgnoreCase);

            bool isInstalled = File.Exists(installedExe);
            bool isFirstRun = forceInstaller || !isInstalledLocation || !isInstalled;

            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = powershell,
                Arguments =
                    "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " +
                    QuoteArgument(wizardPath) +
                    (isFirstRun ? " -InstallerMode" : string.Empty) +
                    " -InstallerExePath " + QuoteArgument(currentExePath) +
                    (smokeTest ? " -SmokeTest" : string.Empty),
                WorkingDirectory = Path.GetDirectoryName(wizardPath),
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (Process wizard = Process.Start(startInfo))
            {
                if (wizard == null)
                {
                    throw new InvalidOperationException("Windows could not start the setup wizard.");
                }

                wizard.WaitForExit();
                return wizard.ExitCode;
            }
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                "The installer could not start.\r\n\r\n" + exception.Message,
                ProductName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            DeleteTemporaryDirectory(temporaryRoot);
        }
    }

    private static void ExtractPayload(string destination)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream payload = assembly.GetManifestResourceStream(PayloadResource))
        {
            if (payload == null)
            {
                throw new InvalidOperationException("The embedded designer-assets payload is missing.");
            }

            string archivePath = Path.Combine(destination, "payload.zip");
            using (FileStream archive = File.Create(archivePath))
            {
                payload.CopyTo(archive);
            }

            ZipFile.ExtractToDirectory(archivePath, destination);
            File.Delete(archivePath);
        }
    }

    private static string QuoteArgument(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void DeleteTemporaryDirectory(string path)
    {
        for (int attempt = 0; attempt < 4; attempt++)
        {
            try
            {
                if (Directory.Exists(path))
                {
                    Directory.Delete(path, true);
                }
                return;
            }
            catch
            {
                Thread.Sleep(300);
            }
        }
    }
}
