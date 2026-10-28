using System;
using System.Collections.Generic;
using System.IO;
using SS_CAM.Models;
using SS_CAM.Services;

namespace SS_CAM.Tests.Suites
{
    public class FrontmatterServiceTests
    {
        public void TestBuildDefaultFrontmatterBasic()
        {
            string fm = FrontmatterService.BuildDefaultFrontmatter("designer_01", "Client Acme", "2026-11-01", null, null, null, null, 1.5, "2026-10-01", "2026-10-05");
            Assert.IsNotNull(fm);
            Assert.StringContains("status: backlog", fm);
            Assert.StringContains("designer: designer_01", fm);
            Assert.StringContains("client: Client Acme", fm);
            Assert.StringContains("deadline: 2026-11-01", fm);
            Assert.StringContains("created: 2026-10-01", fm);
            Assert.StringContains("start_date: 2026-10-05", fm);
            Assert.StringContains("category_weight: 1.5", fm);
        }

        public void TestBuildDefaultFrontmatterWithSubtasks()
        {
            List<ProjectSubtaskItem> subtasks = new List<ProjectSubtaskItem>
            {
                new ProjectSubtaskItem { Id = "sub_1", Name = "Poster Design", Type = "standard", Weight = 2.0, Status = "in-progress" },
                new ProjectSubtaskItem { Id = "sub_2", Name = "Copywriting Hook", Type = "copy", Weight = 1.0, Status = "draft" }
            };

            string fm = FrontmatterService.BuildDefaultFrontmatter("designer_02", "Client Beta", "2026-12-15", null, null, null, subtasks);
            Assert.IsNotNull(fm);
            Assert.StringContains("subtasks:", fm);
            Assert.StringContains("name: \"Poster Design\"", fm);
            Assert.StringContains("weight: 2", fm);
            Assert.StringContains("name: \"Copywriting Hook\"", fm);
        }

        public void TestReadWriteStatusPreservesBody()
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "sscam_test_fm_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                string originalBody = "# Project Brief\n\nThis is a test campaign brief with detailed requirements.\n\n- Deliverable 1\n- Deliverable 2";
                ProjectStatusItem item = new ProjectStatusItem
                {
                    Project = "202610_0001_TEST_Acme_Promo",
                    FullPath = tempDir,
                    Status = "in-progress",
                    Designer = "lead_designer",
                    Client = "Acme Corp",
                    Deadline = "2026-11-30",
                    CreatedDate = "2026-10-20",
                    StartDate = "2026-10-22",
                    Priority = "high",
                    Revision = 2
                };

                FrontmatterService.WriteStatusAndBody(item, originalBody);

                string readmePath = Path.Combine(tempDir, "README.md");
                Assert.IsTrue(File.Exists(readmePath), "README.md was created");

                ProjectStatusItem readItem = FrontmatterService.ReadStatus(tempDir);
                Assert.IsTrue(readItem.HasFrontmatter, "Frontmatter was detected");
                Assert.AreEqual("in-progress", readItem.Status);
                Assert.AreEqual("lead_designer", readItem.Designer);
                Assert.AreEqual("Acme Corp", readItem.Client);
                Assert.AreEqual("2026-11-30", readItem.Deadline);
                Assert.AreEqual("high", readItem.Priority);
                Assert.AreEqual(2, readItem.Revision);

                string body = FrontmatterService.ReadBody(tempDir);
                Assert.StringContains("This is a test campaign brief", body);
                Assert.StringContains("Deliverable 1", body);
            }
            finally
            {
                if (Directory.Exists(tempDir))
                {
                    Directory.Delete(tempDir, true);
                }
            }
        }

        public void TestSubtaskStatusDoesNotOverrideProjectStatus()
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "sscam_test_subtask_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                ProjectStatusItem item = new ProjectStatusItem
                {
                    Project = "202610_0002_TEST_Subtask_Guard",
                    FullPath = tempDir,
                    Status = "review",
                    Designer = "designer_sub",
                    Client = "Test Client",
                    Deadline = "2026-11-15",
                    Subtasks = new List<ProjectSubtaskItem>
                    {
                        new ProjectSubtaskItem { Id = "sub_done", Name = "Task Done", Status = "approved", Weight = 1.0 },
                        new ProjectSubtaskItem { Id = "sub_pending", Name = "Task Pending", Status = "backlog", Weight = 1.0 }
                    }
                };

                FrontmatterService.WriteStatus(item);

                ProjectStatusItem readItem = FrontmatterService.ReadStatus(tempDir);
                Assert.AreEqual("review", readItem.Status, "Project status must remain 'review', not subtask status");
                Assert.IsNotNull(readItem.Subtasks);
                Assert.AreEqual(2, readItem.Subtasks.Count);
                Assert.AreEqual("approved", readItem.Subtasks[0].Status);
                Assert.AreEqual("backlog", readItem.Subtasks[1].Status);
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
