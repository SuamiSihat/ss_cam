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
