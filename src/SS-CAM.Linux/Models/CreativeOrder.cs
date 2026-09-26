using System;
using System.Collections.Generic;

namespace SS_CAM.Linux.Models
{
    public class CreativeOrder
    {
        public string Id { get; set; } = "";
        public string Title { get; set; } = "";
        public string Entity { get; set; } = "SSH";
        public string Priority { get; set; } = "tier_1";
        public string Channel { get; set; } = "digital";
        public string Format { get; set; } = "1_1_feed";
        public string CustomSize { get; set; } = "";
        public string Material { get; set; } = "";
        public string MaterialType { get; set; } = "";
        public string Copy { get; set; } = "";
        private string _targetDate = "";
        public string TargetDate
        {
            get => _targetDate;
            set
            {
                _targetDate = value ?? "";
                if (string.IsNullOrWhiteSpace(_deadline)) _deadline = _targetDate;
            }
        }

        private string _deadline = "";
        public string Deadline
        {
            get => !string.IsNullOrWhiteSpace(_deadline) ? _deadline : TargetDate;
            set
            {
                _deadline = value ?? "";
                _targetDate = value ?? "";
            }
        }

        public string CreatedDate { get; set; } = DateTime.Now.ToString("yyyy-MM-dd");
        public string StartDate { get; set; } = DateTime.Now.ToString("yyyy-MM-dd");

        private string _duration = "";
        public string Duration
        {
            get
            {
                if (!string.IsNullOrWhiteSpace(_duration)) return _duration;
                return CalculateDuration(StartDate, Deadline);
            }
            set => _duration = value ?? "";
        }

        public string AttachmentNote { get; set; } = "";
        public string Requester { get; set; } = "Staff";
        public string RequesterRole { get; set; } = "";
        public string Status { get; set; } = "pending";
        public string SubmittedAt { get; set; } = "";
        public string UpdatedAt { get; set; } = "";
        public string? AssignedTo { get; set; } = null;
        public string? ProjectId { get; set; } = null;
        public string InternalNote { get; set; } = "";

        private int _attachmentCount;
        public int AttachmentCount
        {
            get
            {
                if (Attachments != null && Attachments.Count > 0) return Attachments.Count;
                if (AttachmentFiles != null && AttachmentFiles.Count > 0) return AttachmentFiles.Count;
                return _attachmentCount;
            }
            set => _attachmentCount = value;
        }

        public List<string> AttachmentFiles { get; set; } = new();
        public List<OrderAttachmentItem> Attachments { get; set; } = new();

        public string SafeTitle => string.IsNullOrWhiteSpace(Title) ? "Untitled Request" : Title.Trim();
        public string SafeEntity => string.IsNullOrWhiteSpace(Entity) ? "SSH" : Entity.Trim().ToUpperInvariant();

        public string EntityFullName => SafeEntity switch
        {
            "SSC" => "SuamiSihat Healthcare / Clinic",
            "SSH" => "SuamiSihat Holding",
            "SSE" => "SuamiSihat E-Commerce",
            "SSW" => "SuamiSihat Wellness",
            "SST" => "SuamiSihat Technology",
            _     => "SuamiSihat Brand"
        };

        public string EntityColor => SafeEntity switch
        {
            "SSC" => "#06B6D4",
            "SSH" => "#3B82F6",
            "SSE" => "#8B5CF6",
            "SSW" => "#10B981",
            "SST" => "#F97316",
            _     => "#2563EB"
        };

        public string PriorityBadge
        {
            get
            {
                string p = (Priority ?? "").ToLowerInvariant();
                if (p.Contains("3") || p.Contains("urgent")) return "P3";
                if (p.Contains("2") || p.Contains("fast") || p.Contains("high")) return "P2";
                if (p.Contains("0") || p.Contains("low") || p.Contains("pipeline")) return "P0";
                return "P1";
            }
        }

        public string PriorityLabel => PriorityBadge switch
        {
            "P3" => "P3 (Urgent)",
            "P2" => "P2 (Fast-Track)",
            "P0" => "P0 (Low / Pipeline)",
            _    => "P1 (Standard)"
        };

        public string PriorityColor => PriorityBadge switch
        {
            "P3" => "#EF4444",
            "P2" => "#F59E0B",
            "P0" => "#64748B",
            _    => "#10B981"
        };

