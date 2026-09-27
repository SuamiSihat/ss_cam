using System;
using System.Collections.Generic;
using SS_CAM.Models;
using SS_CAM.Plugins;

namespace SS_CAM.Services
{
    public static class PluginRegistry
    {
        private static List<IAppPlugin> _activePlugins = new List<IAppPlugin>();
        public static List<IAppPlugin> ActivePlugins
        {
            get { return _activePlugins; }
        }

        public static void Initialize()
        {
            _activePlugins.Clear();
            var config = TenantConfigService.Current;
            if (config == null || config.Plugins == null) return;

            var availablePlugins = new List<IAppPlugin>
            {
                new WaktuSolatPlugin(),
                new CreativeWellbeingPlugin(),
                new QrCodeStudioPlugin(),
                new RadioPlayerPlugin()
            };

            foreach (var plugin in availablePlugins)
            {
                PluginConfig pluginConfig;
                if (config.Plugins.TryGetValue(plugin.Id, out pluginConfig) && pluginConfig.Enabled)
                {
                    plugin.Configure(pluginConfig);
                    _activePlugins.Add(plugin);
                }
            }
        }
    }
}
