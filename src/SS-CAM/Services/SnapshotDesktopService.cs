using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using Newtonsoft.Json;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    /// <summary>
    /// Metadata for a snapshotted source design file (.afdesign, .psd, .ai, etc.).
    /// </summary>
    public class SnapshotSourceFileInfo
    {
        public string Name { get; set; }
        public long SizeBytes { get; set; }
        public string SizeFormatted { get; set; }
        public string Extension { get; set; }
        public string ModifiedAt { get; set; }

        public SnapshotSourceFileInfo()
        {
            Name = string.Empty;
            SizeFormatted = "0 B";
            Extension = string.Empty;
            ModifiedAt = string.Empty;
        }
    }

    /// <summary>
    /// Represents an audit-backed point-in-time snapshot of a project.
    /// </summary>
    public class ProjectSnapshotItem
    {
        public string Id { get; set; }
        public string Timestamp { get; set; }
        public string Trigger { get; set; }
        public string Actor { get; set; }
        public int Revision { get; set; }
        public string Status { get; set; }
        public string Note { get; set; }
        public List<SnapshotSourceFileInfo> SourceFiles { get; set; }

        public string FormattedDate
        {
            get
            {
                if (string.IsNullOrWhiteSpace(Timestamp)) return "-";
                DateTime dt;
                if (DateTime.TryParse(Timestamp, null, DateTimeStyles.RoundtripKind, out dt))
                {
                    return dt.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
                }
                return Timestamp;
            }
        }

        public string SourceFilesSummary
        {
            get
            {
                if (SourceFiles == null || SourceFiles.Count == 0) return "No source files";
                return string.Format("{0} design asset(s)", SourceFiles.Count);
            }
        }

        public ProjectSnapshotItem()
        {
            Id = string.Empty;
            Timestamp = string.Empty;
            Trigger = "MANUAL_SNAPSHOT";
            Actor = "Designer";
            Revision = 1;
            Status = "in-progress";
            Note = string.Empty;
            SourceFiles = new List<SnapshotSourceFileInfo>();
        }
    }

    /// <summary>
    /// Result payload returned upon performing a non-destructive rollback.
    /// </summary>
    public class SnapshotRollbackResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public string SnapshotId { get; set; }
        public int RestoredRevision { get; set; }
        public int RestoredSourceFilesCount { get; set; }
        public string PreRollbackBackupId { get; set; }

        public SnapshotRollbackResult()
        {
            Success = false;
            Message = string.Empty;
            SnapshotId = string.Empty;
            PreRollbackBackupId = string.Empty;
        }
    }

    /// <summary>
    /// Desktop C# Service for managing project revision snapshots,
    /// tracking design source binaries (.afdesign, .psd, .ai), and executing safe rollbacks.
    /// </summary>
    public static class SnapshotDesktopService
    {
        private static readonly string[] DesignExtensions = new string[]
        {
            ".afdesign", ".afphoto", ".afpub",
            ".psd", ".psb",
            ".ai", ".eps",
            ".pdf", ".svg",
            ".indd"
        };

        /// <summary>
        /// Gets the dedicated .snapshots directory within a project root.
        /// </summary>
        public static string GetSnapshotsDirectory(string projectFullPath)
        {
            if (string.IsNullOrWhiteSpace(projectFullPath)) return string.Empty;
            string dir = Path.Combine(projectFullPath, ".snapshots");
            if (!Directory.Exists(dir))
            {
                try
                {
                    Directory.CreateDirectory(dir);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] GetSnapshotsDirectory CreateDirectory error: " + ex.Message);
                }
            }
            return dir;
        }

        /// <summary>
        /// Captures a point-in-time snapshot of the project (README.md, COPY.md, and 02_SOURCE_FILES).
        /// </summary>
        public static ProjectSnapshotItem CreateSnapshot(
            string projectFullPath,
            string trigger,
            string actor,
            string note,
            bool includeSourceFiles)
        {
            if (string.IsNullOrWhiteSpace(projectFullPath) || !Directory.Exists(projectFullPath))
            {
                return null;
            }

            string snapshotsDir = GetSnapshotsDirectory(projectFullPath);
            long epochMs = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalMilliseconds;
            string snapId = "snap_" + epochMs.ToString();
            string snapDir = Path.Combine(snapshotsDir, snapId);

            try
            {
                if (!Directory.Exists(snapDir))
                {
                    Directory.CreateDirectory(snapDir);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[SnapshotDesktopService] Create snapDir error: " + ex.Message);
                return null;
            }

            int currentRevision = 1;
            string currentStatus = "in-progress";

            // 1. Copy README.md
            string readmePath = Path.Combine(projectFullPath, "README.md");
            if (File.Exists(readmePath))
            {
                try
                {
                    File.Copy(readmePath, Path.Combine(snapDir, "README.md"), true);
                    ProjectStatusItem statusItem = FrontmatterService.ReadStatus(readmePath);
                    if (statusItem != null)
                    {
                        if (statusItem.Revision > 0) currentRevision = statusItem.Revision;
                        if (!string.IsNullOrWhiteSpace(statusItem.Status)) currentStatus = statusItem.Status;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Copy README.md error: " + ex.Message);
                }
            }

            // 2. Copy COPY.md
            string copyPath = Path.Combine(projectFullPath, "03_COPYWRITING", "COPY.md");
            if (File.Exists(copyPath))
            {
                try
                {
                    File.Copy(copyPath, Path.Combine(snapDir, "COPY.md"), true);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Copy COPY.md error: " + ex.Message);
                }
            }

            // 3. Copy 02_SOURCE_FILES
            List<SnapshotSourceFileInfo> sourceFiles = new List<SnapshotSourceFileInfo>();
            if (includeSourceFiles)
            {
                string sourceDir = Path.Combine(projectFullPath, "02_SOURCE_FILES");
                if (Directory.Exists(sourceDir))
                {
                    try
                    {
                        string[] files = Directory.GetFiles(sourceDir);
                        string snapSourceDir = Path.Combine(snapDir, "02_SOURCE_FILES");

                        foreach (string file in files)
                        {
                            string ext = Path.GetExtension(file);
                            if (IsDesignExtension(ext))
                            {
                                try
                                {
                                    FileInfo fi = new FileInfo(file);
                                    if (!Directory.Exists(snapSourceDir))
                                    {
                                        Directory.CreateDirectory(snapSourceDir);
                                    }
                                    string destPath = Path.Combine(snapSourceDir, fi.Name);
                                    File.Copy(file, destPath, true);

                                    SnapshotSourceFileInfo sfi = new SnapshotSourceFileInfo();
                                    sfi.Name = fi.Name;
                                    sfi.SizeBytes = fi.Length;
                                    sfi.SizeFormatted = FormatBytes(fi.Length);
                                    sfi.Extension = ext.ToLowerInvariant();
                                    sfi.ModifiedAt = fi.LastWriteTimeUtc.ToString("o");
                                    sourceFiles.Add(sfi);
                                }
                                catch (Exception fileEx)
                                {
                                    Debug.WriteLine(string.Format("[SnapshotDesktopService] Copy source file '{0}' error: {1}", file, fileEx.Message));
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("[SnapshotDesktopService] Enumerate source files error: " + ex.Message);
                    }
                    sourceFiles.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));
                }
            }

            ProjectSnapshotItem snapshotItem = new ProjectSnapshotItem();
            snapshotItem.Id = snapId;
            snapshotItem.Timestamp = DateTime.UtcNow.ToString("o");
            snapshotItem.Trigger = string.IsNullOrWhiteSpace(trigger) ? "MANUAL_SNAPSHOT" : trigger;
            snapshotItem.Actor = string.IsNullOrWhiteSpace(actor) ? "Designer" : actor;
            snapshotItem.Revision = currentRevision;
            snapshotItem.Status = currentStatus;
            snapshotItem.Note = string.IsNullOrWhiteSpace(note) ? "Manual studio checkpoint" : note;
            snapshotItem.SourceFiles = sourceFiles;

            string metaPath = Path.Combine(snapDir, "meta.json");
            try
            {
                string json = JsonConvert.SerializeObject(snapshotItem, Formatting.Indented);
                File.WriteAllText(metaPath, json, Encoding.UTF8);
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[SnapshotDesktopService] Write meta.json error: " + ex.Message);
            }

            return snapshotItem;
        }

        /// <summary>
        /// Reads all historical snapshots captured for a given project.
        /// </summary>
        public static List<ProjectSnapshotItem> GetSnapshots(string projectFullPath)
        {
            List<ProjectSnapshotItem> list = new List<ProjectSnapshotItem>();
            if (string.IsNullOrWhiteSpace(projectFullPath) || !Directory.Exists(projectFullPath))
            {
                return list;
            }

            string snapshotsDir = Path.Combine(projectFullPath, ".snapshots");
            if (!Directory.Exists(snapshotsDir))
            {
                return list;
            }

            try
            {
                string[] subDirs = Directory.GetDirectories(snapshotsDir, "snap_*");
                foreach (string subDir in subDirs)
                {
                    string metaPath = Path.Combine(subDir, "meta.json");
                    if (File.Exists(metaPath))
                    {
                        try
                        {
                            string json = File.ReadAllText(metaPath, Encoding.UTF8);
                            ProjectSnapshotItem item = JsonConvert.DeserializeObject<ProjectSnapshotItem>(json);
                            if (item != null)
                            {
                                if (string.IsNullOrWhiteSpace(item.Id))
                                {
                                    item.Id = Path.GetFileName(subDir);
                                }
                                list.Add(item);
                            }
                        }
                        catch (Exception ex)
                        {
                            Debug.WriteLine(string.Format("[SnapshotDesktopService] Read snapshot '{0}' error: {1}", metaPath, ex.Message));
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[SnapshotDesktopService] GetSnapshots error: " + ex.Message);
            }

            list.Sort(new Comparison<ProjectSnapshotItem>(CompareSnapshotsDescending));
            return list;
        }

        /// <summary>
        /// Performs a non-destructive rollback: creates an automated PRE_ROLLBACK_BACKUP,
        /// then restores README.md, COPY.md, and 02_SOURCE_FILES from the specified snapshot.
        /// </summary>
        public static SnapshotRollbackResult Rollback(string projectFullPath, string snapshotId, string actor)
        {
            SnapshotRollbackResult result = new SnapshotRollbackResult();
            result.SnapshotId = snapshotId;

            if (string.IsNullOrWhiteSpace(projectFullPath) || !Directory.Exists(projectFullPath))
            {
                result.Message = "Project folder does not exist.";
                return result;
            }

            string snapshotsDir = Path.Combine(projectFullPath, ".snapshots");
            string targetSnapDir = Path.Combine(snapshotsDir, snapshotId);
            if (!Directory.Exists(targetSnapDir))
            {
                result.Message = string.Format("Snapshot '{0}' not found.", snapshotId);
                return result;
            }

            string operatorName = string.IsNullOrWhiteSpace(actor) ? "Designer" : actor;

            // 1. Safety pre-rollback backup
            ProjectSnapshotItem safetyBackup = CreateSnapshot(
                projectFullPath,
                "PRE_ROLLBACK_BACKUP",
                operatorName,
                string.Format("Safety backup before rolling back to {0}", snapshotId),
                true);

            if (safetyBackup != null)
            {
                result.PreRollbackBackupId = safetyBackup.Id;
            }

            // 2. Restore README.md
            string snapReadme = Path.Combine(targetSnapDir, "README.md");
            if (File.Exists(snapReadme))
            {
                try
                {
                    File.Copy(snapReadme, Path.Combine(projectFullPath, "README.md"), true);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Restore README.md error: " + ex.Message);
                }
            }

            // 3. Restore COPY.md
            string snapCopy = Path.Combine(targetSnapDir, "COPY.md");
            string copyDir = Path.Combine(projectFullPath, "03_COPYWRITING");
            if (File.Exists(snapCopy))
            {
                try
                {
                    if (!Directory.Exists(copyDir)) Directory.CreateDirectory(copyDir);
                    File.Copy(snapCopy, Path.Combine(copyDir, "COPY.md"), true);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Restore COPY.md error: " + ex.Message);
                }
            }

            // 4. Restore 02_SOURCE_FILES
            int restoredSourceFiles = 0;
            string snapSourceDir = Path.Combine(targetSnapDir, "02_SOURCE_FILES");
            string targetSourceDir = Path.Combine(projectFullPath, "02_SOURCE_FILES");
            if (Directory.Exists(snapSourceDir))
            {
                try
                {
                    if (!Directory.Exists(targetSourceDir)) Directory.CreateDirectory(targetSourceDir);
                    string[] sourceFiles = Directory.GetFiles(snapSourceDir);
                    foreach (string sf in sourceFiles)
                    {
                        string destFile = Path.Combine(targetSourceDir, Path.GetFileName(sf));
                        File.Copy(sf, destFile, true);
                        restoredSourceFiles++;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Restore 02_SOURCE_FILES error: " + ex.Message);
                }
            }

            int restoredRevision = 1;
            string metaPath = Path.Combine(targetSnapDir, "meta.json");
            if (File.Exists(metaPath))
            {
                try
                {
                    string json = File.ReadAllText(metaPath, Encoding.UTF8);
                    ProjectSnapshotItem item = JsonConvert.DeserializeObject<ProjectSnapshotItem>(json);
                    if (item != null)
                    {
                        restoredRevision = item.Revision;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] Read target meta.json error: " + ex.Message);
                }
            }

            result.Success = true;
            result.RestoredRevision = restoredRevision;
            result.RestoredSourceFilesCount = restoredSourceFiles;
            result.Message = string.Format("Project successfully restored to snapshot {0} (Rev {1}).", snapshotId, restoredRevision);
            return result;
        }

        /// <summary>
        /// Deletes a specific historical snapshot folder.
        /// </summary>
        public static bool DeleteSnapshot(string projectFullPath, string snapshotId)
        {
            if (string.IsNullOrWhiteSpace(projectFullPath) || string.IsNullOrWhiteSpace(snapshotId))
            {
                return false;
            }

            string snapDir = Path.Combine(projectFullPath, ".snapshots", snapshotId);
            if (Directory.Exists(snapDir))
            {
                try
                {
                    Directory.Delete(snapDir, true);
                    return true;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[SnapshotDesktopService] DeleteSnapshot error: " + ex.Message);
                }
            }
            return false;
        }

        private static bool IsDesignExtension(string ext)
        {
            if (string.IsNullOrWhiteSpace(ext)) return false;
            string lower = ext.ToLowerInvariant();
            for (int i = 0; i < DesignExtensions.Length; i++)
            {
                if (DesignExtensions[i] == lower) return true;
            }
            return false;
        }

        private static int CompareSnapshotsDescending(ProjectSnapshotItem a, ProjectSnapshotItem b)
        {
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            return string.Compare(b.Timestamp, a.Timestamp, StringComparison.Ordinal);
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes <= 0) return "0 B";
            string[] units = new string[] { "B", "KB", "MB", "GB" };
            double size = bytes;
            int order = 0;
            while (size >= 1024 && order < units.Length - 1)
            {
                order++;
                size = size / 1024;
            }
            return string.Format("{0:0.##} {1}", size, units[order]);
        }
    }
}
