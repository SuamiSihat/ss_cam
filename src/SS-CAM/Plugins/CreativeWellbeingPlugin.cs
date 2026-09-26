using System;
using SS_CAM.Models;
using SS_CAM.Views;

namespace SS_CAM.Plugins
{
    public class CreativeWellbeingPlugin : IAppPlugin
    {
        public string Id { get { return "creative-wellbeing"; } }
        public string DisplayName { get { return "Creative Wellbeing"; } }
        public string Description { get { return "Ergonomics, breaks & focus analytics"; } }
        public string NavIconGlyph { get { return "Heart24"; } }
        public Type PageType { get { return typeof(WellbeingPage); } }

        public void Configure(PluginConfig config)
        {
        }
    }
}
