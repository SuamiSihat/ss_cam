using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Newtonsoft.Json;

namespace SS_CAM.Services
{
    public class DashboardWidgetConfig
    {
        public string Id { get; set; }
        public string Title { get; set; }
        public bool IsVisible { get; set; }
        public bool IsPinned { get; set; }
        public int Order { get; set; }

        public DashboardWidgetConfig()
        {
            IsVisible = true;
            IsPinned = false;
        }
    }

    /// <summary>
    /// Manages persistent ordering, pinning, and visibility of dashboard widgets.
    /// Stores layout state in %APPDATA%\SS-CAM\dashboard_layout.json.
    /// </summary>
    public static class DashboardLayoutService
    {
        private static readonly string ConfigDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "SS-CAM"
        );
        private static readonly string ConfigFilePath = Path.Combine(ConfigDir, "dashboard_layout.json");

        public static List<DashboardWidgetConfig> GetDefaultLayout()
        {
            return new List<DashboardWidgetConfig>
            {
                new DashboardWidgetConfig { Id = "kpis", Title = "Key Metric Cards", IsVisible = true, IsPinned = false, Order = 1 },
                new DashboardWidgetConfig { Id = "spotlight", Title = "In-Flight Production Spotlight", IsVisible = true, IsPinned = false, Order = 2 },
                new DashboardWidgetConfig { Id = "transcodes", Title = "Active Transcoder Jobs", IsVisible = true, IsPinned = false, Order = 3 },
                new DashboardWidgetConfig { Id = "live_tasks", Title = "Live Studio Tasks", IsVisible = true, IsPinned = false, Order = 4 },
                new DashboardWidgetConfig { Id = "recent_projects", Title = "Recent Past Projects", IsVisible = true, IsPinned = false, Order = 5 },
                new DashboardWidgetConfig { Id = "workload_radar", Title = "Designer Workload & Capacity Radar", IsVisible = true, IsPinned = false, Order = 6 },
                new DashboardWidgetConfig { Id = "sla_analytics", Title = "Operational SLA Analytics", IsVisible = true, IsPinned = false, Order = 7 },
                new DashboardWidgetConfig { Id = "designer_tip", Title = "Designer Inspiration", IsVisible = true, IsPinned = false, Order = 8 },
                new DashboardWidgetConfig { Id = "team_board", Title = "Team Board", IsVisible = true, IsPinned = false, Order = 9 }
            };
        }

        public static List<DashboardWidgetConfig> LoadLayout()
        {
            try
            {
                if (File.Exists(ConfigFilePath))
                {
                    string json = File.ReadAllText(ConfigFilePath);
                    var list = JsonConvert.DeserializeObject<List<DashboardWidgetConfig>>(json);
                    if (list != null && list.Count > 0)
                    {
                        var defaults = GetDefaultLayout();
                        int maxOrder = list.Max(x => x.Order);
                        foreach (var def in defaults)
                        {
                            if (!list.Any(x => string.Equals(x.Id, def.Id, StringComparison.OrdinalIgnoreCase)))
                            {
                                def.Order = ++maxOrder;
                                list.Add(def);
                            }
                        }
                        return list.OrderBy(x => x.IsPinned ? 0 : 1).ThenBy(x => x.Order).ToList();
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[DashboardLayoutService] LoadLayout error: " + ex.Message);
            }

            return GetDefaultLayout();
        }

        public static void SaveLayout(List<DashboardWidgetConfig> layout)
        {
            if (layout == null || layout.Count == 0) return;

            try
            {
                if (!Directory.Exists(ConfigDir))
                {
                    Directory.CreateDirectory(ConfigDir);
                }

                string json = JsonConvert.SerializeObject(layout, Formatting.Indented);
                File.WriteAllText(ConfigFilePath, json);
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[DashboardLayoutService] SaveLayout error: " + ex.Message);
            }
        }

        public static List<DashboardWidgetConfig> ResetToDefault()
        {
            var def = GetDefaultLayout();
            SaveLayout(def);
            return def;
        }
    }
}
