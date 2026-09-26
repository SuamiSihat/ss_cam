using System;
using System.IO;
using Newtonsoft.Json;
using SS_CAM.Models;
using System.Diagnostics;

namespace SS_CAM.Services
{
    public static class TenantConfigService
    {
        public static TenantConfig Current { get; private set; }

        static TenantConfigService()
        {
            try
            {
                string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "tenant_config.json");
                if (File.Exists(configPath))
                {
                    string json = File.ReadAllText(configPath);
                    Current = JsonConvert.DeserializeObject<TenantConfig>(json);
                }
                else
                {
                    Current = CreateDefaultConfig();
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TenantConfigService] Init: " + ex.Message);
                Current = CreateDefaultConfig();
            }
        }

        private static TenantConfig CreateDefaultConfig()
        {
            return new TenantConfig
            {
                TenantId = "corporate",
                AppFolderName = "Corporate",
                Plugins = new System.Collections.Generic.Dictionary<string, PluginConfig>
                {
                    { "waktu-solat", new PluginConfig { Enabled = true, DefaultZone = "WLY01" } },
                    { "creative-wellbeing", new PluginConfig { Enabled = true } },
                    { "qr-code-studio", new PluginConfig { Enabled = true, DefaultContent = "https://corporate.local", FilenamePrefix = "Corporate_QRCode" } },
                    { "radio-player", new PluginConfig { Enabled = true, PinnedStations = new System.Collections.Generic.List<PinnedStationConfig> {
                        new PinnedStationConfig { Id = "preset_corporate", Name = "Corporate Radio", StreamUrl = "https://radio.corporate.local/listen" }
                    }}}
                }
            };
        }
    }
}
