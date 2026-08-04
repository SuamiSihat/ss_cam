[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [switch]$InstallerMode,
    [string]$InstallerExePath = "",
    [string]$PreviewPath = "",
    [ValidateSet("Setup", "Dashboard", "Projects", "Search", "BrandAssets", "Profile", "Creator", "Settings")]
    [string]$PreviewView = "Dashboard"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$script:AppVersion = "1.9.9"
$script:installationRunning = $false
$script:installerProcess = $null
$script:standardOutputTask = $null
$script:standardErrorTask = $null
$script:expressInstall = $false
$script:uninstallReportMode = $false
$script:readmePreviewMode = $true

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

. (Join-Path $PSScriptRoot "Installer.Common.ps1")

if (-not ("SuamiSihat.Wpf.AppViewModel" -as [type])) {
    Add-Type -ReferencedAssemblies @("WindowsBase", "System") -TypeDefinition @'
using System;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace SuamiSihat.Wpf
{
    public sealed class AppViewModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;
        private void Set<T>(ref T field, T value, string name)
        {
            if (Equals(field, value)) return;
            field = value;
            PropertyChangedEventHandler handler = PropertyChanged;
            if (handler != null) handler(this, new PropertyChangedEventArgs(name));
        }

        private string workspace, jobId, projectName, projectDescription, selectedPreset,
            selectedBrand, selectedYear, selectedPlatform, selectedTemplateExtension,
            previewPath, folderStructure, statusText, nasStatus, staffId, designerName,
            department, email, avatarPath, settingsStatus, installStatus, installLog,
            versionStatus, destination, dashboardTotal, dashboardLatest, dashboardFileSize,
            dashboardTypeSummary, dashboardBrandSummary, dashboardStatus, searchRoot,
            searchQuery, searchDestination, searchStatus, headerContext, installerVersionStatus,
            cpmInstallPath, licenseText, licenseReadStatus, installReport, dashboardThisMonth,
            dashboardDesignerCount, dashboardFileCount, customTemplateExtension,
            selectedDesignerFolderId, designerFolderStatus, projectReadmeContent, selectedProjectPath,
            brandAssetsPath, brandAssetsStatus;
        private bool injectMasterCanvas, includeRevisions, includeRawMedia, hasRecent,
            isInstalling, installBrandKit = true, installProjectManager = true,
            acceptLicence, copyAssets = true, createWebShortcuts = true, isSearching;

        public string Workspace { get { return workspace; } set { Set(ref workspace, value, "Workspace"); } }
        public string JobId { get { return jobId; } set { Set(ref jobId, value, "JobId"); } }
        public string ProjectName { get { return projectName; } set { Set(ref projectName, value, "ProjectName"); } }
        public string ProjectDescription { get { return projectDescription; } set { Set(ref projectDescription, value, "ProjectDescription"); } }
        public string SelectedPreset { get { return selectedPreset; } set { Set(ref selectedPreset, value, "SelectedPreset"); } }
        public string SelectedBrand { get { return selectedBrand; } set { Set(ref selectedBrand, value, "SelectedBrand"); } }
        public string SelectedYear { get { return selectedYear; } set { Set(ref selectedYear, value, "SelectedYear"); } }
        public string SelectedPlatform { get { return selectedPlatform; } set { Set(ref selectedPlatform, value, "SelectedPlatform"); } }
        public string SelectedTemplateExtension { get { return selectedTemplateExtension; } set { Set(ref selectedTemplateExtension, value, "SelectedTemplateExtension"); } }
        public bool InjectMasterCanvas { get { return injectMasterCanvas; } set { Set(ref injectMasterCanvas, value, "InjectMasterCanvas"); } }
        public bool IncludeRevisions { get { return includeRevisions; } set { Set(ref includeRevisions, value, "IncludeRevisions"); } }
        public bool IncludeRawMedia { get { return includeRawMedia; } set { Set(ref includeRawMedia, value, "IncludeRawMedia"); } }
        public string PreviewPath { get { return previewPath; } set { Set(ref previewPath, value, "PreviewPath"); } }
        public string FolderStructure { get { return folderStructure; } set { Set(ref folderStructure, value, "FolderStructure"); } }
        public string StatusText { get { return statusText; } set { Set(ref statusText, value, "StatusText"); } }
        public string NasStatus { get { return nasStatus; } set { Set(ref nasStatus, value, "NasStatus"); } }
        public bool HasRecent { get { return hasRecent; } set { Set(ref hasRecent, value, "HasRecent"); } }
        public string StaffId { get { return staffId; } set { Set(ref staffId, value, "StaffId"); } }
        public string DesignerName { get { return designerName; } set { Set(ref designerName, value, "DesignerName"); } }
        public string Department { get { return department; } set { Set(ref department, value, "Department"); var h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs("DepartmentDisplay")); } }
        public string DepartmentDisplay { get { return string.IsNullOrWhiteSpace(department) ? "User Profile" : department; } }
        public string Email { get { return email; } set { Set(ref email, value, "Email"); } }
        public string AvatarPath { get { return avatarPath; } set { Set(ref avatarPath, value, "AvatarPath"); } }
        public string SettingsStatus { get { return settingsStatus; } set { Set(ref settingsStatus, value, "SettingsStatus"); } }
        public string InstallStatus { get { return installStatus; } set { Set(ref installStatus, value, "InstallStatus"); } }
        public string InstallLog { get { return installLog; } set { Set(ref installLog, value, "InstallLog"); } }
        public string VersionStatus { get { return versionStatus; } set { Set(ref versionStatus, value, "VersionStatus"); } }
        public bool IsInstalling { get { return isInstalling; } set { Set(ref isInstalling, value, "IsInstalling"); } }
        public bool InstallBrandKit { get { return installBrandKit; } set { Set(ref installBrandKit, value, "InstallBrandKit"); } }
        public bool InstallProjectManager { get { return installProjectManager; } set { Set(ref installProjectManager, value, "InstallProjectManager"); } }
        public bool AcceptLicence { get { return acceptLicence; } set { Set(ref acceptLicence, value, "AcceptLicence"); } }
        public bool CopyAssets { get { return copyAssets; } set { Set(ref copyAssets, value, "CopyAssets"); } }
        public bool CreateWebShortcuts { get { return createWebShortcuts; } set { Set(ref createWebShortcuts, value, "CreateWebShortcuts"); } }
        public string Destination { get { return destination; } set { Set(ref destination, value, "Destination"); } }
        public string DashboardTotal { get { return dashboardTotal; } set { Set(ref dashboardTotal, value, "DashboardTotal"); } }
        public string DashboardLatest { get { return dashboardLatest; } set { Set(ref dashboardLatest, value, "DashboardLatest"); } }
        public string DashboardFileSize { get { return dashboardFileSize; } set { Set(ref dashboardFileSize, value, "DashboardFileSize"); } }
        public string DashboardTypeSummary { get { return dashboardTypeSummary; } set { Set(ref dashboardTypeSummary, value, "DashboardTypeSummary"); } }
        public string DashboardBrandSummary { get { return dashboardBrandSummary; } set { Set(ref dashboardBrandSummary, value, "DashboardBrandSummary"); } }
        public string DashboardStatus { get { return dashboardStatus; } set { Set(ref dashboardStatus, value, "DashboardStatus"); } }
        public string DashboardThisMonth { get { return dashboardThisMonth; } set { Set(ref dashboardThisMonth, value, "DashboardThisMonth"); } }
        public string DashboardDesignerCount { get { return dashboardDesignerCount; } set { Set(ref dashboardDesignerCount, value, "DashboardDesignerCount"); } }
        public string DashboardFileCount { get { return dashboardFileCount; } set { Set(ref dashboardFileCount, value, "DashboardFileCount"); } }
        public string CustomTemplateExtension { get { return customTemplateExtension; } set { Set(ref customTemplateExtension, value, "CustomTemplateExtension"); } }
        public string SearchRoot { get { return searchRoot; } set { Set(ref searchRoot, value, "SearchRoot"); } }
        public string SearchQuery { get { return searchQuery; } set { Set(ref searchQuery, value, "SearchQuery"); } }
        public string SearchDestination { get { return searchDestination; } set { Set(ref searchDestination, value, "SearchDestination"); } }
        public string SearchStatus { get { return searchStatus; } set { Set(ref searchStatus, value, "SearchStatus"); } }
        public bool IsSearching { get { return isSearching; } set { Set(ref isSearching, value, "IsSearching"); } }
        public string HeaderContext { get { return headerContext; } set { Set(ref headerContext, value, "HeaderContext"); } }
        public string InstallerVersionStatus { get { return installerVersionStatus; } set { Set(ref installerVersionStatus, value, "InstallerVersionStatus"); } }
        public string CpmInstallPath { get { return cpmInstallPath; } set { Set(ref cpmInstallPath, value, "CpmInstallPath"); } }
        public string LicenseText { get { return licenseText; } set { Set(ref licenseText, value, "LicenseText"); } }
        public string LicenseReadStatus { get { return licenseReadStatus; } set { Set(ref licenseReadStatus, value, "LicenseReadStatus"); } }
        public string InstallReport { get { return installReport; } set { Set(ref installReport, value, "InstallReport"); } }
        public string SelectedDesignerFolderId { get { return selectedDesignerFolderId; } set { Set(ref selectedDesignerFolderId, value, "SelectedDesignerFolderId"); } }
        public string DesignerFolderStatus { get { return designerFolderStatus; } set { Set(ref designerFolderStatus, value, "DesignerFolderStatus"); } }
        public string ProjectReadmeContent { get { return projectReadmeContent; } set { Set(ref projectReadmeContent, value, "ProjectReadmeContent"); } }
        public string SelectedProjectPath { get { return selectedProjectPath; } set { Set(ref selectedProjectPath, value, "SelectedProjectPath"); } }
        public string BrandAssetsPath { get { return brandAssetsPath; } set { Set(ref brandAssetsPath, value, "BrandAssetsPath"); } }
        public string BrandAssetsStatus { get { return brandAssetsStatus; } set { Set(ref brandAssetsStatus, value, "BrandAssetsStatus"); } }

        public ObservableCollection<string> Presets { get; private set; }
        public ObservableCollection<string> Brands { get; private set; }
        public ObservableCollection<string> Years { get; private set; }
        public ObservableCollection<string> Platforms { get; private set; }
        public ObservableCollection<string> TemplateExtensions { get; private set; }
        public ObservableCollection<string> RecentProjects { get; private set; }
        public ObservableCollection<string> DesignerProfiles { get; private set; }
        public ObservableCollection<FileSearchItem> SearchResults { get; private set; }
        public ObservableCollection<DashboardChartItem> DashboardTypeChart { get; private set; }
        public ObservableCollection<DashboardChartItem> DashboardBrandChart { get; private set; }
        public ObservableCollection<DashboardChartItem> DashboardActivityChart { get; private set; }
        public ObservableCollection<DesignerFolderChoice> DesignerFolderChoices { get; private set; }
        public ObservableCollection<DesignerFolderItem> DesignerFolders { get; private set; }

        public AppViewModel()
        {
            Presets = new ObservableCollection<string>();
            Brands = new ObservableCollection<string>();
            Years = new ObservableCollection<string>();
            Platforms = new ObservableCollection<string>();
            TemplateExtensions = new ObservableCollection<string>();
            RecentProjects = new ObservableCollection<string>();
            DesignerProfiles = new ObservableCollection<string>();
            SearchResults = new ObservableCollection<FileSearchItem>();
            DashboardTypeChart = new ObservableCollection<DashboardChartItem>();
            DashboardBrandChart = new ObservableCollection<DashboardChartItem>();
            DashboardActivityChart = new ObservableCollection<DashboardChartItem>();
            DesignerFolderChoices = new ObservableCollection<DesignerFolderChoice>();
            DesignerFolders = new ObservableCollection<DesignerFolderItem>();
        }
    }

    public sealed class DashboardChartItem
    {
        public string Label { get; set; }
        public int Count { get; set; }
        public double BarWidth { get; set; }
        public double BarHeight { get; set; }
        public string Percent { get; set; }
        public string Color { get; set; }
    }

    public sealed class DesignerFolderChoice
    {
        public string Name { get; set; }
        public string StaffId { get; set; }
        public string Display { get { return String.IsNullOrWhiteSpace(StaffId) ? Name : Name + " (" + StaffId + ")"; } }
    }

    public sealed class DesignerFolderItem
    {
        public string Designer { get; set; }
        public string Project { get; set; }
        public string FullPath { get; set; }
        public string Modified { get; set; }
        public long ModifiedTicks { get; set; }
    }

    public sealed class FileSearchItem
    {
        public string Name { get; set; }
        public string FullPath { get; set; }
        public string Folder { get; set; }
        public string Size { get; set; }
        public string Modified { get; set; }
    }

    public sealed class DashboardSnapshot
    {
        public int TotalProjects { get; set; }
        public string LatestProject { get; set; }
        public long TotalBytes { get; set; }
        public string ProjectTypes { get; set; }
        public string SubBrands { get; set; }
        public int ThisMonth { get; set; }
        public int DesignerCount { get; set; }
        public long TotalFiles { get; set; }
        public List<DashboardChartItem> TypeChart { get; set; }
        public List<DashboardChartItem> BrandChart { get; set; }
        public List<DashboardChartItem> ActivityChart { get; set; }
    }

    public static class WorkspaceScanner
    {
        private static readonly Regex ProjectPattern = new Regex(
            @"^\d{6}_((?:[A-Z-]+\d+)|(?:\d+[A-Z-]+))_([A-Z]{2,8})_.+", RegexOptions.IgnoreCase | RegexOptions.Compiled);

        public static Task<DashboardSnapshot> ScanAsync(string root)
        {
            return Task.Factory.StartNew(delegate { return Scan(root); });
        }

        public static DashboardSnapshot Scan(string root)
        {
            DashboardSnapshot result = new DashboardSnapshot();
            result.LatestProject = "No projects found";
            Dictionary<string, int> types = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            Dictionary<string, int> brands = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            Dictionary<string, int> activity = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            HashSet<string> designers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            DateTime now = DateTime.Now;
            for (int offset = 5; offset >= 0; offset--)
            {
                DateTime month = new DateTime(now.Year, now.Month, 1).AddMonths(-offset);
                activity[month.ToString("yyyyMM")] = 0;
            }
            DateTime latest = DateTime.MinValue;
            Queue<string> pending = new Queue<string>();
            if (Directory.Exists(root)) pending.Enqueue(root);

            while (pending.Count > 0)
            {
                string current = pending.Dequeue();
                string[] directories;
                try { directories = Directory.GetDirectories(current); }
                catch { continue; }

                foreach (string directory in directories)
                {
                    string name = Path.GetFileName(directory);
                    Match match = ProjectPattern.Match(name);
                    if (!match.Success)
                    {
                        pending.Enqueue(directory);
                        continue;
                    }

                    result.TotalProjects++;
                    string job = match.Groups[1].Value.ToUpperInvariant();
                    string brand = match.Groups[2].Value.ToUpperInvariant();
                    string jobCode = GetJobCode(job);
                    string type = jobCode.StartsWith("S") ? "Social Media" :
                        jobCode.StartsWith("V") ? "Video" :
                        jobCode.StartsWith("P") ? "Brand Identity" : "Graphic / Print";
                    AddCount(types, type);
                    AddCount(brands, brand);
                    string monthKey = name.Length >= 6 ? name.Substring(0, 6) : "";
                    if (activity.ContainsKey(monthKey)) activity[monthKey]++;
                    if (monthKey == now.ToString("yyyyMM")) result.ThisMonth++;

                    try
                    {
                        string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
                        string fullDirectory = Path.GetFullPath(directory);
                        if (fullDirectory.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
                        {
                            string[] parts = fullDirectory.Substring(fullRoot.Length).Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                            if (parts.Length >= 4 && !Regex.IsMatch(parts[0], @"^\d{4}$")) designers.Add(parts[0]);
                        }
                    }
                    catch { }

                    DateTime modified;
                    try { modified = Directory.GetLastWriteTime(directory); }
                    catch { modified = DateTime.MinValue; }
                    if (modified > latest)
                    {
                        latest = modified;
                        result.LatestProject = name + "\n" + modified.ToString("dd MMM yyyy, HH:mm");
                    }
                    long fileCount;
                    result.TotalBytes += GetDirectoryBytes(directory, out fileCount);
                    result.TotalFiles += fileCount;
                }
            }

            result.ProjectTypes = FormatCounts(types);
            result.SubBrands = FormatCounts(brands);
            result.DesignerCount = designers.Count;
            result.TypeChart = BuildChart(types, false);
            result.BrandChart = BuildChart(brands, false);
            result.ActivityChart = BuildActivityChart(activity);
            return result;
        }

        public static Task<List<DesignerFolderItem>> ListDesignerFoldersAsync(string root, string staffId, int limit)
        {
            return ListDesignerFoldersAsync(root, staffId, "", limit);
        }

        public static Task<List<DesignerFolderItem>> ListDesignerFoldersAsync(string root, string staffId, string query, int limit)
        {
            return Task.Factory.StartNew(delegate { return ListDesignerFolders(root, staffId, query, limit); });
        }

        public static List<DesignerFolderItem> ListDesignerFolders(string root, string staffId, int limit)
        {
            return ListDesignerFolders(root, staffId, "", limit);
        }

        public static List<DesignerFolderItem> ListDesignerFolders(string root, string staffId, string query, int limit)
        {
            List<DesignerFolderItem> results = new List<DesignerFolderItem>();
            if (!Directory.Exists(root)) return results;
            string scanRoot = root;
            if (!String.IsNullOrWhiteSpace(staffId))
            {
                string candidate = Path.Combine(root, staffId);
                if (!Directory.Exists(candidate)) return results;
                scanRoot = candidate;
            }
            Queue<string> pending = new Queue<string>();
            pending.Enqueue(scanRoot);
            while (pending.Count > 0 && results.Count < limit)
            {
                string current = pending.Dequeue();
                string[] directories;
                try { directories = Directory.GetDirectories(current); }
                catch { continue; }
                foreach (string directory in directories)
                {
                    string name = Path.GetFileName(directory);
                    if (ProjectPattern.IsMatch(name))
                    {
                        if (!String.IsNullOrWhiteSpace(query) && name.IndexOf(query, StringComparison.OrdinalIgnoreCase) < 0) continue;
                        string designer = String.IsNullOrWhiteSpace(staffId) ? GetFirstRelativePart(root, directory) : staffId;
                        DateTime modified;
                        try { modified = Directory.GetLastWriteTime(directory); } catch { modified = DateTime.MinValue; }
                        results.Add(new DesignerFolderItem {
                            Designer = designer, Project = name, FullPath = directory,
                            Modified = modified.ToString("dd MMM yyyy HH:mm"), ModifiedTicks = modified.Ticks
                        });
                        if (results.Count >= limit) break;
                    }
                    else pending.Enqueue(directory);
                }
            }
            results.Sort(delegate(DesignerFolderItem left, DesignerFolderItem right) {
                return right.ModifiedTicks.CompareTo(left.ModifiedTicks);
            });
            return results;
        }

        public static Task<List<FileSearchItem>> ListProjectFilesAsync(string root, int limit)
        {
            return Task.Factory.StartNew(delegate { return ListProjectFiles(root, limit); });
        }

        public static List<FileSearchItem> ListProjectFiles(string root, int limit)
        {
            List<FileSearchItem> results = new List<FileSearchItem>();
            Queue<string> pending = new Queue<string>();
            if (!Directory.Exists(root)) return results;
            pending.Enqueue(root);
            while (pending.Count > 0 && results.Count < limit)
            {
                string current = pending.Dequeue();
                try
                {
                    foreach (string directory in Directory.GetDirectories(current)) pending.Enqueue(directory);
                    foreach (string file in Directory.GetFiles(current))
                    {
                        if (results.Count >= limit) break;
                        try
                        {
                            FileInfo info = new FileInfo(file);
                            string relativeFolder = ".";
                            if (info.DirectoryName.Length > root.Length)
                                relativeFolder = info.DirectoryName.Substring(root.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                            results.Add(new FileSearchItem {
                                Name = info.Name, FullPath = info.FullName, Folder = relativeFolder,
                                Size = FormatBytes(info.Length), Modified = info.LastWriteTime.ToString("dd MMM yyyy HH:mm")
                            });
                        }
                        catch { }
                    }
                }
                catch { }
            }
            return results;
        }

        public static string FormatBytes(long bytes)
        {
            double value = bytes;
            string[] units = new string[] { "B", "KB", "MB", "GB", "TB" };
            int unit = 0;
            while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
            return value.ToString(unit == 0 ? "0" : "0.0") + " " + units[unit];
        }

        private static long GetDirectoryBytes(string root, out long fileCount)
        {
            long total = 0;
            fileCount = 0;
            Queue<string> pending = new Queue<string>();
            pending.Enqueue(root);
            while (pending.Count > 0)
            {
                string current = pending.Dequeue();
                try
                {
                    foreach (string file in Directory.GetFiles(current))
                    {
                        try { total += new FileInfo(file).Length; fileCount++; } catch { }
                    }
                    foreach (string directory in Directory.GetDirectories(current)) pending.Enqueue(directory);
                }
                catch { }
            }
            return total;
        }

        private static string GetFirstRelativePart(string root, string path)
        {
            try
            {
                string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
                string fullPath = Path.GetFullPath(path);
                if (fullPath.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
                {
                    string[] parts = fullPath.Substring(fullRoot.Length).Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                    if (parts.Length > 0) return parts[0];
                }
            }
            catch { }
            return "Shared";
        }

        private static List<DashboardChartItem> BuildChart(Dictionary<string, int> values, bool vertical)
        {
            List<DashboardChartItem> items = new List<DashboardChartItem>();
            int maximum = 1;
            int total = 0;
            foreach (int value in values.Values) { if (value > maximum) maximum = value; total += value; }
            string[] colors = new string[] { "#21A1F7", "#043388", "#14B8A6", "#F59E0B", "#8B5CF6", "#EC4899" };
            int colorIndex = 0;
            foreach (KeyValuePair<string, int> item in values)
            {
                items.Add(new DashboardChartItem {
                    Label = item.Key, Count = item.Value,
                    BarWidth = Math.Max(8, 95.0 * item.Value / maximum),
                    BarHeight = Math.Max(8, 100.0 * item.Value / maximum),
                    Percent = total == 0 ? "0%" : Math.Round(100.0 * item.Value / total).ToString("0") + "%",
                    Color = colors[colorIndex++ % colors.Length]
                });
            }
            items.Sort(delegate(DashboardChartItem left, DashboardChartItem right) { return right.Count.CompareTo(left.Count); });
            return items;
        }

        private static List<DashboardChartItem> BuildActivityChart(Dictionary<string, int> activity)
        {
            int maximum = 1;
            foreach (int value in activity.Values) if (value > maximum) maximum = value;
            List<DashboardChartItem> items = new List<DashboardChartItem>();
            List<string> keys = new List<string>(activity.Keys);
            keys.Sort(StringComparer.OrdinalIgnoreCase);
            foreach (string key in keys)
            {
                DateTime month;
                string label = DateTime.TryParseExact(key, "yyyyMM", null, System.Globalization.DateTimeStyles.None, out month) ? month.ToString("MMM") : key;
                items.Add(new DashboardChartItem {
                    Label = label, Count = activity[key], BarWidth = 24,
                    BarHeight = Math.Max(5, 105.0 * activity[key] / maximum), Percent = "", Color = "#21A1F7"
                });
            }
            return items;
        }

        private static void AddCount(Dictionary<string, int> values, string key)
        {
            int count;
            values.TryGetValue(key, out count);
            values[key] = count + 1;
        }

        private static string GetJobCode(string job)
        {
            Match oldFormat = Regex.Match(job, @"^([A-Z-]+)\d+$", RegexOptions.IgnoreCase);
            if (oldFormat.Success) return oldFormat.Groups[1].Value.ToUpperInvariant();
            Match newFormat = Regex.Match(job, @"^\d+([A-Z-]+)$", RegexOptions.IgnoreCase);
            return newFormat.Success ? newFormat.Groups[1].Value.ToUpperInvariant() : job.ToUpperInvariant();
        }

        private static string FormatCounts(Dictionary<string, int> values)
        {
            if (values.Count == 0) return "No project data yet";
            List<string> lines = new List<string>();
            foreach (KeyValuePair<string, int> item in values) lines.Add(item.Key + ": " + item.Value);
            lines.Sort(StringComparer.OrdinalIgnoreCase);
            return String.Join("\n", lines.ToArray());
        }
    }
}
'@
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainWindow"
        Title="SuamiSihat Creative Assets Management"
        Width="1060" Height="820" MinWidth="820" MinHeight="660"
        WindowStartupLocation="CenterScreen" Background="#F4F7FB"
        FontFamily="Segoe UI" FontSize="13" UseLayoutRounding="True"
        SnapsToDevicePixels="True">
  <Window.Resources>
    <BooleanToVisibilityConverter x:Key="BoolToVisibility"/>
    <SolidColorBrush x:Key="BrandNavy" Color="#043388"/>
    <SolidColorBrush x:Key="BrandBlue" Color="#21A1F7"/>
    <SolidColorBrush x:Key="BrandInk" Color="#1E293B"/>
    <SolidColorBrush x:Key="BrandMuted" Color="#64748B"/>
    <SolidColorBrush x:Key="BrandBorder" Color="#CBD5E1"/>
    <SolidColorBrush x:Key="BrandSurface" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="BrandSoft" Color="#EFF6FF"/>
    <SolidColorBrush x:Key="BrandSuccess" Color="#14874B"/>
    <SolidColorBrush x:Key="BrandDanger" Color="#DC2626"/>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource BrandInk}"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style x:Key="PageTitle" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource BrandNavy}"/>
      <Setter Property="FontSize" Value="25"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
    </Style>
    <Style x:Key="SectionTitle" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource BrandNavy}"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
    <Style TargetType="Button">
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Padding" Value="16,7"/>
      <Setter Property="Margin" Value="4"/>
      <Setter Property="Background" Value="{StaticResource BrandNavy}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#E2E8F0"/>
      <Setter Property="Foreground" Value="{StaticResource BrandInk}"/>
    </Style>
    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{StaticResource BrandDanger}"/>
    </Style>
    <Style x:Key="ModuleButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Height" Value="76"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource BrandInk}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="Margin" Value="8,2"/>
      <Setter Property="Padding" Value="16,10"/>
    </Style>
    <Style x:Key="AssetCardButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="MinHeight" Value="132"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="VerticalContentAlignment" Value="Top"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="{StaticResource BrandInk}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="18"/>
    </Style>
    <Style x:Key="LinkButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource BrandBlue}"/>
      <Setter Property="Padding" Value="4,5"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="TextBlock.TextDecorations" Value="Underline"/>
    </Style>
    <Style x:Key="MetricCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource BrandSurface}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="6"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="5"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="MinHeight" Value="34"/>
      <Setter Property="Padding" Value="9,6"/>
      <Setter Property="Margin" Value="0,4,8,8"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="MinHeight" Value="34"/>
      <Setter Property="Padding" Value="7,4"/>
      <Setter Property="Margin" Value="0,4,8,8"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Margin" Value="0,5,18,5"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style TargetType="GroupBox">
      <Setter Property="Margin" Value="0,0,0,14"/>
      <Setter Property="Padding" Value="14"/>
      <Setter Property="Background" Value="{StaticResource BrandSurface}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BrandBorder}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="HiddenTabs" TargetType="TabControl">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <ContentPresenter ContentSource="SelectedContent"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <DockPanel LastChildFill="True">
    <Border DockPanel.Dock="Top" Background="#022057" Padding="24,16" ClipToBounds="True">
      <Grid>
        <Canvas x:Name="HeaderCanvas" IsHitTestVisible="False"/>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border x:Name="ToggleSidebarButton" Background="Transparent" Margin="0,0,16,0" Cursor="Hand">
            <Path Data="M0,0 L18,0 L18,2 L0,2 Z M0,6 L18,6 L18,8 L0,8 Z M0,12 L18,12 L18,14 L0,14 Z" Fill="#BFE4FF" Stretch="Uniform" Width="22" Height="14" VerticalAlignment="Center"/>
          </Border>
          <Image x:Name="HeaderLogo" Width="260" Height="50" Stretch="Uniform" HorizontalAlignment="Left" Margin="0,0,18,0"/>
          <StackPanel>
            <TextBlock Text="{Binding HeaderContext}" Foreground="#BFE4FF" FontSize="13"/>
          </StackPanel>
        </StackPanel>
      </Grid>
    </Border>

    <StatusBar x:Name="AppStatusBar" DockPanel.Dock="Bottom" Background="#E8EEF6" Padding="12,5">
      <StatusBarItem><TextBlock Text="{Binding NasStatus}" Foreground="{StaticResource BrandMuted}"/></StatusBarItem>
      <Separator/>
      <StatusBarItem><TextBlock Text="{Binding VersionStatus}" Foreground="{StaticResource BrandMuted}"/></StatusBarItem>
    </StatusBar>

    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition x:Name="SidebarColumn" Width="235"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="Sidebar" Grid.Column="0" Background="White" BorderBrush="{StaticResource BrandBorder}" BorderThickness="0,0,1,0">
        <DockPanel LastChildFill="True">
          <Button x:Name="NavProfile" DockPanel.Dock="Bottom" Style="{StaticResource ModuleButton}">
            <StackPanel Orientation="Horizontal">
              <Border x:Name="AvatarBorder" Width="42" Height="42" CornerRadius="21" Background="{StaticResource BrandSoft}" Margin="0,0,12,0" ClipToBounds="True" Cursor="Hand">
                <Grid>
                  <Path x:Name="AvatarPlaceholder" Data="M12,12 A5,5 0 1 1 22,12 A5,5 0 1 1 12,12 M7,27 C7,21 11,18 17,18 C23,18 27,21 27,27 Z" Fill="{StaticResource BrandNavy}" Stretch="Uniform" Margin="8"/>
                  <Border x:Name="SidebarAvatarImage" CornerRadius="21" Visibility="Collapsed"/>
                </Grid>
              </Border>
              <StackPanel VerticalAlignment="Center">
                <TextBlock Text="{Binding DesignerName}" FontWeight="SemiBold"/>
                <TextBlock Text="{Binding DepartmentDisplay}" Foreground="{StaticResource BrandMuted}" FontSize="11"/>
              </StackPanel>
            </StackPanel>
          </Button>
          <StackPanel>
            <TextBlock Text="MODULES" Foreground="{StaticResource BrandMuted}" FontSize="11" FontWeight="Bold" Margin="22,20,0,8"/>
            <Button x:Name="NavDashboard" Style="{StaticResource ModuleButton}">
              <StackPanel><TextBlock Text="Dashboard" FontWeight="SemiBold" FontSize="15"/><TextBlock Text="Workspace overview" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
            </Button>
            <Button x:Name="NavProjects" Style="{StaticResource ModuleButton}">
              <StackPanel><TextBlock Text="Project Management" FontWeight="SemiBold" FontSize="15"/><TextBlock Text="Create and manage work" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
            </Button>
            <Button x:Name="NavSearch" Style="{StaticResource ModuleButton}">
              <StackPanel><TextBlock Text="Search &amp; Copy" FontWeight="SemiBold" FontSize="15"/><TextBlock Text="Find project folders" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
            </Button>
            <Button x:Name="NavBrandAssets" Style="{StaticResource ModuleButton}" Visibility="Collapsed">
              <StackPanel><TextBlock Text="Brand Assets" FontWeight="SemiBold" FontSize="15"/><TextBlock Text="Palettes, libraries &amp; logos" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
            </Button>
          </StackPanel>
        </DockPanel>
      </Border>

      <TabControl x:Name="MainViews" Grid.Column="1" Style="{StaticResource HiddenTabs}" Margin="22">
      <TabItem Header="Setup">
        <Grid Margin="-22">
          <Grid.ColumnDefinitions><ColumnDefinition Width="245"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#EAF1FA" BorderBrush="{StaticResource BrandBorder}" BorderThickness="0,0,1,0" Padding="24,30">
            <StackPanel>
              <TextBlock Text="SETUP WIZARD" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="11" Margin="0,0,0,24"/>
              <StackPanel x:Name="InstallerStep1Label" Margin="0,0,0,24">
                <TextBlock Text="01" Foreground="{StaticResource BrandBlue}" FontWeight="Bold" FontSize="12"/>
                <TextBlock Text="Components" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Text="Choose what to install" Foreground="{StaticResource BrandMuted}" FontSize="11"/>
              </StackPanel>
              <StackPanel x:Name="InstallerStep2Label" Margin="0,0,0,24" Opacity="0.5">
                <TextBlock Text="02" Foreground="{StaticResource BrandBlue}" FontWeight="Bold" FontSize="12"/>
                <TextBlock Text="Configuration" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Text="Options and licence" Foreground="{StaticResource BrandMuted}" FontSize="11"/>
              </StackPanel>
              <StackPanel x:Name="InstallerStep3Label" Margin="0,0,0,24" Opacity="0.5">
                <TextBlock Text="03" Foreground="{StaticResource BrandBlue}" FontWeight="Bold" FontSize="12"/>
                <TextBlock Text="Licence" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Text="Read and accept" Foreground="{StaticResource BrandMuted}" FontSize="11"/>
              </StackPanel>
              <StackPanel x:Name="InstallerStep4Label" Opacity="0.5">
                <TextBlock Text="04" Foreground="{StaticResource BrandBlue}" FontWeight="Bold" FontSize="12"/>
                <TextBlock Text="Installation" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/>
                <TextBlock Text="Report and launch" Foreground="{StaticResource BrandMuted}" FontSize="11"/>
              </StackPanel>
            </StackPanel>
          </Border>

          <TabControl x:Name="InstallerSteps" Grid.Column="1" Style="{StaticResource HiddenTabs}" Margin="34,28">
            <TabItem Header="Components">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                  <StackPanel MaxWidth="760">
                    <TextBlock Text="Welcome to SuamiSihat Setup" Style="{StaticResource PageTitle}"/>
                    <TextBlock Text="Select the components to prepare this PC for SuamiSihat creative work." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,22"/>
                    <Border Background="{StaticResource BrandSoft}" BorderBrush="#BFDBFE" BorderThickness="1" CornerRadius="5" Padding="14" Margin="0,0,0,14">
                      <StackPanel><TextBlock Text="VERSION CHECK" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="10"/><TextBlock Text="{Binding InstallerVersionStatus}" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" Margin="0,4,0,0"/></StackPanel>
                    </Border>
                    <Border Style="{StaticResource MetricCard}" Margin="0,0,0,12">
                      <CheckBox IsChecked="{Binding InstallBrandKit}">
                        <StackPanel Margin="8,0"><TextBlock Text="Brand Kit" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/><TextBlock Text="Official fonts, brand assets, design libraries and workstation reports." Foreground="{StaticResource BrandMuted}" Margin="0,4,0,0"/></StackPanel>
                      </CheckBox>
                    </Border>
                    <Border Style="{StaticResource MetricCard}" Margin="0,0,0,12">
                      <CheckBox IsChecked="{Binding InstallProjectManager}">
                        <StackPanel Margin="8,0"><TextBlock Text="Creative Project Management" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" FontSize="17"/><TextBlock Text="SS-CAM dashboard, project creator, Synology search and desktop shortcuts." Foreground="{StaticResource BrandMuted}" Margin="0,4,0,0"/></StackPanel>
                      </CheckBox>
                    </Border>
                    <TextBlock Text="PC information remains local and is not transmitted by this installer." Foreground="{StaticResource BrandMuted}" Margin="5,16,5,6"/>
                    <CheckBox x:Name="RemoveAppStateCheck" Content="When uninstalling, also remove user settings and recent-project history" Foreground="{StaticResource BrandMuted}" Margin="5,0,5,12"/>
                  </StackPanel>
                </ScrollViewer>
                <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Button x:Name="InstallerUninstallButton" Content="Uninstall Existing Installation" Style="{StaticResource DangerButton}" MinWidth="190"/>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="CancelInstallerButton" Content="Cancel" Style="{StaticResource SecondaryButton}" MinWidth="100"/>
                    <Button x:Name="InstallerCustomButton" Content="Custom Install" Style="{StaticResource SecondaryButton}" MinWidth="140"/>
                    <Button x:Name="InstallerExpressButton" Content="Express Install" MinWidth="140"/>
                  </StackPanel>
                </Grid>
              </Grid>
            </TabItem>

            <TabItem Header="Configuration">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                  <StackPanel MaxWidth="760">
                    <Grid Margin="0,0,0,14"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="System Check &amp; Configuration" Style="{StaticResource PageTitle}"/><TextBlock Text="Review this PC, installed creative software and component options." Foreground="{StaticResource BrandMuted}"/></StackPanel><Button x:Name="RescanSystemButton" Grid.Column="1" Content="Rescan" Style="{StaticResource SecondaryButton}"/></Grid>
                    <TabControl Height="250" Margin="0,0,0,14">
                      <TabItem Header="This PC">
                        <DataGrid x:Name="PcSpecsGrid" AutoGenerateColumns="False" IsReadOnly="True" HeadersVisibility="Column" GridLinesVisibility="Horizontal" BorderThickness="0">
                          <DataGrid.Columns><DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="75"/><DataGridTextColumn Header="Component" Binding="{Binding Component}" Width="120"/><DataGridTextColumn Header="Detected" Binding="{Binding Detected}" Width="2*"/><DataGridTextColumn Header="SuamiSihat target" Binding="{Binding Target}" Width="2*"/></DataGrid.Columns>
                        </DataGrid>
                      </TabItem>
                      <TabItem Header="Creative Software">
                        <DataGrid x:Name="SoftwareStatusGrid" AutoGenerateColumns="False" IsReadOnly="True" HeadersVisibility="Column" GridLinesVisibility="Horizontal" BorderThickness="0">
                          <DataGrid.Columns><DataGridTextColumn Header="Application" Binding="{Binding Application}" Width="2*"/><DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="130"/><DataGridTextColumn Header="Installed" Binding="{Binding InstalledVersion}" Width="120"/><DataGridTextColumn Header="Reference" Binding="{Binding LatestVersion}" Width="120"/></DataGrid.Columns>
                        </DataGrid>
                      </TabItem>
                    </TabControl>
                    <GroupBox x:Name="BrandKitOptionsGroup" Header="Brand Kit options" Visibility="{Binding InstallBrandKit, Converter={StaticResource BoolToVisibility}}">
                      <Grid>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <TextBlock Grid.Row="0" Text="Fonts" VerticalAlignment="Center" Margin="0,0,12,0"/>
                        <ComboBox x:Name="FontChoice" Grid.Row="0" Grid.Column="1" SelectedIndex="0"><ComboBoxItem Content="All bundled fonts"/><ComboBoxItem Content="Core brand fonts"/><ComboBoxItem Content="Do not install fonts"/></ComboBox>
                        <CheckBox Grid.Row="1" Grid.ColumnSpan="2" Content="Copy brand assets and generate workstation reports" IsChecked="{Binding CopyAssets}"/>
                        <TextBox Grid.Row="2" Grid.ColumnSpan="2" Text="{Binding Destination, UpdateSourceTrigger=PropertyChanged}"/>
                        <Button x:Name="BrowseInstallDestination" Grid.Row="2" Grid.Column="2" Content="Browse..." Style="{StaticResource SecondaryButton}"/>
                      </Grid>
                    </GroupBox>
                    <GroupBox Header="Creative Project Management" Visibility="{Binding InstallProjectManager, Converter={StaticResource BoolToVisibility}}">
                      <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="Application installation folder"/><TextBox Text="{Binding CpmInstallPath, UpdateSourceTrigger=PropertyChanged}"/></StackPanel><Button x:Name="BrowseCpmInstallPath" Grid.Column="1" Content="Browse..." Style="{StaticResource SecondaryButton}" VerticalAlignment="Bottom"/></Grid>
                    </GroupBox>
                  </StackPanel>
                </ScrollViewer>
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
                  <Button x:Name="InstallerBack2" Content="Back" Style="{StaticResource SecondaryButton}" MinWidth="100"/>
                  <Button x:Name="InstallerNext2" Content="Continue to Licence" MinWidth="170"/>
                </StackPanel>
              </Grid>
            </TabItem>

            <TabItem Header="Licence">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel MaxWidth="760">
                  <TextBlock Text="Licence Agreement" Style="{StaticResource PageTitle}"/>
                  <TextBlock Text="Read the complete agreement. Acceptance unlocks only after you reach the end." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,14"/>
                  <TextBox x:Name="LicenseTextBox" Text="{Binding LicenseText}" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" Height="410" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Disabled"/>
                  <TextBlock Text="{Binding LicenseReadStatus}" Foreground="{StaticResource BrandMuted}" Margin="0,4,0,4"/>
                  <CheckBox x:Name="AcceptLicenseCheck" Content="I have read and accept the licence agreement" IsChecked="{Binding AcceptLicence}" IsEnabled="False" FontWeight="SemiBold"/>
                </StackPanel>
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
                  <Button x:Name="InstallerBack3" Content="Back" Style="{StaticResource SecondaryButton}" MinWidth="100"/>
                  <Button x:Name="InstallButton" Content="Accept &amp; Install" MinWidth="160"/>
                </StackPanel>
              </Grid>
            </TabItem>

            <TabItem Header="Installation">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel MaxWidth="760">
                  <TextBlock Text="Installation Report" Style="{StaticResource PageTitle}"/>
                  <TextBlock Text="Installation progress and component results are recorded below." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,18"/>
                  <GroupBox Header="Selected components">
                    <StackPanel><CheckBox Content="Brand Kit" IsChecked="{Binding InstallBrandKit}" IsHitTestVisible="False"/><CheckBox Content="Creative Project Management" IsChecked="{Binding InstallProjectManager}" IsHitTestVisible="False"/></StackPanel>
                  </GroupBox>
                  <ProgressBar Height="8" IsIndeterminate="{Binding IsInstalling}" Margin="4,10"/>
                  <TextBlock Text="{Binding InstallStatus}" FontWeight="SemiBold" Margin="4,6"/>
                  <TextBox Text="{Binding InstallReport}" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" Height="260" VerticalScrollBarVisibility="Auto"/>
                </StackPanel>
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
                  <Button x:Name="InstallerBack4" Content="Back" Style="{StaticResource SecondaryButton}" MinWidth="100"/>
                  <Button x:Name="OpenInstalledAppButton" Content="Open SS-CAM" Visibility="Collapsed" MinWidth="130"/>
                  <Button x:Name="CloseSetupButton" Content="Close" Style="{StaticResource SecondaryButton}" MinWidth="100"/>
                </StackPanel>
              </Grid>
            </TabItem>
          </TabControl>
        </Grid>
      </TabItem>

      <TabItem Header="Dashboard">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel MaxWidth="1120">
            <Grid Margin="0,0,0,16">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel>
                <TextBlock Text="Creative Workspace Dashboard" Style="{StaticResource PageTitle}"/>
                <TextBlock Text="Live overview of projects in the configured Synology workspace." Foreground="{StaticResource BrandMuted}"/>
              </StackPanel>
              <Button x:Name="RefreshDashboardButton" Grid.Column="1" Content="Refresh Metrics" Style="{StaticResource SecondaryButton}"/>
            </Grid>
            <UniformGrid Columns="4" Margin="-5,0,-5,14">
              <Border Style="{StaticResource MetricCard}">
                <StackPanel><TextBlock Text="TOTAL PROJECTS" Foreground="{StaticResource BrandMuted}" FontSize="11" FontWeight="Bold"/><TextBlock Text="{Binding DashboardTotal}" Foreground="{StaticResource BrandNavy}" FontSize="36" FontWeight="Bold" Margin="0,8,0,0"/></StackPanel>
              </Border>
              <Border Style="{StaticResource MetricCard}">
                <StackPanel><TextBlock Text="LATEST PROJECT" Foreground="{StaticResource BrandMuted}" FontSize="11" FontWeight="Bold"/><TextBlock Text="{Binding DashboardLatest}" Foreground="{StaticResource BrandNavy}" FontSize="15" FontWeight="SemiBold" Margin="0,9,0,0"/></StackPanel>
              </Border>
              <Border Style="{StaticResource MetricCard}">
                <StackPanel><TextBlock Text="PROJECT FILE SIZE" Foreground="{StaticResource BrandMuted}" FontSize="11" FontWeight="Bold"/><TextBlock Text="{Binding DashboardFileSize}" Foreground="{StaticResource BrandNavy}" FontSize="30" FontWeight="Bold" Margin="0,8,0,0"/></StackPanel>
              </Border>
              <Border Style="{StaticResource MetricCard}">
                <StackPanel><TextBlock Text="CREATED THIS MONTH" Foreground="{StaticResource BrandMuted}" FontSize="11" FontWeight="Bold"/><TextBlock Text="{Binding DashboardThisMonth}" Foreground="{StaticResource BrandNavy}" FontSize="36" FontWeight="Bold" Margin="0,8,0,0"/></StackPanel>
              </Border>
            </UniformGrid>
            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions><ColumnDefinition Width="1.15*"/><ColumnDefinition Width="1.15*"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
              <GroupBox Header="Projects by type" Margin="0,0,7,0">
                <ItemsControl ItemsSource="{Binding DashboardTypeChart}">
                  <ItemsControl.ItemTemplate><DataTemplate>
                    <Grid Margin="0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="90"/><ColumnDefinition Width="*"/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
                      <TextBlock Text="{Binding Label}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                      <Border Grid.Column="1" Width="{Binding BarWidth}" Height="14" HorizontalAlignment="Left" VerticalAlignment="Center" Background="{Binding Color}" CornerRadius="7"/>
                      <TextBlock Grid.Column="2" Text="{Binding Count}" FontWeight="Bold" Foreground="{StaticResource BrandNavy}" HorizontalAlignment="Right"/>
                    </Grid>
                  </DataTemplate></ItemsControl.ItemTemplate>
                </ItemsControl>
              </GroupBox>
              <GroupBox Grid.Column="1" Header="Projects by sub-brand" Margin="7,0">
                <ItemsControl ItemsSource="{Binding DashboardBrandChart}">
                  <ItemsControl.ItemTemplate><DataTemplate>
                    <Grid Margin="0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="48"/><ColumnDefinition Width="*"/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions>
                      <TextBlock Text="{Binding Label}" VerticalAlignment="Center" FontWeight="SemiBold"/>
                      <Border Grid.Column="1" Width="{Binding BarWidth}" Height="14" HorizontalAlignment="Left" VerticalAlignment="Center" Background="{Binding Color}" CornerRadius="7"/>
                      <TextBlock Grid.Column="2" Text="{Binding Percent}" Foreground="{StaticResource BrandMuted}" HorizontalAlignment="Right"/>
                    </Grid>
                  </DataTemplate></ItemsControl.ItemTemplate>
                </ItemsControl>
              </GroupBox>
              <GroupBox Grid.Column="2" Header="Six-month activity" Margin="7,0,0,0">
                <ItemsControl ItemsSource="{Binding DashboardActivityChart}" HorizontalAlignment="Center">
                  <ItemsControl.ItemsPanel><ItemsPanelTemplate><StackPanel Orientation="Horizontal"/></ItemsPanelTemplate></ItemsControl.ItemsPanel>
                  <ItemsControl.ItemTemplate><DataTemplate>
                    <Grid Width="28" Height="155"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="22"/><RowDefinition Height="20"/></Grid.RowDefinitions>
                      <Border Height="{Binding BarHeight}" Width="18" VerticalAlignment="Bottom" Background="{Binding Color}" CornerRadius="5,5,0,0"/>
                      <TextBlock Grid.Row="1" Text="{Binding Count}" HorizontalAlignment="Center" FontWeight="Bold" Foreground="{StaticResource BrandNavy}"/>
                      <TextBlock Grid.Row="2" Text="{Binding Label}" HorizontalAlignment="Center" Foreground="{StaticResource BrandMuted}" FontSize="10"/>
                    </Grid>
                  </DataTemplate></ItemsControl.ItemTemplate>
                </ItemsControl>
              </GroupBox>
            </Grid>
            <GroupBox Header="Workspace flow" Margin="0,0,0,14">
              <Grid Margin="8"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Border Background="{StaticResource BrandSoft}" CornerRadius="9" Padding="12"><StackPanel><TextBlock Text="WORKSPACE" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="10"/><TextBlock Text="Synology Drive" Foreground="{StaticResource BrandNavy}" FontWeight="SemiBold" Margin="0,5,0,0"/></StackPanel></Border>
                <TextBlock Grid.Column="1" Text="&#x2192;" FontSize="24" Foreground="{StaticResource BrandBlue}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                <Border Grid.Column="2" Background="{StaticResource BrandSoft}" CornerRadius="9" Padding="12"><StackPanel><TextBlock Text="DESIGNERS" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="10"/><TextBlock Text="{Binding DashboardDesignerCount}" Foreground="{StaticResource BrandNavy}" FontSize="22" FontWeight="Bold"/></StackPanel></Border>
                <TextBlock Grid.Column="3" Text="&#x2192;" FontSize="24" Foreground="{StaticResource BrandBlue}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                <Border Grid.Column="4" Background="{StaticResource BrandSoft}" CornerRadius="9" Padding="12"><StackPanel><TextBlock Text="PROJECTS" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="10"/><TextBlock Text="{Binding DashboardTotal}" Foreground="{StaticResource BrandNavy}" FontSize="22" FontWeight="Bold"/></StackPanel></Border>
                <TextBlock Grid.Column="5" Text="&#x2192;" FontSize="24" Foreground="{StaticResource BrandBlue}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                <Border Grid.Column="6" Background="{StaticResource BrandSoft}" CornerRadius="9" Padding="12"><StackPanel><TextBlock Text="FILES" Foreground="{StaticResource BrandMuted}" FontWeight="Bold" FontSize="10"/><TextBlock Text="{Binding DashboardFileCount}" Foreground="{StaticResource BrandNavy}" FontSize="22" FontWeight="Bold"/></StackPanel></Border>
              </Grid>
            </GroupBox>
            <GroupBox Header="Workspace source">
              <StackPanel>
                <TextBlock Text="{Binding Workspace}" Foreground="{StaticResource BrandNavy}" FontFamily="Consolas"/>
                <TextBlock Text="{Binding DashboardStatus}" Foreground="{StaticResource BrandMuted}" Margin="0,8,0,0"/>
              </StackPanel>
            </GroupBox>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Projects">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel MaxWidth="980">
            <TextBlock Text="Creative Project Folder Creator" Style="{StaticResource PageTitle}"/>
            <TextBlock Text="Official presets with automated folder structure, history tracking and Job ID management." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,16"/>
            <GroupBox Header="Recent active projects">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <ComboBox x:Name="RecentCombo" ItemsSource="{Binding RecentProjects}"/>
                <Button x:Name="OpenRecentButton" Grid.Column="1" Content="Open Folder" IsEnabled="{Binding HasRecent}"/>
              </Grid>
            </GroupBox>
            <GroupBox Header="Project and template options">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="2*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel Grid.Row="0" Grid.Column="0"><TextBlock Text="Creative preset"/><ComboBox ItemsSource="{Binding Presets}" SelectedItem="{Binding SelectedPreset}"/></StackPanel>
                <StackPanel Grid.Row="0" Grid.Column="1"><TextBlock Text="Target platform / specification"/><ComboBox ItemsSource="{Binding Platforms}" SelectedItem="{Binding SelectedPlatform}"/></StackPanel>
                <StackPanel Grid.Row="0" Grid.Column="2"><TextBlock Text="Year"/><ComboBox ItemsSource="{Binding Years}" SelectedItem="{Binding SelectedYear}"/></StackPanel>
                <StackPanel Grid.Row="1" Grid.Column="0"><TextBlock Text="Sub-brand"/><ComboBox ItemsSource="{Binding Brands}" SelectedItem="{Binding SelectedBrand}"/></StackPanel>
                <StackPanel Grid.Row="1" Grid.Column="1"><TextBlock Text="Job ID"/><TextBox Text="{Binding JobId, UpdateSourceTrigger=PropertyChanged}" CharacterCasing="Upper"/></StackPanel>
                <StackPanel Grid.Row="1" Grid.Column="2"><TextBlock Text="Designer"/><ComboBox x:Name="DesignerCombo" ItemsSource="{Binding DesignerProfiles}"/></StackPanel>
                <StackPanel Grid.Row="2" Grid.ColumnSpan="3"><TextBlock Text="Project name"/><TextBox Text="{Binding ProjectName, UpdateSourceTrigger=PropertyChanged}"/></StackPanel>
                <StackPanel Grid.Row="3" Grid.ColumnSpan="3"><TextBlock Text="Project description / creative brief (saved as README.md)"/><TextBox Text="{Binding ProjectDescription, UpdateSourceTrigger=PropertyChanged}" AcceptsReturn="True" TextWrapping="Wrap" MinHeight="90" VerticalScrollBarVisibility="Auto"/></StackPanel>
                <WrapPanel Grid.Row="4" Grid.ColumnSpan="3" VerticalAlignment="Center">
                  <CheckBox Content="Inject master canvas" IsChecked="{Binding InjectMasterCanvas}"/>
                  <ComboBox x:Name="MasterCanvasExtensionCombo" Width="125" ItemsSource="{Binding TemplateExtensions}" SelectedItem="{Binding SelectedTemplateExtension}" IsEnabled="{Binding InjectMasterCanvas}"/>
                  <TextBlock Text="Custom:" VerticalAlignment="Center" Foreground="{StaticResource BrandMuted}" Margin="5,0,0,0"/>
                  <TextBox x:Name="CustomExtensionBox" Width="115" Text="{Binding CustomTemplateExtension, UpdateSourceTrigger=PropertyChanged}" ToolTip="Custom extension, for example .svg" IsEnabled="{Binding InjectMasterCanvas}"/>
                  <Button x:Name="AddCustomExtensionButton" Content="Add extension" Style="{StaticResource SecondaryButton}" IsEnabled="{Binding InjectMasterCanvas}"/>
                  <CheckBox Content="+ Revisions folder" IsChecked="{Binding IncludeRevisions}"/>
                  <CheckBox Content="+ RAW Media" IsChecked="{Binding IncludeRawMedia}"/>
                </WrapPanel>
              </Grid>
            </GroupBox>
            <GroupBox Header="Generated location and subfolder structure">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="1.15*"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
                <StackPanel Margin="0,0,14,0">
                  <TextBlock Text="Project folder location" FontWeight="SemiBold" Foreground="{StaticResource BrandNavy}"/>
                  <TextBlock Text="{Binding PreviewPath}" FontFamily="Consolas" Margin="0,8,0,0" TextWrapping="Wrap"/>
                </StackPanel>
                <Border Grid.Column="1" Background="{StaticResource BrandSoft}" CornerRadius="6" Padding="14">
                  <StackPanel>
                    <TextBlock Text="Subfolders to be created" FontWeight="SemiBold" Foreground="{StaticResource BrandNavy}" Margin="0,0,0,8"/>
                    <TextBlock Text="{Binding FolderStructure}" FontFamily="Consolas" Foreground="{StaticResource BrandMuted}"/>
                  </StackPanel>
                </Border>
              </Grid>
            </GroupBox>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Button x:Name="CreateProjectButton" Content="Create Project Folder &amp; Open Explorer" MinWidth="285"/>
              <Button x:Name="CopyNameButton" Grid.Column="1" Content="Copy Name" Style="{StaticResource SecondaryButton}"/>
              <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                <Button x:Name="ClearFormButton" Content="Clear Form" Style="{StaticResource SecondaryButton}"/>
                <TextBlock Text="{Binding StatusText}" Foreground="{StaticResource BrandSuccess}" HorizontalAlignment="Right"/>
              </StackPanel>
            </Grid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Search">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <StackPanel>
            <TextBlock Text="Project Search &amp; Copy" Style="{StaticResource PageTitle}"/>
            <TextBlock Text="Find a project folder, review its README.md brief, then copy selected project files into your current work order." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,14"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <TextBox Text="{Binding SearchRoot, UpdateSourceTrigger=PropertyChanged}" ToolTip="Synology Drive root folder"/>
              <Button x:Name="BrowseSearchRootButton" Grid.Column="1" Content="Browse Root..." Style="{StaticResource SecondaryButton}"/>
            </Grid>
            <Grid Margin="0,2,0,0">
              <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel><TextBlock Text="Designer"/><ComboBox x:Name="DesignerFolderCombo" ItemsSource="{Binding DesignerFolderChoices}" DisplayMemberPath="Display" SelectedValuePath="StaffId" SelectedValue="{Binding SelectedDesignerFolderId}"/></StackPanel>
              <StackPanel Grid.Column="1"><TextBlock Text="Project folder name"/><TextBox x:Name="SearchQueryBox" Text="{Binding SearchQuery, UpdateSourceTrigger=PropertyChanged}" ToolTip="Enter part of a project folder name, or leave blank to list all"/></StackPanel>
              <Button x:Name="SearchProjectFoldersButton" Grid.Column="2" Content="Find Projects" MinWidth="130" VerticalAlignment="Bottom"/>
            </Grid>
            <ProgressBar Height="5" IsIndeterminate="{Binding IsSearching}" Margin="0,0,0,8"/>
            <Grid Margin="0,0,0,10"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Text="{Binding DesignerFolderStatus}" Foreground="{StaticResource BrandMuted}"/><TextBlock Grid.Column="1" Text="{Binding SearchStatus}" Foreground="{StaticResource BrandMuted}"/></Grid>
          </StackPanel>
          <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="1.2*"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
            <GroupBox Header="Project folders" Margin="0,0,7,0">
              <Grid><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <DataGrid x:Name="DesignerFoldersGrid" ItemsSource="{Binding DesignerFolders}" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Single" SelectionUnit="FullRow" HeadersVisibility="Column" GridLinesVisibility="Horizontal" BorderThickness="0" Background="White">
                  <DataGrid.Columns>
                    <DataGridTextColumn Header="Project" Binding="{Binding Project}" Width="140"/>
                    <DataGridTextColumn Header="Designer" Binding="{Binding Designer}" Width="70"/>
                    <DataGridTextColumn Header="Modified" Binding="{Binding Modified}" Width="125"/>
                  </DataGrid.Columns>
                </DataGrid>
                <Button x:Name="OpenDesignerFolderButton" Grid.Row="1" Content="Open Selected Folder" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" MinWidth="150"/>
              </Grid>
            </GroupBox>
            <TabControl Grid.Column="1" Margin="7,0,0,0">
              <TabItem Header="README.md">
                <Grid Background="White">
                  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                  <Border BorderBrush="{StaticResource BrandBorder}" BorderThickness="0,0,0,1" Padding="8,5">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                      <Button x:Name="ReadmePreviewButton" Content="Preview" MinWidth="88"/>
                      <Button x:Name="ReadmeRawButton" Content="Raw Markdown" Style="{StaticResource SecondaryButton}" MinWidth="112"/>
                    </StackPanel>
                  </Border>
                  <FlowDocumentScrollViewer x:Name="ReadmePreviewViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" IsToolBarVisible="False" Background="White"/>
                  <TextBox x:Name="ReadmeRawTextBox" Grid.Row="1" Text="{Binding ProjectReadmeContent}" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" BorderThickness="0" Padding="12" FontFamily="Consolas" Background="White" Visibility="Collapsed"/>
                </Grid>
              </TabItem>
              <TabItem Header="Project files">
                <DataGrid x:Name="SearchResultsGrid" ItemsSource="{Binding SearchResults}" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended" SelectionUnit="FullRow" HeadersVisibility="Column" GridLinesVisibility="Horizontal" BorderThickness="0" Background="White">
                  <DataGrid.Columns>
                    <DataGridTextColumn Header="File" Binding="{Binding Name}" Width="2*"/>
                    <DataGridTextColumn Header="Relative folder" Binding="{Binding Folder}" Width="2*"/>
                    <DataGridTextColumn Header="Size" Binding="{Binding Size}" Width="75"/>
                    <DataGridTextColumn Header="Modified" Binding="{Binding Modified}" Width="125"/>
                  </DataGrid.Columns>
                </DataGrid>
              </TabItem>
              <TabItem Header="Production / Export">
                <Grid Background="{StaticResource BrandSurface}">
                  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                  <TextBlock x:Name="ProductionStatusText" Text="Select a project folder to preview exported files." Foreground="{StaticResource BrandMuted}" FontSize="12" Padding="10,8" TextWrapping="Wrap"/>
                  <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <WrapPanel x:Name="ProductionThumbnailPanel" Margin="8" Orientation="Horizontal"/>
                  </ScrollViewer>
                </Grid>
              </TabItem>
            </TabControl>
          </Grid>
          <GroupBox Grid.Row="2" Header="Copy to work order" Margin="0,14,0,0">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <TextBox Text="{Binding SearchDestination, UpdateSourceTrigger=PropertyChanged}" ToolTip="Destination work-order folder"/>
              <Button x:Name="BrowseCopyDestinationButton" Grid.Column="1" Content="Choose Work Order..." Style="{StaticResource SecondaryButton}"/>
              <Button x:Name="CopySelectedFilesButton" Grid.Column="2" Content="Copy Selected Files" MinWidth="160"/>
            </Grid>
          </GroupBox>
        </Grid>
      </TabItem>

      <TabItem Header="BrandAssets">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel MaxWidth="980">
            <TextBlock Text="Brand Assets" Style="{StaticResource PageTitle}"/>
            <TextBlock Text="Open installed SuamiSihat creative resources, official links and local installation reports." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,16"/>
            <GroupBox Header="Installed Brand Kit">
              <StackPanel>
                <TextBlock Text="Brand assets location" FontWeight="SemiBold" Foreground="{StaticResource BrandNavy}"/>
                <TextBlock Text="{Binding BrandAssetsPath}" FontFamily="Consolas" Margin="0,6,0,4"/>
                <TextBlock Text="{Binding BrandAssetsStatus}" Foreground="{StaticResource BrandSuccess}"/>
              </StackPanel>
            </GroupBox>
            <!-- Font Awesome Free 7.3.1 icons: CC BY 4.0, Copyright 2026 Fonticons, Inc. https://fontawesome.com/license/free -->
            <GroupBox Header="Asset folders">
              <UniformGrid Columns="3">
                <Button x:Name="OpenColourPalettesButton" Style="{StaticResource AssetCardButton}">
                  <StackPanel><Border Width="48" Height="48" CornerRadius="24" Background="#E0F2FE" HorizontalAlignment="Left"><Viewbox Width="23" Height="23"><Path Fill="{StaticResource BrandBlue}" Data="M512 256c0 .9 0 1.8 0 2.7-.4 36.5-33.6 61.3-70.1 61.3L344 320c-26.5 0-48 21.5-48 48 0 3.4 .4 6.7 1 9.9 2.1 10.2 6.5 20 10.8 29.9 6.1 13.8 12.1 27.5 12.1 42 0 31.8-21.6 60.7-53.4 62-3.5 .1-7 .2-10.6 .2-141.4 0-256-114.6-256-256S114.6 0 256 0 512 114.6 512 256zM128 288a32 32 0 1 0 -64 0 32 32 0 1 0 64 0zm0-96a32 32 0 1 0 0-64 32 32 0 1 0 0 64zM288 96a32 32 0 1 0 -64 0 32 32 0 1 0 64 0zm96 96a32 32 0 1 0 0-64 32 32 0 1 0 0 64z"/></Viewbox></Border><TextBlock Text="Colour Palettes" Foreground="{StaticResource BrandNavy}" FontSize="17" FontWeight="SemiBold" Margin="0,12,0,2"/><TextBlock Text="Official colour files" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
                </Button>
                <Button x:Name="OpenAssetLibrariesButton" Style="{StaticResource AssetCardButton}">
                  <StackPanel><Border Width="48" Height="48" CornerRadius="24" Background="#EDE9FE" HorizontalAlignment="Left"><Viewbox Width="23" Height="23"><Path Fill="#7C3AED" Data="M96 96c0-35.3 28.7-64 64-64l320 0c35.3 0 64 28.7 64 64l0 256c0 35.3-28.7 64-64 64l-320 0c-35.3 0-64-28.7-64-64L96 96zM24 128c13.3 0 24 10.7 24 24l0 296c0 8.8 7.2 16 16 16l360 0c13.3 0 24 10.7 24 24s-10.7 24-24 24L64 512c-35.3 0-64-28.7-64-64L0 152c0-13.3 10.7-24 24-24zm168 32a32 32 0 1 0 0-64 32 32 0 1 0 0 64zm196.5 11.5c-4.4-7.1-12.1-11.5-20.5-11.5s-16.1 4.4-20.5 11.5l-56.3 92.1-24.5-30.6c-4.6-5.7-11.4-9-18.7-9s-14.2 3.3-18.7 9l-64 80c-5.8 7.2-6.9 17.1-2.9 25.4S174.8 352 184 352l272 0c8.7 0 16.7-4.7 20.9-12.3s4.1-16.8-.5-24.3l-88-144z"/></Viewbox></Border><TextBlock Text="Asset Libraries" Foreground="{StaticResource BrandNavy}" FontSize="17" FontWeight="SemiBold" Margin="0,12,0,2"/><TextBlock Text="Affinity and Adobe libraries" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
                </Button>
                <Button x:Name="OpenLogosButton" Style="{StaticResource AssetCardButton}">
                  <StackPanel><Border Width="48" Height="48" CornerRadius="24" Background="#DCFCE7" HorizontalAlignment="Left"><Viewbox Width="25" Height="22"><Path Fill="#15803D" Data="M192 128c0-17.7 14.3-32 32-32s32 14.3 32 32l0 7.8c0 27.7-2.4 55.3-7.1 82.5l-84.4 25.3c-40.6 12.2-68.4 49.6-68.4 92l0 32.4-72 0c-13.3 0-24 10.7-24 24s10.7 24 24 24l72.5 0c4.2 36 34.8 64 72 64 26 0 50-13.9 62.9-36.5l13.9-24.3c26.8-47 46.5-97.7 58.4-150.5l94.4-28.3-12.5 37.5c-3.3 9.8-1.6 20.5 4.4 28.8S405.7 320 416 320l128 0c17.7 0 32-14.3 32-32s-14.3-32-32-32l-83.6 0 18-53.9c3.8-11.3 .9-23.8-7.4-32.4s-20.7-11.8-32.2-8.4L316.4 198.1c2.4-20.7 3.6-41.4 3.6-62.3l0-7.8c0-53-43-96-96-96s-96 43-96 96l0 32c0 17.7 14.3 32 32 32s32-14.3 32-32l0-32zm-9.2 177l49-14.7c-10.4 33.8-24.5 66.4-42.1 97.2l-13.9 24.3c-1.5 2.6-4.3 4.3-7.4 4.3-4.7 0-8.5-3.8-8.5-8.5l0-71.9c0-14.1 9.3-26.6 22.8-30.7zM616 416c13.3 0 24-10.7 24-24s-10.7-24-24-24l-292.9 0c-6.5 16.3-13.7 32.3-21.6 48L616 416z"/></Viewbox></Border><TextBlock Text="Logos" Foreground="{StaticResource BrandNavy}" FontSize="17" FontWeight="SemiBold" Margin="0,12,0,2"/><TextBlock Text="Approved logo packages" Foreground="{StaticResource BrandMuted}" FontSize="11"/></StackPanel>
                </Button>
              </UniformGrid>
            </GroupBox>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="1*"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
              <GroupBox Header="Official links" Margin="0,0,7,0">
                <StackPanel>
                  <Button x:Name="OpenServiceDashboardButton" Content="SuamiSihat Service Dashboard" Style="{StaticResource LinkButton}"/>
                  <Button x:Name="OpenInternalAssetsButton" Content="SuamiSihat Internal Assets" Style="{StaticResource LinkButton}"/>
                  <Button x:Name="OpenPublicBrandAssetsButton" Content="Public Brand Assets" Style="{StaticResource LinkButton}"/>
                </StackPanel>
              </GroupBox>
              <GroupBox Grid.Column="1" Header="Installation reports" Margin="7,0,0,0">
                <StackPanel>
                  <Button x:Name="OpenWorkstationReportButton" Content="View Workstation Report" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Stretch"/>
                  <Button x:Name="OpenFontInventoryReportButton" Content="View Font Inventory" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Stretch"/>
                  <TextBlock Text="Reports open inside the app as Markdown text." Foreground="{StaticResource BrandMuted}" FontSize="11" Margin="5,5,0,0"/>
                </StackPanel>
              </GroupBox>
            </Grid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Profile">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel MaxWidth="920">
            <TextBlock Text="User Profile &amp; Settings" Style="{StaticResource PageTitle}"/>
            <TextBlock Text="Manage your identity, workspace defaults, project history and application maintenance." Foreground="{StaticResource BrandMuted}" Margin="0,0,0,16"/>
            <GroupBox Header="Workspace, history and sequential counter">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel><TextBlock Text="Default parent workspace"/><TextBox Text="{Binding Workspace, UpdateSourceTrigger=PropertyChanged}"/></StackPanel>
                <Button x:Name="BrowseWorkspaceButton" Grid.Column="1" Content="Browse..." Style="{StaticResource SecondaryButton}" VerticalAlignment="Bottom"/>
                <StackPanel Grid.Row="1" Orientation="Horizontal">
                  <StackPanel Width="190"><TextBlock Text="Next Job ID"/><TextBox Text="{Binding JobId, UpdateSourceTrigger=PropertyChanged}" CharacterCasing="Upper"/></StackPanel>
                  <Button x:Name="ClearRecentButton" Content="Clear Recent Projects" Style="{StaticResource SecondaryButton}" VerticalAlignment="Center"/>
                </StackPanel>
              </Grid>
            </GroupBox>
            <GroupBox Header="Designer profile and signature">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="110"/><ColumnDefinition Width="2*"/><ColumnDefinition Width="2*"/><ColumnDefinition Width="2*"/></Grid.ColumnDefinitions>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <StackPanel Grid.Column="0"><TextBlock Text="Staff ID"/><TextBox Text="{Binding StaffId, UpdateSourceTrigger=PropertyChanged}" CharacterCasing="Upper" MaxLength="5"/></StackPanel>
                <StackPanel Grid.Column="1"><TextBlock Text="Designer name"/><TextBox Text="{Binding DesignerName, UpdateSourceTrigger=PropertyChanged}"/></StackPanel>
                <StackPanel Grid.Column="2"><TextBlock Text="Department / role"/><TextBox Text="{Binding Department, UpdateSourceTrigger=PropertyChanged}"/></StackPanel>
                <StackPanel Grid.Column="3"><TextBlock Text="Email address"/><TextBox Text="{Binding Email, UpdateSourceTrigger=PropertyChanged}"/></StackPanel>
                <StackPanel Grid.Row="1" Grid.ColumnSpan="4"><TextBlock Text="Avatar image"/><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox Text="{Binding AvatarPath, UpdateSourceTrigger=PropertyChanged}"/><Button x:Name="BrowseAvatarButton" Grid.Column="1" Content="Browse..." Style="{StaticResource SecondaryButton}"/></Grid></StackPanel>
              </Grid>
            </GroupBox>
            <GroupBox Header="Application maintenance">
              <WrapPanel>
                <Button x:Name="RepairButton" Content="Reinstall / Repair Fonts &amp; Brand Assets"/>
                <Button x:Name="CheckUpdateButton" Content="Check for Updates" Style="{StaticResource SecondaryButton}"/>
                <Button x:Name="UninstallButton" Content="Uninstall App &amp; Shortcuts" Style="{StaticResource DangerButton}"/>
              </WrapPanel>
            </GroupBox>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <TextBlock Text="{Binding SettingsStatus}" Foreground="{StaticResource BrandSuccess}" VerticalAlignment="Center"/>
              <Button x:Name="SaveSettingsButton" Grid.Column="1" Content="Save Settings" MinWidth="150"/>
            </Grid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
      </TabControl>
    </Grid>
  </DockPanel>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$vm = New-Object SuamiSihat.Wpf.AppViewModel
