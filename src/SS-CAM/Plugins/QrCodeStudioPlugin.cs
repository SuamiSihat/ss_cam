using System;
using SS_CAM.Models;
using SS_CAM.Views;

namespace SS_CAM.Plugins
{
    public class QrCodeStudioPlugin : IAppPlugin
    {
        public string Id { get { return "qr-code-studio"; } }
        public string DisplayName { get { return "QR Code Studio"; } }
        public string Description { get { return "Vector QR codes for packaging & marketing"; } }
        public string NavIconGlyph { get { return "QrCode24"; } }
        public Type PageType { get { return typeof(QrCodePage); } }

        public void Configure(PluginConfig config)
        {
        }
    }
}
