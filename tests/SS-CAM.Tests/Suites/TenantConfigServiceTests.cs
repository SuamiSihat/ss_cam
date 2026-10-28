using System;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Tests.Suites
{
    public class TenantConfigServiceTests
    {
        public void TestTenantConfigLoadedAndValid()
        {
            TenantConfig config = TenantConfigService.Current;
            Assert.IsNotNull(config, "TenantConfigService.Current must not be null");
            Assert.IsNotNull(config.TenantId, "TenantId must not be null");
            Assert.IsNotNull(config.AppName, "AppName must not be null");
            Assert.IsNotNull(config.PortalUrl, "PortalUrl must not be null");
        }

        public void TestSubsidiariesConfigured()
        {
            TenantConfig config = TenantConfigService.Current;
            Assert.IsNotNull(config.Subsidiaries, "Subsidiaries list must be defined");
            Assert.IsTrue(config.Subsidiaries.Count > 0, "At least one subsidiary must be configured");

            foreach (var sub in config.Subsidiaries)
            {
                Assert.IsNotNull(sub.Code, "Subsidiary code must not be null");
                Assert.IsNotNull(sub.Name, "Subsidiary name must not be null");
                Assert.IsTrue(sub.ColorHex.StartsWith("#"), "Subsidiary color must start with #");
            }
        }

        public void TestPluginsConfigured()
        {
            TenantConfig config = TenantConfigService.Current;
            Assert.IsNotNull(config.Plugins, "Plugins dictionary must not be null");
            Assert.IsTrue(config.Plugins.ContainsKey("radio-player"), "radio-player plugin must be configured");
        }
    }
}