$window.DataContext = $vm

function Get-Control([string]$Name) {
    $control = $window.FindName($Name)
    if ($null -eq $control) { throw "WPF control was not found: $Name" }
    return $control
}

$views = Get-Control "MainViews"
$recentCombo = Get-Control "RecentCombo"
$designerCombo = Get-Control "DesignerCombo"
$fontChoice = Get-Control "FontChoice"
$searchResultsGrid = Get-Control "SearchResultsGrid"
$designerFoldersGrid = Get-Control "DesignerFoldersGrid"
$designerFolderCombo = Get-Control "DesignerFolderCombo"
$readmePreviewViewer = Get-Control "ReadmePreviewViewer"
$readmeRawTextBox = Get-Control "ReadmeRawTextBox"
$readmePreviewButton = Get-Control "ReadmePreviewButton"
$readmeRawButton = Get-Control "ReadmeRawButton"
$sidebar = Get-Control "Sidebar"
$sidebarColumn = Get-Control "SidebarColumn"
$headerLogo = Get-Control "HeaderLogo"
$appStatusBar = Get-Control "AppStatusBar"
$installerSteps = Get-Control "InstallerSteps"
$installerStepLabels = @(
    (Get-Control "InstallerStep1Label"),
    (Get-Control "InstallerStep2Label"),
    (Get-Control "InstallerStep3Label"),
    (Get-Control "InstallerStep4Label")
)
$pcSpecsGrid = Get-Control "PcSpecsGrid"
$softwareStatusGrid = Get-Control "SoftwareStatusGrid"
$licenseTextBox = Get-Control "LicenseTextBox"
$acceptLicenseCheck = Get-Control "AcceptLicenseCheck"

