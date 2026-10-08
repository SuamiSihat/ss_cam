using System;
using System.Collections.Generic;

namespace SS_CAM.Models
{
    /// <summary>
    /// Represents a single batch archive operation appended to
    /// _Archive/_archive_catalog.jsonl on the NAS workspace.
    /// </summary>
    public class ArchiveCatalogEntry
    {
        /// <summary>Unique ID for this archive operation (GUID).</summary>
        public string Id { get; set; }

        /// <summary>ISO 8601 timestamp when the archive was created.</summary>
        public string Timestamp { get; set; }

        /// <summary>Designer / operator who triggered the batch archive.</summary>
        public string Operator { get; set; }

        /// <summary>List of project folder names (leaf directory names) that were archived.</summary>
        public List<string> ArchivedProjects { get; set; }

        /// <summary>Number of projects included in this batch.</summary>
        public int ProjectCount { get; set; }

        /// <summary>Absolute path to the ZIP file that was produced.</summary>
        public string ZipFilePath { get; set; }

        /// <summary>Total compressed size in bytes of the resulting ZIP.</summary>
        public long ZipSizeBytes { get; set; }

        /// <summary>
        /// Whether the source project folder was moved (destructive) or only copied
        /// (non-destructive). v4.12.0 ships CopyOnly = true.
        /// </summary>
        public bool CopyOnly { get; set; }

        /// <summary>Total uncompressed bytes reclaimed from active workspace by moving projects to archive.</summary>
        public long ReclaimedBytes { get; set; }

        /// <summary>Number of source project folders pruned from active storage.</summary>
        public int PrunedCount { get; set; }

        /// <summary>Overall result of the operation.</summary>
        public bool Success { get; set; }

        /// <summary>Error message if the operation failed, otherwise null.</summary>
        public string ErrorMessage { get; set; }

        public ArchiveCatalogEntry()
        {
            Id = Guid.NewGuid().ToString("N");
            Timestamp = DateTime.UtcNow.ToString("o");
            ArchivedProjects = new List<string>();
            CopyOnly = true;
            Success = false;
        }
    }
}
