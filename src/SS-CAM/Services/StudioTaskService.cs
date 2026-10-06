using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    /// <summary>
    /// Service for managing lightweight pre-production StudioTasks (.sscam/tasks/*.md)
    /// and executing the NAS Workspace Provisioning Bridge to upgrade tasks into heavy Project Vaults.
    /// </summary>
    public static class StudioTaskService
    {
        private const string Delimiter = "---";

        /// <summary>
        /// Gets the dedicated tasks directory (.sscam/tasks) under the workspace root.
        /// </summary>
        public static string GetTasksDirectory(string workspaceRoot)
        {
            if (string.IsNullOrWhiteSpace(workspaceRoot)) return string.Empty;
            string tasksDir = Path.Combine(workspaceRoot, ".sscam", "tasks");
            if (!Directory.Exists(tasksDir))
            {
                try
                {
                    Directory.CreateDirectory(tasksDir);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[StudioTaskService] GetTasksDirectory CreateDirectory error: " + ex.Message);
                }
            }
            return tasksDir;
        }

        /// <summary>
        /// Loads all pre-production studio tasks from .sscam/tasks/*.md.
        /// </summary>
        public static List<ProjectStatusItem> LoadStudioTasks(string workspaceRoot)
        {
            List<ProjectStatusItem> list = new List<ProjectStatusItem>();
            if (string.IsNullOrWhiteSpace(workspaceRoot) || !Directory.Exists(workspaceRoot))
            {
                return list;
            }

            string tasksDir = Path.Combine(workspaceRoot, ".sscam", "tasks");
            if (!Directory.Exists(tasksDir))
            {
                return list;
            }

            try
            {
                string[] files = Directory.GetFiles(tasksDir, "*.md");
                foreach (string file in files)
                {
                    try
                    {
                        ProjectStatusItem item = ParseStudioTaskFile(file);
                        if (item != null)
                        {
                            list.Add(item);
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine(string.Format("[StudioTaskService] ParseStudioTaskFile error for '{0}': {1}", file, ex.Message));
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[StudioTaskService] LoadStudioTasks error: " + ex.Message);
            }

            return list;
        }

        /// <summary>
        /// Parses a single task markdown file into a ProjectStatusItem with IsStudioTask=true.
        /// </summary>
        public static ProjectStatusItem ParseStudioTaskFile(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath)) return null;

            string[] lines = File.ReadAllLines(filePath, Encoding.UTF8);
            if (lines.Length == 0) return null;

            Dictionary<string, string> fm = ParseFrontmatter(lines);
            string id = GetValue(fm, "id", Path.GetFileNameWithoutExtension(filePath));
            string title = GetValue(fm, "title", "Untitled Studio Task");
            string status = GetValue(fm, "status", "backlog");
            string priority = GetValue(fm, "priority", "medium");
            string brand = GetValue(fm, "brand", "SS");
            string assignee = GetValue(fm, "assignee", "");
            string assigneeName = GetValue(fm, "assigneeName", assignee);
            string dueDate = GetValue(fm, "dueDate", GetValue(fm, "deadline", ""));
            string createdDate = GetValue(fm, "createdAt", GetValue(fm, "created", ""));
            string jobId = GetValue(fm, "jobId", "");
            string projectId = GetValue(fm, "projectId", "");

            if (createdDate.Length > 10)
            {
                DateTime dt;
                if (DateTime.TryParse(createdDate, out dt))
                {
                    createdDate = dt.ToString("yyyy-MM-dd");
                }
            }

            ProjectStatusItem item = new ProjectStatusItem
            {
                Project = title,
                FullPath = filePath,
                Status = status,
                Priority = priority,
                Designer = !string.IsNullOrWhiteSpace(assigneeName) ? assigneeName : assignee,
                Client = brand,
                Deadline = dueDate,
                CreatedDate = createdDate,
                StartDate = createdDate,
                IsStudioTask = true,
                TaskId = id,
                TaskBrand = brand,
                ConvertedJobId = jobId,
                ConvertedProjectId = projectId,
                HasFrontmatter = true
            };

            return item;
        }

        /// <summary>
        /// Reads body notes below YAML frontmatter in a studio task markdown file.
        /// </summary>
        public static string ReadStudioTaskBody(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath)) return "";
            try
            {
                string[] lines = File.ReadAllLines(filePath, Encoding.UTF8);
                bool inFrontmatter = false;
                StringBuilder sb = new StringBuilder();

                for (int i = 0; i < lines.Length; i++)
                {
                    string trimmed = lines[i].Trim();
                    if (trimmed == Delimiter)
                    {
                        if (!inFrontmatter && i == 0)
                        {
                            inFrontmatter = true;
                            continue;
                        }
                        if (inFrontmatter)
                        {
                            inFrontmatter = false;
                            continue;
                        }
                    }

                    if (!inFrontmatter)
                    {
                        sb.AppendLine(lines[i]);
                    }
                }
                return sb.ToString().Trim();
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[StudioTaskService] ReadStudioTaskBody error: " + ex.Message);
                return "";
            }
        }

        /// <summary>
        /// Saves updated task frontmatter and body notes back to .sscam/tasks/{id}.md.
        /// </summary>
        public static void SaveStudioTask(ProjectStatusItem item, string newBody)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.FullPath)) return;

            try
            {
                string body = newBody;
                if (body == null && File.Exists(item.FullPath))
                {
                    body = ReadStudioTaskBody(item.FullPath);
                }

                StringBuilder sb = new StringBuilder();
                sb.AppendLine(Delimiter);
                sb.AppendLine(string.Format("id: {0}", !string.IsNullOrWhiteSpace(item.TaskId) ? item.TaskId : Path.GetFileNameWithoutExtension(item.FullPath)));
                sb.AppendLine(string.Format("title: \"{0}\"", (item.Project ?? "Untitled Studio Task").Replace("\"", "\\\"")));
                sb.AppendLine(string.Format("assignee: {0}", item.Designer ?? ""));
                sb.AppendLine(string.Format("assigneeName: {0}", item.Designer ?? ""));
                sb.AppendLine(string.Format("status: {0}", item.Status ?? "backlog"));
                sb.AppendLine(string.Format("priority: {0}", item.Priority ?? "medium"));
                sb.AppendLine(string.Format("brand: {0}", !string.IsNullOrWhiteSpace(item.TaskBrand) ? item.TaskBrand : (!string.IsNullOrWhiteSpace(item.Client) ? item.Client : "SS")));
                sb.AppendLine(string.Format("dueDate: {0}", item.Deadline ?? ""));
                sb.AppendLine(string.Format("createdAt: {0}", !string.IsNullOrWhiteSpace(item.CreatedDate) ? item.CreatedDate : DateTime.Today.ToString("yyyy-MM-dd")));
                sb.AppendLine(string.Format("updatedAt: {0}", DateTime.UtcNow.ToString("o")));
                sb.AppendLine(string.Format("jobId: {0}", !string.IsNullOrWhiteSpace(item.ConvertedJobId) ? item.ConvertedJobId : "null"));
                sb.AppendLine(string.Format("projectId: {0}", !string.IsNullOrWhiteSpace(item.ConvertedProjectId) ? item.ConvertedProjectId : "null"));
                sb.AppendLine(Delimiter);

                if (!string.IsNullOrWhiteSpace(body))
                {
                    sb.AppendLine();
                    sb.Append(body);
                }

                File.WriteAllText(item.FullPath, sb.ToString(), Encoding.UTF8);
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[StudioTaskService] SaveStudioTask error: " + ex.Message);
                throw;
            }
        }

        /// <summary>
        /// Creates a new pre-production Studio Task markdown file in .sscam/tasks/{id}.md.
        /// </summary>
        public static ProjectStatusItem CreateStudioTask(
            string workspaceRoot,
            string title,
            string brand,
            string priority,
            string assignee,
            string dueDate,
            string briefNotes)
        {
            if (string.IsNullOrWhiteSpace(workspaceRoot) || !Directory.Exists(workspaceRoot))
            {
                throw new DirectoryNotFoundException("Workspace root is invalid or not accessible.");
            }

            string tasksDir = GetTasksDirectory(workspaceRoot);
            long timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            string id = "task-" + timestamp.ToString();
            string filePath = Path.Combine(tasksDir, id + ".md");

            string cleanBrand = !string.IsNullOrWhiteSpace(brand) ? brand.Trim().ToUpperInvariant() : "SS";
            string cleanPriority = !string.IsNullOrWhiteSpace(priority) ? priority.Trim().ToLowerInvariant() : "medium";
            string cleanAssignee = !string.IsNullOrWhiteSpace(assignee) ? assignee.Trim() : "";
            string cleanDueDate = !string.IsNullOrWhiteSpace(dueDate) ? dueDate.Trim() : "";
            string today = DateTime.Today.ToString("yyyy-MM-dd");

            StringBuilder sb = new StringBuilder();
            sb.AppendLine(Delimiter);
            sb.AppendLine(string.Format("id: {0}", id));
            sb.AppendLine(string.Format("title: \"{0}\"", (title ?? "Untitled Studio Task").Replace("\"", "\\\"")));
            sb.AppendLine(string.Format("assignee: {0}", cleanAssignee));
            sb.AppendLine(string.Format("assigneeName: {0}", cleanAssignee));
            sb.AppendLine("status: backlog");
            sb.AppendLine(string.Format("priority: {0}", cleanPriority));
            sb.AppendLine(string.Format("brand: {0}", cleanBrand));
            sb.AppendLine(string.Format("dueDate: {0}", cleanDueDate));
            sb.AppendLine(string.Format("createdAt: {0}", today));
            sb.AppendLine(string.Format("updatedAt: {0}", DateTime.UtcNow.ToString("o")));
            sb.AppendLine("jobId: null");
            sb.AppendLine("projectId: null");
            sb.AppendLine(Delimiter);

            if (!string.IsNullOrWhiteSpace(briefNotes))
            {
                sb.AppendLine();
                sb.AppendLine(briefNotes.Trim());
            }

            File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);

            return ParseStudioTaskFile(filePath);
        }

        /// <summary>
        /// Simplified overload for provisioning a task using its own designer and brand metadata.
        /// </summary>
        public static async Task<ProvisionTaskResult> ProvisionTaskToProjectAsync(string workspaceRoot, ProjectStatusItem task)
        {
            if (task == null) return new ProvisionTaskResult { Success = false, ErrorMessage = "Task cannot be null." };
            if (string.IsNullOrWhiteSpace(workspaceRoot) || !Directory.Exists(workspaceRoot))
            {
                return new ProvisionTaskResult { Success = false, ErrorMessage = "Workspace root is invalid or not accessible." };
            }

            try
            {
                string designer = !string.IsNullOrWhiteSpace(task.Designer) ? task.Designer : "Design-Studio";
                string brand = !string.IsNullOrWhiteSpace(task.TaskBrand) ? task.TaskBrand : (!string.IsNullOrWhiteSpace(task.Client) ? task.Client : "SS");
                string targetDir = await ProvisionTaskToProjectAsync(task, workspaceRoot, designer, brand, "Display & Social");
                return new ProvisionTaskResult
                {
                    Success = !string.IsNullOrEmpty(targetDir) && Directory.Exists(targetDir),
                    ProjectFolder = targetDir,
                    JobId = task.ConvertedJobId,
                    ProjectName = Path.GetFileName(targetDir)
                };
            }
            catch (Exception ex)
            {
                return new ProvisionTaskResult
                {
                    Success = false,
                    ErrorMessage = ex.Message
                };
            }
        }

        /// <summary>
        /// THE BRIDGE: Provisions a lightweight pre-production StudioTask into a full Synology NAS Project Vault.
        /// Scaffolds 5 canonical folders, populates README.md and COPY.md, and marks the task as converted.
        /// </summary>
        public static async Task<string> ProvisionTaskToProjectAsync(
            ProjectStatusItem task,
            string workspaceRoot,
            string designer,
            string brandCode,
            string presetType)
        {
            if (task == null) throw new ArgumentNullException("task");
            if (string.IsNullOrWhiteSpace(workspaceRoot) || !Directory.Exists(workspaceRoot))
            {
                throw new DirectoryNotFoundException("Workspace root is invalid or not accessible.");
            }

            return await Task.Run(() =>
            {
                // 1. Calculate official Job ID
                int nextIdNum = AutoCalculateNextJobId(workspaceRoot);
                string typeSuffix = "D";
                if (!string.IsNullOrWhiteSpace(presetType))
                {
                    string p = presetType.ToLowerInvariant();
                    if (p.Contains("video")) typeSuffix = "V";
                    else if (p.Contains("social")) typeSuffix = "S";
                    else if (p.Contains("brand")) typeSuffix = "P";
                }
                string formattedJobId = string.Format("{0:D4}{1}", nextIdNum, typeSuffix);

                // 2. Format canonical project folder name: {YYYYMM}_{JobID}_{Brand}_{CleanTitle}
                string yearStr = DateTime.Now.Year.ToString();
                string monthNum = DateTime.Now.ToString("yyyyMM");
                string monthName = DateTime.Now.ToString("MMMM", CultureInfo.InvariantCulture);
                string monthFolder = string.Format("{0}_{1}", monthNum, monthName);

                string brand = !string.IsNullOrWhiteSpace(brandCode) ? brandCode.Trim().ToUpperInvariant() : (!string.IsNullOrWhiteSpace(task.TaskBrand) ? task.TaskBrand : "SS");
                string cleanTitle = Regex.Replace(task.Project ?? "Creative_Project", @"[\\/:*?""<>|]", "_").Trim();
                cleanTitle = Regex.Replace(cleanTitle, @"\s+", "_");

                string folderName = string.Format("{0}_{1}_{2}_{3}", monthNum, formattedJobId, brand, cleanTitle);

                // 3. Resolve Designer Directory Target
                string cleanDesigner = !string.IsNullOrWhiteSpace(designer) ? Regex.Replace(designer.Trim(), @"[\\/:*?""<>|]", "") : "Design-Studio";
                if (string.IsNullOrWhiteSpace(cleanDesigner)) cleanDesigner = "Design-Studio";

                string designerRoot = Path.Combine(workspaceRoot, cleanDesigner, string.Format("SS-{0}", yearStr), monthFolder);
                if (!Directory.Exists(designerRoot))
                {
                    // Fallback to standard monthly root if designer container is absent
                    designerRoot = Path.Combine(workspaceRoot, yearStr, monthFolder);
                }

                if (!Directory.Exists(designerRoot))
                {
                    Directory.CreateDirectory(designerRoot);
                }

                string targetProjectDir = Path.Combine(designerRoot, folderName);
                if (!Directory.Exists(targetProjectDir))
                {
                    Directory.CreateDirectory(targetProjectDir);
                }

                // 4. Scaffold Canonical 5 Folders
                string briefAssetsDir = Path.Combine(targetProjectDir, SmartIngesterService.FOLDER_BRIEF_ASSETS);
                string sourceFilesDir = Path.Combine(targetProjectDir, SmartIngesterService.FOLDER_SOURCE_FILES);
                string copywritingDir = Path.Combine(targetProjectDir, SmartIngesterService.FOLDER_COPYWRITING);
                string wipDir = Path.Combine(targetProjectDir, SmartIngesterService.FOLDER_WIP);
                string deliverablesDir = Path.Combine(targetProjectDir, SmartIngesterService.FOLDER_DELIVERABLES);

                Directory.CreateDirectory(briefAssetsDir);
                Directory.CreateDirectory(sourceFilesDir);
                Directory.CreateDirectory(copywritingDir);
                Directory.CreateDirectory(wipDir);
                Directory.CreateDirectory(deliverablesDir);

                // 5. Populate initial COPY.md
                string copyPath = Path.Combine(copywritingDir, "COPY.md");
                string taskNotes = ReadStudioTaskBody(task.FullPath);
                string copyContent = string.Format(
@"---
project_id: {0}
title: {1}
brand: {2}
designer: {3}
created: {4}
---

# {1} — Production Script & Copy

## Creative Brief & Concept Notes
{5}

## Production Deliverables Plan
- [ ] Master Visual Key Artwork
- [ ] Format Resizes & Social Adaptations
- [ ] Final Package Handover
", formattedJobId, task.Project, brand, cleanDesigner, DateTime.Today.ToString("yyyy-MM-dd"), !string.IsNullOrWhiteSpace(taskNotes) ? taskNotes : "_Brief transferred from Studio Task " + task.TaskId + "_");

                File.WriteAllText(copyPath, copyContent, Encoding.UTF8);

                // 6. Populate project README.md
                string readmePath = Path.Combine(targetProjectDir, "README.md");
                string deadlineStr = !string.IsNullOrWhiteSpace(task.Deadline) ? task.Deadline : DateTime.Today.AddDays(4).ToString("yyyy-MM-dd");
                string readmeContent = string.Format(
@"---
status: in-progress
designer: {0}
client: {1}
created: {2}
start_date: {2}
deadline: {3}
priority: {4}
source_task_id: {5}
job_id: {6}
---

# 🎨 {7}

## 📋 Creative Campaign Brief (Provisioned from Studio Task {5})
{8}

## 🧭 Studio Production Pipeline
- **Project ID**: `{6}`
- **NAS Vault Folder**: `{9}`
- **Assigned Designer**: {0}
- **Originating Pre-Production Task**: [{5}]
", cleanDesigner, brand, DateTime.Today.ToString("yyyy-MM-dd"), deadlineStr, task.Priority ?? "medium", task.TaskId, formattedJobId, task.Project, !string.IsNullOrWhiteSpace(taskNotes) ? taskNotes : "High-converting visual assets compliant with SuamiSihat creative standards.", folderName);

                File.WriteAllText(readmePath, readmeContent, Encoding.UTF8);

                // 7. Update originating StudioTask file as 'converted'
                task.Status = "converted";
                task.ConvertedJobId = formattedJobId;
                task.ConvertedProjectId = folderName;
                SaveStudioTask(task, taskNotes);

                return targetProjectDir;
            });
        }

        private static int AutoCalculateNextJobId(string workspaceRoot)
        {
            int maxId = 88;
            Regex regex = new Regex(@"^\d{6}_(\d{4})[A-Za-z0-9]", RegexOptions.IgnoreCase);

            try
            {
                List<DesignerFolderItem> recent = WorkspaceScanner.ListDesignerFolders(workspaceRoot, "", "", 300);
                if (recent != null)
                {
                    foreach (var item in recent)
                    {
                        if (item != null && !string.IsNullOrWhiteSpace(item.Project))
                        {
                            Match m = regex.Match(item.Project);
                            if (m.Success)
                            {
                                int val;
                                if (int.TryParse(m.Groups[1].Value, out val) && val > maxId)
                                {
                                    maxId = val;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[StudioTaskService] AutoCalculateNextJobId error: " + ex.Message);
            }

            return maxId + 1;
        }

        private static Dictionary<string, string> ParseFrontmatter(string[] lines)
        {
            Dictionary<string, string> result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (lines == null || lines.Length == 0 || lines[0].Trim() != Delimiter) return result;

            for (int i = 1; i < lines.Length; i++)
            {
                if (lines[i].Trim() == Delimiter) break;
                string line = lines[i];
                if (string.IsNullOrWhiteSpace(line) || char.IsWhiteSpace(line[0]) || line.TrimStart().StartsWith("-"))
                {
                    continue;
                }

                int colon = line.IndexOf(':');
                if (colon > 0)
                {
                    string key = line.Substring(0, colon).Trim();
                    string val = line.Substring(colon + 1).Trim();
                    if (val.Length >= 2 && ((val.StartsWith("\"") && val.EndsWith("\"")) || (val.StartsWith("'") && val.EndsWith("'"))))
                    {
                        val = val.Substring(1, val.Length - 2).Trim();
                    }
                    if (val == "null") val = "";
                    result[key] = val;
                }
            }
            return result;
        }

        private static string GetValue(Dictionary<string, string> dict, string key, string fallback)
        {
            if (dict == null) return fallback;
            string val;
            if (dict.TryGetValue(key, out val) && !string.IsNullOrWhiteSpace(val))
            {
                return val;
            }
            return fallback;
        }
    }

    /// <summary>
    /// Result payload returned upon provisioning a StudioTask into a Project Vault.
    /// </summary>
    public class ProvisionTaskResult
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public string ProjectFolder { get; set; }
        public string JobId { get; set; }
        public string ProjectName { get; set; }
    }
}