function Set-UninstallOptionVisibility([bool]$IsInstalled) {
    $visibility = if ($IsInstalled) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    (Get-Control "InstallerUninstallButton").Visibility = $visibility
    (Get-Control "RemoveAppStateCheck").Visibility = $visibility
}

$logoPath = Join-Path (Split-Path -Parent $PSScriptRoot) "assets\suamisihat-logo-on-dark-ui.png"
if (Test-Path -LiteralPath $logoPath -PathType Leaf) {
    $logoBitmap = New-Object Windows.Media.Imaging.BitmapImage
    $logoBitmap.BeginInit()
    $logoBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $logoBitmap.UriSource = New-Object Uri($logoPath, [UriKind]::Absolute)
    $logoBitmap.EndInit()
    $logoBitmap.Freeze()
    $headerLogo.Source = $logoBitmap
}
$taskbarIconPath = Join-Path (Split-Path -Parent $PSScriptRoot) "assets\app-icon.ico"
if (Test-Path -LiteralPath $taskbarIconPath -PathType Leaf) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri($taskbarIconPath, [UriKind]::Absolute)))
}

$script:appState = Get-SuamiSihatAppState
$vm.Workspace = $script:appState.DefaultWorkspace
$vm.JobId = $script:appState.NextJobNumber
$vm.ProjectName = ""
$vm.ProjectDescription = ""
$vm.InjectMasterCanvas = $true
$vm.IncludeRevisions = $false
$vm.IncludeRawMedia = $false
$vm.StaffId = $script:appState.StaffID
$vm.DesignerName = $script:appState.DesignerName
$vm.Department = $script:appState.Department
$vm.Email = $script:appState.DesignerEmail
$vm.AvatarPath = $script:appState.AvatarPath
$vm.Destination = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "SuamiSihat Brand Assets"
$vm.CpmInstallPath = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management"
$vm.InstallStatus = "Ready to install."
$vm.InstallLog = ""
$vm.InstallReport = "Installation has not started."
$vm.VersionStatus = "SS-CAM v$($script:AppVersion)"
$vm.HeaderContext = if ($InstallerMode) { "Setup Wizard | v$($script:AppVersion)" } else { "Creative Assets Management | v$($script:AppVersion)" }
$vm.DashboardTotal = "-"
$vm.DashboardLatest = "Scanning workspace..."
$vm.DashboardFileSize = "-"
$vm.DashboardTypeSummary = "Scanning..."
$vm.DashboardBrandSummary = "Scanning..."
$vm.DashboardThisMonth = "-"
$vm.DashboardDesignerCount = "-"
$vm.DashboardFileCount = "-"
$vm.DashboardStatus = "Waiting to scan the workspace."
$vm.CustomTemplateExtension = ""
$vm.SearchRoot = $script:appState.DefaultWorkspace
$vm.SearchQuery = ""
$vm.SearchDestination = if (@($script:appState.RecentProjects).Count -gt 0) { [string]$script:appState.RecentProjects[0].ProjectPath } else { $script:appState.DefaultWorkspace }
$vm.SearchStatus = "Select a project to load its files."
$vm.DesignerFolderStatus = "Enter part of a folder name, or leave blank to list all projects."
$vm.ProjectReadmeContent = "Select a project folder to view its README.md creative brief."
$vm.SelectedProjectPath = ""
$script:brandKitRegistration = Get-SuamiSihatBrandKitRegistration
$vm.BrandAssetsPath = [string]$script:brandKitRegistration.AssetsPath
$vm.BrandAssetsStatus = if ($script:brandKitRegistration.IsInstalled) {
    "Brand Kit detected and ready."
} else {
    "Brand Kit is not installed. Run the installer and select Brand Kit to enable this module."
}
(Get-Control "NavBrandAssets").Visibility = if ($script:brandKitRegistration.IsInstalled -or ($SmokeTest -and $PreviewView -eq "BrandAssets")) {
    [Windows.Visibility]::Visible
} else {
    [Windows.Visibility]::Collapsed
}

