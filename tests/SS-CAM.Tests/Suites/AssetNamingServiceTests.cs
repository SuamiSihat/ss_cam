using System;
using System.IO;
using SS_CAM.Services;

namespace SS_CAM.Tests.Suites
{
    public class AssetNamingServiceTests
    {
        public void TestAuditDetectsCanonicalAndNonCanonicalAssets()
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "sscam_test_naming_" + Guid.NewGuid().ToString("N"));
            string projectFolder = Path.Combine(tempDir, "202610_0005D_SS_Ramadan_Promo");
            string deliverablesDir = Path.Combine(projectFolder, "05_DELIVERABLES");
            Directory.CreateDirectory(deliverablesDir);

            try
            {
                // Create 1 valid file
                string validFile = Path.Combine(deliverablesDir, "202610_0005D_SS_Feed_Poster_1080x1350.png");
                File.WriteAllText(validFile, "dummy image content");

                // Create 1 invalid file (missing prefix and has spaces)
                string invalidFile = Path.Combine(deliverablesDir, "final poster copy (1).png");
                File.WriteAllText(invalidFile, "dummy image content");

                AssetNamingAuditReport report = AssetNamingService.AuditProjectAssets(projectFolder);

                Assert.AreEqual(2, report.TotalAudited, "Total audited files must be 2");
                Assert.AreEqual(1, report.ValidCount, "Valid count must be 1");
                Assert.AreEqual(1, report.IssueCount, "Issue count must be 1");
                Assert.AreEqual(1, report.Issues.Count);

                AssetNamingIssue issue = report.Issues[0];
                Assert.AreEqual("final poster copy (1).png", issue.CurrentFileName);
                Assert.IsTrue(issue.SuggestedFileName.StartsWith("202610_0005D_SS_"), "Suggested name must add project prefix");
                Assert.IsFalse(issue.SuggestedFileName.Contains(" "), "Suggested name must not contain spaces");

                // Test applying renames
                int renamed = AssetNamingService.ApplySuggestedRenames(report.Issues);
                Assert.AreEqual(1, renamed, "Should successfully rename 1 issue");
                Assert.IsTrue(File.Exists(Path.Combine(deliverablesDir, issue.SuggestedFileName)));
            }
            finally
            {
                if (Directory.Exists(tempDir))
                {
                    Directory.Delete(tempDir, true);
                }
            }
        }
    }
}
