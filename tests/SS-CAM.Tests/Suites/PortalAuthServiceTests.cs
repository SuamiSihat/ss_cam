using System;
using System.Net.Security;
using SS_CAM.Services;

namespace SS_CAM.Tests.Suites
{
    public class PortalAuthServiceTests
    {
        public void TestValidCertificateAlwaysAcceptable()
        {
            Uri publicUri = new Uri("https://github.com/SuamiSihat/ss_cam/releases");
            bool acceptable = PortalAuthService.IsCertificateAcceptable(publicUri, SslPolicyErrors.None);
            Assert.IsTrue(acceptable, "Valid SSL certificates with SslPolicyErrors.None must always be accepted");
        }

        public void TestUntrustedPublicHostCertificateRejected()
        {
            Uri untrustedUri = new Uri("https://malicious-or-expired-domain.com/api/test");
            bool acceptable = PortalAuthService.IsCertificateAcceptable(untrustedUri, SslPolicyErrors.RemoteCertificateChainErrors);
            Assert.IsFalse(acceptable, "Certificates with errors on arbitrary third-party domains MUST be rejected");
        }

        public void TestConfiguredPortalHostAcceptsSelfSignedCertificate()
        {
            Uri portalUri = new Uri(PortalAuthService.PortalBaseUrl);
            bool acceptable = PortalAuthService.IsCertificateAcceptable(portalUri, SslPolicyErrors.RemoteCertificateChainErrors);
            Assert.IsTrue(acceptable, "Self-signed or internal CA certificate errors on the configured PortalHost must be accepted");
        }

        public void TestTenantConfiguredHostsAcceptInternalCertificates()
        {
            Uri radioUri = new Uri("https://radio.suamisihat.myds.me/live.mp3");
            bool acceptable = PortalAuthService.IsCertificateAcceptable(radioUri, SslPolicyErrors.RemoteCertificateNameMismatch);
            Assert.IsTrue(acceptable, "Tenant-configured endpoints (radio, assets, clinic) must be permitted for internal/NAS hosts");

            Uri assetUri = new Uri("https://assets.suamisihat.myds.me/brand-system/");
            bool assetAcceptable = PortalAuthService.IsCertificateAcceptable(assetUri, SslPolicyErrors.RemoteCertificateChainErrors);
            Assert.IsTrue(assetAcceptable, "Asset portal endpoint must be permitted for internal/NAS hosts");
        }

        public void TestNullUriIsRejectedWhenErrorsPresent()
        {
            bool acceptable = PortalAuthService.IsCertificateAcceptable(null, SslPolicyErrors.RemoteCertificateChainErrors);
            Assert.IsFalse(acceptable, "Null URI with SSL errors must return false");
        }

        public void TestPortalBaseUrlAlwaysEndsWithSlash()
        {
            string url = PortalAuthService.PortalBaseUrl;
            Assert.IsNotNull(url);
            Assert.IsTrue(url.EndsWith("/"), "PortalBaseUrl must always terminate with a trailing slash");
        }
    }
}