$licensePath = Join-Path (Split-Path -Parent $PSScriptRoot) "EULA.txt"
$vm.LicenseText = if (Test-Path -LiteralPath $licensePath -PathType Leaf) { Get-Content -LiteralPath $licensePath -Raw } else { "Licence agreement file is unavailable." }
$vm.LicenseReadStatus = "Scroll to the end of the agreement to enable acceptance."

$detectedInstall = Get-SuamiSihatInstalledVersion
Set-UninstallOptionVisibility -IsInstalled $detectedInstall.IsInstalled
if (-not $detectedInstall.IsInstalled) {
    $vm.InstallerVersionStatus = "No installed version detected. Package v$($script:AppVersion) is ready."
} elseif ([string]::IsNullOrWhiteSpace($detectedInstall.Version)) {
    $vm.InstallerVersionStatus = "An existing installation was detected. Its version could not be determined; package v$($script:AppVersion) can repair it."
} else {
    try {
        $installedVersion = [version]$detectedInstall.Version
        $packageVersion = [version]$script:AppVersion
        $vm.InstallerVersionStatus = if ($installedVersion -lt $packageVersion) {
            "Upgrade available: installed v$($detectedInstall.Version) -> package v$($script:AppVersion)."
        } elseif ($installedVersion -gt $packageVersion) {
            "A newer version is installed: v$($detectedInstall.Version). Package v$($script:AppVersion) would be a downgrade."
        } else {
            "v$($detectedInstall.Version) is already installed. Continue to repair or modify components."
        }
    } catch {
        $vm.InstallerVersionStatus = "Installed v$($detectedInstall.Version); package v$($script:AppVersion) is ready."
    }
}