        public string FormatLabel
        {
            get
            {
                string label = (Format ?? "").ToLowerInvariant() switch
                {
                    "9_16_video"          => "9:16 Video / Reels",
                    "1_1_feed"            => "1:1 Feed Post",
                    "4_5_portrait"        => "4:5 Portrait Feed",
                    "16_9_landscape"      => "16:9 Landscape HD",
                    "print_digital"       => "Digital Banner / Web",
                    "custom_digital"      => "Custom Screen",
                    "print_packaging_box" => "Packaging Box & Sleeve",
                    "print_label"         => "Bottle / Jar Label",
                    "print_posm"          => "Print / POSM Poster",
                    "print_banner_rollup" => "Roll-Up / Bunting",
                    "print_flyer"         => "Flyer / Leaflet",
                    "custom_print"        => "Custom Print",
                    _ => string.IsNullOrWhiteSpace(Format) ? "Standard Asset" : Format.Replace('_', ' ')
                };

                if (!string.IsNullOrWhiteSpace(CustomSize))
                    label += $" ({CustomSize.Trim()})";

                string mat = !string.IsNullOrWhiteSpace(Material) ? Material : MaterialType;
                if (!string.IsNullOrWhiteSpace(mat))
                    label += $" · {mat.Replace('_', ' ')}";

                return label;
            }
        }

        public string StatusLabel => (Status ?? "").ToLowerInvariant() switch
        {
            "pending"      => "Pending Review",
            "in_progress"  => "In Progress",
            "for_approval" => "For Approval",
            "done" or "completed" => "Added to Backlog",
            "cancelled"    => "Cancelled",
            _ => Status ?? "Pending"
        };

        public string StatusColor => (Status ?? "").ToLowerInvariant() switch
        {
            "pending"      => "#F59E0B",
            "in_progress"  => "#3B82F6",
            "for_approval" => "#8B5CF6",
            "done" or "completed" => "#10B981",
            "cancelled"    => "#64748B",
            _ => "#94A3B8"
        };

        public bool IsConverted => !string.IsNullOrWhiteSpace(ProjectId);

        public string FormattedTargetDate
        {
            get
            {
                if (DateTime.TryParse(TargetDate, out var dt))
                    return dt.ToString("dd MMM yyyy (ddd)");
                return TargetDate ?? "No Deadline";
            }
        }

        public string CopySnippet
        {
            get
            {
                if (string.IsNullOrWhiteSpace(Copy)) return "No copy provided.";
                string clean = Copy.Replace('\r', ' ').Replace('\n', ' ').Trim();
                return clean.Length > 120 ? clean.Substring(0, 117) + "..." : clean;
            }
        }

        public static string CalculateDuration(string? startStr, string? endStr)
        {
            if (DateTime.TryParse(startStr, out var s) && DateTime.TryParse(endStr, out var e))
            {
                int days = (int)Math.Round((e.Date - s.Date).TotalDays);
                if (days <= 0) return "Same day (1d)";
                if (days == 1) return "1 day";
                if (days % 7 == 0) return $"{days / 7}w ({days}d)";
                return $"{days} days";
            }
            return "";
        }
    }

    /// <summary>
    /// Represents an attachment file stored in the NAS order vault.
    /// </summary>
    public class OrderAttachmentItem
    {
        public string Filename { get; set; } = "";
        public long SizeBytes { get; set; }
        public string SizeFormatted { get; set; } = "";
        public string FilePath { get; set; } = "";
        public string Url { get; set; } = "";
        public string UploadedAt { get; set; } = "";

        public string DisplaySize
        {
            get
            {
                if (!string.IsNullOrWhiteSpace(SizeFormatted)) return SizeFormatted;
                if (SizeBytes < 1024) return $"{SizeBytes} B";
                if (SizeBytes < 1024 * 1024) return $"{SizeBytes / 1024.0:0.#} KB";
                return $"{SizeBytes / (1024.0 * 1024.0):0.#} MB";
            }
        }
    }

    /// <summary>
    /// Lightweight order item used in dropdowns, ProjectCreator linking, and attachment ingestion.
    /// </summary>
    public class CreativeOrderItem
    {
        public string Id { get; set; } = "";
        public string Title { get; set; } = "";
        public string SubBrand { get; set; } = "";
        public string RequesterName { get; set; } = "";
        public string RequesterEmail { get; set; } = "";
        public string DeliverableType { get; set; } = "";
        public string Priority { get; set; } = "";
        public string Deadline { get; set; } = "";
        public string CreatedDate { get; set; } = "";
        public string StartDate { get; set; } = "";
        public string Duration { get; set; } = "";
        public string Description { get; set; } = "";
        public string Status { get; set; } = "";
        public string ProjectId { get; set; } = "";
        public string CreatedAt { get; set; } = "";
        public string UpdatedAt { get; set; } = "";
        public int AttachmentCount { get; set; }
        public System.Collections.Generic.List<string> AttachmentFiles { get; set; } = new();
        public System.Collections.Generic.List<OrderAttachmentItem> Attachments { get; set; } = new();

        public string DisplayText
        {
            get
            {
                string attachBadge = AttachmentCount > 0 ? $" [📎 {AttachmentCount} files]" : "";
                string brand = !string.IsNullOrWhiteSpace(SubBrand) ? $"[{SubBrand}] " : "";
                return $"{brand}{Id} | {Title ?? "Untitled"}{attachBadge}";
            }
        }

        public override string ToString() => DisplayText;
    }
}
