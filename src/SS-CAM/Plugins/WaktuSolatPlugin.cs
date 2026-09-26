using System;
using SS_CAM.Models;
using SS_CAM.Views;

namespace SS_CAM.Plugins
{
    public class WaktuSolatPlugin : IAppPlugin
    {
        public string Id { get { return "waktu-solat"; } }
        public string DisplayName { get { return "Waktu Solat"; } }
        public string Description { get { return "Prayer times & Islamic calendar"; } }
        public string NavIconGlyph { get { return "Clock24"; } }
        public Type PageType { get { return typeof(WaktuSolatPage); } }

        public void Configure(PluginConfig config)
        {
            // Default Zone will be retrieved from TenantConfigService.Current
        }
    }
}