@("Graphic & Print Design", "Social Media Content", "Video Production", "Brand Identity", "E-Commerce") | ForEach-Object { $vm.Presets.Add($_) }
@(
    "SS - SuamiSihat",
    "SSH - SuamiSihat Holding Sdn. Bhd.",
    "SSC - SuamiSihat Healthcare Sdn. Bhd.",
    "SSW - SuamiSihat Wellness Sdn. Bhd.",
    "SSE - SuamiSihat Ecommerce Sdn. Bhd.",
    "SST - SuamiSihat Technology Sdn. Bhd."
) | ForEach-Object { $vm.Brands.Add($_) }
((Get-Date).Year..((Get-Date).Year + 2)) | ForEach-Object { $vm.Years.Add([string]$_) }
@("Meta / IG Square (1:1 - 1080x1080 RGB)", "Meta / IG Story (9:16 - 1080x1920 RGB)", "YouTube / Video (16:9 - 1920x1080 RGB)", "Print Production (CMYK 300 DPI)", "Flexible / Custom") | ForEach-Object { $vm.Platforms.Add($_) }
@(".afdesign", ".psd", ".ai") | ForEach-Object { $vm.TemplateExtensions.Add($_) }
$vm.SelectedPreset = $vm.Presets[0]
$vm.SelectedBrand = $vm.Brands[0]
$vm.SelectedYear = [string](Get-Date).Year
$vm.SelectedPlatform = $vm.Platforms[0]
$vm.SelectedTemplateExtension = $vm.TemplateExtensions[0]

foreach ($profile in @($script:appState.Profiles)) {
    if ($profile -and $profile.Name) { $vm.DesignerProfiles.Add([string]$profile.Name) }
}
if ($vm.DesignerProfiles.Count -gt 0) { $designerCombo.SelectedIndex = 0 }

function Add-DesignerFolderChoice([string]$Name, [string]$StaffId, [hashtable]$Seen) {
    $cleanId = if ($null -eq $StaffId) { "" } else { $StaffId.Trim().ToUpperInvariant() }
    $key = if ([string]::IsNullOrWhiteSpace($cleanId)) { "__ALL__" } else { $cleanId }
    if ($Seen.ContainsKey($key)) { return }
    $choice = New-Object SuamiSihat.Wpf.DesignerFolderChoice
    $choice.Name = if ([string]::IsNullOrWhiteSpace($Name)) { $cleanId } else { $Name.Trim() }
    $choice.StaffId = $cleanId
    $vm.DesignerFolderChoices.Add($choice)
    $Seen[$key] = $true
}

function Refresh-DesignerFolderChoices {
    $currentSelection = $vm.SelectedDesignerFolderId
    $vm.DesignerFolderChoices.Clear()
    $seen = @{}
    Add-DesignerFolderChoice -Name "All designers" -StaffId "" -Seen $seen
    if (-not [string]::IsNullOrWhiteSpace($vm.StaffId)) {
        Add-DesignerFolderChoice -Name $vm.DesignerName -StaffId $vm.StaffId -Seen $seen
    }
    if (Test-Path -LiteralPath $vm.SearchRoot -PathType Container) {
        try {
            foreach ($directory in @(Get-ChildItem -LiteralPath $vm.SearchRoot -Directory -ErrorAction Stop)) {
                if ($directory.Name -notmatch '^\d{4}$' -and $directory.Name -notmatch '^\d{6}_') {
                    Add-DesignerFolderChoice -Name $directory.Name -StaffId $directory.Name -Seen $seen
                }
            }
        } catch {}
    }
    $matchingChoice = @($vm.DesignerFolderChoices) | Where-Object { $_.StaffId -eq $currentSelection } | Select-Object -First 1
    $vm.SelectedDesignerFolderId = if ($matchingChoice) { $matchingChoice.StaffId } else { "" }
    $designerFolderCombo.SelectedIndex = if ($matchingChoice) { $vm.DesignerFolderChoices.IndexOf($matchingChoice) } else { 0 }
}

Refresh-DesignerFolderChoices

function Get-SubBrandCode([string]$Value) {
    if ($Value -match '^\s*([A-Z]{2,4})\s+-\s+') { return $matches[1].ToUpperInvariant() }
    switch -Wildcard ($Value) {
        "*HOLDING*" { "SSH" }
        "*HEALTHCARE*" { "SSC" }
        "*WELLNESS*" { "SSW" }
        "*ECOM*" { "SSE" }
        "*TECH*" { "SST" }
        "SSH" { "SSH" }
        "SSC" { "SSC" }
        "SSW" { "SSW" }
        "SSE" { "SSE" }
        "SST" { "SST" }
        default { "SS" }
    }
}

function Get-ProjectFolderName {
    $dateCode = "$($vm.SelectedYear)$((Get-Date).ToString('MM'))"
    $job = (($vm.JobId -replace '\s+', '').ToUpper())
    $job = ConvertTo-SuamiSihatJobID $job
    if ([string]::IsNullOrWhiteSpace($job)) { $job = "0001D" }
    $project = (($vm.ProjectName -replace '[\\/:*?"<>|]', '_') -replace '\s+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($project)) { $project = "Project" }
    return "${dateCode}_${job}_$(Get-SubBrandCode $vm.SelectedBrand)_${project}"
}

function Update-ProjectPreview {
    $folderName = Get-ProjectFolderName
    $yearFolder = "$($vm.SelectedYear)"
    $monthFolder = "$(Get-Date -Format 'yyyyMM')_$(Get-Date -Format 'MMMM')"
    $root = $vm.Workspace
    if (-not [string]::IsNullOrWhiteSpace($vm.StaffId)) { $root = Join-Path $root $vm.StaffId }
    $vm.PreviewPath = Join-Path (Join-Path (Join-Path $root $yearFolder) $monthFolder) $folderName

    $folders = switch -Wildcard ($vm.SelectedPreset) {
        "*Social*" { @("Working Files", "Source Assets", "Copywriting", "Final Exports") }
        "*Video*" { @("Project Files", "Footage", "Audio", "Graphics", "Final Exports") }
        "*Brand*" { @("Strategy", "Identity System", "Applications", "Guidelines", "Final Exports") }
        "*E-Commerce*" { @("Working Files", "Product Assets", "Copywriting", "Final Exports") }
        default { @("Artwork Design", "Artwork Mockup", "Assets", "Production") }
    }
    if ($vm.IncludeRevisions) { $folders += "Client Revisions" }
    if ($vm.IncludeRawMedia) { $folders += "RAW Media" }
    $tree = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $folders.Count; $index++) {
        $marker = if ($index -eq ($folders.Count - 1)) { "\--" } else { "+--" }
        $tree.Add("$marker $($folders[$index])")
        if ($index -eq 0 -and $vm.InjectMasterCanvas) {
            $tree.Add("|   \-- ${folderName}$($vm.SelectedTemplateExtension)")
        }
    }
    $vm.FolderStructure = $tree -join [Environment]::NewLine
}

function Refresh-RecentProjects {
    $vm.RecentProjects.Clear()
    foreach ($project in @($script:appState.RecentProjects) | Select-Object -First 5) {
        $vm.RecentProjects.Add("$($project.FolderName)  ($($project.Created))")
    }
    $vm.HasRecent = $vm.RecentProjects.Count -gt 0
    if ($vm.HasRecent) { $recentCombo.SelectedIndex = 0 }
}

function Update-NasStatus {
    if (Test-NASAvailable -WorkspaceRoot $vm.Workspace) {
        $vm.NasStatus = "NAS online"
    } else {
        $vm.NasStatus = "NAS offline | local Job ID pool active"
    }
}

$script:dashboardTask = $null
$dashboardTimer = New-Object Windows.Threading.DispatcherTimer
$dashboardTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$dashboardTimer.Add_Tick({
    if ($null -eq $script:dashboardTask -or -not $script:dashboardTask.IsCompleted) { return }
    $dashboardTimer.Stop()
    try {
        $snapshot = $script:dashboardTask.Result
        $vm.DashboardTotal = [string]$snapshot.TotalProjects
        $vm.DashboardLatest = [string]$snapshot.LatestProject
        $vm.DashboardFileSize = [SuamiSihat.Wpf.WorkspaceScanner]::FormatBytes($snapshot.TotalBytes)
        $vm.DashboardTypeSummary = [string]$snapshot.ProjectTypes
        $vm.DashboardBrandSummary = [string]$snapshot.SubBrands
        $vm.DashboardThisMonth = [string]$snapshot.ThisMonth
        $vm.DashboardDesignerCount = [string]$snapshot.DesignerCount
        $vm.DashboardFileCount = ('{0:N0}' -f $snapshot.TotalFiles)
        $vm.DashboardTypeChart.Clear()
        foreach ($item in $snapshot.TypeChart) { $vm.DashboardTypeChart.Add($item) }
        $vm.DashboardBrandChart.Clear()
        foreach ($item in $snapshot.BrandChart) { $vm.DashboardBrandChart.Add($item) }
        $vm.DashboardActivityChart.Clear()
        foreach ($item in $snapshot.ActivityChart) { $vm.DashboardActivityChart.Add($item) }
        $vm.DashboardStatus = "Metrics refreshed $((Get-Date).ToString('dd MMM yyyy, HH:mm'))."
    } catch {
        $vm.DashboardStatus = "Unable to scan workspace: $($_.Exception.GetBaseException().Message)"
    } finally {
        $script:dashboardTask = $null
    }
})

function Start-DashboardRefresh {
    if ($script:dashboardTask -and -not $script:dashboardTask.IsCompleted) { return }
    if ([string]::IsNullOrWhiteSpace($vm.Workspace) -or -not (Test-Path -LiteralPath $vm.Workspace -PathType Container)) {
        $vm.DashboardStatus = "Choose an available Synology workspace in User Profile."
        $vm.DashboardTotal = "0"
        $vm.DashboardLatest = "Workspace unavailable"
        $vm.DashboardFileSize = "0 B"
        $vm.DashboardThisMonth = "0"
        $vm.DashboardDesignerCount = "0"
        $vm.DashboardFileCount = "0"
        $vm.DashboardTypeChart.Clear()
        $vm.DashboardBrandChart.Clear()
        $vm.DashboardActivityChart.Clear()
        return
    }
    $vm.DashboardStatus = "Scanning projects and file sizes in the background..."
    $script:dashboardTask = [SuamiSihat.Wpf.WorkspaceScanner]::ScanAsync($vm.Workspace)
    $dashboardTimer.Start()
}

$script:searchTask = $null
$script:searchTaskProjectPath = ""
$script:pendingProjectPath = ""
$searchTimer = New-Object Windows.Threading.DispatcherTimer
$searchTimer.Interval = [TimeSpan]::FromMilliseconds(200)
$searchTimer.Add_Tick({
    if ($null -eq $script:searchTask -or -not $script:searchTask.IsCompleted) { return }
    $searchTimer.Stop()
    $vm.IsSearching = $false
    try {
        $items = $script:searchTask.Result
        if ($script:searchTaskProjectPath.Equals($vm.SelectedProjectPath, [StringComparison]::OrdinalIgnoreCase)) {
            $vm.SearchResults.Clear()
            foreach ($item in $items) { $vm.SearchResults.Add($item) }
            $suffix = if ($items.Count -ge 500) { " (showing first 500)" } else { "" }
            $vm.SearchStatus = "$($items.Count) file(s) in selected project$suffix."
        }
    } catch {
        $vm.SearchStatus = "Search failed: $($_.Exception.GetBaseException().Message)"
    } finally {
        $script:searchTask = $null
        $script:searchTaskProjectPath = ""
        $pendingPath = $script:pendingProjectPath
        $script:pendingProjectPath = ""
        if (-not [string]::IsNullOrWhiteSpace($pendingPath) -and $pendingPath.Equals($vm.SelectedProjectPath, [StringComparison]::OrdinalIgnoreCase)) {
            Start-ProjectFileListing -ProjectPath $pendingPath
        }
    }
})

function Start-ProjectFileListing([string]$ProjectPath) {
    if ($script:searchTask -and -not $script:searchTask.IsCompleted) {
        $script:pendingProjectPath = $ProjectPath
        return
    }
    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        $vm.SearchStatus = "The selected project folder is unavailable."
        return
    }
    $vm.IsSearching = $true
    $vm.SearchStatus = "Loading project files..."
    $script:searchTaskProjectPath = $ProjectPath
    $script:searchTask = [SuamiSihat.Wpf.WorkspaceScanner]::ListProjectFilesAsync($ProjectPath, 500)
    $searchTimer.Start()
}

function Show-SelectedProject {
    param([object]$Folder = $null)
    $folder = if ($null -ne $Folder) { $Folder } else { $designerFoldersGrid.SelectedItem }
    $vm.SearchResults.Clear()
    if (-not $folder -or -not (Test-Path -LiteralPath $folder.FullPath -PathType Container)) {
        $vm.SelectedProjectPath = ""
        $vm.ProjectReadmeContent = "Select a project folder to view its README.md creative brief."
        $vm.SearchStatus = "Select a project to load its files."
        return
    }

    $vm.SelectedProjectPath = [string]$folder.FullPath
    $readmePath = Join-Path $folder.FullPath "README.md"
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        try {
            $readmeFile = Get-Item -LiteralPath $readmePath
            if ($readmeFile.Length -gt 1048576) {
                $vm.ProjectReadmeContent = "README.md is larger than 1 MB. Open the project folder to view it."
            } else {
                $vm.ProjectReadmeContent = Get-Content -LiteralPath $readmePath -Raw
            }
        } catch {
            $vm.ProjectReadmeContent = "README.md could not be read: $($_.Exception.Message)"
        }
    } else {
        $vm.ProjectReadmeContent = "# No README.md found`n`nProject: $($folder.Project)`nPath: $($folder.FullPath)"
    }
    Start-ProjectFileListing -ProjectPath $folder.FullPath
}

$script:designerFolderTask = $null
$designerFolderTimer = New-Object Windows.Threading.DispatcherTimer
$designerFolderTimer.Interval = [TimeSpan]::FromMilliseconds(200)
$designerFolderTimer.Add_Tick({
    if ($null -eq $script:designerFolderTask -or -not $script:designerFolderTask.IsCompleted) { return }
    $designerFolderTimer.Stop()
    $vm.IsSearching = $false
    try {
        $folders = $script:designerFolderTask.Result
        $vm.DesignerFolders.Clear()
        foreach ($folder in $folders) { $vm.DesignerFolders.Add($folder) }
        $suffix = if ($folders.Count -ge 500) { " (showing first 500)" } else { "" }
        $vm.DesignerFolderStatus = "$($folders.Count) project folder(s) found$suffix."
        if ($folders.Count -gt 0) {
            $designerFoldersGrid.SelectedIndex = 0
        } else {
            Show-SelectedProject
        }
    } catch {
        $vm.DesignerFolderStatus = "Unable to list designer folders: $($_.Exception.GetBaseException().Message)"
    } finally {
        $script:designerFolderTask = $null
    }
})

function Start-DesignerFolderListing {
    if ($script:designerFolderTask -and -not $script:designerFolderTask.IsCompleted) { return }
    if (-not (Test-Path -LiteralPath $vm.SearchRoot -PathType Container)) {
        $vm.DesignerFolderStatus = "The selected Synology root folder is unavailable."
        return
    }
    $vm.DesignerFolders.Clear()
    $vm.SearchResults.Clear()
    $vm.ProjectReadmeContent = "Select a project folder to view its README.md creative brief."
    $designerName = if ([string]::IsNullOrWhiteSpace($vm.SelectedDesignerFolderId)) { "all designers" } else { $vm.SelectedDesignerFolderId }
    $query = ([string]$vm.SearchQuery).Trim()
    $queryDescription = if ([string]::IsNullOrWhiteSpace($query)) { "all project folders" } else { "folders matching '$query'" }
    $vm.IsSearching = $true
    $vm.DesignerFolderStatus = "Searching $queryDescription for $designerName..."
    $script:designerFolderTask = [SuamiSihat.Wpf.WorkspaceScanner]::ListDesignerFoldersAsync($vm.SearchRoot, $vm.SelectedDesignerFolderId, $query, 500)
    $designerFolderTimer.Start()
}

