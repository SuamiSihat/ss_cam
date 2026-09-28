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
            LoadConfig();
        }

        public static string GetConfigFilePath()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string localFile = Path.Combine(baseDir, "tenant_config.json");
            if (File.Exists(localFile))
            {
                return localFile;
            }

            string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string appDataFile = Path.Combine(appData, "SuamiSihat", "tenant_config.json");
            if (File.Exists(appDataFile))
            {
                return appDataFile;
            }

            string corpAppDataFile = Path.Combine(appData, "Corporate", "tenant_config.json");
            if (File.Exists(corpAppDataFile))
            {
                return corpAppDataFile;
            }

            return localFile;
        }

        public static void LoadConfig()
        {
            try
            {
                string configPath = GetConfigFilePath();
                if (File.Exists(configPath))
                {
                    string json = File.ReadAllText(configPath);
                    Current = JsonConvert.DeserializeObject<TenantConfig>(json);
                    if (Current == null)
                    {
                        Current = CreateDefaultConfig();
                    }
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

        public static void SaveCurrentConfig()
        {
            if (Current == null) return;
            try
            {
                string targetPath = GetConfigFilePath();
                string json = JsonConvert.SerializeObject(Current, Formatting.Indented);
                try
                {
                    File.WriteAllText(targetPath, json);
                }
                catch (UnauthorizedAccessException)
                {
                    string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                    string dir = Path.Combine(appData, "SuamiSihat");
                    if (!Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                    }
                    string fallbackPath = Path.Combine(dir, "tenant_config.json");
                    File.WriteAllText(fallbackPath, json);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TenantConfigService] SaveCurrentConfig: " + ex.Message);
            }
        }

        public static void SetPluginEnabled(string pluginId, bool enabled)
        {
            if (Current == null)
            {
                Current = CreateDefaultConfig();
            }

            if (Current.Plugins == null)
            {
                Current.Plugins = new System.Collections.Generic.Dictionary<string, PluginConfig>();
            }

            PluginConfig config;
            if (Current.Plugins.TryGetValue(pluginId, out config))
            {
                config.Enabled = enabled;
            }
            else
            {
                Current.Plugins[pluginId] = new PluginConfig { Enabled = enabled };
            }

            SaveCurrentConfig();
        }

        public static bool IsPluginEnabled(string pluginId)
        {
            if (Current == null || Current.Plugins == null) return true;
            PluginConfig config;
            if (Current.Plugins.TryGetValue(pluginId, out config))
            {
                return config.Enabled;
            }
            return true;
        }

        private static TenantConfig CreateDefaultConfig()
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            bool isExistingSuamiSihat = Directory.Exists(Path.Combine(appData, "SuamiSihat"));

            if (isExistingSuamiSihat)
            {
                return new TenantConfig
                {
                    TenantId = "suamisihat",
                    AppFolderName = "SuamiSihat",
                    AppName = "SuamiSihat Creative Assets Management",
                    CompanyUrl = "https://suamisihat.clinic",
                    PortalUrl = "https://creative.suamisihat.myds.me",
                    AssetPortalUrl = "https://assets.suamisihat.myds.me",
                    StorageLabel = "SSNAS",
                    ThemeDefaultName = "SS Default (Nord Light)",
                    Plugins = new System.Collections.Generic.Dictionary<string, PluginConfig>
                    {
                        { "waktu-solat", new PluginConfig { Enabled = true, DefaultZone = "SGR02" } },
                        { "creative-wellbeing", new PluginConfig { Enabled = true } },
                        { "qr-code-studio", new PluginConfig { Enabled = true, DefaultContent = "https://suamisihat.clinic", FilenamePrefix = "SuamiSihat_QRCode" } },
                        { "radio-player", new PluginConfig { Enabled = true, PinnedStations = new System.Collections.Generic.List<PinnedStationConfig> {
                            new PinnedStationConfig { Id = "preset_suamisihat", Name = "SuamiSihat Radio Official", StreamUrl = "https://radio.suamisihat.myds.me/live" }
                        }}}
                    },
                    Subsidiaries = new System.Collections.Generic.List<SubsidiaryConfig>
                    {
                        new SubsidiaryConfig { Code = "SS", Name = "SuamiSihat", DisplayName = "SS - SuamiSihat", ColorHex = "#0047AB" },
                        new SubsidiaryConfig { Code = "HQ", Name = "SuamiSihat Holding", DisplayName = "HQ - SuamiSihat Holding", ColorHex = "#1E3A8A" },
                        new SubsidiaryConfig { Code = "SSE", Name = "SuamiSihat Ecommerce", DisplayName = "SSE - SuamiSihat Ecommerce", ColorHex = "#0D9488" },
                        new SubsidiaryConfig { Code = "SSC", Name = "SuamiSihat Clinic", DisplayName = "SSC - Klinik SuamiSihat", ColorHex = "#0284C7" },
                        new SubsidiaryConfig { Code = "KOP", Name = "Koperasi SuamiSihat", DisplayName = "KOP - Koperasi SuamiSihat", ColorHex = "#D97706" },
                        new SubsidiaryConfig { Code = "HQM", Name = "HQ Media", DisplayName = "HQM - SuamiSihat Media", ColorHex = "#7C3AED" },
                        new SubsidiaryConfig { Code = "PRO", Name = "SuamiSihat Pro", DisplayName = "PRO - SuamiSihat Pro", ColorHex = "#DC2626" }
                    }
                };
            }

            return new TenantConfig
            {
                TenantId = "corporate",
                AppFolderName = "Corporate",
                AppName = "Creative Assets Management",
                CompanyUrl = "https://corporate.local",
                PortalUrl = "https://portal.corporate.local",
                AssetPortalUrl = "https://assets.corporate.local",
                StorageLabel = "NAS",
                ThemeDefaultName = "Corporate Light",
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
