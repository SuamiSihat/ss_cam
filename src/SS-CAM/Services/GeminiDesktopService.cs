using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace SS_CAM.Services
{
    public class BriefValidationReport
    {
        public int Score { get; set; }
        public bool Passed { get; set; }
        public List<string> Strengths { get; set; }
        public List<string> MissingItems { get; set; }
        public List<string> Recommendations { get; set; }
        public List<string> SuggestedBrandTokens { get; set; }

        public BriefValidationReport()
        {
            Strengths = new List<string>();
            MissingItems = new List<string>();
            Recommendations = new List<string>();
            SuggestedBrandTokens = new List<string>();
        }
    }

    public class CopyPreflightReport
    {
        public int Score { get; set; }
        public string ToneVerdict { get; set; }
        public List<string> RegulatoryWarnings { get; set; }
        public List<string> HookSuggestions { get; set; }
        public List<string> ActionableImprovements { get; set; }

        public CopyPreflightReport()
        {
            RegulatoryWarnings = new List<string>();
            HookSuggestions = new List<string>();
            ActionableImprovements = new List<string>();
        }
    }

    /// <summary>
    /// AI Brief Intelligence and Style Preflight Service for Windows Desktop.
    /// Integrates with Google Gemini using NAS vault credentials (_Team/ai-config.json)
    /// with intelligent offline heuristic fallback.
    /// </summary>
    public static class GeminiDesktopService
    {
        private static readonly HttpClient _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(25) };

        public static string GetApiKey(string workspaceRoot)
        {
            // 1. Environment variable
            string envKey = Environment.GetEnvironmentVariable("GEMINI_API_KEY");
            if (!string.IsNullOrWhiteSpace(envKey)) return envKey.Trim();

            // 2. Shared Synology NAS config (_Team/ai-config.json)
            if (!string.IsNullOrWhiteSpace(workspaceRoot) && Directory.Exists(workspaceRoot))
            {
                string nasConfigFile = Path.Combine(workspaceRoot, "_Team", "ai-config.json");
                if (File.Exists(nasConfigFile))
                {
                    try
                    {
                        string content = File.ReadAllText(nasConfigFile, Encoding.UTF8);
                        Match match = Regex.Match(content, "\"apiKey\"\\s*:\\s*\"([^\"]+)\"");
                        if (match.Success && !string.IsNullOrWhiteSpace(match.Groups[1].Value))
                        {
                            return match.Groups[1].Value.Trim();
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("[GeminiDesktopService] Read NAS ai-config error: " + ex.Message);
                    }
                }
            }

            // 3. Local AppData fallback
            string localDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SS-CAM");
            string localConfig = Path.Combine(localDir, "ai-config.json");
            if (File.Exists(localConfig))
            {
                try
                {
                    string content = File.ReadAllText(localConfig, Encoding.UTF8);
                    Match match = Regex.Match(content, "\"apiKey\"\\s*:\\s*\"([^\"]+)\"");
                    if (match.Success) return match.Groups[1].Value.Trim();
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[GeminiDesktopService] Read local ai-config error: " + ex.Message);
                }
            }

            return null;
        }

        public static async Task<BriefValidationReport> ValidateBriefAsync(string briefContent, string client, string title, string workspaceRoot)
        {
            return await Task.Run(async () =>
            {
                string apiKey = GetApiKey(workspaceRoot);
                if (string.IsNullOrWhiteSpace(apiKey))
                {
                    return PerformOfflineBriefValidation(briefContent, client, title);
                }

                try
                {
                    string prompt = string.Format(
                        "You are Lead Creative Director for SuamiSihat brand holding company.\n" +
                        "Evaluate this creative project brief for client '{0}' titled '{1}'.\n\n" +
                        "Brief Content:\n\"\"\"\n{2}\n\"\"\"\n\n" +
                        "Perform an audit on:\n" +
                        "1. Target Audience clarity\n" +
                        "2. Value proposition / Key Benefits\n" +
                        "3. Deliverables / Dimensions / Specifications completeness\n" +
                        "4. Tone of Voice (Must be Masculine, Authoritative, Trustworthy, Medical Luxury)\n" +
                        "5. Regulatory considerations (KKM / LIU health claim limits)\n\n" +
                        "Provide your response in this exact format:\n" +
                        "SCORE: [number 0-100]\n" +
                        "STRENGTHS:\n- [strength]\n" +
                        "MISSING:\n- [missing element]\n" +
                        "RECOMMENDATIONS:\n- [recommendation]\n" +
                        "BRAND_TOKENS:\n- [token e.g. #043388 Royal Navy, #D4AF37 Luxury Gold]",
                        client, title, briefContent);

                    string responseText = await CallGeminiApiAsync(apiKey, prompt);
                    if (!string.IsNullOrWhiteSpace(responseText))
                    {
                        return ParseBriefResponse(responseText);
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[GeminiDesktopService] Online brief validation failed, falling back to offline: " + ex.Message);
                }

                return PerformOfflineBriefValidation(briefContent, client, title);
            });
        }

        public static async Task<CopyPreflightReport> PreflightCopyAsync(string copyContent, string brand, string platform, string workspaceRoot)
        {
            return await Task.Run(async () =>
            {
                string apiKey = GetApiKey(workspaceRoot);
                if (string.IsNullOrWhiteSpace(apiKey))
                {
                    return PerformOfflineCopyPreflight(copyContent, brand, platform);
                }

                try
                {
                    string prompt = string.Format(
                        "You are an elite creative director and compliance auditor for SuamiSihat health brands in Malaysia.\n" +
                        "Audit this copywriting script for brand '{0}' on platform '{1}'.\n\n" +
                        "Copywriting Script:\n\"\"\"\n{2}\n\"\"\"\n\n" +
                        "Audit requirements:\n" +
                        "1. Tone: Must be masculine, authoritative, trustworthy, premium medical (not cheap clickbait).\n" +
                        "2. Regulatory (KKM / LIU): Flag any illegal cure claims (e.g., 'sembuh 100%', 'pasti pulih', unverified medical cures).\n" +
                        "3. Hook strength: Is the opening hook powerful within 3 seconds?\n" +
                        "4. CTA: Is the call to action clear and compelling?\n\n" +
                        "Format:\n" +
                        "SCORE: [0-100]\n" +
                        "VERDICT: [1-line tone verdict]\n" +
                        "REGULATORY_WARNINGS:\n- [warning or 'None identified']\n" +
                        "HOOK_SUGGESTIONS:\n- [improved hook variant]\n" +
                        "RECOMMENDATIONS:\n- [actionable tip]",
                        brand, platform, copyContent);

                    string responseText = await CallGeminiApiAsync(apiKey, prompt);
                    if (!string.IsNullOrWhiteSpace(responseText))
                    {
                        return ParseCopyPreflightResponse(responseText);
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[GeminiDesktopService] Online copy preflight failed, falling back to offline: " + ex.Message);
                }

                return PerformOfflineCopyPreflight(copyContent, brand, platform);
            });
        }

        private static async Task<string> CallGeminiApiAsync(string apiKey, string prompt)
        {
            string url = string.Format("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={0}", apiKey);
            string jsonBody = "{\"contents\":[{\"parts\":[{\"text\":\"" + EscapeJson(prompt) + "\"}]}]}";

            StringContent content = new StringContent(jsonBody, Encoding.UTF8, "application/json");
            HttpResponseMessage response = await _httpClient.PostAsync(url, content);

            if (!response.IsSuccessStatusCode)
            {
                string err = await response.Content.ReadAsStringAsync();
                throw new Exception("Gemini API error (" + response.StatusCode + "): " + err);
            }

            string responseJson = await response.Content.ReadAsStringAsync();
            Match textMatch = Regex.Match(responseJson, "\"text\"\\s*:\\s*\"([^\"]+)\"");
            if (textMatch.Success)
            {
                return UnescapeJson(textMatch.Groups[1].Value);
            }

            return null;
        }

        private static BriefValidationReport ParseBriefResponse(string text)
        {
            BriefValidationReport report = new BriefValidationReport();
            report.Score = 75;

            Match scoreMatch = Regex.Match(text, @"SCORE:\s*(\d+)");
            int s;
            if (scoreMatch.Success && int.TryParse(scoreMatch.Groups[1].Value, out s))
            {
                report.Score = Math.Min(100, Math.Max(0, s));
            }
            report.Passed = report.Score >= 70;

            ParseBulletSection(text, "STRENGTHS:", report.Strengths);
            ParseBulletSection(text, "MISSING:", report.MissingItems);
            ParseBulletSection(text, "RECOMMENDATIONS:", report.Recommendations);
            ParseBulletSection(text, "BRAND_TOKENS:", report.SuggestedBrandTokens);

            if (report.Strengths.Count == 0) report.Strengths.Add("Project structure established.");
            return report;
        }

        private static CopyPreflightReport ParseCopyPreflightResponse(string text)
        {
            CopyPreflightReport report = new CopyPreflightReport();
            report.Score = 80;

            Match scoreMatch = Regex.Match(text, @"SCORE:\s*(\d+)");
            int s;
            if (scoreMatch.Success && int.TryParse(scoreMatch.Groups[1].Value, out s))
            {
                report.Score = Math.Min(100, Math.Max(0, s));
            }

            Match verdictMatch = Regex.Match(text, @"VERDICT:\s*(.+)");
            if (verdictMatch.Success)
            {
                report.ToneVerdict = verdictMatch.Groups[1].Value.Trim();
            }
            else
            {
                report.ToneVerdict = "Masculine & Authoritative Voice";
            }

            ParseBulletSection(text, "REGULATORY_WARNINGS:", report.RegulatoryWarnings);
            ParseBulletSection(text, "HOOK_SUGGESTIONS:", report.HookSuggestions);
            ParseBulletSection(text, "RECOMMENDATIONS:", report.ActionableImprovements);

            return report;
        }

        private static void ParseBulletSection(string text, string header, List<string> targetList)
        {
            int idx = text.IndexOf(header, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) return;

            string remainder = text.Substring(idx + header.Length);
            string[] lines = remainder.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

            foreach (string line in lines)
            {
                string trimmed = line.Trim();
                if (string.IsNullOrWhiteSpace(trimmed)) continue;
                if (Regex.IsMatch(trimmed, @"^[A-Z_]+:")) break; // next section

                if (trimmed.StartsWith("-") || trimmed.StartsWith("•") || trimmed.StartsWith("*"))
                {
                    targetList.Add(trimmed.TrimStart('-', '•', '*', ' '));
                }
            }
        }

        private static BriefValidationReport PerformOfflineBriefValidation(string briefContent, string client, string title)
        {
            BriefValidationReport report = new BriefValidationReport();
            int score = 60;

            if (string.IsNullOrWhiteSpace(briefContent))
            {
                report.Score = 20;
                report.Passed = false;
                report.MissingItems.Add("Brief content is empty. Please define project objectives and deliverables.");
                report.Recommendations.Add("Use the H2 header buttons to structure Objectives, Specs, and Audience.");
                return report;
            }

            string lower = briefContent.ToLowerInvariant();

            // Check audience
            if (lower.Contains("audience") || lower.Contains("demographic") || lower.Contains("sasaran"))
            {
                score += 10;
                report.Strengths.Add("Target audience demographic identified.");
            }
            else
            {
                report.MissingItems.Add("Missing explicit target audience / demographic definition.");
            }

            // Check specs/deliverables
            if (lower.Contains("deliverable") || lower.Contains("spec") || lower.Contains("format") || lower.Contains("resolution") || lower.Contains("1080"))
            {
                score += 15;
                report.Strengths.Add("Clear deliverables and asset dimensions specified.");
            }
            else
            {
                report.MissingItems.Add("Missing asset dimensions, formats, or deliverables checklist.");
            }

            // Check deadline
            if (lower.Contains("deadline") || lower.Contains("tarikh") || lower.Contains("due"))
            {
                score += 10;
                report.Strengths.Add("Timeline and deadline guidance defined.");
            }

            // Master Brand Tokens
            report.SuggestedBrandTokens.Add("Primary Accent: #043388 (SuamiSihat Royal Navy)");
            report.SuggestedBrandTokens.Add("Luxury Accent: #D4AF37 (Canary Gold)");
            report.SuggestedBrandTokens.Add("Typography: Inter Display Bold / Plus Jakarta Sans");

            report.Score = Math.Min(100, score);
            report.Passed = report.Score >= 70;

            if (report.Recommendations.Count == 0)
            {
                report.Recommendations.Add("Ensure all creative deliverables link to official KKM pre-approved claim references.");
                report.Recommendations.Add("Include required 300 DPI CMYK bleed specifications if print or packaging is intended.");
            }

            return report;
        }

        private static CopyPreflightReport PerformOfflineCopyPreflight(string copyContent, string brand, string platform)
        {
            CopyPreflightReport report = new CopyPreflightReport();
            int score = 85;

            if (string.IsNullOrWhiteSpace(copyContent))
            {
                report.Score = 25;
                report.ToneVerdict = "Empty Script";
                report.RegulatoryWarnings.Add("Script is blank.");
                return report;
            }

            string lower = copyContent.ToLowerInvariant();

            // Prohibited KKM / health claim regex checks
            string[] prohibitedTerms = new[] { "sembuh 100%", "pasti sembuh", "ubat ajaib", "tiada kesan sampingan", "hilang selamanya", "dijamin sembuh" };
            foreach (string term in prohibitedTerms)
            {
                if (lower.Contains(term))
                {
                    report.RegulatoryWarnings.Add(string.Format("Prohibited medical claim detected: '{0}'. KKM regulations forbid absolute cure guarantees.", term));
                    score -= 20;
                }
            }

            // Hook check
            if (lower.Contains("hook") || lower.Contains("rahsia") || lower.Contains("tahukah anda") || lower.Contains("pernahkah"))
            {
                report.ToneVerdict = "Authoritative Masculine Tone (Strong Engagement)";
            }
            else
            {
                report.ToneVerdict = "Neutral Tone (Needs Pattern Interrupt Hook)";
                report.HookSuggestions.Add("\"Rahsia Tenaga Lelaki Sejati Kini Terbongkar — 100% Asli Tanpa Kompromi.\"");
                report.HookSuggestions.Add("\"Ramai lelaki salah sangka tentang punca keletihan kronik... Ini faktanya:\"");
                score -= 10;
            }

            // CTA check
            if (lower.Contains("cta") || lower.Contains("klik") || lower.Contains("tempah") || lower.Contains("dapatkan") || lower.Contains("whatsapp"))
            {
                report.ActionableImprovements.Add("Call to action present. Verify direct WhatsApp number or checkout URL formatting.");
            }
            else
            {
                report.ActionableImprovements.Add("Add an urgent Call to Action (e.g. [ Dapatkan Tawaran Eksklusif Sekarang ]).");
                score -= 15;
            }

            report.Score = Math.Max(10, Math.Min(100, score));
            return report;
        }

        private static string EscapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
        }

        private static string UnescapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\n", "\n").Replace("\\r", "\r").Replace("\\t", "\t").Replace("\\\"", "\"").Replace("\\\\", "\\");
        }
    }
}