function Select-Folder([string]$InitialPath) {
    $shell = New-Object -ComObject Shell.Application
    try {
        $folder = $shell.BrowseForFolder(0, "Select folder", 0, $InitialPath)
        if ($folder) { return [string]$folder.Self.Path }
        return $null
    } finally {
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null
    }
}

function Open-BrandAssetFolder([string]$RelativePath) {
    $target = Join-Path $vm.BrandAssetsPath $RelativePath
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        [Windows.MessageBox]::Show("This Brand Kit folder is unavailable:`n`n$target`n`nRun the installer and select Brand Kit to repair the assets.", "Folder unavailable", "OK", "Information") | Out-Null
        return
    }
    Start-Process -FilePath "explorer.exe" -ArgumentList @($target)
}

function Open-SuamiSihatLink([string]$Url) {
    try { Start-Process -FilePath $Url } catch {
        [Windows.MessageBox]::Show("The link could not be opened:`n$Url", "Unable to open link", "OK", "Warning") | Out-Null
    }
}

function Add-MarkdownInlineRuns([Windows.Documents.Paragraph]$Paragraph, [string]$Text) {
    $cursor = 0
    foreach ($match in [regex]::Matches($Text, '(\*\*.+?\*\*|`.+?`)')) {
        if ($match.Index -gt $cursor) {
            [void]$Paragraph.Inlines.Add((New-Object Windows.Documents.Run($Text.Substring($cursor, $match.Index - $cursor))))
        }
        $token = $match.Value
        if ($token.StartsWith('**')) {
            $run = New-Object Windows.Documents.Run($token.Substring(2, $token.Length - 4))
            $run.FontWeight = [Windows.FontWeights]::SemiBold
        } else {
            $run = New-Object Windows.Documents.Run($token.Substring(1, $token.Length - 2))
            $run.FontFamily = New-Object Windows.Media.FontFamily("Consolas")
            $run.Background = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(241,245,249))
        }
        [void]$Paragraph.Inlines.Add($run)
        $cursor = $match.Index + $match.Length
    }
    if ($cursor -lt $Text.Length) {
        [void]$Paragraph.Inlines.Add((New-Object Windows.Documents.Run($Text.Substring($cursor))))
    }
}

function New-MarkdownParagraph([string]$Text, [double]$FontSize = 13, [bool]$Bold = $false) {
    $paragraph = New-Object Windows.Documents.Paragraph
    $paragraph.Margin = New-Object Windows.Thickness(0,3,0,7)
    $paragraph.FontSize = $FontSize
    if ($Bold) { $paragraph.FontWeight = [Windows.FontWeights]::SemiBold }
    Add-MarkdownInlineRuns -Paragraph $paragraph -Text $Text
    return $paragraph
}

function ConvertFrom-MarkdownToFlowDocument([string]$Markdown) {
    $document = New-Object Windows.Documents.FlowDocument
    $document.PagePadding = New-Object Windows.Thickness(22)
    $document.FontFamily = New-Object Windows.Media.FontFamily("Segoe UI")
    $document.FontSize = 13
    $document.Foreground = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(30,41,59))
    $lines = @($Markdown -split "`r?`n")
    # Strip YAML frontmatter (--- ... ---) before rendering
    $startIndex = 0
    if ($lines.Count -gt 0 -and ([string]$lines[0]).Trim() -eq '---') {
        $closeIdx = 1
        while ($closeIdx -lt $lines.Count -and ([string]$lines[$closeIdx]).Trim() -ne '---') { $closeIdx++ }
        $startIndex = if ($closeIdx -lt $lines.Count) { $closeIdx + 1 } else { 0 }
    }
    $index = $startIndex
    while ($index -lt $lines.Count) {
        $line = [string]$lines[$index]
        if ([string]::IsNullOrWhiteSpace($line)) { $index++; continue }

        if ($line -match '^(#{1,4})\s+(.+)$') {
            $level = $matches[1].Length
            $size = switch ($level) { 1 { 25 } 2 { 19 } 3 { 16 } default { 14 } }
            $heading = New-MarkdownParagraph -Text $matches[2] -FontSize $size -Bold $true
            $heading.Foreground = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(4,51,136))
            $heading.Margin = New-Object Windows.Thickness(0, $(if ($level -eq 1) { 0 } else { 12 }), 0, 8)
            [void]$document.Blocks.Add($heading)
            $index++; continue
        }

        if ($line.TrimStart().StartsWith('|')) {
            $tableLines = @()
            while ($index -lt $lines.Count -and ([string]$lines[$index]).TrimStart().StartsWith('|')) {
                $tableLines += [string]$lines[$index]
                $index++
            }
            $dataRows = @($tableLines | Where-Object { $_ -notmatch '^\s*\|?[\s:\-|]+\|?\s*$' })
            if ($dataRows.Count -gt 0) {
                $table = New-Object Windows.Documents.Table
                $table.CellSpacing = 0
                $table.Margin = New-Object Windows.Thickness(0,5,0,13)
                $columnCount = @(($dataRows[0].Trim().Trim('|')) -split '\|').Count
                for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
                    [void]$table.Columns.Add((New-Object Windows.Documents.TableColumn))
                }
                $rowGroup = New-Object Windows.Documents.TableRowGroup
                for ($rowIndex = 0; $rowIndex -lt $dataRows.Count; $rowIndex++) {
                    $row = New-Object Windows.Documents.TableRow
                    if ($rowIndex -eq 0) { $row.Background = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(226,232,240)) }
                    foreach ($cellText in @(($dataRows[$rowIndex].Trim().Trim('|')) -split '\|')) {
                        $cellParagraph = New-MarkdownParagraph -Text $cellText.Trim() -FontSize 12 -Bold ($rowIndex -eq 0)
                        $cellParagraph.Margin = New-Object Windows.Thickness(0)
                        $cell = New-Object Windows.Documents.TableCell($cellParagraph)
                        $cell.Padding = New-Object Windows.Thickness(8,6,8,6)
                        $cell.BorderBrush = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(203,213,225))
                        $cell.BorderThickness = New-Object Windows.Thickness(0,0,0,1)
                        [void]$row.Cells.Add($cell)
                    }
                    [void]$rowGroup.Rows.Add($row)
                }
                [void]$table.RowGroups.Add($rowGroup)
                [void]$document.Blocks.Add($table)
            }
            continue
        }

        if ($line -match '^\s*[-*]\s+(.+)$') {
            $list = New-Object Windows.Documents.List
            $list.MarkerStyle = [Windows.TextMarkerStyle]::Disc
            $list.Margin = New-Object Windows.Thickness(18,3,0,9)
            while ($index -lt $lines.Count -and ([string]$lines[$index]) -match '^\s*[-*]\s+(.+)$') {
                $itemParagraph = New-MarkdownParagraph -Text $matches[1] -FontSize 13
                $itemParagraph.Margin = New-Object Windows.Thickness(0,1,0,3)
                [void]$list.ListItems.Add((New-Object Windows.Documents.ListItem($itemParagraph)))
                $index++
            }
            [void]$document.Blocks.Add($list)
            continue
        }

        [void]$document.Blocks.Add((New-MarkdownParagraph -Text $line))
        $index++
    }
    return $document
}

function Update-ReadmePreview {
    try {
        $readmePreviewViewer.Document = ConvertFrom-MarkdownToFlowDocument ([string]$vm.ProjectReadmeContent)
    } catch {
        $fallback = New-Object Windows.Documents.FlowDocument
        [void]$fallback.Blocks.Add((New-MarkdownParagraph -Text "README preview could not be rendered: $($_.Exception.Message)"))
        $readmePreviewViewer.Document = $fallback
    }
}

function Set-ReadmeViewMode([bool]$ShowPreview) {
    $script:readmePreviewMode = $ShowPreview
    $readmePreviewViewer.Visibility = if ($ShowPreview) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $readmeRawTextBox.Visibility = if ($ShowPreview) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }
    $readmePreviewButton.Background = if ($ShowPreview) { $window.FindResource("BrandNavy") } else { New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(226,232,240)) }
    $readmePreviewButton.Foreground = if ($ShowPreview) { [Windows.Media.Brushes]::White } else { $window.FindResource("BrandInk") }
    $readmeRawButton.Background = if ($ShowPreview) { New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(226,232,240)) } else { $window.FindResource("BrandNavy") }
    $readmeRawButton.Foreground = if ($ShowPreview) { $window.FindResource("BrandInk") } else { [Windows.Media.Brushes]::White }
    if ($ShowPreview) { Update-ReadmePreview }
}

function Show-MarkdownReport([string]$FileName, [string]$Title) {
    $reportPath = Join-Path (Join-Path $vm.BrandAssetsPath "Reports") $FileName
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        [Windows.MessageBox]::Show("This report is unavailable:`n`n$reportPath`n`nRun Brand Kit repair to regenerate it.", "Report unavailable", "OK", "Information") | Out-Null
        return
    }

    $reportWindow = New-Object Windows.Window
    $reportWindow.Title = $Title
    $reportWindow.Width = 820
    $reportWindow.Height = 650
    $reportWindow.MinWidth = 620
    $reportWindow.MinHeight = 440
    $reportWindow.Owner = $window
    $reportWindow.Icon = $window.Icon
    $reportWindow.WindowStartupLocation = "CenterOwner"
    $reportWindow.Background = [Windows.Media.Brushes]::White

    $layout = New-Object Windows.Controls.DockPanel
    $layout.Margin = New-Object Windows.Thickness(18)
    $closeButton = New-Object Windows.Controls.Button
    $closeButton.Content = "Close"
    $closeButton.Width = 100
    $closeButton.HorizontalAlignment = "Right"
    $closeButton.Margin = New-Object Windows.Thickness(0,12,0,0)
    [Windows.Controls.DockPanel]::SetDock($closeButton, "Bottom")
    $closeButton.Add_Click({ $reportWindow.Close() })
    [void]$layout.Children.Add($closeButton)

    $reportViewer = New-Object Windows.Controls.FlowDocumentScrollViewer
    $reportViewer.Document = ConvertFrom-MarkdownToFlowDocument (Get-Content -LiteralPath $reportPath -Raw)
    $reportViewer.VerticalScrollBarVisibility = "Auto"
    $reportViewer.HorizontalScrollBarVisibility = "Disabled"
    $reportViewer.IsToolBarVisible = $false
    [void]$layout.Children.Add($reportViewer)
    $reportWindow.Content = $layout
    [void]$reportWindow.ShowDialog()
}

function Show-ImagePopup {
    param([string]$ImagePath, [string]$Title = "")
    if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) { return }
    try {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource = [System.Uri]::new([System.IO.Path]::GetFullPath($ImagePath))
        $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit(); $bmp.Freeze()
        $popup = New-Object Windows.Window
        $popup.Title = if ($Title) { $Title } else { [System.IO.Path]::GetFileName($ImagePath) }
        $popup.Width = 860; $popup.Height = 660
        $popup.MinWidth = 320; $popup.MinHeight = 240
        $popup.WindowStartupLocation = "CenterOwner"
        $popup.Owner = $window
        $popup.Background = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(15,22,36))
        $popup.WindowStyle = "SingleBorderWindow"
        $img = New-Object Windows.Controls.Image
        $img.Source = $bmp
        $img.Stretch = [Windows.Media.Stretch]::Uniform
        $img.Margin = New-Object Windows.Thickness(16)
        $popup.Content = $img
        [void]$popup.ShowDialog()
    } catch {}
}

function Update-ProductionThumbnails {
    $panel   = Get-Control "ProductionThumbnailPanel"
    $status  = Get-Control "ProductionStatusText"
    $panel.Children.Clear()
    $path = [string]$vm.SelectedProjectPath
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
        $status.Text = "Select a project folder to preview exported files."
        return
    }
    $imgExts = @('.png','.jpg','.jpeg','.gif','.bmp','.tiff','.tif','.webp')
    $scanDirs = @("Production","Export","Exports","Output","Outputs") | ForEach-Object { Join-Path $path $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
    $files = @($scanDirs | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse -ErrorAction SilentlyContinue } | Where-Object { $imgExts -contains $_.Extension.ToLower() } | Select-Object -First 60)
    if ($files.Count -eq 0) {
        $status.Text = "No exported images found in Production/Export subfolders."
        return
    }
    $status.Text = "$($files.Count) file(s) - click any thumbnail to preview full size"
    foreach ($file in $files) {
        try {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = [System.Uri]::new($file.FullName)
            $bmp.DecodePixelWidth = 160
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit(); $bmp.Freeze()
            $img = New-Object Windows.Controls.Image
            $img.Source = $bmp; $img.Width = 160; $img.Height = 120
            $img.Stretch = [Windows.Media.Stretch]::UniformToFill
            $img.VerticalAlignment = "Top"
            $lbl = New-Object Windows.Controls.TextBlock
            $lbl.Text = $file.Name
            $lbl.FontSize = 10; $lbl.MaxWidth = 160
            $lbl.TextTrimming = "CharacterEllipsis"
            $lbl.Foreground = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(71,85,105))
            $lbl.Padding = New-Object Windows.Thickness(4,3,4,4)
            $sp = New-Object Windows.Controls.StackPanel
            [void]$sp.Children.Add($img); [void]$sp.Children.Add($lbl)
            $card = New-Object Windows.Controls.Border
            $card.Margin = New-Object Windows.Thickness(5)
            $card.BorderBrush = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(203,213,225))
            $card.BorderThickness = New-Object Windows.Thickness(1)
            $card.CornerRadius = New-Object Windows.CornerRadius(6)
            $card.Background = [Windows.Media.Brushes]::White
            $card.Cursor = [Windows.Input.Cursors]::Hand
            $card.Child = $sp
            $filePath = $file.FullName; $fileName = $file.Name
            $card.Add_MouseLeftButtonDown({ Show-ImagePopup -ImagePath $filePath -Title $fileName }.GetNewClosure())
            [void]$panel.Children.Add($card)
        } catch {}
    }
}

function Save-WpfSettings {
    $previousWorkspace = $script:appState.DefaultWorkspace
    $script:appState = Save-SuamiSihatAppState `
        -LastProjectPath $script:appState.LastProjectPath `
        -LastProjectName $script:appState.LastProjectName `
        -LastJobNumber $script:appState.LastJobNumber `
        -NextJobNumber $vm.JobId `
        -DefaultWorkspace $vm.Workspace `
        -DesignerName $vm.DesignerName `
        -Department $vm.Department `
        -DesignerEmail $vm.Email `
        -AvatarPath $vm.AvatarPath `
        -StaffID $vm.StaffId `
        -LocalJobPool @($script:appState.LocalJobPool) `
        -PendingSync @($script:appState.PendingSync)
    $vm.JobId = $script:appState.NextJobNumber
    if ([string]::IsNullOrWhiteSpace($vm.SearchRoot) -or $vm.SearchRoot -eq $previousWorkspace) { $vm.SearchRoot = $vm.Workspace }
    Refresh-DesignerFolderChoices
    $vm.SettingsStatus = "Settings and profile saved."
    Update-ProjectPreview
    Start-DashboardRefresh
    Update-AvatarDisplay
}

function Update-AvatarDisplay {
    $avatarImg = Get-Control "SidebarAvatarImage"
    $avatarHolder = Get-Control "AvatarPlaceholder"
    $path = [string]$vm.AvatarPath
    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        try {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = [System.Uri]::new([System.IO.Path]::GetFullPath($path))
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $bmp.Freeze()
            $brush = New-Object Windows.Media.ImageBrush
            $brush.ImageSource = $bmp
            $brush.Stretch = [Windows.Media.Stretch]::UniformToFill
            $avatarImg.Background = $brush
            $avatarImg.Visibility = [Windows.Visibility]::Visible
            $avatarHolder.Visibility = [Windows.Visibility]::Collapsed
        } catch {
            $avatarImg.Background = $null
            $avatarImg.Visibility = [Windows.Visibility]::Collapsed
            $avatarHolder.Visibility = [Windows.Visibility]::Visible
        }
    } else {
        $avatarImg.Background = $null
        $avatarImg.Visibility = [Windows.Visibility]::Collapsed
        $avatarHolder.Visibility = [Windows.Visibility]::Visible
    }
}

function Set-InstallerStep([int]$Index) {
    if ($Index -lt 0 -or $Index -gt 3) { return }
    $installerSteps.SelectedIndex = $Index
    for ($step = 0; $step -lt $installerStepLabels.Count; $step++) {
        $installerStepLabels[$step].Opacity = if ($step -eq $Index) { 1.0 } elseif ($step -lt $Index) { 0.75 } else { 0.45 }
    }
}

function Enter-InstallerSurface {
    $currentInstall = Get-SuamiSihatInstalledVersion
    Set-UninstallOptionVisibility -IsInstalled $currentInstall.IsInstalled
    $views.SelectedIndex = 0
    $sidebar.Visibility = [Windows.Visibility]::Collapsed
    $sidebarColumn.Width = New-Object Windows.GridLength(0)
    $appStatusBar.Visibility = [Windows.Visibility]::Collapsed
    $vm.HeaderContext = "Setup Wizard | v$($script:AppVersion)"
    (Get-Control "InstallerBack4").Visibility = [Windows.Visibility]::Visible
    (Get-Control "OpenInstalledAppButton").Visibility = [Windows.Visibility]::Collapsed
    (Get-Control "CloseSetupButton").Content = "Close"
    $vm.InstallReport = "Installation has not started."
    $script:uninstallReportMode = $false
    Set-InstallerStep 0
}

