using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace SS_CAM.Services
{
    /// <summary>
    /// Represents an individual ingested file item.
    /// </summary>
    public class IngestedAsset
    {
        public string SourcePath { get; set; }
        public string DestinationPath { get; set; }
        public string FileName { get; set; }
        public string TargetSubfolder { get; set; }
        public long FileSizeBytes { get; set; }
    }

    /// <summary>
    /// Summary result of a smart ingestion operation.
    /// </summary>
    public class SmartIngestResult
    {
        public bool Success { get; set; }
        public int TotalIngested { get; set; }
        public string ErrorMessage { get; set; }
        public List<IngestedAsset> Assets { get; set; }
        public Dictionary<string, int> CountsByFolder { get; set; }

        public SmartIngestResult()
        {
            Assets = new List<IngestedAsset>();
            CountsByFolder = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// Canonical smart ingestion service for SS-CAM. Automatically classifies and routes
    /// files and recursive directory drops into the standardized 5-folder project vault structure:
    /// - 01_BRIEF_ASSETS
    /// - 02_SOURCE_FILES
    /// - 03_COPYWRITING
    /// - 04_WORK_IN_PROGRESS
    /// - 05_DELIVERABLES
    /// </summary>
    public static class SmartIngesterService
    {
        public const string FOLDER_BRIEF_ASSETS = "01_BRIEF_ASSETS";
        public const string FOLDER_SOURCE_FILES = "02_SOURCE_FILES";
        public const string FOLDER_COPYWRITING = "03_COPYWRITING";
        public const string FOLDER_WIP = "04_WORK_IN_PROGRESS";
        public const string FOLDER_DELIVERABLES = "05_DELIVERABLES";

        private static readonly HashSet<string> SourceExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".ai", ".psd", ".afdesign", ".prproj", ".aep", ".indd",
            ".blend", ".c4d", ".fig", ".sketch", ".cdr", ".svg",
            ".eps", ".raw", ".cr2", ".nef", ".dng", ".arw"
        };

        private static readonly HashSet<string> BriefExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".docx", ".doc", ".xlsx", ".xls", ".pptx", ".ppt", ".txt", ".csv"
        };

        private static readonly HashSet<string> MediaExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".mp4", ".mov", ".avi", ".mkv", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".pdf", ".tiff"
        };

        /// <summary>
        /// Classifies any file into the canonical SS-CAM 5-folder project vault structure.
        /// </summary>
        public static string ClassifySubfolder(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath)) return FOLDER_BRIEF_ASSETS;

            string filename = Path.GetFileName(filePath);
            string ext = Path.GetExtension(filePath);
            string baseLower = Path.GetFileNameWithoutExtension(filePath).ToLowerInvariant();

            // 1. Source files (.psd, .ai, .afdesign, etc.)
            if (SourceExtensions.Contains(ext))
            {
                return FOLDER_SOURCE_FILES;
            }

            // 2. Copywriting documents (.md, .rtf, or name indicates script/copy)
            if (string.Equals(ext, ".md", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(ext, ".rtf", StringComparison.OrdinalIgnoreCase) ||
                baseLower.Contains("copy") || baseLower.Contains("script") || baseLower.Contains("naskah"))
            {
                return FOLDER_COPYWRITING;
            }

            // 3. Brief & reference documents
            if (BriefExtensions.Contains(ext) ||
                baseLower.Contains("brief") || baseLower.Contains("guideline") ||
                baseLower.Contains("spec") || baseLower.Contains("requirement") ||
                baseLower.Contains("panduan") || baseLower.Contains("reference"))
            {
                return FOLDER_BRIEF_ASSETS;
            }

            // 4. Media renders (Images & Videos) -> Work In Progress vs Final Deliverables
            if (MediaExtensions.Contains(ext))
            {
                if (baseLower.Contains("wip") || baseLower.Contains("draft") ||
                    baseLower.Contains("preview") || baseLower.Contains("sample") ||
                    baseLower.Contains("test") || baseLower.Contains("progress") ||
                    baseLower.Contains("temp"))
                {
                    return FOLDER_WIP;
                }
                return FOLDER_DELIVERABLES;
            }

            // Default fallback
            return FOLDER_BRIEF_ASSETS;
        }

        /// <summary>
        /// Ingests a collection of files or directories into a target project vault asynchronously.
        /// Recursively discovers files in dropped folders, auto-routes to the 5 canonical folders,
        /// and applies non-destructive collision renaming (_1, _2) without overwriting existing assets.
        /// </summary>
        public static async Task<SmartIngestResult> IngestAsync(
            string projectFullPath,
            IEnumerable<string> rawPaths,
            IProgress<int> progress = null)
        {
            return await Task.Run(() => Ingest(projectFullPath, rawPaths, progress));
        }

        /// <summary>
        /// Synchronously ingests dropped files and folders into the target project vault.
        /// </summary>
        public static SmartIngestResult Ingest(
            string projectFullPath,
            IEnumerable<string> rawPaths,
            IProgress<int> progress = null)
        {
            SmartIngestResult result = new SmartIngestResult();

            if (string.IsNullOrWhiteSpace(projectFullPath) || !Directory.Exists(projectFullPath))
            {
                result.Success = false;
                result.ErrorMessage = "Target project directory does not exist or is invalid.";
                return result;
            }

            if (rawPaths == null)
            {
                result.Success = true;
                return result;
            }

            try
            {
                // Flatten all files from both individual files and dropped directories
                List<string> filesToProcess = new List<string>();
                foreach (string path in rawPaths)
                {
                    if (string.IsNullOrWhiteSpace(path)) continue;

                    if (File.Exists(path))
                    {
                        filesToProcess.Add(path);
                    }
                    else if (Directory.Exists(path))
                    {
                        try
                        {
                            string[] dirFiles = Directory.GetFiles(path, "*.*", SearchOption.AllDirectories);
                            filesToProcess.AddRange(dirFiles);
                        }
                        catch (Exception dirEx)
                        {
                            Debug.WriteLine("[SmartIngesterService] Error reading directory " + path + ": " + dirEx.Message);
                        }
                    }
                }

                int processedCount = 0;
                foreach (string sourceFilePath in filesToProcess)
                {
                    if (!File.Exists(sourceFilePath)) continue;

                    string targetFolder = ClassifySubfolder(sourceFilePath);
                    string destDirectory = Path.Combine(projectFullPath, targetFolder);
                    if (!Directory.Exists(destDirectory))
                    {
                        Directory.CreateDirectory(destDirectory);
                    }

                    string originalFileName = Path.GetFileName(sourceFilePath);
                    string safeFileName = ResolveCollisionSafeFileName(destDirectory, originalFileName);
                    string destinationPath = Path.Combine(destDirectory, safeFileName);

                    File.Copy(sourceFilePath, destinationPath, false);

                    long fileSize = 0;
                    try { fileSize = new FileInfo(destinationPath).Length; }
                    catch (Exception ex) { Debug.WriteLine("[SmartIngesterService] File length check error: " + ex.Message); }

                    IngestedAsset asset = new IngestedAsset
                    {
                        SourcePath = sourceFilePath,
                        DestinationPath = destinationPath,
                        FileName = safeFileName,
                        TargetSubfolder = targetFolder,
                        FileSizeBytes = fileSize
                    };

                    result.Assets.Add(asset);

                    if (!result.CountsByFolder.ContainsKey(targetFolder))
                    {
                        result.CountsByFolder[targetFolder] = 0;
                    }
                    result.CountsByFolder[targetFolder]++;
                    result.TotalIngested++;

                    processedCount++;
                    if (progress != null)
                    {
                        progress.Report(processedCount);
                    }
                }

                result.Success = true;
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[SmartIngesterService] Ingestion error: " + ex.Message);
                result.Success = false;
                result.ErrorMessage = ex.Message;
            }

            return result;
        }

        /// <summary>
        /// Generates a collision-safe destination filename (e.g. "asset_1.png") if
        /// a file with the same name already exists in target directory.
        /// </summary>
        public static string ResolveCollisionSafeFileName(string destDirectory, string fileName)
        {
            string targetPath = Path.Combine(destDirectory, fileName);
            if (!File.Exists(targetPath)) return fileName;

            string nameWithoutExt = Path.GetFileNameWithoutExtension(fileName);
            string ext = Path.GetExtension(fileName);

            int counter = 1;
            while (File.Exists(Path.Combine(destDirectory, string.Format("{0}_{1}{2}", nameWithoutExt, counter, ext))))
            {
                counter++;
            }

            return string.Format("{0}_{1}{2}", nameWithoutExt, counter, ext);
        }
    }
}
