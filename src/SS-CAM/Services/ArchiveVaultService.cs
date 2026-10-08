using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    /// <summary>
    /// Result of a single batch archive operation.
    /// </summary>
    public class ArchiveBatchResult
    {
        public bool Success { get; set; }
        public int ArchivedCount { get; set; }
        public int FailedCount { get; set; }
        public long TotalZipBytes { get; set; }
        public long ReclaimedBytes { get; set; }
        public int PrunedCount { get; set; }
        public string CatalogPath { get; set; }
        public string ErrorMessage { get; set; }
        public List<string> FailedProjects { get; set; }

        public ArchiveBatchResult()
        {
            FailedProjects = new List<string>();
        }
    }

    /// <summary>
    /// Options for a batch archive operation.
    /// </summary>
    public class ArchiveBatchOptions
    {
        /// <summary>Root path of the _Archive/ directory on NAS.</summary>
        public string ArchiveRoot { get; set; }

        /// <summary>
        /// When true (v4.12.0 default), source folders are preserved (copy-only, non-destructive).
        /// When false, source folders are moved into the archive (destructive — v4.13+ only).
        /// </summary>
        public bool CopyOnly { get; set; }

        /// <summary>Designer / operator name for the catalog entry.</summary>
        public string OperatorName { get; set; }

        /// <summary>Options forwarded to ExportPackagingService per project.</summary>
        public ExportPackageOptions PackageOptions { get; set; }

        /// <summary>Progress callback: (processedCount, totalCount, currentProjectName).</summary>
        public Action<int, int, string> ProgressCallback { get; set; }

        public ArchiveBatchOptions()
        {
            CopyOnly = true;  // Safety: non-destructive by default
            PackageOptions = new ExportPackageOptions
            {
                IncludeDeliverables = true,
                IncludeWipMockups   = false,
                IncludeCopywriting  = true,
                IncludeBriefMarkdown = true,
                IncludeHtmlSummary  = true
            };
        }
    }

    /// <summary>
    /// Batch vault archival service for SS-CAM v4.12.0.
    ///
    /// Responsibilities:
    ///   - Accept a list of project full paths and archive each one into a
    ///     cold-storage ZIP under _Archive/[YYYY]/[YYYYMM]/
    ///   - Append each operation to _archive_catalog.jsonl (JSONL, non-destructive)
    ///   - Report storage delta (before/after NAS quota)
    ///
    /// Safety rules:
    ///   - v4.12.0 ships CopyOnly=true exclusively. Move-to-archive is deferred to v4.13.
    ///   - All paths are validated before any write operation.
    ///   - The catalog is appended, never overwritten.
    /// </summary>
    public static class ArchiveVaultService
    {
        private const string ArchiveCatalogFileName = "_archive_catalog.jsonl";

        /// <summary>
        /// Archives a list of project folders into the vault asynchronously.
        /// Runs on a background thread — does NOT block the UI thread.
        /// </summary>
        public static Task<ArchiveBatchResult> ArchiveBatchAsync(
            IEnumerable<string> projectPaths,
            ArchiveBatchOptions options)
        {
            return Task.Factory.StartNew(() => ArchiveBatch(projectPaths, options));
        }

        private static ArchiveBatchResult ArchiveBatch(
            IEnumerable<string> projectPaths,
            ArchiveBatchOptions options)
        {
            var result = new ArchiveBatchResult();

            // --- Input validation ---
            if (projectPaths == null)
            {
                result.ErrorMessage = "Project list is null.";
                return result;
            }

            var paths = projectPaths.Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
            if (paths.Count == 0)
            {
                result.ErrorMessage = "No projects supplied for archiving.";
                return result;
            }

            if (options == null)
            {
                options = new ArchiveBatchOptions();
            }

            if (string.IsNullOrWhiteSpace(options.ArchiveRoot))
            {
                result.ErrorMessage = "ArchiveRoot must be specified.";
                return result;
            }

            // Prevent path traversal: archive root must be an absolute path
            if (!Path.IsPathRooted(options.ArchiveRoot))
            {
                result.ErrorMessage = "ArchiveRoot must be an absolute path.";
                return result;
            }

            // --- Build archive sub-directory: _Archive/[YYYY]/[YYYYMM]/ ---
            DateTime now = DateTime.Now;
            string yearFolder  = now.ToString("yyyy");
            string monthFolder = now.ToString("yyyyMM_") + now.ToString("MMMM", System.Globalization.CultureInfo.InvariantCulture);
            string archiveDir  = Path.Combine(options.ArchiveRoot, yearFolder, monthFolder);

            try
            {
                if (!Directory.Exists(archiveDir))
                {
                    Directory.CreateDirectory(archiveDir);
                }
            }
            catch (Exception ex)
            {
                result.ErrorMessage = "Cannot create archive directory: " + ex.Message;
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] CreateDir error: " + ex.Message);
                return result;
            }

            // --- Catalog file path ---
            string catalogPath = Path.Combine(options.ArchiveRoot, ArchiveCatalogFileName);
            result.CatalogPath = catalogPath;

            var catalogEntry = new ArchiveCatalogEntry
            {
                Operator = options.OperatorName ?? "Unknown",
                CopyOnly = options.CopyOnly
            };

            int total = paths.Count;
            int processed = 0;

            // --- Per-project archival loop ---
            foreach (string projectPath in paths)
            {
                try
                {
                    // Validate source
                    if (!Directory.Exists(projectPath))
                    {
                        System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] Skipping missing: " + projectPath);
                        result.FailedProjects.Add(Path.GetFileName(projectPath) + " (not found)");
                        result.FailedCount++;
                        processed++;
                        continue;
                    }

                    string projectName = new DirectoryInfo(projectPath).Name;

                    // Sanitize ZIP name: replace invalid chars with _
                    string safeProjectName = SanitizeFileName(projectName);
                    string zipFileName = string.Format("{0}_{1}_ARCHIVE.zip",
                        now.ToString("yyyyMMdd"),
                        safeProjectName);
                    string zipPath = Path.Combine(archiveDir, zipFileName);

                    // Report progress
                    if (options.ProgressCallback != null)
                    {
                        options.ProgressCallback(processed, total, projectName);
                    }

                    // CreateHandoverPackageAsync is called here on a background thread
                    // (inside Task.Factory.StartNew) — no SynchronizationContext, so
                    // .GetAwaiter().GetResult() is safe and cannot deadlock.
                    var packResult = ExportPackagingService.CreateHandoverPackageAsync(
                        projectPath,
                        zipPath,
                        options.PackageOptions).GetAwaiter().GetResult();

                    if (packResult.Success)
                    {
                        result.ArchivedCount++;
                        result.TotalZipBytes += packResult.TotalSizeBytes;
                        catalogEntry.ArchivedProjects.Add(projectName);
                        catalogEntry.ProjectCount++;

                        // Destructive Move-to-Archive & Storage Pruning (v4.14.0):
                        if (!options.CopyOnly)
                        {
                            if (File.Exists(zipPath) && new FileInfo(zipPath).Length > 0)
                            {
                                try
                                {
                                    long projectSize = GetDirectorySize(projectPath);
                                    Directory.Delete(projectPath, true);
                                    result.PrunedCount++;
                                    result.ReclaimedBytes += projectSize;
                                    catalogEntry.PrunedCount++;
                                    catalogEntry.ReclaimedBytes += projectSize;
                                    System.Diagnostics.Debug.WriteLine(string.Format(
                                        "[ArchiveVaultService] Source pruned: {0} ({1} bytes reclaimed)", projectName, projectSize));
                                }
                                catch (Exception delEx)
                                {
                                    System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] Source prune error: " + delEx.Message);
                                }
                            }
                        }

                        System.Diagnostics.Debug.WriteLine(string.Format(
                            "[ArchiveVaultService] Archived '{0}' → {1} ({2} files, {3} bytes)",
                            projectName, zipPath, packResult.FileCount, packResult.TotalSizeBytes));
                    }
                    else
                    {
                        result.FailedProjects.Add(projectName + " (" + packResult.ErrorMessage + ")");
                        result.FailedCount++;
                        System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] PackageFail: " + projectName + " — " + packResult.ErrorMessage);
                    }
                }
                catch (Exception ex)
                {
                    string projectName = Path.GetFileName(projectPath);
                    result.FailedProjects.Add(projectName + " (exception)");
                    result.FailedCount++;
                    System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] ArchiveBatch exception for " + projectPath + ": " + ex.Message);
                }

                processed++;
            }

            // --- Final progress tick ---
            if (options.ProgressCallback != null)
            {
                options.ProgressCallback(total, total, "Done");
            }

            // --- Write catalog entry ---
            if (catalogEntry.ArchivedProjects.Count > 0)
            {
                try
                {
                    catalogEntry.ZipFilePath   = archiveDir;   // Directory, not single ZIP (batch may contain multiple)
                    catalogEntry.ZipSizeBytes  = result.TotalZipBytes;
                    catalogEntry.Success       = result.FailedCount == 0;

                    string jsonLine = JsonConvert.SerializeObject(catalogEntry, Formatting.None) + "\n";
                    File.AppendAllText(catalogPath, jsonLine, Encoding.UTF8);

                    System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] Catalog appended: " + catalogPath);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] CatalogWrite error: " + ex.Message);
                    // Catalog write failure is non-fatal; archiving succeeded
                }
            }

            result.Success = result.ArchivedCount > 0;
            return result;
        }

        /// <summary>
        /// Loads all catalog entries from the _archive_catalog.jsonl file.
        /// Returns an empty list if the file does not exist or is unreadable.
        /// </summary>
        public static List<ArchiveCatalogEntry> LoadCatalog(string archiveRoot)
        {
            var entries = new List<ArchiveCatalogEntry>();
            if (string.IsNullOrWhiteSpace(archiveRoot)) return entries;

            string catalogPath = Path.Combine(archiveRoot, ArchiveCatalogFileName);
            if (!File.Exists(catalogPath)) return entries;

            try
            {
                string[] lines = File.ReadAllLines(catalogPath, Encoding.UTF8);
                foreach (string line in lines)
                {
                    if (string.IsNullOrWhiteSpace(line)) continue;
                    try
                    {
                        var entry = JsonConvert.DeserializeObject<ArchiveCatalogEntry>(line);
                        if (entry != null) entries.Add(entry);
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] CatalogParse skip: " + ex.Message);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] LoadCatalog error: " + ex.Message);
            }

            return entries;
        }

        /// <summary>
        /// Returns the canonical archive root path for a given workspace root.
        /// Convention: {workspaceRoot}/_Archive/
        /// </summary>
        public static string GetArchiveRoot(string workspaceRoot)
        {
            if (string.IsNullOrWhiteSpace(workspaceRoot)) return null;
            return Path.Combine(workspaceRoot, "_Archive");
        }

        private static string SanitizeFileName(string name)
        {
            if (string.IsNullOrWhiteSpace(name)) return "Project";
            char[] invalid = Path.GetInvalidFileNameChars();
            var sb = new StringBuilder();
            foreach (char c in name)
            {
                sb.Append(Array.IndexOf(invalid, c) >= 0 ? '_' : c);
            }
            string safe = sb.ToString().Trim('_', ' ');
            return string.IsNullOrWhiteSpace(safe) ? "Project" : safe;
        }

        private static long GetDirectorySize(string dirPath)
        {
            try
            {
                if (!Directory.Exists(dirPath)) return 0;
                long total = 0;
                foreach (string f in Directory.GetFiles(dirPath, "*.*", SearchOption.AllDirectories))
                {
                    try
                    {
                        var fi = new FileInfo(f);
                        total += fi.Length;
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] GetDirectorySize file error: " + ex.Message);
                    }
                }
                return total;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[ArchiveVaultService] GetDirectorySize error: " + ex.Message);
                return 0;
            }
        }
    }
}