function Refresh-InstallerSystemCheck {
    $systemInfo = Get-WorkstationInformation
    $windowsReady = $false
    try { $windowsReady = ([version]$systemInfo.WindowsVersion).Major -ge 10 } catch {}
    $memoryReady = $systemInfo.MemoryGB -is [ValueType] -and [double]$systemInfo.MemoryGB -ge 16
    $architectureReady = $systemInfo.Architecture -eq "X64"
    $processorReady = [int]$systemInfo.ProcessorCores -ge 6
    $graphicsReady = [double]$systemInfo.GraphicsMemoryGB -ge 4
    $storageReady = $systemInfo.SystemDriveFreeGB -is [ValueType] -and [double]$systemInfo.SystemDriveFreeGB -ge 100
    $displayWidth = [int][Windows.SystemParameters]::PrimaryScreenWidth
    $displayHeight = [int][Windows.SystemParameters]::PrimaryScreenHeight
    $displayReady = [Math]::Max($displayWidth, $displayHeight) -ge 1920 -and [Math]::Min($displayWidth, $displayHeight) -ge 1080
    $pcSpecsGrid.ItemsSource = @(
        [pscustomobject]@{ Status = $(if ($windowsReady) { "Ready" } else { "Review" }); Component = "Windows"; Detected = $systemInfo.Windows; Target = "Windows 10+ (Windows 11 recommended)" },
        [pscustomobject]@{ Status = $(if ($architectureReady) { "Ready" } else { "Review" }); Component = "Architecture"; Detected = $systemInfo.Architecture; Target = "64-bit" },
        [pscustomobject]@{ Status = $(if ($memoryReady) { "Ready" } else { "Review" }); Component = "Memory"; Detected = "$($systemInfo.MemoryGB) GB RAM"; Target = "16 GB minimum; 32 GB recommended" },
        [pscustomobject]@{ Status = $(if ($processorReady) { "Ready" } else { "Review" }); Component = "Processor"; Detected = "$($systemInfo.ProcessorCores) cores - $($systemInfo.Processor)"; Target = "6+ cores recommended" },
        [pscustomobject]@{ Status = $(if ($graphicsReady) { "Ready" } else { "Review" }); Component = "Graphics"; Detected = "$($systemInfo.Graphics) ($($systemInfo.GraphicsMemoryGB) GB)"; Target = "4 GB+ VRAM recommended" },
        [pscustomobject]@{ Status = $(if ($storageReady) { "Ready" } else { "Review" }); Component = "Storage"; Detected = "$($systemInfo.SystemDriveFreeGB) GB free"; Target = "100 GB+ free recommended" },
        [pscustomobject]@{ Status = $(if ($displayReady) { "Ready" } else { "Review" }); Component = "Display"; Detected = "${displayWidth} x ${displayHeight}"; Target = "1920 x 1080+ recommended" }
    )

    $knownVersions = @{
        "Affinity" = "2.6.0"; "Canva" = "1.100.0"; "Figma" = "116.0.0"
        "Adobe Creative Cloud" = "6.6.0"; "Adobe Photoshop" = "26.0"
        "Adobe Illustrator" = "29.0"; "CapCut" = "5.0.0"; "DaVinci Resolve" = "19.1"
    }
    $softwareRows = @()
    foreach ($software in @(Get-DesignSoftwareInventory)) {
        $installedVersionText = if ([string]::IsNullOrWhiteSpace([string]$software.Version)) { "-" } else { "v$($software.Version)" }
        $reference = if ($knownVersions.ContainsKey($software.Name)) { "v$($knownVersions[$software.Name])" } else { "-" }
        $status = if (-not $software.Installed) { "Not installed" } else {
            $outdated = $false
            if ($software.Version -and $knownVersions.ContainsKey($software.Name)) {
                try {
                    $installedVersionObject = [version]([string]$software.Version -replace '[^0-9.]','')
                    $referenceVersionObject = [version]([string]$knownVersions[$software.Name])
                    $outdated = $installedVersionObject -lt $referenceVersionObject
                } catch {}
            }
            if ($outdated) { "Update available" } else { "Installed" }
        }
        $softwareRows += [pscustomobject]@{ Application = $software.Name; Status = $status; InstalledVersion = $installedVersionText; LatestVersion = $reference }
    }
    $softwareStatusGrid.ItemsSource = $softwareRows
}

function Prepare-LicenseStep {
    $vm.AcceptLicence = $false
    $acceptLicenseCheck.IsEnabled = $false
    $vm.LicenseReadStatus = "Scroll to the end of the agreement to enable acceptance."
    Set-InstallerStep 2
    $licenseTextBox.ScrollToHome()
}

$licenseTextBox.AddHandler([Windows.Controls.ScrollViewer]::ScrollChangedEvent, [Windows.Controls.ScrollChangedEventHandler]{
    param($sender, $eventArgs)
    $hasReachedEnd = $eventArgs.ExtentHeight -le $eventArgs.ViewportHeight -or
        ($eventArgs.VerticalOffset + $eventArgs.ViewportHeight) -ge ($eventArgs.ExtentHeight - 1)
    if ($hasReachedEnd) {
        $acceptLicenseCheck.IsEnabled = $true
        $vm.LicenseReadStatus = "End of agreement reached. You may now accept the licence."
    }
})

$vm.add_PropertyChanged({
    param($sender, $eventArgs)
    if ($eventArgs.PropertyName -in @("Workspace", "JobId", "ProjectName", "SelectedPreset", "SelectedBrand", "SelectedYear", "SelectedTemplateExtension", "InjectMasterCanvas", "IncludeRevisions", "IncludeRawMedia", "StaffId")) {
        Update-ProjectPreview
    }
    # Update Job ID suffix when preset changes
    if ($eventArgs.PropertyName -eq "SelectedPreset") {
        $newPrefix = Get-SuamiSihatJobPrefix -PresetName $vm.SelectedPreset
        $currentId = [string]$vm.JobId
        if ($currentId -match '^(\d+)[A-Za-z]+$') {
            $vm.JobId = "$($matches[1])$newPrefix"
        } elseif ($currentId -match '^(\d+)$') {
            $vm.JobId = "$($matches[1])$newPrefix"
        }
    }
    if ($eventArgs.PropertyName -eq "AvatarPath") {
        Update-AvatarDisplay
    }
    if ($eventArgs.PropertyName -eq "SelectedProjectPath") {
        Update-ProductionThumbnails
    }
    if ($eventArgs.PropertyName -eq "ProjectReadmeContent" -and $script:readmePreviewMode) {
        Update-ReadmePreview
    }
})

$readmePreviewButton.Add_Click({ Set-ReadmeViewMode -ShowPreview $true })
$readmeRawButton.Add_Click({ Set-ReadmeViewMode -ShowPreview $false })

$script:sidebarExpanded = $true
(Get-Control "ToggleSidebarButton").Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    $script:sidebarExpanded = -not $script:sidebarExpanded
    if ($script:sidebarExpanded) {
        $sidebar.Visibility = [Windows.Visibility]::Visible
        $sidebarColumn.Width = New-Object Windows.GridLength(235)
    } else {
        $sidebar.Visibility = [Windows.Visibility]::Collapsed
        $sidebarColumn.Width = New-Object Windows.GridLength(0)
    }
})

(Get-Control "NavDashboard").Add_Click({ $views.SelectedIndex = 1; Start-DashboardRefresh })
(Get-Control "NavProjects").Add_Click({ $views.SelectedIndex = 2 })
(Get-Control "NavSearch").Add_Click({ $views.SelectedIndex = 3; Start-DesignerFolderListing })
(Get-Control "NavBrandAssets").Add_Click({ $views.SelectedIndex = 4 })
(Get-Control "NavProfile").Add_Click({ $views.SelectedIndex = 5 })
(Get-Control "OpenColourPalettesButton").Add_Click({ Open-BrandAssetFolder "Colour Palettes" })
(Get-Control "OpenAssetLibrariesButton").Add_Click({ Open-BrandAssetFolder "Libraries" })
(Get-Control "OpenLogosButton").Add_Click({ Open-BrandAssetFolder "Logos" })
(Get-Control "OpenServiceDashboardButton").Add_Click({ Open-SuamiSihatLink "https://suamisihat.myds.me" })
(Get-Control "OpenInternalAssetsButton").Add_Click({ Open-SuamiSihatLink "https://assets.suamisihat.myds.me/" })
(Get-Control "OpenPublicBrandAssetsButton").Add_Click({ Open-SuamiSihatLink "https://suamisihat.com.my/brand-assets/" })
(Get-Control "OpenWorkstationReportButton").Add_Click({ Show-MarkdownReport "SuamiSihat-Workstation-Report.md" "SuamiSihat Workstation Report" })
(Get-Control "OpenFontInventoryReportButton").Add_Click({ Show-MarkdownReport "SuamiSihat-Font-Inventory.md" "SuamiSihat Font Inventory" })
(Get-Control "RefreshDashboardButton").Add_Click({ Start-DashboardRefresh })
(Get-Control "CloseSetupButton").Add_Click({ $window.Close() })
(Get-Control "CancelInstallerButton").Add_Click({ $window.Close() })
(Get-Control "InstallerUninstallButton").Add_Click({
    $installed = Get-SuamiSihatInstalledVersion
    if (-not $installed.IsInstalled) {
        [Windows.MessageBox]::Show("No SS-CAM installation was detected on this PC.", "Nothing to uninstall", "OK", "Information") | Out-Null
        return
    }

    $removeState = (Get-Control "RemoveAppStateCheck").IsChecked -eq $true
    $stateMessage = if ($removeState) {
        "User settings and recent-project history will also be removed."
    } else {
        "User settings and recent-project history will be preserved."
    }
    $confirmation = [Windows.MessageBox]::Show(
        "Uninstall Creative Project Management?`n`n$stateMessage`nBrand Kit assets and installed fonts will remain on this PC.",
        "Uninstall SS-CAM", "YesNo", "Warning")
    if ($confirmation -ne [Windows.MessageBoxResult]::Yes) { return }

    $script:uninstallReportMode = $true
    Set-InstallerStep 3
    (Get-Control "InstallerBack4").Content = "Back to Setup"
    (Get-Control "InstallerBack4").Visibility = [Windows.Visibility]::Visible
    (Get-Control "OpenInstalledAppButton").Visibility = [Windows.Visibility]::Collapsed
    (Get-Control "CloseSetupButton").Content = "Finish"
    $vm.InstallStatus = "Uninstalling Creative Project Management..."
    $vm.InstallReport = "Uninstall in progress..."
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)

    try {
        $result = Uninstall-SuamiSihatApp -RemoveAppState:$removeState
        $errorText = if (@($result.Errors).Count -gt 0) { @($result.Errors) -join [Environment]::NewLine } else { "None" }
        $vm.InstallStatus = if ($result.Success) { "Uninstall complete." } else { "Uninstall could not remove every application file." }
        $vm.InstallReport = @"
SUAMISIHAT UNINSTALLATION REPORT
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Creative Project Management: $(if ($result.Success) { 'Removed' } else { 'Removal incomplete' })
Previous path: $($result.ExePath)
User settings: $(if ($result.SettingsRemoved) { 'Removed' } else { 'Preserved' })
Brand Kit assets and fonts: Preserved
Errors: $errorText
"@
        if ($result.Success) {
            $vm.InstallerVersionStatus = "No installed version detected. Package v$($script:AppVersion) is ready."
            Set-UninstallOptionVisibility -IsInstalled $false
        }
    } catch {
        $vm.InstallStatus = "Uninstall failed."
        $vm.InstallReport = "Uninstall failed: $($_.Exception.Message)"
    }
})
(Get-Control "InstallerExpressButton").Add_Click({
    if (-not $vm.InstallBrandKit -and -not $vm.InstallProjectManager) {
        [Windows.MessageBox]::Show("Select at least one component to continue.", "Nothing selected", "OK", "Information") | Out-Null
        return
    }
    $script:expressInstall = $true
    Prepare-LicenseStep
})
(Get-Control "InstallerCustomButton").Add_Click({
    if (-not $vm.InstallBrandKit -and -not $vm.InstallProjectManager) {
        [Windows.MessageBox]::Show("Select at least one component to continue.", "Nothing selected", "OK", "Information") | Out-Null
        return
    }
    $script:expressInstall = $false
    Set-InstallerStep 1
    Refresh-InstallerSystemCheck
})
(Get-Control "InstallerBack2").Add_Click({ Set-InstallerStep 0 })
(Get-Control "InstallerNext2").Add_Click({
    if ($vm.InstallProjectManager -and [string]::IsNullOrWhiteSpace($vm.CpmInstallPath)) {
        [Windows.MessageBox]::Show("Choose an installation folder for Creative Project Management.", "Application path required", "OK", "Information") | Out-Null
        return
    }
    if ($vm.InstallProjectManager -and -not [string]::IsNullOrWhiteSpace($InstallerExePath) -and (Test-Path -LiteralPath $InstallerExePath -PathType Leaf)) {
        $sourceExePath = [IO.Path]::GetFullPath($InstallerExePath)
        $targetExePath = [IO.Path]::GetFullPath((Join-Path ([Environment]::ExpandEnvironmentVariables($vm.CpmInstallPath.Trim())) "SS-CAM.exe"))
        if (-not $sourceExePath.Equals($targetExePath, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $targetExePath -PathType Leaf)) {
            try {
                $lockTest = [IO.File]::Open($targetExePath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                $lockTest.Dispose()
            } catch {
                [Windows.MessageBox]::Show("Close the currently running SS-CAM application, then try the installation again.", "SS-CAM is running", "OK", "Information") | Out-Null
                return
            }
        }
    }
    Prepare-LicenseStep
})
(Get-Control "InstallerBack3").Add_Click({ if (-not $script:installationRunning) { Set-InstallerStep $(if ($script:expressInstall) { 0 } else { 1 }) } })
(Get-Control "InstallerBack4").Add_Click({
    if ($script:installationRunning) { return }
    if ($script:uninstallReportMode) {
        $script:uninstallReportMode = $false
        (Get-Control "InstallerBack4").Content = "Back"
        (Get-Control "CloseSetupButton").Content = "Close"
        Set-InstallerStep 0
    } else {
        Prepare-LicenseStep
    }
})
(Get-Control "RescanSystemButton").Add_Click({
    $button = Get-Control "RescanSystemButton"
    $button.IsEnabled = $false
    $button.Content = "Scanning..."
    try { Refresh-InstallerSystemCheck } finally { $button.Content = "Rescan"; $button.IsEnabled = $true }
})
(Get-Control "OpenInstalledAppButton").Add_Click({
    $installedApp = Join-Path $vm.CpmInstallPath "SS-CAM.exe"
    if (Test-Path -LiteralPath $installedApp -PathType Leaf) { Start-Process -FilePath $installedApp }
    $window.Close()
})

(Get-Control "ClearFormButton").Add_Click({
    $vm.ProjectName = ""
    $vm.ProjectDescription = ""
    $vm.SelectedPreset = $vm.Presets[0]
    $vm.SelectedBrand = $vm.Brands[0]
    $vm.StatusText = ""
})

(Get-Control "CopyNameButton").Add_Click({
    [Windows.Clipboard]::SetText((Get-ProjectFolderName))
    $vm.StatusText = "Project name copied."
})

(Get-Control "AddCustomExtensionButton").Add_Click({
    $extension = ([string]$vm.CustomTemplateExtension).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($extension)) {
        $vm.StatusText = "Enter a custom extension, for example .svg or .indd."
        return
    }
    if (-not $extension.StartsWith('.')) { $extension = ".$extension" }
    if ($extension -notmatch '^\.[a-z0-9]{1,12}$') {
        $vm.StatusText = "Custom extension may contain only a dot, letters and numbers."
        return
    }
    if (-not $vm.TemplateExtensions.Contains($extension)) { $vm.TemplateExtensions.Add($extension) }
    $vm.SelectedTemplateExtension = $extension
    (Get-Control "MasterCanvasExtensionCombo").SelectedItem = $extension
    $vm.CustomTemplateExtension = ""
    $vm.StatusText = "Master Canvas extension added: $extension"
    Update-ProjectPreview
})

(Get-Control "OpenRecentButton").Add_Click({
    $index = $recentCombo.SelectedIndex
    if ($index -ge 0 -and $index -lt @($script:appState.RecentProjects).Count) {
        $path = [string]$script:appState.RecentProjects[$index].ProjectPath
        if (Test-Path -LiteralPath $path -PathType Container) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$path`""
        } else {
            [Windows.MessageBox]::Show("That project folder no longer exists.", "Recent project unavailable", "OK", "Information") | Out-Null
        }
    }
})

$designerCombo.Add_SelectionChanged({
    if ($designerCombo.SelectedItem) {
        $profile = @($script:appState.Profiles) | Where-Object { $_.Name -eq [string]$designerCombo.SelectedItem } | Select-Object -First 1
        if ($profile) {
            $vm.DesignerName = [string]$profile.Name
            $vm.Department = [string]$profile.Department
            $vm.Email = [string]$profile.Email
            $vm.AvatarPath = [string]$profile.AvatarPath
        }
    }
})

(Get-Control "CreateProjectButton").Add_Click({
    try {
        $extraFolders = @()
        if ($vm.IncludeRevisions) { $extraFolders += "Client Revisions" }
        if ($vm.IncludeRawMedia) { $extraFolders += "RAW Media" }
        $prefix = Get-SuamiSihatJobPrefix -PresetName $vm.SelectedPreset
        $claim = Claim-NextJobID -WorkspaceRoot $vm.Workspace -JobPrefix $prefix -AppState $script:appState
        if ([string]::IsNullOrWhiteSpace($claim.JobID)) { throw "Unable to claim a Job ID." }

        $root = $vm.Workspace
        if (-not [string]::IsNullOrWhiteSpace($vm.StaffId)) { $root = Join-Path $root $vm.StaffId }
        $result = New-SuamiSihatProjectFolder `
            -RootDirectory $root -SubBrand $vm.SelectedBrand -JobNumber $claim.JobID `
            -ProjectName $vm.ProjectName -PresetType $vm.SelectedPreset -Year $vm.SelectedYear `
            -Description $vm.ProjectDescription -ExtraSubFolders $extraFolders `
            -InjectTemplates:$vm.InjectMasterCanvas -TemplateExtension $vm.SelectedTemplateExtension `
            -DesignerName $vm.DesignerName -DesignerDept $vm.Department -TargetPlatform $vm.SelectedPlatform

        $pendingEntry = @{
            JobID = $claim.JobID; StaffID = $vm.StaffId; FolderName = $result.FolderName
            Path = $result.ProjectPath; PresetType = $vm.SelectedPreset; Created = (Get-Date).ToString("o")
        }
        if ($claim.Source -eq "NAS") {
            try {
                $registry = Read-TeamRegistry -WorkspaceRoot $vm.Workspace
                $registry.Projects += $pendingEntry
                Write-TeamRegistry -WorkspaceRoot $vm.Workspace -Registry $registry
                if (-not [string]::IsNullOrWhiteSpace($vm.StaffId)) {
                    Register-TeamDesigner -WorkspaceRoot $vm.Workspace -StaffID $vm.StaffId -Name $vm.DesignerName -Department $vm.Department -Email $vm.Email
                }
            } catch {}
        } else {
            $pending = [System.Collections.ArrayList]::new()
            foreach ($item in @($script:appState.PendingSync)) { if ($item -and $item.JobID) { [void]$pending.Add($item) } }
            [void]$pending.Add($pendingEntry)
            $script:appState.PendingSync = @($pending)
        }

        $script:appState = Save-SuamiSihatAppState `
            -LastProjectPath $result.ProjectPath -LastProjectName $result.FolderName `
            -LastJobNumber $claim.JobID -DefaultWorkspace $vm.Workspace `
            -DesignerName $vm.DesignerName -Department $vm.Department -DesignerEmail $vm.Email `
            -AvatarPath $vm.AvatarPath -StaffID $vm.StaffId `
            -LocalJobPool @($script:appState.LocalJobPool) -PendingSync @($script:appState.PendingSync)
        $vm.JobId = $script:appState.NextJobNumber
        $vm.StatusText = "Project created: $($claim.JobID)$(if ($claim.Source -ne 'NAS') { ' | offline sync queued' })"
        $vm.SearchDestination = $result.ProjectPath
        Refresh-RecentProjects
        Update-NasStatus
        Update-ProjectPreview
        Start-DashboardRefresh
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($result.ProjectPath)`""
    } catch {
        $vm.StatusText = "Unable to create project: $($_.Exception.Message)"
    }
})

