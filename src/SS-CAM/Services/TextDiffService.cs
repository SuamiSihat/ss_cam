using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace SS_CAM.Services
{
    public enum DiffLineType
    {
        Unchanged,
        Added,
        Deleted
    }

    public class DiffLine
    {
        public DiffLineType Type { get; set; }
        public int? OldLineNumber { get; set; }
        public int? NewLineNumber { get; set; }
        public string Text { get; set; }

        public override string ToString()
        {
            string prefix = Type == DiffLineType.Added ? "+ " : (Type == DiffLineType.Deleted ? "- " : "  ");
            return prefix + Text;
        }
    }

    public class DiffResult
    {
        public List<DiffLine> Lines { get; set; }
        public int TotalOldLines { get; set; }
        public int TotalNewLines { get; set; }
        public int AddedCount { get; set; }
        public int DeletedCount { get; set; }
        public int UnchangedCount { get; set; }
        public double SimilarityPercentage { get; set; }

        public DiffResult()
        {
            Lines = new List<DiffLine>();
        }
    }

    public class RevisionItem
    {
        public string FilePath { get; set; }
        public string DisplayName { get; set; }
        public DateTime Timestamp { get; set; }
        public long FileSizeBytes { get; set; }
        public bool IsCurrent { get; set; }
    }

    /// <summary>
    /// Line-by-line diff engine and revision snapshot manager for Markdown documents
    /// (COPY.md scripts and README.md project briefs).
    /// </summary>
    public static class TextDiffService
    {
        /// <summary>
        /// Computes line-by-line differences using the Longest Common Subsequence (LCS) algorithm.
        /// </summary>
        public static DiffResult Compare(string oldText, string newText)
        {
            DiffResult result = new DiffResult();

            string[] oldLines = (oldText ?? string.Empty).Replace("\r\n", "\n").Split('\n');
            string[] newLines = (newText ?? string.Empty).Replace("\r\n", "\n").Split('\n');

            result.TotalOldLines = oldLines.Length;
            result.TotalNewLines = newLines.Length;

            // Compute LCS table
            int n = oldLines.Length;
            int m = newLines.Length;
            int[,] lcs = new int[n + 1, m + 1];

            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < m; j++)
                {
                    if (oldLines[i] == newLines[j])
                    {
                        lcs[i + 1, j + 1] = lcs[i, j] + 1;
                    }
                    else
                    {
                        lcs[i + 1, j + 1] = Math.Max(lcs[i + 1, j], lcs[i, j + 1]);
                    }
                }
            }

            // Backtrack to build diff lines
            List<DiffLine> reversedLines = new List<DiffLine>();
            int x = n;
            int y = m;

            while (x > 0 || y > 0)
            {
                if (x > 0 && y > 0 && oldLines[x - 1] == newLines[y - 1])
                {
                    reversedLines.Add(new DiffLine
                    {
                        Type = DiffLineType.Unchanged,
                        OldLineNumber = x,
                        NewLineNumber = y,
                        Text = oldLines[x - 1]
                    });
                    result.UnchangedCount++;
                    x--;
                    y--;
                }
                else if (y > 0 && (x == 0 || lcs[x, y - 1] >= lcs[x - 1, y]))
                {
                    reversedLines.Add(new DiffLine
                    {
                        Type = DiffLineType.Added,
                        OldLineNumber = null,
                        NewLineNumber = y,
                        Text = newLines[y - 1]
                    });
                    result.AddedCount++;
                    y--;
                }
                else if (x > 0 && (y == 0 || lcs[x, y - 1] < lcs[x - 1, y]))
                {
                    reversedLines.Add(new DiffLine
                    {
                        Type = DiffLineType.Deleted,
                        OldLineNumber = x,
                        NewLineNumber = null,
                        Text = oldLines[x - 1]
                    });
                    result.DeletedCount++;
                    x--;
                }
            }

            reversedLines.Reverse();
            result.Lines = reversedLines;

            int totalComparable = result.TotalOldLines + result.TotalNewLines;
            if (totalComparable > 0)
            {
                result.SimilarityPercentage = Math.Round((2.0 * result.UnchangedCount / totalComparable) * 100.0, 1);
            }
            else
            {
                result.SimilarityPercentage = 100.0;
            }

            return result;
        }

        /// <summary>
        /// Creates an automatic timestamped snapshot of a document in the archive folder.
        /// </summary>
        public static string CreateSnapshot(string projectPath, string docType, string content)
        {
            if (string.IsNullOrWhiteSpace(projectPath) || !Directory.Exists(projectPath)) return null;

            try
            {
                bool isCopy = string.Equals(docType, "copy", StringComparison.OrdinalIgnoreCase);
                string subDir = isCopy ? Path.Combine(projectPath, "03_COPYWRITING", "archive") : Path.Combine(projectPath, "01_BRIEF_ASSETS", "archive");

                if (!Directory.Exists(subDir))
                {
                    Directory.CreateDirectory(subDir);
                }

                string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                string fileName = isCopy ? string.Format("COPY_{0}.md", timestamp) : string.Format("README_{0}.md", timestamp);
                string targetPath = Path.Combine(subDir, fileName);

                File.WriteAllText(targetPath, content ?? string.Empty, Encoding.UTF8);
                return targetPath;
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TextDiffService] Error writing snapshot: " + ex.Message);
                return null;
            }
        }

        /// <summary>
        /// Discovers all available revision files and snapshots for a document in a project.
        /// </summary>
        public static List<RevisionItem> GetRevisions(string projectPath, string docType)
        {
            List<RevisionItem> revisions = new List<RevisionItem>();
            if (string.IsNullOrWhiteSpace(projectPath) || !Directory.Exists(projectPath)) return revisions;

            bool isCopy = string.Equals(docType, "copy", StringComparison.OrdinalIgnoreCase);

            // 1. Current active file
            string currentPath = isCopy ?
                Path.Combine(projectPath, "03_COPYWRITING", "COPY.md") :
                Path.Combine(projectPath, "README.md");

            if (!File.Exists(currentPath) && isCopy)
            {
                currentPath = Path.Combine(projectPath, "COPY.md");
            }

            if (File.Exists(currentPath))
            {
                FileInfo fi = new FileInfo(currentPath);
                revisions.Add(new RevisionItem
                {
                    FilePath = currentPath,
                    DisplayName = string.Format("● Current Working Copy ({0:yyyy-MM-dd HH:mm})", fi.LastWriteTime),
                    Timestamp = fi.LastWriteTime,
                    FileSizeBytes = fi.Length,
                    IsCurrent = true
                });
            }

            // 2. Archive snapshots
            string archiveDir = isCopy ?
                Path.Combine(projectPath, "03_COPYWRITING", "archive") :
                Path.Combine(projectPath, "01_BRIEF_ASSETS", "archive");

            if (Directory.Exists(archiveDir))
            {
                string searchPattern = isCopy ? "COPY_*.md" : "README_*.md";
                string[] snapshotFiles = Directory.GetFiles(archiveDir, searchPattern);
                foreach (string file in snapshotFiles)
                {
                    FileInfo fi = new FileInfo(file);
                    revisions.Add(new RevisionItem
                    {
                        FilePath = file,
                        DisplayName = string.Format("Snapshot: {0} ({1:yyyy-MM-dd HH:mm})", fi.Name, fi.LastWriteTime),
                        Timestamp = fi.LastWriteTime,
                        FileSizeBytes = fi.Length,
                        IsCurrent = false
                    });
                }
            }

            // Also check .snapshots directory
            string hiddenSnapDir = isCopy ?
                Path.Combine(projectPath, "03_COPYWRITING", ".snapshots") :
                Path.Combine(projectPath, ".snapshots");
            if (Directory.Exists(hiddenSnapDir))
            {
                string[] snapFiles = Directory.GetFiles(hiddenSnapDir, "*.md");
                foreach (string file in snapFiles)
                {
                    if (revisions.Any(r => string.Equals(r.FilePath, file, StringComparison.OrdinalIgnoreCase)))
                        continue;

                    FileInfo fi = new FileInfo(file);
                    revisions.Add(new RevisionItem
                    {
                        FilePath = file,
                        DisplayName = string.Format("Snapshot: {0} ({1:yyyy-MM-dd HH:mm})", fi.Name, fi.LastWriteTime),
                        Timestamp = fi.LastWriteTime,
                        FileSizeBytes = fi.Length,
                        IsCurrent = false
                    });
                }
            }

            // 3. Sibling versions in parent folders (e.g., COPY_v1.md, COPY_draft.md)
            string parentDir = isCopy ? Path.Combine(projectPath, "03_COPYWRITING") : projectPath;
            if (Directory.Exists(parentDir))
            {
                string[] files = Directory.GetFiles(parentDir, isCopy ? "COPY_*.md" : "README_*.md");
                foreach (string file in files)
                {
                    if (revisions.Any(r => string.Equals(r.FilePath, file, StringComparison.OrdinalIgnoreCase)))
                        continue;

                    FileInfo fi = new FileInfo(file);
                    revisions.Add(new RevisionItem
                    {
                        FilePath = file,
                        DisplayName = string.Format("Version: {0} ({1:yyyy-MM-dd HH:mm})", fi.Name, fi.LastWriteTime),
                        Timestamp = fi.LastWriteTime,
                        FileSizeBytes = fi.Length,
                        IsCurrent = false
                    });
                }
            }

            // Order by timestamp descending (most recent first)
            return revisions.OrderByDescending(r => r.Timestamp).ToList();
        }
    }
}
