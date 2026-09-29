using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using SS_CAM.Models;

namespace SS_CAM.Services
{
    /// <summary>
    /// Result payload returned upon completion of a transcode execution.
    /// </summary>
    public class TranscodeResult
    {
        public bool Success { get; set; }
        public string OutputPath { get; set; }
        public long OutputSizeBytes { get; set; }
        public TimeSpan Duration { get; set; }
        public string ErrorMessage { get; set; }

        public TranscodeResult()
        {
            Success = false;
            OutputPath = "";
            OutputSizeBytes = 0;
            Duration = TimeSpan.Zero;
            ErrorMessage = "";
        }
    }

    /// <summary>
    /// Background execution service for FFmpeg-powered media conversions.
    /// Supports preset video and image transformations for web deliverables.
    /// </summary>
    public static class TranscoderService
    {
        private static readonly ConcurrentDictionary<string, Process> _activeProcesses = new ConcurrentDictionary<string, Process>();
        private static string _cachedFFmpegPath = null;
        private static string _cachedVersion = null;

        // ─── FFmpeg Discovery ─────────────────────────────────────────────────────

        /// <summary>
        /// Locates the ffmpeg.exe binary across UserProfile preferences,
        /// application payload directories, system PATH, and WinGet packages.
        /// </summary>
        public static string FindFFmpegPath()
        {
            if (!string.IsNullOrEmpty(_cachedFFmpegPath) && File.Exists(_cachedFFmpegPath))
            {
                return _cachedFFmpegPath;
            }

            try
            {
                // 1. Check user profile configuration
                var profile = UserProfileService.LoadProfile();
                if (profile != null && !string.IsNullOrEmpty(profile.FFmpegPath) && File.Exists(profile.FFmpegPath))
                {
                    _cachedFFmpegPath = profile.FFmpegPath;
                    return _cachedFFmpegPath;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] FindFFmpegPath profile check: " + ex.Message);
            }

            try
            {
                // 2. Check bundled payload folder
                string payloadDir = PayloadInstallerService.FindPayloadDirectory();
                if (!string.IsNullOrEmpty(payloadDir))
                {
                    string candidate = Path.Combine(payloadDir, "ffmpeg", "ffmpeg.exe");
                    if (File.Exists(candidate))
                    {
                        _cachedFFmpegPath = candidate;
                        return _cachedFFmpegPath;
                    }
                    candidate = Path.Combine(payloadDir, "ffmpeg", "bin", "ffmpeg.exe");
                    if (File.Exists(candidate))
                    {
                        _cachedFFmpegPath = candidate;
                        return _cachedFFmpegPath;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] FindFFmpegPath payload check: " + ex.Message);
            }

            try
            {
                // 3. Check system PATH
                string pathEnv = Environment.GetEnvironmentVariable("PATH");
                if (!string.IsNullOrEmpty(pathEnv))
                {
                    string[] paths = pathEnv.Split(Path.PathSeparator);
                    for (int i = 0; i < paths.Length; i++)
                    {
                        string p = paths[i].Trim();
                        if (string.IsNullOrEmpty(p)) continue;
                        try
                        {
                            string candidate = Path.Combine(p, "ffmpeg.exe");
                            if (File.Exists(candidate))
                            {
                                _cachedFFmpegPath = candidate;
                                return _cachedFFmpegPath;
                            }
                        }
                        catch (Exception exPath)
                        {
                            Debug.WriteLine("[TranscoderService] FindFFmpegPath PATH entry: " + exPath.Message);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] FindFFmpegPath PATH search: " + ex.Message);
            }

            try
            {
                // 4. Check WinGet standard packages in LocalAppData
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                if (!string.IsNullOrEmpty(localAppData))
                {
                    string wingetDir = Path.Combine(localAppData, "Microsoft", "WinGet", "Packages");
                    if (Directory.Exists(wingetDir))
                    {
                        string[] dirs = Directory.GetDirectories(wingetDir, "*Gyan.FFmpeg*");
                        for (int i = 0; i < dirs.Length; i++)
                        {
                            string[] files = Directory.GetFiles(dirs[i], "ffmpeg.exe", SearchOption.AllDirectories);
                            if (files.Length > 0 && File.Exists(files[0]))
                            {
                                _cachedFFmpegPath = files[0];
                                return _cachedFFmpegPath;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] FindFFmpegPath WinGet check: " + ex.Message);
            }

            try
            {
                // 5. Check fallback root C:\ffmpeg\bin\ffmpeg.exe
                string fallback = @"C:\ffmpeg\bin\ffmpeg.exe";
                if (File.Exists(fallback))
                {
                    _cachedFFmpegPath = fallback;
                    return _cachedFFmpegPath;
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] FindFFmpegPath root fallback: " + ex.Message);
            }

            return null;
        }

        /// <summary>
        /// Tests if FFmpeg is available and extracts version string.
        /// </summary>
        public static bool IsFFmpegAvailable(out string detectedPath, out string version)
        {
            detectedPath = FindFFmpegPath();
            version = _cachedVersion;

            if (string.IsNullOrEmpty(detectedPath) || !File.Exists(detectedPath))
            {
                detectedPath = null;
                version = null;
                return false;
            }

            if (!string.IsNullOrEmpty(_cachedVersion))
            {
                return true;
            }

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = detectedPath,
                    Arguments = "-version",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                };

                using (var proc = Process.Start(psi))
                {
                    if (proc != null)
                    {
                        string line = proc.StandardOutput.ReadLine();
                        proc.WaitForExit(3000);
                        if (!string.IsNullOrEmpty(line))
                        {
                            // "ffmpeg version 9.0-full_build..." -> "9.0"
                            var m = Regex.Match(line, @"ffmpeg\s+version\s+([^\s]+)", RegexOptions.IgnoreCase);
                            if (m.Success)
                            {
                                _cachedVersion = m.Groups[1].Value;
                            }
                            else
                            {
                                _cachedVersion = line.Trim();
                            }
                            version = _cachedVersion;
                            return true;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("[TranscoderService] IsFFmpegAvailable version probe: " + ex.Message);
            }

            _cachedVersion = "Detected";
            version = _cachedVersion;
            return true;
        }

        // ─── Preset Paths & Argument Builders ─────────────────────────────────────

        /// <summary>
        /// Derives canonical output destination path based on source file and chosen preset.
        /// </summary>
        public static string GetDefaultOutputPath(string sourcePath, TranscodePreset preset, string destinationFolder)
        {
            if (string.IsNullOrEmpty(sourcePath)) return "";

            string folder = !string.IsNullOrEmpty(destinationFolder) && Directory.Exists(destinationFolder)
                ? destinationFolder
                : Path.GetDirectoryName(sourcePath);

            if (string.IsNullOrEmpty(folder)) folder = AppDomain.CurrentDomain.BaseDirectory;

            string stem = Path.GetFileNameWithoutExtension(sourcePath);
            string suffix;
            string extension;

            switch (preset)
            {
                case TranscodePreset.WebP_Image:
                    suffix = "_web";
                    extension = ".webp";
                    break;
                case TranscodePreset.Avif_Image:
                    suffix = "_web";
                    extension = ".avif";
                    break;
                case TranscodePreset.WebM_Video:
                    suffix = "_web";
                    extension = ".webm";
                    break;
                case TranscodePreset.Social_Gif_10s:
                    suffix = "_social";
                    extension = ".gif";
                    break;
                case TranscodePreset.Mp4_Compress:
                    suffix = "_compressed";
                    extension = ".mp4";
                    break;
                default:
                    suffix = "_transcoded";
                    extension = Path.GetExtension(sourcePath);
                    break;
            }

            string targetFileName = stem + suffix + extension;
            return Path.Combine(folder, targetFileName);
        }

        /// <summary>
        /// Generates FFmpeg command-line arguments for the target preset.
        /// </summary>
        public static string BuildArguments(string sourcePath, string outputPath, TranscodePreset preset)
        {
            // Quote paths safely
            string src = "\"" + sourcePath + "\"";
            string dst = "\"" + outputPath + "\"";

            switch (preset)
            {
                case TranscodePreset.WebP_Image:
                    // High-quality lossy WebP for web delivery
                    return string.Format("-y -hide_banner -i {0} -c:v libwebp -quality 85 {1}", src, dst);

                case TranscodePreset.Avif_Image:
                    // AVIF still image compression
                    return string.Format("-y -hide_banner -i {0} -c:v libaom-av1 -crf 28 -b:v 0 {1}", src, dst);

                case TranscodePreset.WebM_Video:
                    // VP9 video with Opus audio for HTML5 playback
                    return string.Format("-y -hide_banner -i {0} -c:v libvpx-vp9 -b:v 0 -crf 30 -c:a libopus {1}", src, dst);

                case TranscodePreset.Social_Gif_10s:
                    // 10-second preview animated GIF at 15fps, 480px width, lanczos scaler
                    return string.Format("-y -hide_banner -i {0} -t 10 -vf \"fps=15,scale=480:-1:flags=lanczos\" {1}", src, dst);

                case TranscodePreset.Mp4_Compress:
                    // H.264 web-streamable MP4 with AAC audio and faststart moov atom
                    return string.Format("-y -hide_banner -i {0} -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -movflags +faststart {1}", src, dst);

                default:
                    return string.Format("-y -hide_banner -i {0} {1}", src, dst);
            }
        }

        // ─── Execution ────────────────────────────────────────────────────────────

        /// <summary>
        /// Executes a transcode job synchronously on the calling thread (intended for background task).
        /// Parses stderr in real-time to report percent progress.
        /// </summary>
        public static TranscodeResult ExecuteJob(TranscodeJob job, Action<int, string> progressCallback)
        {
            var result = new TranscodeResult();
            var sw = Stopwatch.StartNew();

            if (job == null)
            {
                result.ErrorMessage = "Job is null";
                return result;
            }

            if (!File.Exists(job.SourceFilePath))
            {
                result.ErrorMessage = "Source file does not exist: " + job.SourceFilePath;
                return result;
            }

            string ffmpegPath = FindFFmpegPath();
            if (string.IsNullOrEmpty(ffmpegPath) || !File.Exists(ffmpegPath))
            {
                result.ErrorMessage = "FFmpeg executable not found. Please install FFmpeg or set its path in Settings.";
                return result;
            }

            string outputDir = Path.GetDirectoryName(job.OutputFilePath);
            if (!string.IsNullOrEmpty(outputDir) && !Directory.Exists(outputDir))
            {
                try { Directory.CreateDirectory(outputDir); }
                catch (Exception ex)
                {
                    result.ErrorMessage = "Could not create output directory: " + ex.Message;
                    return result;
                }
            }

            // Record source size
            try
            {
                var fi = new FileInfo(job.SourceFilePath);
                job.SourceSizeBytes = fi.Length;
            }
            catch (Exception exFi)
            {
                Debug.WriteLine("[TranscoderService] FileInfo source read: " + exFi.Message);
            }

            string args = BuildArguments(job.SourceFilePath, job.OutputFilePath, job.Preset);

            var psi = new ProcessStartInfo
            {
                FileName = ffmpegPath,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };

            Process process = null;
            double totalSeconds = 0.0;
            string errorLog = "";

            try
            {
                process = new Process();
                process.StartInfo = psi;
                _activeProcesses[job.Id] = process;

                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (string.IsNullOrEmpty(e.Data)) return;

                    string line = e.Data;
                    errorLog += line + "\n";

                    // Check for Duration: 00:01:23.45
                    if (totalSeconds <= 0.0)
                    {
                        var mDuration = Regex.Match(line, @"Duration:\s*(\d{2}):(\d{2}):(\d{2})\.?(\d*)", RegexOptions.IgnoreCase);
                        if (mDuration.Success)
                        {
                            int h = int.Parse(mDuration.Groups[1].Value);
                            int m = int.Parse(mDuration.Groups[2].Value);
                            int s = int.Parse(mDuration.Groups[3].Value);
                            totalSeconds = (h * 3600) + (m * 60) + s;
                            if (job.Preset == TranscodePreset.Social_Gif_10s && totalSeconds > 10.0)
                            {
                                totalSeconds = 10.0;
                            }
                        }
                    }

                    // Check for time=00:00:12.34
                    var mTime = Regex.Match(line, @"time=\s*(\d{2}):(\d{2}):(\d{2})\.?(\d*)", RegexOptions.IgnoreCase);
                    if (mTime.Success)
                    {
                        int h = int.Parse(mTime.Groups[1].Value);
                        int m = int.Parse(mTime.Groups[2].Value);
                        int s = int.Parse(mTime.Groups[3].Value);
                        double currentSeconds = (h * 3600) + (m * 60) + s;

                        int percent = 0;
                        if (totalSeconds > 0.0)
                        {
                            percent = (int)Math.Min(98, Math.Max(1, (currentSeconds / totalSeconds) * 100.0));
                        }
                        else
                        {
                            percent = 50;
                        }

                        if (progressCallback != null)
                        {
                            progressCallback(percent, string.Format("Processing ({0}s / {1}s)...", (int)currentSeconds, (int)totalSeconds));
                        }
                    }
                };

                if (progressCallback != null) progressCallback(5, "Starting engine...");
                process.Start();
                process.BeginErrorReadLine();
                process.BeginOutputReadLine();

                process.WaitForExit();

                sw.Stop();
                result.Duration = sw.Elapsed;

                if (process.ExitCode == 0 && File.Exists(job.OutputFilePath))
                {
                    var outFi = new FileInfo(job.OutputFilePath);
                    if (outFi.Length > 0)
                    {
                        result.Success = true;
                        result.OutputPath = job.OutputFilePath;
                        result.OutputSizeBytes = outFi.Length;
                        if (progressCallback != null) progressCallback(100, "Done");
                    }
                    else
                    {
                        result.ErrorMessage = "Output file was created but has 0 bytes.";
                    }
                }
                else
                {
                    result.ErrorMessage = !string.IsNullOrEmpty(errorLog)
                        ? "FFmpeg process failed (Code " + process.ExitCode + "): " + GetRelevantError(errorLog)
                        : "Conversion failed with exit code " + process.ExitCode;
                }
            }
            catch (Exception ex)
            {
                sw.Stop();
                result.Duration = sw.Elapsed;
                result.ErrorMessage = "Exception during transcoding: " + ex.Message;
                Debug.WriteLine("[TranscoderService] ExecuteJob exception: " + ex.Message);
            }
            finally
            {
                Process dummy;
                _activeProcesses.TryRemove(job.Id, out dummy);
                if (process != null)
                {
                    try { process.Dispose(); }
                    catch (Exception ex) { Debug.WriteLine("[TranscoderService] process dispose: " + ex.Message); }
                }
            }

            return result;
        }

        /// <summary>
        /// Cancels an actively running job by killing its underlying FFmpeg process.
        /// </summary>
        public static bool CancelJob(string jobId)
        {
            if (string.IsNullOrEmpty(jobId)) return false;

            Process proc;
            if (_activeProcesses.TryGetValue(jobId, out proc))
            {
                try
                {
                    if (!proc.HasExited)
                    {
                        proc.Kill();
                        return true;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[TranscoderService] CancelJob: " + ex.Message);
                }
            }
            return false;
        }

        /// <summary>
        /// Cancels all active transcoding jobs.
        /// </summary>
        public static void CancelAll()
        {
            foreach (var kvp in _activeProcesses)
            {
                try
                {
                    if (kvp.Value != null && !kvp.Value.HasExited)
                    {
                        kvp.Value.Kill();
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine("[TranscoderService] CancelAll: " + ex.Message);
                }
            }
            _activeProcesses.Clear();
        }

        private static string GetRelevantError(string log)
        {
            if (string.IsNullOrEmpty(log)) return "";
            string[] lines = log.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
            for (int i = lines.Length - 1; i >= 0; i--)
            {
                string line = lines[i].Trim();
                if (line.IndexOf("error", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    line.IndexOf("invalid", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    line.IndexOf("failed", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return line;
                }
            }
            return lines.Length > 0 ? lines[lines.Length - 1] : "Unknown error";
        }
    }
}