(Get-Control "BrowseWorkspaceButton").Add_Click({
    $selected = Select-Folder $vm.Workspace
    if ($selected) { $vm.Workspace = $selected }
})
(Get-Control "BrowseInstallDestination").Add_Click({
    $selected = Select-Folder $vm.Destination
    if ($selected) { $vm.Destination = Join-Path $selected "SuamiSihat Brand Assets" }
})
(Get-Control "BrowseCpmInstallPath").Add_Click({
    $selected = Select-Folder $vm.CpmInstallPath
    if ($selected) { $vm.CpmInstallPath = Join-Path $selected "SuamiSihat Creative Assets Management" }
})
(Get-Control "BrowseSearchRootButton").Add_Click({
    $selected = Select-Folder $vm.SearchRoot
    if ($selected) {
        $vm.SearchRoot = $selected
        Refresh-DesignerFolderChoices
        $vm.DesignerFolders.Clear()
        $vm.SearchResults.Clear()
        $vm.ProjectReadmeContent = "Select a project folder to view its README.md creative brief."
    }
})
(Get-Control "BrowseCopyDestinationButton").Add_Click({
    $selected = Select-Folder $vm.SearchDestination
    if ($selected) { $vm.SearchDestination = $selected }
})
(Get-Control "SearchProjectFoldersButton").Add_Click({ Start-DesignerFolderListing })
(Get-Control "OpenDesignerFolderButton").Add_Click({
    $folder = $designerFoldersGrid.SelectedItem
    if ($folder -and (Test-Path -LiteralPath $folder.FullPath -PathType Container)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($folder.FullPath)`""
    } else {
        $vm.DesignerFolderStatus = "Select an available project folder to open."
    }
})
$designerFoldersGrid.Add_SelectionChanged({ Show-SelectedProject -Folder $designerFoldersGrid.SelectedItem })
$designerFoldersGrid.Add_MouseDoubleClick({
    $folder = $designerFoldersGrid.SelectedItem
    if ($folder -and (Test-Path -LiteralPath $folder.FullPath -PathType Container)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($folder.FullPath)`""
    }
})
(Get-Control "SearchQueryBox").Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [Windows.Input.Key]::Enter) {
        Start-DesignerFolderListing
        $eventArgs.Handled = $true
    }
})
(Get-Control "CopySelectedFilesButton").Add_Click({
    $selectedItems = @($searchResultsGrid.SelectedItems)
    if ($selectedItems.Count -eq 0) {
        $vm.SearchStatus = "Select one or more files to copy."
        return
    }
    if (-not (Test-Path -LiteralPath $vm.SearchDestination -PathType Container)) {
        $vm.SearchStatus = "Choose an existing destination work-order folder."
        return
    }

    $conflicts = @($selectedItems | Where-Object { Test-Path -LiteralPath (Join-Path $vm.SearchDestination $_.Name) -PathType Leaf })
    $overwrite = $false
    if ($conflicts.Count -gt 0) {
        $answer = [Windows.MessageBox]::Show(
            "$($conflicts.Count) file(s) already exist in the work order. Overwrite them?",
            "Existing files", "YesNoCancel", "Warning")
        if ($answer -eq [Windows.MessageBoxResult]::Cancel) { return }
        $overwrite = $answer -eq [Windows.MessageBoxResult]::Yes
    }

    $copied = 0
    $skipped = 0
    foreach ($item in $selectedItems) {
        try {
            $target = Join-Path $vm.SearchDestination $item.Name
            if ((Test-Path -LiteralPath $target -PathType Leaf) -and -not $overwrite) { $skipped++; continue }
            Copy-Item -LiteralPath $item.FullPath -Destination $target -Force:$overwrite
            $copied++
        } catch { $skipped++ }
    }
    $vm.SearchStatus = "$copied file(s) copied to the work order$(if ($skipped -gt 0) { "; $skipped skipped" })."
})

(Get-Control "BrowseAvatarButton").Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tiff;*.webp"
    $dialog.Title = "Select profile picture"
    if ($dialog.ShowDialog($window)) { $vm.AvatarPath = $dialog.FileName }
})

# Avatar border click ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ full-size popup
$avatarBorder = Get-Control "AvatarBorder"
$avatarBorder.Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    if (-not [string]::IsNullOrWhiteSpace($vm.AvatarPath) -and (Test-Path -LiteralPath $vm.AvatarPath -PathType Leaf)) {
        $e.Handled = $true
        Show-ImagePopup -ImagePath $vm.AvatarPath -Title $vm.DesignerName
    }
})
(Get-Control "SaveSettingsButton").Add_Click({
    try { Save-WpfSettings } catch { $vm.SettingsStatus = "Unable to save settings: $($_.Exception.Message)" }
})
(Get-Control "ClearRecentButton").Add_Click({
    if (-not $vm.HasRecent) { $vm.SettingsStatus = "Recent projects are already clear."; return }
    $answer = [Windows.MessageBox]::Show(
        "Clear all recent project history?`n`nNo project folders, Job IDs or settings will be deleted.",
        "Clear Recent Projects", "YesNo", "Question")
    if ($answer -eq [Windows.MessageBoxResult]::Yes) {
        $script:appState = Clear-SuamiSihatRecentProjects
        Refresh-RecentProjects
        $vm.SettingsStatus = "Recent project history cleared."
    }
})
(Get-Control "UninstallButton").Add_Click({
    if ([Windows.MessageBox]::Show("Uninstall SS-CAM and its shortcuts?", "Uninstall", "YesNo", "Warning") -eq [Windows.MessageBoxResult]::Yes) {
        $result = Uninstall-SuamiSihatApp
        $vm.SettingsStatus = if ($result.Success) { "Application and shortcuts removed." } else { "Uninstall did not complete." }
    }
})
(Get-Control "CheckUpdateButton").Add_Click({
    try {
        $vm.SettingsStatus = "Checking for updates..."
        $update = Get-SuamiSihatLatestRelease -CurrentVersion $script:AppVersion
        if ($update.HasUpdate) {
            $vm.SettingsStatus = "Update available: v$($update.LatestVersion)"
            $prompt = [Windows.MessageBox]::Show(
                "SS-CAM v$($update.LatestVersion) is available.`nYou are running v$($update.CurrentVersion).`n`nOpen the download page?",
                "Update Available",
                [Windows.MessageBoxButton]::YesNo,
                [Windows.MessageBoxImage]::Information
            )
            if ($prompt -eq [Windows.MessageBoxResult]::Yes) {
                $releaseUrl = if ($update.HtmlUrl) { $update.HtmlUrl } else { "https://github.com/SuamiSihat/ss_cam/releases/latest" }
                Start-Process $releaseUrl
            }
        } else {
            $vm.SettingsStatus = "You are running the latest version (v$($update.CurrentVersion))."
        }
    } catch { $vm.SettingsStatus = "Update check unavailable." }
})
(Get-Control "RepairButton").Add_Click({
    Enter-InstallerSurface
    $vm.InstallBrandKit = $true
    $vm.InstallProjectManager = $false
    $vm.InstallStatus = "Repair mode ready. Review the options and select Install."
})

function Quote-ProcessArgument([string]$Value) {
    if ($null -eq $Value) { return '""' }
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Start-WpfInstallation {
    if (-not $vm.InstallBrandKit -and -not $vm.InstallProjectManager) {
        [Windows.MessageBox]::Show("Select at least one component.", "Nothing selected", "OK", "Information") | Out-Null
        return
    }
    if (-not $vm.AcceptLicence) {
        [Windows.MessageBox]::Show("Accept the licence agreement before installing.", "Licence required", "OK", "Information") | Out-Null
        return
    }
    if ($vm.InstallProjectManager -and [string]::IsNullOrWhiteSpace($vm.CpmInstallPath)) {
        [Windows.MessageBox]::Show("Select an installation folder for Creative Project Management.", "Install folder required", "OK", "Information") | Out-Null
        return
    }

    $installer = Join-Path $PSScriptRoot "Install-SuamiSihat.ps1"
    $arguments = @("-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Quote-ProcessArgument $installer))
    if (-not $vm.InstallBrandKit) {
        $arguments += @("-SkipFonts", "-SkipAssets", "-SkipReports", "-SkipWebShortcuts")
    } else {
        if ($fontChoice.SelectedIndex -eq 2) { $arguments += "-SkipFonts" }
        else { $arguments += @("-FontSet", $(if ($fontChoice.SelectedIndex -eq 1) { "Core" } else { "All" })) }
        if ($vm.CopyAssets) { $arguments += @("-Destination", (Quote-ProcessArgument $vm.Destination)) }
        else { $arguments += @("-SkipAssets", "-SkipReports") }
        if (-not $vm.CreateWebShortcuts) { $arguments += "-SkipWebShortcuts" }
    }
    # CPM deployment is handled after the Brand Kit engine completes. Keeping
    # the EXE out of the engine also guarantees Brand-Kit-only installs do not
    # install Creative Project Management as a side effect.

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = $arguments -join " "
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $PSScriptRoot
    $script:installerProcess = New-Object Diagnostics.Process
    $script:installerProcess.StartInfo = $startInfo
    if (-not $script:installerProcess.Start()) { throw "Windows could not start the setup engine." }
    $script:standardOutputTask = $script:installerProcess.StandardOutput.ReadToEndAsync()
    $script:standardErrorTask = $script:installerProcess.StandardError.ReadToEndAsync()
    $script:installationRunning = $true
    $vm.IsInstalling = $true
    $vm.InstallStatus = "Installing SuamiSihat creative tools..."
    $vm.InstallLog = "Setup is running. This can take a few minutes."
    $vm.InstallReport = "Installation in progress..."
    Set-InstallerStep 3
    (Get-Control "InstallerBack4").Visibility = [Windows.Visibility]::Collapsed
    (Get-Control "OpenInstalledAppButton").Visibility = [Windows.Visibility]::Collapsed
    (Get-Control "CloseSetupButton").IsEnabled = $false
    $installTimer.Start()
}

$installTimer = New-Object Windows.Threading.DispatcherTimer
$installTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$installTimer.Add_Tick({
    if ($null -eq $script:installerProcess -or -not $script:installerProcess.HasExited) { return }
    $installTimer.Stop()
    $output = ($script:standardOutputTask.Result.Trim() + [Environment]::NewLine + $script:standardErrorTask.Result.Trim()).Trim()
    $exitCode = $script:installerProcess.ExitCode
    $script:installerProcess.Dispose()
    $script:installerProcess = $null
    $script:installationRunning = $false
    $vm.IsInstalling = $false
    $vm.InstallLog = if ([string]::IsNullOrWhiteSpace($output)) { "Setup produced no status output." } else { $output }
    $projectManagerResult = if ($vm.InstallProjectManager) { "Pending" } else { "Skipped (not selected)" }
    $brandKitResult = if (-not $vm.InstallBrandKit) {
        "Skipped (not selected)"
    } elseif ($output -match 'font file\(s\) could not be installed') {
        "Installed with font warnings"
    } else {
        "Installed"
    }
    if ($exitCode -eq 0) {
        try {
            if ($vm.InstallProjectManager -and -not [string]::IsNullOrWhiteSpace($InstallerExePath) -and (Test-Path -LiteralPath $InstallerExePath -PathType Leaf)) {
                $installDir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($vm.CpmInstallPath.Trim()))
                New-Item -ItemType Directory -Path $installDir -Force | Out-Null
                $targetExe = Join-Path $installDir "SS-CAM.exe"
                $sourceExe = [IO.Path]::GetFullPath($InstallerExePath)
                $targetExe = [IO.Path]::GetFullPath($targetExe)
                if (-not $sourceExe.Equals($targetExe, [StringComparison]::OrdinalIgnoreCase)) {
                    Copy-Item -LiteralPath $sourceExe -Destination $targetExe -Force
                }
                Install-SuamiSihatShortcuts -TargetExePath $targetExe -Version $script:AppVersion
                $projectManagerResult = if ($sourceExe.Equals($targetExe, [StringComparison]::OrdinalIgnoreCase)) { "Verified / repaired" } else { "Installed" }
            } elseif ($vm.InstallProjectManager) {
                throw "The Creative Project Management installer executable was not available."
            }
        } catch {
            $exitCode = 1
            $projectManagerResult = "Failed: $($_.Exception.Message)"
            $output = ($output + [Environment]::NewLine + $_.Exception.Message).Trim()
        }
    }

    $vm.InstallReport = @"
SUAMISIHAT INSTALLATION REPORT
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Installer version: $($script:AppVersion)

Creative Project Management: $projectManagerResult
Install path: $(if ($vm.InstallProjectManager) { $vm.CpmInstallPath } else { 'Not applicable' })
Brand Kit: $brandKitResult

Setup engine output:
$(if ([string]::IsNullOrWhiteSpace($output)) { 'No additional output.' } else { $output })
"@

    (Get-Control "CloseSetupButton").IsEnabled = $true
    if ($exitCode -eq 0) {
        $vm.InstallStatus = "Setup complete. This PC is ready for SuamiSihat creative work."
        Set-InstallerStep 3
        (Get-Control "InstallerBack4").Visibility = [Windows.Visibility]::Collapsed
        (Get-Control "CloseSetupButton").Content = "Finish"
        if ($vm.InstallProjectManager) {
            (Get-Control "OpenInstalledAppButton").Visibility = [Windows.Visibility]::Visible
        }
    } else {
        $vm.InstallStatus = "Setup failed with exit code $exitCode. Review the log below."
        (Get-Control "InstallerBack4").Visibility = [Windows.Visibility]::Visible
    }
})

(Get-Control "InstallButton").Add_Click({
    if (-not (Get-Control "AcceptLicenseCheck").IsEnabled -or -not $vm.AcceptLicence) {
        [Windows.MessageBox]::Show("Read the entire licence agreement, then select the acceptance checkbox.", "Licence required", "OK", "Information") | Out-Null
        return
    }
    try { Start-WpfInstallation } catch { $vm.InstallStatus = "Setup could not start: $($_.Exception.Message)" }
})

$window.Add_Closing({
    param($sender, $eventArgs)
    if ($script:installationRunning) {
        $eventArgs.Cancel = $true
        [Windows.MessageBox]::Show("Please wait for installation to finish.", "Installation in progress", "OK", "Information") | Out-Null
    }
})
$window.Add_KeyDown({
    param($sender, $eventArgs)
    if ($views.SelectedIndex -eq 2 -and $eventArgs.KeyboardDevice.Modifiers -band [Windows.Input.ModifierKeys]::Control -and $eventArgs.Key -eq [Windows.Input.Key]::Enter) {
        (Get-Control "CreateProjectButton").RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
    }
})

Refresh-RecentProjects
Update-NasStatus
Update-ProjectPreview
Set-ReadmeViewMode -ShowPreview $true

if ($InstallerMode) {
    Enter-InstallerSurface
} else {
    $views.SelectedIndex = 1
    if (-not $SmokeTest) { Start-DashboardRefresh }
}
$window.Add_ContentRendered({
    if (-not $SmokeTest) {
        if ($InstallerMode) { Enter-InstallerSurface } else { $views.SelectedIndex = 1; Start-DashboardRefresh }
    }
    Update-AvatarDisplay

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ PS Vita-style floating geometry animation ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $script:headerCanvas = Get-Control "HeaderCanvas"
    $shapeData = @(
        @{X= 60; Y= 10; VX= 0.45; VY= 0.20; D= 72; O= 0.09}
        @{X=210; Y=-18; VX=-0.28; VY= 0.28; D= 44; O= 0.07}
        @{X=390; Y= 28; VX= 0.22; VY=-0.18; D= 90; O= 0.06}
        @{X=540; Y=  5; VX=-0.32; VY= 0.22; D= 56; O= 0.08}
        @{X=720; Y= 32; VX= 0.28; VY=-0.22; D= 38; O= 0.07}
        @{X=860; Y=-8;  VX=-0.20; VY= 0.25; D= 78; O= 0.055}
        @{X=1000;Y= 22; VX= 0.36; VY=-0.14; D= 50; O= 0.08}
        @{X=1120;Y= 12; VX=-0.24; VY= 0.17; D= 64; O= 0.06}
    )
    $script:animItems = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($d in $shapeData) {
        $e = New-Object Windows.Shapes.Ellipse
        $e.Width = $d.D; $e.Height = $d.D
        $e.Stroke = [Windows.Media.Brushes]::White
        $e.StrokeThickness = 1.4
        $e.Opacity = $d.O
        $e.Fill = [Windows.Media.Brushes]::Transparent
        [Windows.Controls.Canvas]::SetLeft($e, $d.X)
        [Windows.Controls.Canvas]::SetTop($e, $d.Y)
        [void]$script:headerCanvas.Children.Add($e)
        $script:animItems.Add(@{Shape=$e; VX=[double]$d.VX; VY=[double]$d.VY; D=[double]$d.D})
    }
    $script:headerTimer = New-Object Windows.Threading.DispatcherTimer
    $script:headerTimer.Interval = [TimeSpan]::FromMilliseconds(33)
    $script:headerTimer.Add_Tick({
        $cw = [double]$script:headerCanvas.ActualWidth
        $ch = [double]$script:headerCanvas.ActualHeight
        if ($cw -le 0 -or $ch -le 0) { return }
        foreach ($item in $script:animItems) {
            $x = [Windows.Controls.Canvas]::GetLeft($item.Shape) + $item.VX
            $y = [Windows.Controls.Canvas]::GetTop($item.Shape) + $item.VY
            $d = $item.D
            if ($x -gt $cw)  { $x = -$d }
            elseif ($x -lt -$d) { $x = $cw }
            if ($y -gt $ch)  { $y = -$d }
            elseif ($y -lt -$d) { $y = $ch }
            [Windows.Controls.Canvas]::SetLeft($item.Shape, $x)
            [Windows.Controls.Canvas]::SetTop($item.Shape, $y)
        }
    })
    $script:headerTimer.Start()
})

$window.Add_Closed({ if ($script:headerTimer) { $script:headerTimer.Stop() } })

if ($SmokeTest) {
    $views.SelectedIndex = switch ($PreviewView) {
        "Setup" { 0 }
        "Projects" { 2 }
        "Creator" { 2 }
        "Search" { 3 }
        "BrandAssets" { 4 }
        "Profile" { 5 }
        "Settings" { 5 }
        default { 1 }
    }
    if ($PreviewView -eq "Setup") { $vm.InstallBrandKit = $false }
    if ($PreviewView -ne "Setup") {
        $sidebar.Visibility = [Windows.Visibility]::Visible
        $sidebarColumn.Width = New-Object Windows.GridLength(235)
    }
    if (-not [string]::IsNullOrWhiteSpace($PreviewPath)) {
        $window.WindowStartupLocation = "Manual"
        $window.Left = -32000
        $window.Top = -32000
        $window.Show()
        $window.UpdateLayout()
        $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
        $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $window.UpdateLayout()
        $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth, [int]$window.ActualHeight, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window)
        $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream = [IO.File]::Open($PreviewPath, [IO.FileMode]::Create)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
        $window.Hide()
    }
    Write-Output "WPF construction and data binding: OK"
} else {
    [void]$window.ShowDialog()
}

if ($script:installerProcess) { $script:installerProcess.Dispose() }
$installTimer.Stop()
$dashboardTimer.Stop()
$searchTimer.Stop()
$designerFolderTimer.Stop()
$reader.Close()





