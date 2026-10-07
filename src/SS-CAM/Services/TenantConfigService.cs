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

            // If localFile directory is drive root (e.g. D:\) or not write-friendly, prefer appDataFile
            if (baseDir.TrimEnd('\\').Length <= 3)
            {
                return appDataFile;
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
                    var settings = new JsonSerializerSettings
                    {
                        ObjectCreationHandling = ObjectCreationHandling.Replace
                    };
                    Current = JsonConvert.DeserializeObject<TenantConfig>(json, settings);
                }

                if (Current == null)
                {
                    Current = LoadEmbeddedConfig();
                }

                if (Current == null)
                {
                    Current = CreateDefaultConfig();
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TenantConfigService] Init: " + ex.Message);
                Current = LoadEmbeddedConfig() ?? CreateDefaultConfig();
            }
        }

        private static TenantConfig LoadEmbeddedConfig()
        {
            try
            {
                var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                string resourceName = "SS_CAM.tenant_config.json";
                using (var stream = assembly.GetManifestResourceStream(resourceName))
                {
                    if (stream != null)
                    {
                        using (var reader = new StreamReader(stream))
                        {
                            string json = reader.ReadToEnd();
                            var settings = new JsonSerializerSettings
                            {
                                ObjectCreationHandling = ObjectCreationHandling.Replace
                            };
                            return JsonConvert.DeserializeObject<TenantConfig>(json, settings);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TenantConfigService] LoadEmbeddedConfig error: " + ex.Message);
            }
            return null;
        }

        public static void SaveCurrentConfig()
        {
            if (Current == null) return;

            // Anti-poisoning guard: Never overwrite SuamiSihat directory with corporate profile
            if (Current.TenantId == "corporate")
            {
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string ssDir = Path.Combine(appData, "SuamiSihat");
                string targetPath = GetConfigFilePath();
                if (targetPath.StartsWith(ssDir, StringComparison.OrdinalIgnoreCase))
                {
                    Debug.WriteLine("[TenantConfigService] Refusing to overwrite SuamiSihat profile with corporate fallback.");
                    return;
                }
            }

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
                    string targetFolder = Current.TenantId == "suamisihat" ? "SuamiSihat" : "Corporate";
                    string dir = Path.Combine(appData, targetFolder);
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
            bool isSsCamProcess = AppDomain.CurrentDomain.FriendlyName != null &&
                                  AppDomain.CurrentDomain.FriendlyName.IndexOf("SS-CAM", StringComparison.OrdinalIgnoreCase) >= 0;

            if (isExistingSuamiSihat || isSsCamProcess)
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
                        new SubsidiaryConfig { Code = "SSH", Name = "SuamiSihat Holding", DisplayName = "SSH - SuamiSihat Holding", ColorHex = "#022057" },
                        new SubsidiaryConfig { Code = "SSC", Name = "SuamiSihat Clinic", DisplayName = "SSC - SuamiSihat Clinic", ColorHex = "#043388" },
                        new SubsidiaryConfig { Code = "SSW", Name = "SuamiSihat Wellness", DisplayName = "SSW - SuamiSihat Wellness", ColorHex = "#21A1F7" },
                        new SubsidiaryConfig { Code = "SSE", Name = "SuamiSihat Ecommerce", DisplayName = "SSE - SuamiSihat Ecommerce", ColorHex = "#BD9A73" },
                        new SubsidiaryConfig { Code = "SST", Name = "SuamiSihat Technology", DisplayName = "SST - SuamiSihat Technology", ColorHex = "#6DC6EC" }
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
