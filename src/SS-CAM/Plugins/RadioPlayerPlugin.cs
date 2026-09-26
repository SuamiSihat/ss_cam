using System;
using SS_CAM.Models;
using SS_CAM.Views;
using SS_CAM.Services;

namespace SS_CAM.Plugins
{
    public class RadioPlayerPlugin : IAppPlugin
    {
        public string Id { get { return "radio-player"; } }
        public string DisplayName { get { return "Radio Player"; } }
        public string Description { get { return "Ambient radio streams & focus audio"; } }
        public string NavIconGlyph { get { return "MusicNote224"; } }
        public Type PageType { get { return typeof(RadioPage); } }

        public void Configure(PluginConfig config)
        {
            // Inject pinned stations from config into RadioStreamService
            if (config.PinnedStations != null && config.PinnedStations.Count > 0)
            {
                // To avoid multiple insertions, we could clear specific pinned stations first
                // or just let the RadioStreamService handle initialization using this config.
                // The actual logic is moved into RadioStreamService to read TenantConfigService.Current
            }
        }
    }
}
