using System;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace SS_CAM.Models
{
    public class TenantConfig
    {
        public string TenantId { get; set; }
        public string AppFolderName { get; set; }
        public string AppName { get; set; }
        public string CompanyUrl { get; set; }
        public string PortalUrl { get; set; }
        public string AssetPortalUrl { get; set; }
        public string StorageLabel { get; set; }
        public string ThemeDefaultName { get; set; }

        [JsonProperty(ObjectCreationHandling = ObjectCreationHandling.Replace)]
        public List<SubsidiaryConfig> Subsidiaries { get; set; }

        [JsonProperty(ObjectCreationHandling = ObjectCreationHandling.Replace)]
        public Dictionary<string, PluginConfig> Plugins { get; set; }

        public TenantConfig()
        {
            TenantId = "corporate";
            AppFolderName = "Corporate";
            AppName = "Creative Assets Management";
            CompanyUrl = "https://corporate.local";
            PortalUrl = "https://portal.corporate.local";
            AssetPortalUrl = "https://assets.corporate.local";
            StorageLabel = "NAS";
            ThemeDefaultName = "Corporate Light";
            Plugins = new Dictionary<string, PluginConfig>();
            Subsidiaries = new List<SubsidiaryConfig>
            {
                new SubsidiaryConfig { Code = "CORP", Name = "Corporate Brand", DisplayName = "CORP - Corporate Brand", ColorHex = "#333333" },
                new SubsidiaryConfig { Code = "CH", Name = "Corporate Holding Sdn Bhd", DisplayName = "CH - Corporate Holding", ColorHex = "#3B82F6" },
                new SubsidiaryConfig { Code = "CC", Name = "Corporate Healthcare / Clinic", DisplayName = "CC - Corporate Healthcare", ColorHex = "#06B6D4" },
                new SubsidiaryConfig { Code = "CW", Name = "Corporate Wellness Sdn Bhd", DisplayName = "CW - Corporate Wellness", ColorHex = "#10B981" },
                new SubsidiaryConfig { Code = "CE", Name = "Corporate Ecommerce Sdn Bhd", DisplayName = "CE - Corporate Ecommerce", ColorHex = "#8B5CF6" },
                new SubsidiaryConfig { Code = "CT", Name = "Corporate Technology Sdn Bhd", DisplayName = "CT - Corporate Technology", ColorHex = "#F97316" }
            };
        }
    }

    public class PluginConfig
    {
        public bool Enabled { get; set; }
        public string DefaultZone { get; set; }
        public string DefaultContent { get; set; }
        public string FilenamePrefix { get; set; }
        public List<PinnedStationConfig> PinnedStations { get; set; }

        public PluginConfig()
        {
            Enabled = true;
            PinnedStations = new List<PinnedStationConfig>();
        }
    }

    public class PinnedStationConfig
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string StreamUrl { get; set; }
    }

    public class SubsidiaryConfig
    {
        public string Code { get; set; }
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string ColorHex { get; set; }
    }
}
