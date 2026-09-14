using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using SS_CAM.Utilities;

namespace SS_CAM.Services
{
    public enum NotePriority
    {
        Normal = 0,
        Medium = 1,
        High = 2
    }

    /// <summary>
    /// Manages Markdown note files stored in %LOCALAPPDATA%\SuamiSihat\SS-CAM\Notes\.
    /// Each note is a plain .md file with optional YAML frontmatter header.
    /// </summary>
    public static class QuickNoteService
    {
        private static readonly HttpClient _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(4) };
        private const string WebPortalNotesApiUrl = "https://creative.suamisihat.myds.me/api/notes";

        private static string NotesDirectory
        {
            get
            {
                string dir = Path.Combine(AppPaths.AppDataFolder, "Notes");
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                return dir;
            }
        }

        /// <summary>
        /// Lists all notes sorted: Pinned first, then Priority (High > Medium > Normal), then newest modification.
        /// </summary>
        public static List<QuickNoteItem> ListNotes()
        {
            try
            {
                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrWhiteSpace(profile.WorkspaceRoot))
                {
                    NasConfigSyncService.SyncFolderFromNasIfNewer(profile.WorkspaceRoot, "Notes");
                }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] NAS sync error: " + ex.Message); }

            List<QuickNoteItem> notes = new List<QuickNoteItem>();
            string dir = NotesDirectory;

