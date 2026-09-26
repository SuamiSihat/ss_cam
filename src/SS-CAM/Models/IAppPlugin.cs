using System;
using SS_CAM.Models;

namespace SS_CAM.Models
{
    public interface IAppPlugin
    {
        string Id { get; }
        string DisplayName { get; }
        string Description { get; }
        string NavIconGlyph { get; }
        Type PageType { get; }
        void Configure(PluginConfig config);
    }
}