            string[] files;
            try { files = Directory.GetFiles(dir, "*.md"); }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); return notes; }

            foreach (string file in files)
            {
                try
                {
                    string content = File.ReadAllText(file, Encoding.UTF8);
                    bool isPinned = false;
                    NotePriority priority = NotePriority.Normal;
                    string icon = "📝";
                    string category = "General";

                    ParseFrontmatter(content, out isPinned, out priority, out icon, out category);

                    string title = ExtractTitle(content, Path.GetFileNameWithoutExtension(file));
                    DateTime modified = File.GetLastWriteTime(file);
                    DateTime created = File.GetCreationTime(file);
                    int completedTasks, totalTasks;
                    ExtractTaskStats(content, out completedTasks, out totalTasks);
                    string snippet = ExtractSnippet(content, title);

                    string[] tokens = (content ?? "").Split(new char[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                    int wordCount = tokens.Length;
                    int readingTime = Math.Max(1, (int)Math.Ceiling(wordCount / 200.0));

                    if (icon == "📝")
                    {
                        if (category == "Idea") icon = "💡";
                        else if (category == "Meeting") icon = "💬";
                        else if (category == "Brief") icon = "📋";
                        else if (category == "Tasks") icon = "🎯";
                        else if (category == "Copywriting") icon = "⚡";
                    }

                    notes.Add(new QuickNoteItem
                    {
                        FilePath = file,
                        Title = title,
                        Content = content,
                        Snippet = snippet,
                        TotalTasks = totalTasks,
                        CompletedTasks = completedTasks,
                        IsPinned = isPinned,
                        Priority = priority,
                        Icon = icon,
                        Category = category,
                        ReadingTimeMinutes = readingTime,
                        WordCount = wordCount,
                        CreatedTicks = created.Ticks,
                        ModifiedTicks = modified.Ticks,
                        ModifiedDisplay = FormatRelativeTime(modified)
                    });
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
            }

            notes.Sort(delegate(QuickNoteItem a, QuickNoteItem b)
            {
                if (a.IsPinned != b.IsPinned)
                    return b.IsPinned.CompareTo(a.IsPinned);
                if (a.Priority != b.Priority)
                    return ((int)b.Priority).CompareTo((int)a.Priority);
                return b.ModifiedTicks.CompareTo(a.ModifiedTicks);
            });

            return notes;
        }

        public static string FormatRelativeTime(DateTime dt)
        {
            TimeSpan diff = DateTime.Now - dt;
            if (diff.TotalMinutes < 1) return "Just now";
            if (diff.TotalMinutes < 60) return string.Format("{0}m ago", (int)diff.TotalMinutes);
            if (dt.Date == DateTime.Today) return "Today, " + dt.ToString("HH:mm");
            if (dt.Date == DateTime.Today.AddDays(-1)) return "Yesterday, " + dt.ToString("HH:mm");
            return dt.ToString("dd MMM yyyy");
        }

        /// <summary>
        /// Creates a new empty note and returns its file path.
        /// </summary>
        public static string CreateNote(string title = "New Note", string bodyContent = null, string icon = "📝", string category = "General")
        {
            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string fileName = string.Format("{0}.md", timestamp);
            string filePath = Path.Combine(NotesDirectory, fileName);
            string body = !string.IsNullOrWhiteSpace(bodyContent)
                ? bodyContent
                : string.Format("# {0}\n\n_{1}_\n\n", title, DateTime.Now.ToString("dd MMMM yyyy"));
            string fullContent = BuildContentWithFrontmatter(body, false, NotePriority.Normal, icon, category);
            File.WriteAllText(filePath, fullContent, Encoding.UTF8);
            return filePath;
        }

        /// <summary>
        /// Saves note content with pinned and priority metadata in YAML frontmatter.
        /// </summary>
        public static void SaveNote(string filePath, string rawContent, bool isPinned, NotePriority priority, string icon = "📝", string category = "General")
        {
            if (string.IsNullOrWhiteSpace(filePath)) return;
            try
            {
                string fullContent = BuildContentWithFrontmatter(rawContent, isPinned, priority, icon, category);
                File.WriteAllText(filePath, fullContent, Encoding.UTF8);

                string noteId = Path.GetFileNameWithoutExtension(filePath);
                string title = ExtractTitle(rawContent, noteId);
                var profile = UserProfileService.LoadProfile();

                try
                {
                    if (profile != null && !string.IsNullOrWhiteSpace(profile.WorkspaceRoot))
                    {
                        NasConfigSyncService.SaveFolderToNas(profile.WorkspaceRoot, "Notes");
                    }
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] SaveNote NAS sync error: " + ex.Message); }

                try
                {
                    string username = (profile != null && !string.IsNullOrWhiteSpace(profile.DesignerName)) ? profile.DesignerName.ToLowerInvariant() : "harus";
                    PushNoteToWebPortalAsync(noteId, title, rawContent, isPinned, priority, username);
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] SaveNote Portal push error: " + ex.Message); }
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }

        public static void SaveNote(string filePath, string rawContent, bool isPinned, NotePriority priority)
        {
            SaveNote(filePath, rawContent, isPinned, priority, "📝", "General");
        }

        /// <summary>
        /// Saves plain content to file.
        /// </summary>
        public static void SaveNote(string filePath, string content)
        {
            if (string.IsNullOrWhiteSpace(filePath)) return;
            try { File.WriteAllText(filePath, content, Encoding.UTF8); }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }

        /// <summary>
        /// Deletes a note file locally and removes it from NAS and Web Portal.
        /// </summary>
        public static void DeleteNote(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath)) return;
            try
            {
                string fileName = Path.GetFileName(filePath);
                string noteId = Path.GetFileNameWithoutExtension(filePath);
                File.Delete(filePath);

                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrWhiteSpace(profile.WorkspaceRoot))
                {
                    NasConfigSyncService.DeleteFileFromNas(profile.WorkspaceRoot, "Notes", fileName);
                }

                DeleteNoteFromWebPortalAsync(noteId);
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine(ex); }
        }

        /// <summary>
        /// Synchronizes notes with the Web Portal / Mobile REST API.
        /// Discovers notes created on mobile or web and downloads them into local storage.
        /// </summary>
        public static async Task SyncWithWebPortalAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync(WebPortalNotesApiUrl);
                if (!response.IsSuccessStatusCode) return;

                string json = await response.Content.ReadAsStringAsync();
                if (string.IsNullOrWhiteSpace(json)) return;

                var root = JObject.Parse(json);
                var notesArray = root["notes"] as JArray;
                if (notesArray == null) return;

                string dir = NotesDirectory;
                var profile = UserProfileService.LoadProfile();
                string wsRoot = (profile != null && !string.IsNullOrWhiteSpace(profile.WorkspaceRoot)) ? profile.WorkspaceRoot : null;
                string nasNotesDir = wsRoot != null ? Path.Combine(wsRoot, "_Team", "_Config", "Notes") : null;

                foreach (var token in notesArray)
                {
                    try
                    {
                        string id = token["id"] != null ? token["id"].ToString() : null;
                        string filename = token["filename"] != null ? token["filename"].ToString() : null;
                        if (string.IsNullOrWhiteSpace(filename))
                        {
                            if (string.IsNullOrWhiteSpace(id)) continue;
                            filename = id + ".md";
                        }

                        string body = token["body"] != null ? token["body"].ToString() : "";
                        bool isPinned = token["isPinned"] != null && (bool)token["isPinned"];
                        string prioStr = token["priority"] != null ? token["priority"].ToString().ToLowerInvariant() : "normal";
                        NotePriority priority = NotePriority.Normal;
                        if (prioStr == "high") priority = NotePriority.High;
                        else if (prioStr == "medium") priority = NotePriority.Medium;

                        long modifiedMs = 0L;
                        if (token["modified"] != null)
                        {
                            try { modifiedMs = Convert.ToInt64(token["modified"]); }
                            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] modified timestamp parse: " + ex.Message); }
                        }
                        DateTime serverModified = modifiedMs > 0
                            ? new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddMilliseconds(modifiedMs)
                            : DateTime.UtcNow;

                        string localPath = Path.Combine(dir, filename);
                        bool needsWrite = false;

                        if (!File.Exists(localPath))
                        {
                            needsWrite = true;
                        }
                        else
                        {
                            DateTime localModified = File.GetLastWriteTimeUtc(localPath);
                            if (serverModified > localModified.AddSeconds(2))
                            {
                                needsWrite = true;
                            }
                        }

                        if (needsWrite)
                        {
                            string fullContent = BuildContentWithFrontmatter(body, isPinned, priority);
                            File.WriteAllText(localPath, fullContent, Encoding.UTF8);
                            try { File.SetLastWriteTimeUtc(localPath, serverModified); }
                            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] SetLastWriteTimeUtc: " + ex.Message); }

                            if (nasNotesDir != null && Directory.Exists(nasNotesDir))
                            {
                                try
                                {
                                    string nasPath = Path.Combine(nasNotesDir, filename);
                                    File.Copy(localPath, nasPath, true);
                                }
                                catch (Exception ex) { System.Diagnostics.Debug.WriteLine("[QuickNoteService] NAS notes mirror: " + ex.Message); }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine("[QuickNoteService] Note sync item: " + ex.Message);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("[QuickNoteService] SyncWithWebPortal error: " + ex.Message);
            }
        }

        private static void PushNoteToWebPortalAsync(string id, string title, string body, bool isPinned, NotePriority priority, string username)
        {
            Task.Run(async () =>
            {
                try
                {
                    var payload = new
                    {
                        id = id,
                        title = title,
                        body = body,
                        isPinned = isPinned,
                        priority = priority.ToString().ToLowerInvariant(),
                        user = username
                    };
                    string json = JsonConvert.SerializeObject(payload);
                    var content = new StringContent(json, Encoding.UTF8, "application/json");
                    await _httpClient.PostAsync(WebPortalNotesApiUrl, content);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[QuickNoteService] PushNoteToWebPortal error: " + ex.Message);
                }
            });
        }

        private static void DeleteNoteFromWebPortalAsync(string id)
        {
            Task.Run(async () =>
            {
                try
                {
                    await _httpClient.DeleteAsync(WebPortalNotesApiUrl + "/" + id);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[QuickNoteService] DeleteNoteFromWebPortal error: " + ex.Message);
                }
            });
        }

        /// <summary>
        /// Strips YAML frontmatter block from markdown content if present.
        /// </summary>
        public static string StripFrontmatter(string content)
        {
            if (string.IsNullOrWhiteSpace(content)) return "";
            string text = content.Trim();
            if (!text.StartsWith("---")) return text;

            int end = text.IndexOf("---", 3);
            if (end > 0)
            {
                return text.Substring(end + 3).TrimStart('\r', '\n', ' ');
            }
            int nextBlank = text.IndexOf("\n\n");
            if (nextBlank > 0)
            {
                return text.Substring(nextBlank + 2).TrimStart('\r', '\n', ' ');
            }
            return text;
        }

        /// <summary>
        /// Extracts the first non-empty line as title, skipping YAML frontmatter.
        /// </summary>
        public static string ExtractTitle(string content, string fallback)
        {
            if (string.IsNullOrWhiteSpace(content)) return fallback;
            string text = StripFrontmatter(content);
            foreach (string line in text.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string trimmed = line.Trim().TrimStart('#').Trim();
                if (!string.IsNullOrWhiteSpace(trimmed)) return trimmed;
            }
            return fallback;
        }

        /// <summary>
        /// Parses pinned, priority, icon, and category metadata from YAML frontmatter block if present.
        /// </summary>
        public static void ParseFrontmatter(string content, out bool isPinned, out NotePriority priority, out string icon, out string category)
        {
            isPinned = false;
            priority = NotePriority.Normal;
            icon = "📝";
            category = "General";
            if (string.IsNullOrWhiteSpace(content)) return;

            string text = content.Trim();
            if (!text.StartsWith("---")) return;

            int end = text.IndexOf("---", 3);
            if (end <= 0) return;

            string header = text.Substring(3, end - 3);
            foreach (string line in header.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                int colonIdx = line.IndexOf(':');
                if (colonIdx > 0)
                {
                    string key = line.Substring(0, colonIdx).Trim().ToLowerInvariant();
                    string val = line.Substring(colonIdx + 1).Trim();

                    if (key == "pinned")
                    {
                        string v = val.ToLowerInvariant();
                        isPinned = v == "true" || v == "yes" || v == "1";
                    }
                    else if (key == "priority")
                    {
                        string v = val.ToLowerInvariant();
                        if (v == "high" || v == "2") priority = NotePriority.High;
                        else if (v == "medium" || v == "med" || v == "1") priority = NotePriority.Medium;
                        else priority = NotePriority.Normal;
                    }
                    else if (key == "icon")
                    {
                        if (!string.IsNullOrWhiteSpace(val)) icon = val;
                    }
                    else if (key == "category")
                    {
                        if (!string.IsNullOrWhiteSpace(val)) category = val;
                    }
                }
            }
        }

        public static void ParseFrontmatter(string content, out bool isPinned, out NotePriority priority)
        {
            string icon, category;
            ParseFrontmatter(content, out isPinned, out priority, out icon, out category);
        }

        /// <summary>
        /// Rebuilds note content with standardized YAML frontmatter header.
        /// </summary>
        public static string BuildContentWithFrontmatter(string content, bool isPinned, NotePriority priority, string icon = "📝", string category = "General")
        {
            string body = content != null ? content.Trim() : "";
            if (body.StartsWith("---"))
            {
                int end = body.IndexOf("---", 3);
                if (end > 0) body = body.Substring(end + 3).TrimStart('\r', '\n');
            }

            bool hasIcon = !string.IsNullOrWhiteSpace(icon) && icon != "📝";
            bool hasCat = !string.IsNullOrWhiteSpace(category) && category != "General";

            if (!isPinned && priority == NotePriority.Normal && !hasIcon && !hasCat)
            {
                return body;
            }

            StringBuilder sb = new StringBuilder();
            sb.AppendLine("---");
            if (isPinned) sb.AppendLine("pinned: true");
            if (priority == NotePriority.High) sb.AppendLine("priority: high");
            else if (priority == NotePriority.Medium) sb.AppendLine("priority: medium");
            if (hasIcon) sb.AppendLine(string.Format("icon: {0}", icon));
            if (hasCat) sb.AppendLine(string.Format("category: {0}", category));
            sb.AppendLine("---");
            sb.AppendLine();
            sb.Append(body);

            return sb.ToString();
        }

        public static string BuildContentWithFrontmatter(string content, bool isPinned, NotePriority priority)
        {
            return BuildContentWithFrontmatter(content, isPinned, priority, "📝", "General");
        }

        /// <summary>
        /// Extracts a clean 1-line text snippet (skipping title and frontmatter) for sidebar display.
        /// </summary>
        public static string ExtractSnippet(string content, string title)
        {
            if (string.IsNullOrWhiteSpace(content)) return "Empty note";
            string body = StripFrontmatter(content);
            string[] lines = body.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string rawLine in lines)
            {
                string line = rawLine.Trim();
                if (string.IsNullOrWhiteSpace(line)) continue;
                string cleanLine = line.TrimStart('#', '*', '_', '-', '>', ' ', '`');
                if (cleanLine.Equals(title, StringComparison.OrdinalIgnoreCase)) continue;
                if (cleanLine.Length > 0)
                {
                    cleanLine = cleanLine.Replace("**", "").Replace("*", "").Replace("_", "").Replace("~~", "").Replace("[ ]", "").Replace("[x]", "").Trim();
                    if (cleanLine.Length > 60) cleanLine = cleanLine.Substring(0, 57) + "...";
                    return cleanLine;
                }
            }
            return "No additional text";
        }

        /// <summary>
        /// Extracts completed and total task checkbox count (- [ ] and - [x]).
        /// </summary>
        public static void ExtractTaskStats(string content, out int completed, out int total)
        {
            completed = 0;
            total = 0;
            if (string.IsNullOrWhiteSpace(content)) return;
            string[] lines = content.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string line in lines)
            {
                string t = line.Trim();
                if (t.StartsWith("- [ ]", StringComparison.OrdinalIgnoreCase) || t.StartsWith("* [ ]", StringComparison.OrdinalIgnoreCase))
                {
                    total++;
                }
                else if (t.StartsWith("- [x]", StringComparison.OrdinalIgnoreCase) || t.StartsWith("* [x]", StringComparison.OrdinalIgnoreCase))
                {
                    total++;
                    completed++;
                }
            }
        }

        #region Notion & Evernote Inspired Creative Templates

        public static string GetTemplateCreativeBrief()
        {
            return "# 📋 Creative Brief: [Project Title]\n\n" +
                   "> [!NOTE] Campaign Objective\n" +
                   "> Drive high-converting direct response leads with thumb-stopping visual hooks and clear value propositions.\n\n" +
                   "### 🎯 Target Audience\n" +
                   "- **Primary Persona:** Working professionals (28–45 years old)\n" +
                   "- **Core Pain Point:** Daily fatigue, stress, lack of stamina\n" +
                   "- **Desired Action:** Click through to WhatsApp consultation or direct web order\n\n" +
                   "### ⚡ Deliverables Matrix\n" +
                   "| Deliverable | Format / Ratio | Specs | Channel |\n" +
                   "| :--- | :--- | :--- | :--- |\n" +
                   "| Video Ad Cut | 9:16 (1080x1920) | MP4, < 30s | Meta & TikTok Ads |\n" +
                   "| Feed Carousel (3 slides) | 1:1 (1080x1080) | PNG, RGB 72 DPI | Meta Ads / IG Feed |\n" +
                   "| Story Banner | 9:16 (1080x1920) | Static PNG | IG Story |\n\n" +
                   "### 🎣 Core Angle & Hooks\n" +
                   "- **Hook 1 (Problem Callout):** \"Ramai ingat penat biasa, rupa-rupanya...\"\n" +
                   "- **Hook 2 (Social Proof):** \"Dah cuba macam-macam suplemen tapi tak ada kesan?\"\n" +
                   "- **Hook 3 (Urgency):** \"Slot konsultasi percuma terhad untuk 50 pelanggan pertama!\"\n\n" +
                   "### ☑️ Milestone Checklist\n" +
                   "- [ ] Art Director brief alignment\n" +
                   "- [ ] Copywriting draft approved\n" +
                   "- [ ] Visual asset rendering & grading\n" +
                   "- [ ] Export final packages to 05_DELIVERABLES\n";
        }

        public static string GetTemplateMeetingMinutes()
        {
            return "# 💬 Creative Sync & Decisions — " + DateTime.Now.ToString("dd MMM yyyy") + "\n\n" +
                   "> [!TIP] Focus\n" +
                   "> Quick 15-minute sync on active campaign deliverables and production blockers.\n\n" +
                   "### 👥 Attendees\n" +
                   "- Harussani (Head of Creative)\n" +
                   "- Creative Team Designers\n\n" +
                   "### 📌 Agenda & Discussion Points\n" +
                   "1. **Current Sprint Priorities:** Review active video cuts and print packaging dielines.\n" +
                   "2. **Asset Approvals:** Update status on Meta feed creatives for client review.\n" +
                   "3. **Nas Storage & Vault:** Ensure all completed deliverables are indexed in `05_DELIVERABLES`.\n\n" +
                   "### 💡 Key Decisions\n" +
                   "- Standardize all video exports to H.264 1080x1920 with burnt-in Malay captions.\n" +
                   "- Retain high-resolution master project files in `02_SOURCE_FILES`.\n\n" +
                   "### ☑️ Action Items & Ownership\n" +
                   "- [ ] Finalize packaging box sleeve dieline (Due: Tomorrow 3 PM)\n" +
                   "- [ ] Run AI Preflight check on WhatsApp broadcast copy\n" +
                   "- [ ] Upload approved deliverables to Synology NAS\n";
        }

        public static string GetTemplateAdCopyHookMatrix()
        {
            return "# ⚡ Direct-Response Ad Script & 3-Hook Matrix\n\n" +
                   "> [!WARNING] Regulatory Guard (KKM / LIU)\n" +
                   "> Do NOT use prohibited absolutes like \"100% sembuh\", \"pasti berkesan\", or \"tiada tandingan\". Focus on lifestyle improvement and premium natural ingredients.\n\n" +
                   "### 🎣 3-Hook Matrix Table\n" +
                   "| Hook # | Angle Type | Opening Audio (0–3s) | Visual Retention Cue |\n" +
                   "| :--- | :--- | :--- | :--- |\n" +
                   "| **Hook 1** | Pain-Point Callout | *\"Dah cuba macam-macam suplemen tapi badan masih lemau?\"* | Fast zoom-in on exhausted expression |\n" +
                   "| **Hook 2** | Story & Curiosity | *\"Saya ingat umur 40-an memang macam ni, rupanya silap...\"* | Split screen before vs. after |\n" +
                   "| **Hook 3** | Solution Demo | *\"Tengok apa jadi lepas konsisten amalkan herba terpilih ni...\"* | Dynamic product reveal with lighting sweep |\n\n" +
                   "### 📝 Body Script (15–25s)\n" +
                   "- **Problem Agitation:** Masalah stamina bukan sekadar faktor umur, tapi cara pemakanan dan gaya hidup seharian.\n" +
                   "- **Unique Mechanism:** Ekstrak herba asli standardisasi premium yang membantu menyegarkan badan secara semula jadi.\n" +
                   "- **Social Proof:** Lebih 12,000 pelanggan setia di seluruh Malaysia telah merasai perbezaannya.\n\n" +
                   "### 🚀 Call-To-Action (CTA)\n" +
                   "> *\"Tekan butang 'Learn More' di bawah sekarang untuk dapatkan pakej pengenalan eksklusif!\"*\n";
        }

        public static string GetTemplateMindDrop()
        {
            return "# 💡 Mind Drop & Concept Brainstorm\n\n" +
                   "> [!NOTE] Raw Inspiration\n" +
                   "> Unfiltered ideas, moodboard notes, visual styles, and references.\n\n" +
                   "### 🌟 Core Concept\n" +
                   "- **Elevator Pitch:** \n" +
                   "- **Emotional Benefit:** \n" +
                   "- **Aesthetic Direction:** Minimalist luxury, clean medical typography, 60-30-10 color balance.\n\n" +
                   "### 🎨 Visual & Moodboard References\n" +
                   "- Primary Color Accent: `#0078D4` (SS Royal Blue)\n" +
                   "- Secondary Accent: `#D97706` (Luxury Gold)\n" +
                   "- Reference Link 1: [Moodboard / Pinterest]()\n" +
                   "- Reference Link 2: [Competitor Campaign Reference]()\n\n" +
                   "### ☑️ Next Steps to Validate\n" +
                   "- [ ] Mock up rapid 1:1 canvas comp in Photoshop\n" +
                   "- [ ] Check with Art Director for brand token alignment\n" +
                   "- [ ] Draft 3 copy variations in Copywriting Studio\n";
        }

        public static string GetTemplateTaskSprint()
        {
            return "# 🎯 Creative Sprint & Task Backlog\n\n" +
                   "> [!TIP] Daily Rhythm\n" +
                   "> Knock out High Priority tasks before 12 PM. Group administrative feedback into the afternoon block.\n\n" +
                   "### 🔥 High Priority (Today)\n" +
                   "- [ ] Review client comments on Video Ad #3\n" +
                   "- [ ] Export high-res packaging labels for print vendor\n" +
                   "- [ ] Sync project brief changes with Task Manager\n\n" +
                   "### ⚡ Medium Priority (In Progress)\n" +
                   "- [ ] Design Instagram carousel slides (1:1 ratio)\n" +
                   "- [ ] Organize raw shoot footage into `02_SOURCE_FILES`\n" +
                   "- [ ] Update README.md milestone frontmatter\n\n" +
                   "### 📦 Backlog & Next Up\n" +
                   "- [ ] Explore Canva template bridge for social templates\n" +
                   "- [ ] Archive completed Q2 campaign folders on Synology NAS\n";
        }

        public static string GetTemplateClientFeedback()
        {
            return "# 📋 Client Feedback & Revision Log\n\n" +
                   "> [!WARNING] Scope Alert\n" +
                   "> Revisions outside the original approved brief require Art Director sign-off.\n\n" +
                   "**Client / Brand:** SuamiSihat Clinic  \n" +
                   "**Revision Round:** Round 2  \n" +
                   "**Date Received:** " + DateTime.Now.ToString("dd MMM yyyy") + "  \n\n" +
                   "### 🔍 Requested Changes\n" +
                   "| Section | Current State | Requested Revision | Priority |\n" +
                   "| :--- | :--- | :--- | :--- |\n" +
                   "| Opening Hook | Text caption too small | Increase font size by 20% with white drop shadow | High |\n" +
                   "| Callout Box | Mentioned 30-day guarantee | Remove claim; replace with \"Konsultasi Klinikal Percuma\" | Critical |\n" +
                   "| Logo Outro | 2-second hold | Extend logo outro to 3.5 seconds with website URL | Medium |\n\n" +
                   "### ☑️ Revision Checklist\n" +
                   "- [ ] Update master composition in After Effects\n" +
                   "- [ ] Re-export MP4 to `05_DELIVERABLES/REV2_Ad.mp4`\n" +
                   "- [ ] Upload revision preview for client approval\n";
        }

        #endregion
    }

    public class QuickNoteItem
    {
        public string FilePath { get; set; }
        public string Title { get; set; }
        public string Content { get; set; }
        public string Snippet { get; set; }
        public int TotalTasks { get; set; }
        public int CompletedTasks { get; set; }
        public bool IsPinned { get; set; }
        public NotePriority Priority { get; set; }
        public string Icon { get; set; }
        public string Category { get; set; }
        public int ReadingTimeMinutes { get; set; }
        public int WordCount { get; set; }
        public long CreatedTicks { get; set; }
        public long ModifiedTicks { get; set; }
        public string ModifiedDisplay { get; set; }

        public QuickNoteItem()
        {
            Icon = "📝";
            Category = "General";
            ReadingTimeMinutes = 1;
            WordCount = 0;
        }

        public string ReadingTimeDisplay
        {
            get { return string.Format("{0} min read", Math.Max(1, ReadingTimeMinutes)); }
        }

        public string CategoryDisplay
        {
            get { return string.IsNullOrWhiteSpace(Category) ? "General" : Category; }
        }

        public System.Windows.Visibility CategoryBadgeVisibility
        {
            get { return string.IsNullOrWhiteSpace(Category) || Category == "General" ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible; }
        }

        public System.Windows.Visibility PinBadgeVisibility
        {
            get { return IsPinned ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed; }
        }

        public System.Windows.Visibility PriorityBadgeVisibility
        {
            get { return Priority != NotePriority.Normal ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed; }
        }

        public System.Windows.Visibility TaskBadgeVisibility
        {
            get { return TotalTasks > 0 ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed; }
        }

        public string TaskProgressDisplay
        {
            get { return string.Format("✓ {0}/{1}", CompletedTasks, TotalTasks); }
        }

        public string PriorityLabel
        {
            get
            {
                switch (Priority)
                {
                    case NotePriority.High: return "P2";
                    case NotePriority.Medium: return "P1";
                    default: return "";
                }
            }
        }
    }
}
